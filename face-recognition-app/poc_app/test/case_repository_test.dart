import 'dart:convert';

import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:http/http.dart' as http;
import 'package:http/testing.dart';
import 'package:poc_app/repository/case_repository.dart';
import 'package:poc_app/screens/my_cases_screen.dart';
import 'package:poc_app/theme.dart';

Map<String, Object?> _case({
  String caseType = 'missing',
  int matchCount = 0,
  String matchState = 'searching',
  String? myImageUrl,
  String? otherImageUrl,
}) {
  return {
    'id': '7c40725a-3000-43f7-b24d-12d6daea4b5d',
    'case_type': caseType,
    'subject_label': caseType == 'missing'
        ? 'Missing person submission'
        : 'Found person submission',
    'status': 'active',
    'match_count': matchCount,
    'match_state': matchState,
    'photos': [
      {
        'id': '81af2226-4a12-4eb4-8a11-6636a7f50ecb',
        'image_url': 'https://images.example.com/person.jpg',
        'quality': 0.92,
        'created_at': '2026-11-22T12:00:00Z',
      },
    ],
    'my_image_url': myImageUrl,
    'other_image_url': otherImageUrl,
    'created_at': '2026-11-22T12:00:00Z',
  };
}

CaseRepository _repository(MockClient client) {
  return CaseRepository(
    baseUrl: 'https://api.example.com',
    tokenProvider: () async => 'access-token',
    onAuthenticationFailure: () async {},
    client: client,
  );
}

void main() {
  test('lists authenticated uploaded cases and their photos', () async {
    final repository = _repository(
      MockClient((request) async {
        expect(request.method, 'GET');
        expect(request.url.path, '/v1/cases');
        expect(request.headers['authorization'], 'Bearer access-token');
        return http.Response(
          jsonEncode({
            'results': [
              _case(
                myImageUrl: 'https://images.example.com/missing.jpg',
                otherImageUrl: 'https://images.example.com/found.jpg',
              ),
            ],
          }),
          200,
        );
      }),
    );

    final cases = await repository.list();

    expect(cases, hasLength(1));
    expect(cases.single.caseType, 'missing');
    expect(cases.single.matchState, 'searching');
    expect(cases.single.photos, hasLength(1));
    expect(cases.single.photos.single.quality, 0.92);
    expect(
      cases.single.myImageUrl,
      'https://images.example.com/missing.jpg',
    );
    expect(
      cases.single.otherImageUrl,
      'https://images.example.com/found.jpg',
    );
  });

  testWidgets('shows searching and matched uploaded cases', (tester) async {
    final repository = _repository(
      MockClient((request) async {
        return http.Response(
          jsonEncode({
            'results': [
              _case(),
              _case(
                caseType: 'found',
                matchCount: 2,
                matchState: 'potential_match',
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
        home: MyCasesScreen(repository: repository),
      ),
    );
    await tester.pumpAndSettle();

    expect(find.text('My Cases'), findsOneWidget);
    expect(find.text('MISSING PERSON'), findsOneWidget);
    expect(find.text('Searching for potential matches'), findsOneWidget);

    await tester.scrollUntilVisible(
      find.text('FOUND PERSON'),
      300,
      scrollable: find.byType(Scrollable).first,
    );

    expect(find.text('FOUND PERSON'), findsOneWidget);
    expect(find.text('2 potential matches found'), findsOneWidget);
    expect(find.text('Nov 22, 2026'), findsWidgets);
  });

  testWidgets('shows an accurate empty state', (tester) async {
    final repository = _repository(
      MockClient((request) async {
        return http.Response(jsonEncode({'results': []}), 200);
      }),
    );

    await tester.pumpWidget(
      MaterialApp(
        theme: buildTheme(Brightness.light),
        home: MyCasesScreen(repository: repository),
      ),
    );
    await tester.pumpAndSettle();

    expect(find.text('No uploaded cases yet'), findsOneWidget);
    expect(find.textContaining('They will appear here'), findsOneWidget);
  });

  testWidgets('missing case shows its matched found-photo pair',
      (tester) async {
    final repository = _repository(
      MockClient((request) async {
        return http.Response(
          jsonEncode({
            'results': [
              _case(
                matchCount: 1,
                matchState: 'potential_match',
                myImageUrl: 'https://images.example.com/missing.jpg',
                otherImageUrl: 'https://images.example.com/found.jpg',
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
        home: MyCasesScreen(repository: repository),
      ),
    );
    await tester.pumpAndSettle();

    expect(find.text('MATCHED PAIR'), findsOneWidget);
    expect(find.text('YOUR PHOTO'), findsOneWidget);
    expect(find.text('FOUND PHOTO'), findsOneWidget);
  });

  testWidgets('found case shows its matched missing-photo pair',
      (tester) async {
    final repository = _repository(
      MockClient((request) async {
        return http.Response(
          jsonEncode({
            'results': [
              _case(
                caseType: 'found',
                matchCount: 1,
                matchState: 'potential_match',
                myImageUrl: 'https://images.example.com/found.jpg',
                otherImageUrl: 'https://images.example.com/missing.jpg',
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
        home: MyCasesScreen(repository: repository),
      ),
    );
    await tester.pumpAndSettle();

    expect(find.text('MATCHED PAIR'), findsOneWidget);
    expect(find.text('YOUR PHOTO'), findsOneWidget);
    expect(find.text('MISSING PHOTO'), findsOneWidget);
  });
}
