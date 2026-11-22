import 'dart:convert';

import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:http/http.dart' as http;
import 'package:http/testing.dart';
import 'package:poc_app/connections/connection_repository.dart';
import 'package:poc_app/screens/my_matches_screen.dart';
import 'package:poc_app/theme.dart';

Map<String, Object?> _connection({
  bool myConsented = false,
  bool otherConsented = false,
  bool unread = true,
  String status = 'pending_consent',
  String? meetingCode,
  bool myVerifiedPeer = false,
  bool otherVerifiedPeer = false,
  String? meetingCodeExpiresAt,
}) {
  return {
    'id': '0d43113f-40b4-4444-a6eb-c29a77b79d2a',
    'role': 'missing',
    'status': status,
    'my_case_id': 'cb6b985c-b258-47f1-91bc-fd8d2dc9122a',
    'other_case_id': '5c17190c-a719-4639-8bf9-9272f45f19ef',
    'other_subject_label': 'Possible found-person case',
    'score': 0.81,
    'image_url': null,
    'my_consented': myConsented,
    'other_consented': otherConsented,
    'my_verified_peer': myVerifiedPeer,
    'other_verified_peer': otherVerifiedPeer,
    'unread': unread,
    'meeting_code': meetingCode,
    'meeting_code_expires_at': meetingCodeExpiresAt ??
        (meetingCode == null ? null : '2030-01-01T12:00:00Z'),
    'created_at': '2026-10-01T12:00:00Z',
  };
}

Map<String, Object?> _matchHistory({
  bool sameAccount = true,
  String? connectionId,
}) {
  return {
    'id': 'b975ec71-ad73-4c50-a449-8fb40406b150',
    'role': sameAccount ? 'both' : 'missing',
    'missing_case_id': '7c40725a-3000-43f7-b24d-12d6daea4b5d',
    'found_case_id': '1bf35de6-3945-450c-b05c-322bb76bfaca',
    'missing_subject_label': 'Previous missing report',
    'found_subject_label': 'Latest found report',
    'score': 0.78,
    'decision': 'match',
    'image_url': null,
    'same_account': sameAccount,
    'connection_id': connectionId,
    'connection_status': connectionId == null ? null : 'pending_consent',
    'created_at': '2026-10-02T12:00:00Z',
  };
}

ConnectionRepository _repository(MockClient client) {
  return ConnectionRepository(
    baseUrl: 'https://api.example.com',
    tokenProvider: () async => 'access-token',
    onAuthenticationFailure: () async {},
    client: client,
  );
}

