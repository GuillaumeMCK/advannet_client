import 'dart:convert';

import 'package:http/http.dart' as http;

import '../auth/digest_auth.dart';
import '../errors/advannet_exception.dart';
import '../model/credentials.dart';

abstract interface class HttpTransport {
  Future<String> get(String path);
  Future<String> put(String path, {String? body});
}

final class DefaultHttpTransport implements HttpTransport {
  DefaultHttpTransport({
    required this.baseUri,
    required this.credentials,
    this.timeout = const Duration(seconds: 10),
    http.Client? client,
  }) : _client = client ?? http.Client(),
       _digestHelper = _makeDigestHelper(credentials);

  final Uri baseUri;
  final AdvanNetCredentials credentials;
  final Duration timeout;
  final http.Client _client;
  final DigestAuthHelper? _digestHelper;

  @override
  Future<String> get(String path) async {
    final uri = _buildUri(path);
    return _request(HttpMethod.get, uri, path);
  }

  @override
  Future<String> put(String path, {String? body}) async {
    final uri = _buildUri(path);
    return _request(HttpMethod.put, uri, path, body: body);
  }

  // ── internals ─────────────────────────────────────────────────────────────

  Future<String> _request(
    HttpMethod method,
    Uri uri,
    String originalPath, {
    String? body,
  }) async {
    try {
      var response = await _send(method, uri, body: body);

      // Digest challenge handling: on 401, parse WWW-Authenticate and retry once.
      if (response.statusCode == 401) {
        if (_digestHelper case final helper?) {
          final wwwAuth = response.headers['www-authenticate'];
          if (helper.processChallenge(wwwAuth, method.toString(), uri.path)
              case final authHeader?) {
            response = await _send(
              method,
              uri,
              body: body,
              overrideAuth: authHeader,
            );
          }
        }
      }

      return _extractBody(response, method, originalPath);
    } on AdvanNetException {
      rethrow;
    } catch (err) {
      throw AdvanNetTransportException(
        message: 'Network error',
        method: method,
        path: originalPath,
        cause: err,
      );
    }
  }

  Future<http.Response> _send(
    HttpMethod method,
    Uri uri, {
    String? body,
    String? overrideAuth,
  }) async {
    final headers = <String, String>{
      'Accept': 'application/xml',
      if (body != null) 'Content-Type': 'application/xml; charset=utf-8',
    };

    // Auth: Basic is always proactive; Digest can be proactive (cached nonce)
    // or will be set via overrideAuth on the challenge-retry.
    final auth =
        overrideAuth ??
        _basicAuthHeader() ??
        _digestHelper?.proactiveHeader(method.toString(), uri.path);
    if (auth case final auth?) headers['Authorization'] = auth;

    return switch (method) {
      HttpMethod.put =>
        _client.put(uri, headers: headers, body: body).timeout(timeout),
      HttpMethod.get => _client.get(uri, headers: headers).timeout(timeout),
    };
  }

  String? _basicAuthHeader() => switch (credentials) {
    BasicAdvanNetCredentials(:final username, :final password) =>
      'Basic ${base64Encode(utf8.encode('$username:$password'))}',
    _ => null,
  };

  String _extractBody(http.Response response, HttpMethod method, String path) {
    if (response.statusCode == 401 || response.statusCode == 403) {
      throw AdvanNetAuthException(
        message: 'Authentication failed (HTTP ${response.statusCode})',
        method: method,
        path: path,
        statusCode: response.statusCode,
      );
    }
    if (response.statusCode >= 400) {
      throw AdvanNetServerError(
        message: 'HTTP error ${response.statusCode}',
        method: method,
        path: path,
        code: '${response.statusCode}',
      );
    }
    return utf8.decode(response.bodyBytes);
  }

  Uri _buildUri(String path) {
    if (path.split('/').any((s) => s == '..')) {
      throw ArgumentError.value(path, 'path', 'Path traversal not allowed');
    }
    final normalized = path.startsWith('/') ? path : '/$path';
    return Uri(
      scheme: baseUri.scheme,
      host: baseUri.host,
      port: baseUri.port,
      path: normalized,
    );
  }

  static DigestAuthHelper? _makeDigestHelper(AdvanNetCredentials credentials) =>
      switch (credentials) {
        DigestAdvanNetCredentials(:final username, :final password) =>
          DigestAuthHelper(username: username, password: password),
        _ => null,
      };
}
