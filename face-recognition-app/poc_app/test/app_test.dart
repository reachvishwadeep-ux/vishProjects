import 'dart:convert';
import 'dart:io';
import 'dart:typed_data';

import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:http/http.dart' as http;
import 'package:http/testing.dart';
import 'package:image/image.dart' as img;
import 'package:poc_app/connections/connection_repository.dart';
import 'package:poc_app/app_state.dart';
import 'package:poc_app/main.dart';
import 'package:poc_app/matching/perceptual_matcher.dart';
import 'package:poc_app/matching/signature.dart';
import 'package:poc_app/models.dart';
import 'package:poc_app/repository/gallery_repository.dart';
import 'package:poc_app/screens/result_screen.dart';
import 'package:poc_app/theme.dart';

Uint8List _jpeg() {
  final image = img.Image(width: 128, height: 128);
  img.fill(image, color: img.ColorRgb8(30, 120, 200));
  return Uint8List.fromList(img.encodeJpg(image));
}

void main() {
  late Directory root;
  late AppState state;

  setUp(() {
    root = Directory.systemTemp.createTempSync('app_test');
    state = AppState(
      repository: GalleryRepository(root: root),
      matcher: const PerceptualMatcher(),
    );
  });
  tearDown(() => root.deleteSync(recursive: true));

  testWidgets('starts on the upload tab and exposes the redesigned flow',
      (tester) async {
    await tester.runAsync(() async {
      await tester.pumpWidget(PocApp(state: state));
      await Future<void>.delayed(const Duration(milliseconds: 100));
    });
    await tester.pumpAndSettle();

    expect(find.text('ReuniteNow'), findsOneWidget);
    expect(find.text('Search for a Missing Person'), findsOneWidget);
    expect(
      find.textContaining(
        'This app supports the search for missing people by face recognition',
      ),
      findsOneWidget,
    );
    expect(find.text('I’m looking for someone'), findsOneWidget);
    expect(find.text('I found someone'), findsOneWidget);

    await tester.scrollUntilVisible(
      find.text('Choose up to 5 from Gallery'),
      300,
      scrollable: find.byType(Scrollable).first,
    );
    expect(find.text('Choose up to 5 from Gallery'), findsOneWidget);

    await tester.scrollUntilVisible(
      find.textContaining('A simple background can help face detection'),
      300,
      scrollable: find.byType(Scrollable).first,
    );
    expect(
      find.textContaining('A simple background can help face detection'),
      findsOneWidget,
    );

    await tester.tap(find.text('My Cases'));
    await tester.pumpAndSettle();

    expect(find.text('No uploaded cases yet'), findsOneWidget);

    await tester.tap(find.text('Saved Info'));
    await tester.pumpAndSettle();

    expect(find.text('No saved images yet'), findsOneWidget);
  });

  testWidgets('stored images appear in the repository tab', (tester) async {
    // Adding hashes in a real isolate, so it has to run outside the fake clock.
    await tester.runAsync(
      () => state.addImage(bytes: _jpeg(), label: 'Amber Ridge'),
    );

    await tester.pumpWidget(PocApp(state: state));
    await tester.pumpAndSettle();

    await tester.tap(find.text('Saved Info'));
    await tester.pumpAndSettle();

    expect(find.text('Amber Ridge'), findsOneWidget);
    expect(find.textContaining('1 saved image'), findsOneWidget);
  });

  testWidgets('the result screen reports a match with its candidates',
      (tester) async {
    final bytes = _jpeg();
    final signature = ImageSignature.fromBytes(bytes)!;
    final file = File('${root.path}/amber.jpg')..writeAsBytesSync(bytes);
    final stored = StoredImage(
      id: 'amber',
      label: 'Amber Ridge',
      path: file.path,
      signature: signature,
      addedAt: DateTime(2024),
    );

    await tester.pumpWidget(
      MaterialApp(
        theme: buildTheme(Brightness.light),
        home: ResultScreen(
          probe: bytes,
          outcome: MatchOutcome(
            decision: Decision.match,
            candidates: [
              MatchCandidate(
                image: stored,
                score: 0.97,
                structureScore: 0.98,
                colourScore: 0.94,
              ),
            ],
            matcherName: 'Perceptual hash (on-device)',
            duration: const Duration(milliseconds: 12),
            comparisons: 1,
          ),
        ),
      ),
    );
    await tester.pumpAndSettle();

    expect(find.text('MATCH FOUND!'), findsOneWidget);
    expect(find.text('Potential match found'), findsOneWidget);
    expect(find.text('Amber Ridge'), findsOneWidget);
    expect(find.text('97%'), findsOneWidget);
  });

  testWidgets('requesting a secure connection opens that match consent page',
      (tester) async {
    final bytes = _jpeg();
    final requests = <String>[];
    final connections = ConnectionRepository(
      baseUrl: 'https://api.example.com',
      tokenProvider: () async => 'access-token',
      onAuthenticationFailure: () async {},
      client: MockClient((request) async {
        requests.add('${request.method} ${request.url.path}');
        return http.Response(
          jsonEncode({
            'results': [
              {
                'id': 'other-connection',
                'role': 'missing',
                'status': 'pending_consent',
                'my_case_id': 'my-case',
                'other_case_id': 'other-case',
                'other_subject_label': 'Unrelated case',
                'score': 0.8,
                'image_url': null,
                'my_consented': false,
                'other_consented': false,
                'my_contact_sharing_consented': true,
                'other_contact_sharing_consented': true,
                'other_phone_number': '+919000000003',
                'my_verified_peer': false,
                'other_verified_peer': false,
                'unread': true,
                'meeting_code': null,
                'meeting_code_expires_at': null,
                'created_at': '2026-10-01T12:00:00Z',
              },
              {
                'id': 'matched-connection',
                'role': 'missing',
                'status': 'pending_consent',
                'my_case_id': 'my-case',
                'other_case_id': 'found-case',
                'other_subject_label': 'Possible found-person case',
                'score': 0.88,
                'image_url': null,
                'my_consented': false,
                'other_consented': false,
                'my_contact_sharing_consented': true,
                'other_contact_sharing_consented': true,
                'other_phone_number': '+919000000002',
                'my_verified_peer': false,
                'other_verified_peer': false,
                'unread': true,
                'meeting_code': null,
                'meeting_code_expires_at': null,
                'created_at': '2026-10-01T12:00:00Z',
              },
            ],
          }),
          200,
        );
      }),
    );

    await tester.pumpWidget(
      MaterialApp(
        theme: buildTheme(Brightness.light),
        home: ResultScreen(
          probe: bytes,
          connections: connections,
          outcome: MatchOutcome(
            decision: Decision.match,
            candidates: [
              MatchCandidate(
                image: StoredImage.remote(
                  id: 'found-case',
                  label: 'Found person submission',
                  remoteUrl: null,
                ),
                score: 0.88,
                structureScore: 0.88,
                colourScore: 0.88,
                connectionId: 'matched-connection',
              ),
            ],
            matcherName: 'ArcFace (remote service)',
            duration: const Duration(milliseconds: 12),
            comparisons: 1,
          ),
        ),
      ),
    );
    await tester.pumpAndSettle();

    await tester.scrollUntilVisible(
      find.text('View matched contact'),
      300,
      scrollable: find.byType(Scrollable).first,
    );
    await tester.tap(find.text('View matched contact'));
    await tester.pumpAndSettle();

    expect(requests, ['GET /v1/connections']);
    expect(find.text('Secure connection'), findsOneWidget);
    expect(find.text('Possible found-person case'), findsOneWidget);
    expect(find.text('Unrelated case'), findsNothing);
    expect(find.text('+919000000002'), findsOneWidget);
    expect(
      find.text('Secure contact requests are not enabled yet.'),
      findsNothing,
    );
  });
}
