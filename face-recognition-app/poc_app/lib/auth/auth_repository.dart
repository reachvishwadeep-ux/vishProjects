import 'dart:async';
import 'dart:convert';

import 'package:flutter_secure_storage/flutter_secure_storage.dart';
import 'package:http/http.dart' as http;

class OtpChallenge {
  const OtpChallenge({
    required this.id,
    required this.expiresIn,
    this.developmentCode,
  });

  final String id;
  final int expiresIn;
  final String? developmentCode;
}

class AccountSession {
  const AccountSession({required this.accountId, required this.phoneNumber});

  final String accountId;
  final String phoneNumber;
}

abstract class TokenStore {
  Future<String?> read(String key);
  Future<void> write(String key, String value);
  Future<void> deleteAll();
}

class SecureTokenStore implements TokenStore {
  SecureTokenStore([FlutterSecureStorage? storage])
      : _storage = storage ?? const FlutterSecureStorage();

  final FlutterSecureStorage _storage;

  @override
  Future<String?> read(String key) => _storage.read(key: key);

  @override
  Future<void> write(String key, String value) =>
      _storage.write(key: key, value: value);

  @override
  Future<void> deleteAll() => _storage.deleteAll();
}

class AuthRepository {
  AuthRepository({
    required this.baseUrl,
    http.Client? client,
    TokenStore? tokenStore,
  })  : _client = client ?? http.Client(),
        _tokenStore = tokenStore ?? SecureTokenStore();

  static const _refreshTokenKey = 'matchsnap_refresh_token';
  static const _phoneNumberKey = 'matchsnap_phone_number';

  final String baseUrl;
  final http.Client _client;
  final TokenStore _tokenStore;

  String? _accessToken;
  DateTime? _accessTokenExpiresAt;
  AccountSession? _account;

  AccountSession? get account => _account;

  Future<OtpChallenge> requestOtp(String phoneNumber) async {
    final response = await _post(
      Uri.parse('$baseUrl/v1/auth/otp/request'),
      headers: {'Content-Type': 'application/json'},
      body: jsonEncode({'phone_number': phoneNumber}),
    );
    final payload = _payload(response);
    if (response.statusCode != 202) {
      throw AuthException(_errorMessage(payload));
    }
    return OtpChallenge(
      id: payload['challenge_id']! as String,
      expiresIn: payload['expires_in']! as int,
      developmentCode: payload['development_code'] as String?,
    );
  }

  Future<AccountSession> verifyOtp({
    required String phoneNumber,
    required String challengeId,
    required String code,
  }) async {
    final response = await _post(
      Uri.parse('$baseUrl/v1/auth/otp/verify'),
      headers: {'Content-Type': 'application/json'},
      body: jsonEncode({
        'phone_number': phoneNumber,
        'challenge_id': challengeId,
        'code': code,
      }),
    );
    final payload = _payload(response);
    if (response.statusCode != 200) {
      throw AuthException(_errorMessage(payload));
    }
    return _saveSession(payload);
  }

  Future<AccountSession?> restore() async {
    final refreshToken = await _tokenStore.read(_refreshTokenKey);
    if (refreshToken == null) {
      return null;
    }
    try {
      return await _refresh(refreshToken);
    } on SessionExpiredException {
      await clear();
      return null;
    } on AuthException {
      return null;
    }
  }

  Future<String?> validAccessToken() async {
    final now = DateTime.now().toUtc();
    if (_accessToken != null &&
        _accessTokenExpiresAt != null &&
        _accessTokenExpiresAt!.isAfter(now.add(const Duration(seconds: 30)))) {
      return _accessToken;
    }
    final refreshToken = await _tokenStore.read(_refreshTokenKey);
    if (refreshToken == null) {
      return null;
    }
    await _refresh(refreshToken);
    return _accessToken;
  }

  Future<void> logout() async {
    final token = _accessToken;
    if (token != null) {
      try {
        await _post(
          Uri.parse('$baseUrl/v1/auth/logout'),
          headers: {'Authorization': 'Bearer $token'},
        );
      } on AuthException {
        // Local sign-out must still succeed when the demo server is offline.
      }
    }
    await clear();
  }

  Future<void> clear() async {
    _accessToken = null;
    _accessTokenExpiresAt = null;
    _account = null;
    await _tokenStore.deleteAll();
  }

  Future<AccountSession> _refresh(String refreshToken) async {
    final response = await _post(
      Uri.parse('$baseUrl/v1/auth/refresh'),
      headers: {'Content-Type': 'application/json'},
      body: jsonEncode({'refresh_token': refreshToken}),
    );
    final payload = _payload(response);
    if (response.statusCode != 200) {
      if (response.statusCode == 401) {
        throw SessionExpiredException(_errorMessage(payload));
      }
      throw AuthException(_errorMessage(payload));
    }
    return _saveSession(payload);
  }

  Future<AccountSession> _saveSession(Map<String, Object?> payload) async {
    final accountPayload = payload['account']! as Map<String, Object?>;
    final account = AccountSession(
      accountId: accountPayload['id']! as String,
      phoneNumber: accountPayload['phone_number']! as String,
    );
    _accessToken = payload['access_token']! as String;
    _accessTokenExpiresAt = DateTime.now().toUtc().add(
          Duration(seconds: payload['expires_in']! as int),
        );
    _account = account;
    await _tokenStore.write(
      _refreshTokenKey,
      payload['refresh_token']! as String,
    );
    await _tokenStore.write(_phoneNumberKey, account.phoneNumber);
    return account;
  }

  Map<String, Object?> _payload(http.Response response) {
    if (response.body.isEmpty) {
      return {};
    }
    try {
      return jsonDecode(response.body) as Map<String, Object?>;
    } on FormatException {
      throw const AuthException(
          'The authentication service returned invalid data.');
    }
  }

  String _errorMessage(Map<String, Object?> payload) {
    return payload['detail']?.toString() ?? 'Authentication failed.';
  }

  Future<http.Response> _post(
    Uri uri, {
    Map<String, String>? headers,
    Object? body,
  }) async {
    try {
      return await _client
          .post(uri, headers: headers, body: body)
          .timeout(const Duration(seconds: 15));
    } on TimeoutException {
      throw const AuthException('The authentication service timed out.');
    } on http.ClientException {
      throw const AuthException('The authentication service is unavailable.');
    }
  }
}

class AuthException implements Exception {
  const AuthException(this.message);

  final String message;

  @override
  String toString() => message;
}

class SessionExpiredException extends AuthException {
  const SessionExpiredException(super.message);
}
