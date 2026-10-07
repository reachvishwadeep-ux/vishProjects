import 'dart:convert';

import 'package:flutter_test/flutter_test.dart';
import 'package:http/http.dart' as http;
import 'package:http/testing.dart';
import 'package:poc_app/audit/installation_repository.dart';

class MemoryInstallationStore implements InstallationStore {
  final values = <String, String>{};

  @override
  Future<String?> read(String key) async => values[key];

  @override
  Future<void> write(String key, String value) async {
    values[key] = value;
  }
}

void main() {
  test('registers one stable random installation identifier', () async {
    final store = MemoryInstallationStore();
    final requests = <http.Request>[];
    final repository = InstallationRepository(
      baseUrl: 'https://api.example.com',
      appVersion: '1.0.0',
      buildNumber: '1',
      platform: 'android',
      store: store,
      client: MockClient((request) async {
        requests.add(request);
        return http.Response('{}', 201);
      }),
    );

    await repository.register();
    await repository.register();

    final first = jsonDecode(requests.first.body) as Map<String, Object?>;
    final second = jsonDecode(requests.last.body) as Map<String, Object?>;
    expect(first['installation_id'], second['installation_id']);
    expect(
      first['installation_id'],
      matches(
        RegExp(
          r'^[0-9a-f]{8}-[0-9a-f]{4}-4[0-9a-f]{3}-'
          r'[89ab][0-9a-f]{3}-[0-9a-f]{12}$',
        ),
      ),
    );
    expect(first['platform'], 'android');
  });

  test('binds the installation only with an authenticated session', () async {
    final requests = <http.Request>[];
    final repository = InstallationRepository(
      baseUrl: 'https://api.example.com',
      appVersion: '1.0.0',
      buildNumber: '1',
      platform: 'android',
      store: MemoryInstallationStore(),
      tokenProvider: () async => 'access-token',
      client: MockClient((request) async {
        requests.add(request);
        return http.Response('{}', 200);
      }),
    );

    await repository.bind();

    expect(requests.single.url.path, '/v1/audit/installations/bind');
    expect(requests.single.headers['Authorization'], 'Bearer access-token');
  });
}
