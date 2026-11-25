import 'dart:async';
import 'dart:convert';

import 'package:http/http.dart' as http;

class UploadedCasePhoto {
  const UploadedCasePhoto({
    required this.id,
    required this.imageUrl,
    required this.createdAt,
    this.quality,
  });

  factory UploadedCasePhoto.fromJson(Map<String, Object?> json) {
    return UploadedCasePhoto(
      id: json['id']! as String,
      imageUrl: json['image_url']! as String,
      quality: (json['quality'] as num?)?.toDouble(),
      createdAt: DateTime.parse(json['created_at']! as String).toLocal(),
    );
  }

  final String id;
  final String imageUrl;
  final double? quality;
  final DateTime createdAt;
}

class UploadedCase {
  const UploadedCase({
    required this.id,
    required this.caseType,
    required this.subjectLabel,
    required this.status,
    required this.matchCount,
    required this.matchState,
    required this.photos,
    required this.createdAt,
    this.myImageUrl,
    this.otherImageUrl,
  });

  factory UploadedCase.fromJson(Map<String, Object?> json) {
    return UploadedCase(
      id: json['id']! as String,
      caseType: json['case_type']! as String,
      subjectLabel: json['subject_label']! as String,
      status: json['status']! as String,
      matchCount: (json['match_count']! as num).toInt(),
      matchState: json['match_state']! as String,
      photos: (json['photos']! as List<Object?>)
          .map(
            (value) => UploadedCasePhoto.fromJson(
              value! as Map<String, Object?>,
            ),
          )
          .toList(),
      createdAt: DateTime.parse(json['created_at']! as String).toLocal(),
      myImageUrl: json['my_image_url'] as String?,
      otherImageUrl: json['other_image_url'] as String?,
    );
  }

  final String id;
  final String caseType;
  final String subjectLabel;
  final String status;
  final int matchCount;
  final String matchState;
  final List<UploadedCasePhoto> photos;
  final DateTime createdAt;
  final String? myImageUrl;
  final String? otherImageUrl;

  bool get hasMatchedPhotoPair => myImageUrl != null && otherImageUrl != null;
}

class CaseRepository {
  CaseRepository({
    required this.baseUrl,
    required this.tokenProvider,
    required this.onAuthenticationFailure,
    http.Client? client,
  }) : _client = client ?? http.Client();

  final String baseUrl;
  final Future<String?> Function() tokenProvider;
  final Future<void> Function() onAuthenticationFailure;
  final http.Client _client;

  Future<List<UploadedCase>> list() async {
    final token = await tokenProvider();
    if (token == null) {
      await onAuthenticationFailure();
      throw const CaseRepositoryException(
        'Your session expired. Sign in again to continue.',
      );
    }
    try {
      final response = await _client.get(
        Uri.parse('$baseUrl/v1/cases'),
        headers: {'Authorization': 'Bearer $token'},
      ).timeout(const Duration(seconds: 15));
      final payload = response.body.isEmpty
          ? <String, Object?>{}
          : jsonDecode(response.body) as Map<String, Object?>;
      if (response.statusCode == 401) {
        await onAuthenticationFailure();
        throw const CaseRepositoryException(
          'Your session expired. Sign in again to continue.',
        );
      }
      if (response.statusCode < 200 || response.statusCode >= 300) {
        throw CaseRepositoryException(
          payload['detail']?.toString() ??
              'Your uploaded cases could not be loaded.',
        );
      }
      return (payload['results']! as List<Object?>)
          .map(
            (value) => UploadedCase.fromJson(
              value! as Map<String, Object?>,
            ),
          )
          .toList();
    } on TimeoutException {
      throw const CaseRepositoryException(
        'Loading your cases timed out. Try again.',
      );
    } on http.ClientException {
      throw const CaseRepositoryException(
        'Your cases are temporarily unavailable.',
      );
    } on FormatException {
      throw const CaseRepositoryException(
        'The case service returned invalid data.',
      );
    }
  }
}

class CaseRepositoryException implements Exception {
  const CaseRepositoryException(this.message);

  final String message;

  @override
  String toString() => message;
}
