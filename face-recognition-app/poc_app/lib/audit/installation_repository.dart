import 'dart:async';
import 'dart:convert';
import 'dart:io';
import 'dart:math';

import 'package:flutter_secure_storage/flutter_secure_storage.dart';
import 'package:http/http.dart' as http;

abstract class InstallationStore {
  Future<String?> read(String key);
  Future<void> write(String key, String value);
}

class SecureInstallationStore implements InstallationStore {
  SecureInstallationStore([FlutterSecureStorage? storage])
      : _storage = storage ?? const FlutterSecureStorage();

  final FlutterSecureStorage _storage;

  @override
  Future<String?> read(String key) => _storage.read(key: key);

  @override
  Future<void> write(String key, String value) =>
      _storage.write(key: key, value: value);
}

class InstallationRepository {
  InstallationRepository({
    required this.baseUrl,
    required this.appVersion,
    required this.buildNumber,
    this.tokenProvider,
    String? platform,
    http.Client? client,
    InstallationStore? store,
  })  : platform = platform ?? Platform.operatingSystem,
        _client = client ?? http.Client(),
        _store = store ?? SecureInstallationStore();

  static const _installationIdKey = 'matchsnap_installation_id';

  final String baseUrl;
  final String appVersion;
  final String buildNumber;
  final String platform;
  final Future<String?> Function()? tokenProvider;
  final http.Client _client;
  final InstallationStore _store;

  Future<String>? _installationIdFuture;

  Future<String> installationId() =>
      _installationIdFuture ??= _loadOrCreateInstallationId();

  Future<void> register() async {
    await _send('/v1/audit/installations/register');
  }

  Future<void> bind() async {
    final token = await tokenProvider?.call();
    if (token == null) {
      return;
    }
    await _send(
      '/v1/audit/installations/bind',
      headers: {'Authorization': 'Bearer $token'},
    );
  }

  Future<void> _send(
    String path, {
    Map<String, String>? headers,
  }) async {
    final response = await _client
        .post(
          Uri.parse('$baseUrl$path'),
          headers: {
            'Content-Type': 'application/json',
            ...?headers,
          },
          body: jsonEncode({
            'installation_id': await installationId(),
            'platform': platform,
            'app_version': appVersion,
            'build_number': buildNumber,
          }),
        )
        .timeout(const Duration(seconds: 15));
    if (response.statusCode < 200 || response.statusCode >= 300) {
      throw InstallationRegistrationException(response.statusCode);
    }
  }

  Future<String> _loadOrCreateInstallationId() async {
    final existing = await _store.read(_installationIdKey);
    if (existing != null) {
      return existing;
    }
    final generated = _randomUuid();
    await _store.write(_installationIdKey, generated);
    return generated;
  }

  String _randomUuid() {
    final random = Random.secure();
    final bytes = List<int>.generate(16, (_) => random.nextInt(256));
    bytes[6] = (bytes[6] & 0x0f) | 0x40;
    bytes[8] = (bytes[8] & 0x3f) | 0x80;
    final hex = bytes.map((value) => value.toRadixString(16).padLeft(2, '0'));
    final value = hex.join();
    return '${value.substring(0, 8)}-'
        '${value.substring(8, 12)}-'
        '${value.substring(12, 16)}-'
        '${value.substring(16, 20)}-'
        '${value.substring(20)}';
  }
}

class InstallationRegistrationException implements Exception {
  const InstallationRegistrationException(this.statusCode);

  final int statusCode;
}
