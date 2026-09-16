import 'dart:async';
import 'dart:convert';
import 'dart:typed_data';

import 'package:http/http.dart' as http;

import '../models.dart';
import 'matcher.dart';

class RemoteMatcher implements Matcher {
  RemoteMatcher({
    required this.baseUrl,
    http.Client? client,
  }) : _client = client ?? http.Client();

  final String baseUrl;
  final http.Client _client;

  @override
  String get name => 'ArcFace (remote service)';

  @override
  Future<MatchOutcome> match({
    required Uint8List probe,
    required List<StoredImage> gallery,
    required CaseType caseType,
    required String fileName,
    int topK = 5,
  }) async {
    final stopwatch = Stopwatch()..start();
    final request = http.MultipartRequest(
      'POST',
      Uri.parse('$baseUrl/v1/cases'),
    )
      ..fields['case_type'] = caseType.name
      ..fields['subject_label'] = _subjectLabel(caseType)
      ..fields['top_k'] = topK.toString()
      ..files.add(
        http.MultipartFile.fromBytes(
          'image',
          probe,
          filename: fileName,
        ),
      );

    final streamed = await _client.send(request).timeout(
          const Duration(seconds: 120),
          onTimeout: () => throw const RemoteRecognitionException(
            'The recognition service did not respond in time.',
          ),
        );
    final response = await http.Response.fromStream(streamed);
    if (response.statusCode != 201) {
      throw RemoteRecognitionException(_errorMessage(response));
    }

    final payload = jsonDecode(response.body) as Map<String, Object?>;
    final match = payload['match']! as Map<String, Object?>;
    final results = (match['results']! as List<Object?>)
        .cast<Map<String, Object?>>()
        .map(
          (item) => MatchCandidate(
            image: StoredImage.remote(
              id: item['case_id']! as String,
              label: item['subject_label']! as String,
              remoteUrl: item['image_url'] as String?,
            ),
            score: (item['score']! as num).toDouble(),
            structureScore: (item['score']! as num).toDouble(),
            colourScore: (item['score']! as num).toDouble(),
          ),
        )
        .toList();

    stopwatch.stop();
    return MatchOutcome(
      decision: _decision(match['decision']! as String),
      candidates: results,
      matcherName: name,
      duration: stopwatch.elapsed,
      comparisons: results.length,
    );
  }

  String _subjectLabel(CaseType caseType) {
    return caseType == CaseType.missing
        ? 'Missing person submission'
        : 'Found person submission';
  }

  Decision _decision(String value) {
    return switch (value) {
      'match' => Decision.match,
      'review' => Decision.review,
      _ => Decision.noMatch,
    };
  }

  String _errorMessage(http.Response response) {
    try {
      final payload = jsonDecode(response.body) as Map<String, Object?>;
      final detail = payload['detail'];
      if (detail is String) {
        return detail;
      }
      if (detail is Map<String, Object?>) {
        final reasons = detail['reasons'];
        if (reasons is List<Object?> && reasons.isNotEmpty) {
          return reasons.join(', ');
        }
        return detail['error']?.toString() ?? 'Remote recognition failed.';
      }
    } on FormatException {
      return 'Remote recognition failed (${response.statusCode}).';
    }
    return 'Remote recognition failed (${response.statusCode}).';
  }
}

class RemoteRecognitionException implements Exception {
  const RemoteRecognitionException(this.message);

  final String message;

  @override
  String toString() => message;
}
