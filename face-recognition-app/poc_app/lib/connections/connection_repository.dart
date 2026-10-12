import 'dart:async';
import 'dart:convert';

import 'package:http/http.dart' as http;

class MatchConnection {
  const MatchConnection({
    required this.id,
    required this.role,
    required this.status,
    required this.otherSubjectLabel,
    required this.score,
    required this.myConsented,
    required this.otherConsented,
    required this.myVerifiedPeer,
    required this.otherVerifiedPeer,
    required this.unread,
    required this.createdAt,
    this.imageUrl,
    this.meetingCode,
    this.meetingCodeExpiresAt,
  });

  factory MatchConnection.fromJson(Map<String, Object?> json) {
    return MatchConnection(
      id: json['id']! as String,
      role: json['role']! as String,
      status: json['status']! as String,
      otherSubjectLabel: json['other_subject_label']! as String,
      score: (json['score']! as num).toDouble(),
      imageUrl: json['image_url'] as String?,
      myConsented: json['my_consented']! as bool,
      otherConsented: json['other_consented']! as bool,
      myVerifiedPeer: json['my_verified_peer']! as bool,
      otherVerifiedPeer: json['other_verified_peer']! as bool,
      unread: json['unread']! as bool,
      meetingCode: json['meeting_code'] as String?,
      meetingCodeExpiresAt: json['meeting_code_expires_at'] == null
          ? null
          : DateTime.parse(
              json['meeting_code_expires_at']! as String,
            ).toLocal(),
      createdAt: DateTime.parse(json['created_at']! as String).toLocal(),
    );
  }

  final String id;
  final String role;
  final String status;
  final String otherSubjectLabel;
  final double score;
  final String? imageUrl;
  final bool myConsented;
  final bool otherConsented;
  final bool myVerifiedPeer;
  final bool otherVerifiedPeer;
  final bool unread;
  final String? meetingCode;
  final DateTime? meetingCodeExpiresAt;
  final DateTime createdAt;
}

class ConnectionRepository {
  ConnectionRepository({
    required this.baseUrl,
    required this.tokenProvider,
    required this.onAuthenticationFailure,
    http.Client? client,
  }) : _client = client ?? http.Client();

  final String baseUrl;
  final Future<String?> Function() tokenProvider;
  final Future<void> Function() onAuthenticationFailure;
  final http.Client _client;

  Future<List<MatchConnection>> list() async {
    final payload = await _request('GET', '/v1/connections');
    final results = payload['results']! as List<Object?>;
    return results
        .map(
          (value) => MatchConnection.fromJson(
            value! as Map<String, Object?>,
          ),
        )
        .toList();
  }

  Future<MatchConnection> markRead(String connectionId) =>
      _action('/v1/connections/$connectionId/read');

  Future<MatchConnection> consent(String connectionId) =>
      _action('/v1/connections/$connectionId/consent');

  Future<MatchConnection> withdrawConsent(String connectionId) =>
      _action('/v1/connections/$connectionId/withdraw-consent');

  Future<MatchConnection> renewMeetingCode(String connectionId) =>
      _action('/v1/connections/$connectionId/meeting-code/renew');

  Future<MatchConnection> verifyMeetingCode(
    String connectionId,
    String code,
  ) async {
    final payload = await _request(
      'POST',
      '/v1/connections/$connectionId/meeting-code/verify',
      body: {'code': code},
    );
    return MatchConnection.fromJson(payload);
  }

  Future<MatchConnection> _action(String path) async {
    final payload = await _request('POST', path);
    return MatchConnection.fromJson(payload);
  }

  Future<Map<String, Object?>> _request(
    String method,
    String path, {
    Map<String, Object?>? body,
  }) async {
    final token = await tokenProvider();
    if (token == null) {
      await onAuthenticationFailure();
      throw const ConnectionException(
        'Your session expired. Sign in again to continue.',
      );
    }
    try {
      final request = http.Request(method, Uri.parse('$baseUrl$path'))
        ..headers['Authorization'] = 'Bearer $token'
        ..headers['Content-Type'] = 'application/json';
      if (body != null) {
        request.body = jsonEncode(body);
      }
      final streamed = await _client.send(request).timeout(
            const Duration(seconds: 15),
          );
      final response = await http.Response.fromStream(streamed);
      final payload = response.body.isEmpty
          ? <String, Object?>{}
          : jsonDecode(response.body) as Map<String, Object?>;
      if (response.statusCode == 401) {
        await onAuthenticationFailure();
        throw const ConnectionException(
          'Your session expired. Sign in again to continue.',
        );
      }
      if (response.statusCode < 200 || response.statusCode >= 300) {
        throw ConnectionException(
          payload['detail']?.toString() ??
              'The connection service could not complete this request.',
        );
      }
      return payload;
    } on TimeoutException {
      throw const ConnectionException(
        'The connection service timed out. Try again.',
      );
    } on http.ClientException {
      throw const ConnectionException(
        'The connection service is unavailable.',
      );
    } on FormatException {
      throw const ConnectionException(
        'The connection service returned invalid data.',
      );
    }
  }
}

class ConnectionException implements Exception {
  const ConnectionException(this.message);

  final String message;

  @override
  String toString() => message;
}
