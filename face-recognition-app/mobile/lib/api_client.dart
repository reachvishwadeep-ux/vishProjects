import 'dart:convert';
import 'dart:io';

import 'package:http/http.dart' as http;

import 'config.dart';
import 'models.dart';

class ApiClient {
  ApiClient({http.Client? client, String? baseUrl})
    : _client = client ?? http.Client(),
      _baseUrl = baseUrl ?? Config.apiBaseUrl;

  final http.Client _client;
  final String _baseUrl;

  Future<EnrollResult> enroll({
    required File image,
    required String personName,
    bool force = false,
  }) async {
    final request =
        http.MultipartRequest('POST', Uri.parse('$_baseUrl/v1/enroll'))
          ..fields['person_name'] = personName
          ..fields['force'] = force.toString()
          ..files.add(await http.MultipartFile.fromPath('image', image.path));
    final json = await _send(request);
    return EnrollResult.fromJson(json as Map<String, dynamic>);
  }

  Future<SearchResult> search({required File image, int topK = 5}) async {
    final request =
        http.MultipartRequest('POST', Uri.parse('$_baseUrl/v1/search'))
          ..fields['top_k'] = topK.toString()
          ..files.add(await http.MultipartFile.fromPath('image', image.path));
    final json = await _send(request);
    return SearchResult.fromJson(json as Map<String, dynamic>);
  }

  Future<List<Person>> listPersons() async {
    final response = await _client.get(Uri.parse('$_baseUrl/v1/persons'));
    final json = _decode(response);
    return (json as List<dynamic>)
        .map((entry) => Person.fromJson(entry as Map<String, dynamic>))
        .toList();
  }

  Future<void> deletePerson(String personId) async {
    final response = await _client.delete(
      Uri.parse('$_baseUrl/v1/persons/$personId'),
    );
    if (response.statusCode != HttpStatus.noContent) {
      _decode(response);
    }
  }

  Future<Object?> _send(http.MultipartRequest request) async {
    final response = await http.Response.fromStream(
      await _client.send(request),
    );
    return _decode(response);
  }

  Object? _decode(http.Response response) {
    if (response.statusCode >= 200 &&
        response.statusCode < HttpStatus.multipleChoices) {
      return response.body.isEmpty ? null : jsonDecode(response.body);
    }
    throw _errorFor(response);
  }

  ApiException _errorFor(http.Response response) {
    try {
      final detail =
          (jsonDecode(response.body) as Map<String, dynamic>)['detail'];
      if (detail is Map<String, dynamic>) {
        return ApiException(
          detail['error'] as String? ?? 'request failed',
          reasons: (detail['reasons'] as List<dynamic>? ?? const [])
              .cast<String>(),
        );
      }
      return ApiException(
        detail?.toString() ?? 'request failed (${response.statusCode})',
      );
    } on FormatException {
      return ApiException('request failed (${response.statusCode})');
    }
  }
}
