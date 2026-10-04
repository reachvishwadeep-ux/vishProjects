import 'dart:convert';

import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:http/http.dart' as http;
import 'package:http/testing.dart';
import 'package:poc_app/auth/auth_controller.dart';
import 'package:poc_app/auth/auth_repository.dart';
import 'package:poc_app/screens/phone_auth_screen.dart';

class MemoryTokenStore implements TokenStore {
  final values = <String, String>{};

  @override
  Future<void> deleteAll() async => values.clear();

  @override
  Future<String?> read(String key) async => values[key];

  @override
  Future<void> write(String key, String value) async {
    values[key] = value;
  }
}

Map<String, Object?> _tokens(String refreshToken) => {
      'access_token': 'access-token',
      'refresh_token': refreshToken,
      'token_type': 'bearer',
      'expires_in': 900,
      'account': {
        'id': '3f51621c-566c-4e87-b657-9728bfbd0e53',
        'phone_number': '+919876543210',
      },
    };

void main() {
  test('requests and verifies a development OTP', () async {
    final store = MemoryTokenStore();
    final client = MockClient((request) async {
      if (request.url.path.endsWith('/otp/request')) {
        expect(jsonDecode(request.body)['phone_number'], '+919876543210');
        return http.Response(
          jsonEncode({
            'challenge_id': 'challenge-id',
            'expires_in': 300,
            'development_code': '123456',
          }),
          202,
        );
      }
      expect(request.url.path, '/v1/auth/otp/verify');
      final body = jsonDecode(request.body) as Map<String, Object?>;
      expect(body['challenge_id'], 'challenge-id');
      expect(body['code'], '123456');
      return http.Response(jsonEncode(_tokens('refresh-one')), 200);
    });
    final repository = AuthRepository(
      baseUrl: 'https://api.example.com',
      client: client,
      tokenStore: store,
    );

    final challenge = await repository.requestOtp('+919876543210');
    final account = await repository.verifyOtp(
      phoneNumber: '+919876543210',
      challengeId: challenge.id,
      code: challenge.developmentCode!,
    );

    expect(challenge.developmentCode, '123456');
    expect(account.phoneNumber, '+919876543210');
    expect(await repository.validAccessToken(), 'access-token');
    expect(store.values.values, contains('refresh-one'));
  });

  test('restores a session by rotating the refresh token', () async {
    final store = MemoryTokenStore()
      ..values['matchsnap_refresh_token'] = 'refresh-one';
    final client = MockClient((request) async {
      expect(request.url.path, '/v1/auth/refresh');
      expect(jsonDecode(request.body)['refresh_token'], 'refresh-one');
      return http.Response(jsonEncode(_tokens('refresh-two')), 200);
    });
    final repository = AuthRepository(
      baseUrl: 'https://api.example.com',
      client: client,
      tokenStore: store,
    );

    final account = await repository.restore();

    expect(account?.phoneNumber, '+919876543210');
    expect(store.values.values, contains('refresh-two'));
    expect(store.values.values, isNot(contains('refresh-one')));
  });

  testWidgets('phone screen completes the development OTP flow',
      (tester) async {
    final repository = AuthRepository(
      baseUrl: 'https://api.example.com',
      tokenStore: MemoryTokenStore(),
      client: MockClient((request) async {
        if (request.url.path.endsWith('/otp/request')) {
          return http.Response(
            jsonEncode({
              'challenge_id': 'challenge-id',
              'expires_in': 300,
              'development_code': '123456',
            }),
            202,
          );
        }
        return http.Response(jsonEncode(_tokens('refresh-one')), 200);
      }),
    );
    final controller = AuthController(repository: repository);
    await controller.initialize();
    await tester.pumpWidget(
      MaterialApp(home: PhoneAuthScreen(controller: controller)),
    );

    await tester.enterText(find.byType(TextField).first, '+919876543210');
    await tester.tap(find.text('Send verification code'));
    await tester.pumpAndSettle();

    expect(find.text('Local demo code: 123456'), findsOneWidget);

    await tester.tap(find.text('Verify and continue'));
    await tester.pumpAndSettle();

    expect(controller.authenticated, isTrue);
    expect(controller.account?.phoneNumber, '+919876543210');
  });
}