void main() {
  test('lists authenticated match connections', () async {
    final repository = _repository(
      MockClient((request) async {
        expect(request.method, 'GET');
        expect(request.url.path, '/v1/connections');
        expect(request.headers['authorization'], 'Bearer access-token');
        return http.Response(
          jsonEncode({
            'results': [_connection()],
          }),
          200,
        );
      }),
    );

    final connections = await repository.list();

    expect(connections, hasLength(1));
    expect(connections.single.otherSubjectLabel, 'Possible found-person case');
    expect(connections.single.score, 0.81);
    expect(connections.single.unread, isTrue);
  });

  test('lists authenticated current and previous match history', () async {
    final repository = _repository(
      MockClient((request) async {
        expect(request.method, 'GET');
        expect(request.url.path, '/v1/connections/matches');
        expect(request.headers['authorization'], 'Bearer access-token');
        return http.Response(
          jsonEncode({
            'results': [_matchHistory()],
          }),
          200,
        );
      }),
    );

    final matches = await repository.listMatches();

    expect(matches, hasLength(1));
    expect(matches.single.role, 'both');
    expect(matches.single.sameAccount, isTrue);
    expect(matches.single.connectionId, isNull);
  });

  test('submits consent and a peer meeting code', () async {
    var requestCount = 0;
    final repository = _repository(
      MockClient((request) async {
        requestCount += 1;
        if (requestCount == 1) {
          expect(request.url.path, contains('/consent'));
          return http.Response(
            jsonEncode(_connection(myConsented: true)),
            200,
          );
        }
        expect(request.url.path, contains('/meeting-code/verify'));
        expect(jsonDecode(request.body)['code'], '123456');
        return http.Response(
          jsonEncode(
            _connection(
              myConsented: true,
              otherConsented: true,
              status: 'ready_to_meet',
              meetingCode: '654321',
            ),
          ),
          200,
        );
      }),
    );

    final consented = await repository.consent(
      '0d43113f-40b4-4444-a6eb-c29a77b79d2a',
    );
    final verified = await repository.verifyMeetingCode(
      '0d43113f-40b4-4444-a6eb-c29a77b79d2a',
      '123456',
    );

    expect(consented.myConsented, isTrue);
    expect(verified.meetingCode, '654321');
  });

  testWidgets('match screen renders consent and privacy safeguards',
      (tester) async {
    final repository = _repository(
      MockClient((request) async {
        if (request.url.path == '/v1/connections/matches') {
          return http.Response(jsonEncode({'results': []}), 200);
        }
        return http.Response(
          jsonEncode({
            'results': [_connection()],
          }),
          200,
        );
      }),
    );
    await tester.pumpWidget(
      MaterialApp(
        theme: buildTheme(Brightness.light),
        home: MyMatchesScreen(repository: repository),
      ),
    );
    await tester.pumpAndSettle();

    expect(find.text('Possible found-person case'), findsOneWidget);
    expect(find.text('Consent to a safe meeting'), findsOneWidget);
    expect(find.text('Private by design'), findsOneWidget);
    expect(
      find.textContaining('Meeting codes confirm account presence'),
      findsOneWidget,
    );
  });

  testWidgets('match screen shows same-account current and previous matches',
      (tester) async {
    final repository = _repository(
      MockClient((request) async {
        if (request.url.path == '/v1/connections/matches') {
          return http.Response(
            jsonEncode({
              'results': [_matchHistory()],
            }),
            200,
          );
        }
        return http.Response(jsonEncode({'results': []}), 200);
      }),
    );
    await tester.pumpWidget(
      MaterialApp(
        theme: buildTheme(Brightness.light),
        home: MyMatchesScreen(repository: repository),
      ),
    );
    await tester.pumpAndSettle();

    expect(find.text('Potential match history'), findsOneWidget);
    expect(
      find.text('Previous missing report ↔ Latest found report'),
      findsOneWidget,
    );
    expect(
      find.textContaining('Both cases are yours'),
      findsOneWidget,
    );
    expect(find.text('No connections yet'), findsNothing);
    expect(
        find.textContaining('Similarity is review evidence'), findsOneWidget);
  });

  testWidgets('peer code remains verifiable after own code is consumed',
      (tester) async {
    final repository = _repository(
      MockClient((request) async {
        if (request.url.path == '/v1/connections/matches') {
          return http.Response(jsonEncode({'results': []}), 200);
        }
        return http.Response(
          jsonEncode({
            'results': [
              _connection(
                myConsented: true,
                otherConsented: true,
                status: 'ready_to_meet',
                otherVerifiedPeer: true,
                meetingCodeExpiresAt: '2030-01-01T12:00:00Z',
              ),
            ],
          }),
          200,
        );
      }),
    );
    await tester.pumpWidget(
      MaterialApp(
        theme: buildTheme(Brightness.light),
        home: MyMatchesScreen(repository: repository),
      ),
    );
    await tester.pumpAndSettle();

    expect(
      find.textContaining('The other party verified your code'),
      findsOneWidget,
    );
    expect(find.text('Other party’s code'), findsOneWidget);
    expect(find.text('Verify other code'), findsOneWidget);
    expect(find.text('Create new meeting codes'), findsNothing);
  });
}
