import 'dart:convert';
import 'dart:typed_data';

import 'package:flutter_test/flutter_test.dart';
import 'package:http/http.dart' as http;
import 'package:http/testing.dart';
import 'package:poc_app/matching/remote_matcher.dart';
import 'package:poc_app/models.dart';

void main() {
  test('uploads the role and maps remote match candidates', () async {
    final client = MockClient((request) async {
      expect(request.url.toString(), 'https://api.example.com/v1/cases');
      expect(request.method, 'POST');
      expect(request.headers['authorization'], 'Bearer access-token');
      expect(
        request.headers['x-installation-id'],
        'f6bb3c98-6841-4ab4-93bb-8d9b80d8f4a3',
      );
      expect(request.body, contains('name="case_type"'));
      expect(request.body, contains('found'));
      expect(request.body, contains('name="top_k"'));
      expect(request.body, contains('3'));
      expect(request.body, contains('filename="photo.jpg"'));
      return http.Response(
        jsonEncode({
          'case_id': '79ed0d79-6341-4fee-9155-5942e90c531f',
          'case_type': 'found',
          'subject_label': 'Found person submission',
          'quality': {
            'face_pixels': 160,
            'det_score': 0.99,
            'blur_variance': 140,
            'yaw_degrees': 2,
            'score': 0.93,
            'passed': true,
            'reasons': <String>[],
          },
          'match': {
            'decision': 'match',
            'threshold': 0.42,
            'results': [
              {
                'case_id': 'd1466de1-e081-4f70-97cc-9899592f09e7',
                'subject_label': 'Missing person submission',
                'score': 0.88,
                'image_url': 'https://images.example.com/candidate.jpg',
              },
            ],
          },
        }),
        201,
      );
    });
    final matcher = RemoteMatcher(
      baseUrl: 'https://api.example.com',
      client: client,
      tokenProvider: () async => 'access-token',
      installationIdProvider: () async =>
          'f6bb3c98-6841-4ab4-93bb-8d9b80d8f4a3',
    );

    final outcome = await matcher.match(
      probe: Uint8List.fromList([1, 2, 3]),
      gallery: const [],
      caseType: CaseType.found,
      fileName: 'photo.jpg',
      topK: 3,
    );

    expect(outcome.decision, Decision.match);
    expect(outcome.matcherName, 'ArcFace (remote service)');
    expect(outcome.best!.image.label, 'Missing person submission');
    expect(
      outcome.best!.image.remoteUrl,
      'https://images.example.com/candidate.jpg',
    );
  });

  test('surfaces remote quality errors', () async {
    final client = MockClient(
      (_) async => http.Response(
        jsonEncode({
          'detail': {
            'error': 'photo quality too low for recognition',
            'reasons': ['face too small', 'image too blurry'],
          },
        }),
        422,
      ),
    );
    final matcher = RemoteMatcher(
      baseUrl: 'https://api.example.com',
      client: client,
    );

    expect(
      () => matcher.match(
        probe: Uint8List.fromList([1, 2, 3]),
        gallery: const [],
        caseType: CaseType.missing,
        fileName: 'photo.jpg',
      ),
      throwsA(
        isA<RemoteRecognitionException>().having(
          (error) => error.message,
          'message',
          'face too small, image too blurry',
        ),
      ),
    );
  });

  test('clears authentication when the remote session is rejected', () async {
    var authenticationFailureHandled = false;
    final matcher = RemoteMatcher(
      baseUrl: 'https://api.example.com',
      client: MockClient(
        (_) async => http.Response(
          jsonEncode({'detail': 'valid authentication is required'}),
          401,
        ),
      ),
      tokenProvider: () async => 'revoked-access-token',
      onAuthenticationFailure: () async {
        authenticationFailureHandled = true;
      },
    );

    await expectLater(
      matcher.match(
        probe: Uint8List.fromList([1, 2, 3]),
        gallery: const [],
        caseType: CaseType.found,
        fileName: 'photo.jpg',
      ),
      throwsA(
        isA<RemoteRecognitionException>().having(
          (error) => error.message,
          'message',
          'Your session expired. Sign in again to continue.',
        ),
      ),
    );
    expect(authenticationFailureHandled, isTrue);
  });
}
