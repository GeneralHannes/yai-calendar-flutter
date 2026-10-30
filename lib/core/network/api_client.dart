import 'dart:async';
import 'dart:convert';

import 'package:flutter/foundation.dart' show compute;
import 'package:http/http.dart' as http;

import '../environment.dart';

class ApiException implements Exception {
  const ApiException(this.statusCode, this.message, {this.body});

  /// Null when the request never got an HTTP response (offline, timeout, DNS).
  final int? statusCode;
  final String message;
  final Object? body;

  bool get isNetworkError => statusCode == null;

  /// Worth retrying later with backoff.
  bool get isTransient {
    final c = statusCode;
    return c == null || c >= 500 || c == 408 || c == 429 || c == 401;
  }

  @override
  String toString() => 'ApiException($statusCode): $message';
}

typedef TokenProvider = Future<String?> Function();

/// Thin JSON wrapper over `package:http`. One persistent client, so
/// connections are kept alive across sync passes.
class ApiClient {
  ApiClient({
    http.Client? client,
    String baseUrl = Environment.apiBaseUrl,
    this.tokenProvider,
    this.timeout = const Duration(seconds: 20),
  })  : _client = client ?? http.Client(),
        _base = Uri.parse(baseUrl);

  final http.Client _client;
  final Uri _base;
  final TokenProvider? tokenProvider;
  final Duration timeout;

  /// Bodies larger than this are decoded off the UI isolate to avoid jank
  /// during the first full sync (on web, compute runs inline).
  static const _isolateDecodeThreshold = 64 * 1024;

  Future<Object?> get(String path, {Map<String, String>? query}) =>
      _send('GET', path, query: query);

  Future<Object?> put(String path, Object body) =>
      _send('PUT', path, body: body);

  Future<Object?> post(String path, Object body) =>
      _send('POST', path, body: body);

  Future<Object?> delete(String path) => _send('DELETE', path);

  Future<Object?> _send(
    String method,
    String path, {
    Map<String, String>? query,
    Object? body,
  }) async {
    final req = http.Request(method, _resolve(path, query))
      ..headers['Accept'] = 'application/json';

    final token = await tokenProvider?.call();
    if (token != null) req.headers['Authorization'] = 'Bearer $token';
    if (body != null) {
      req.headers['Content-Type'] = 'application/json; charset=utf-8';
      req.body = jsonEncode(body);
    }

    final http.Response res;
    try {
      res = await _client
          .send(req)
          .then(http.Response.fromStream)
          .timeout(timeout);
    } on TimeoutException {
      throw const ApiException(null, 'Request timed out');
    } on http.ClientException catch (e) {
      throw ApiException(null, e.message);
    }

    final decoded = await _decode(res.body);
    if (res.statusCode < 200 || res.statusCode >= 300) {
      throw ApiException(
          res.statusCode, res.reasonPhrase ?? 'HTTP ${res.statusCode}',
          body: decoded);
    }
    return decoded;
  }

  Uri _resolve(String path, Map<String, String>? query) {
    final basePath = _base.path.endsWith('/')
        ? _base.path.substring(0, _base.path.length - 1)
        : _base.path;
    return _base.replace(
      path: '$basePath$path',
      queryParameters: (query == null || query.isEmpty) ? null : query,
    );
  }

  static Future<Object?> _decode(String body) async {
    if (body.isEmpty) return null;
    try {
      return body.length > _isolateDecodeThreshold
          ? await compute(jsonDecode, body)
          : jsonDecode(body);
    } on FormatException {
      return body; // non-JSON error pages etc.
    }
  }

  void close() => _client.close();
}
