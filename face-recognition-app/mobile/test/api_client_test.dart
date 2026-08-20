import 'dart:convert';
import 'dart:io';

import 'package:facerec_app/api_client.dart';
import 'package:facerec_app/models.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:http/http.dart' as http;
import 'package:http/testing.dart';

void main() {
  late Directory tempDir;
  late File photo;

  setUp(() async {
    tempDir = await Directory.systemTemp.createTemp('facerec_test');
    photo = File('${tempDir.path}/probe.jpg')..writeAsBytesSync([1, 2, 3]);
  });

  tearDown(() => tempDir.deleteSync(recursive: true));

  test('search parses decision and ranked matches', () async {
    final client = ApiClient(
      baseUrl: 'http://api.test',
      client: MockClient((request) async {
        expect(request.url.path, '/v1/search');
        return http.Response(
          jsonEncode({
            'decision': 'match',
            'threshold': 0.42,
            'results': [
              {
                'person_id': 'p1',
                'display_name': 'Alice',
                'face_id': 'f1',
                'score': 0.81,
                'image_url': 'http://minio/alice.jpg',
              },
            ],
          }),
          200,
        );
      }),
    );

    final result = await client.search(image: photo);

    expect(result.decision, Decision.match);
    expect(result.results.single.displayName, 'Alice');
    expect(result.results.single.score, closeTo(0.81, 1e-9));
  });

  test('enroll surfaces quality-gate reasons from a 422', () async {
    final client = ApiClient(
      baseUrl: 'http://api.test',
      client: MockClient((request) async {
        return http.Response(
          jsonEncode({
            'detail': {
              'error': 'photo quality too low for enrolment',
              'reasons': ['face too small (101px < 112px)'],
            },
          }),
          422,
        );
      }),
    );

    expect(
      () => client.enroll(image: photo, personName: 'Alice'),
      throwsA(
        isA<ApiException>()
            .having((e) => e.reasons, 'reasons', contains(contains('face too small'))),
      ),
    );
  });

  test('a plain string detail becomes the error message', () async {
    final client = ApiClient(
      baseUrl: 'http://api.test',
      client: MockClient((request) async {
        return http.Response(jsonEncode({'detail': 'no face detected'}), 422);
      }),
    );

    expect(
      () => client.search(image: photo),
      throwsA(isA<ApiException>().having((e) => e.message, 'message', 'no face detected')),
    );
  });
}
