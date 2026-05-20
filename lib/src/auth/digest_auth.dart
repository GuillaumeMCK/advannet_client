import 'dart:convert';
import 'dart:math';

import 'package:crypto/crypto.dart';

/// Implements RFC 2617 / RFC 7616 HTTP Digest authentication.
///
/// Stateful per-transport instance: caches the latest challenge so subsequent
/// requests use a proactive Authorization header without a fresh 401 round-trip.
final class DigestAuthHelper {
  DigestAuthHelper({
    required String username,
    required String password,
    String Function()? cnonceGenerator,
  }) : _username = username,
       _password = password,
       _cnonceGenerator = cnonceGenerator ?? _randomCnonce;

  final String _username;
  final String _password;
  final String Function() _cnonceGenerator;
  _DigestChallenge? _cached;

  /// Returns a proactive Authorization header using the cached challenge nonce,
  /// or null if no challenge has been seen yet for this session.
  String? proactiveHeader(String method, String uri) {
    final challenge = _cached;
    if (challenge == null) return null;
    return _buildHeader(method, uri, challenge);
  }

  /// Processes the 401 `WWW-Authenticate` response header and returns the
  /// Authorization header to use on the retry request.
  ///
  /// Returns null if the header is not a Digest challenge (e.g. it is Basic).
  String? processChallenge(String? wwwAuthenticate, String method, String uri) {
    if (wwwAuthenticate == null) return null;
    final challenge = _parseChallenge(wwwAuthenticate);
    if (challenge == null) return null;
    _cached = challenge;
    return _buildHeader(method, uri, challenge);
  }

  String _buildHeader(String method, String uri, _DigestChallenge challenge) {
    final cnonce = _cnonceGenerator();
    challenge.nc++;
    final nc = challenge.nc.toRadixString(16).padLeft(8, '0');

    final ha1 = _computeHa1(challenge, cnonce);
    final ha2 = _hash('$method:$uri', challenge.algorithm);
    final response = challenge.qop != null
        ? _hash(
            '$ha1:${challenge.nonce}:$nc:$cnonce:${challenge.qop}:$ha2',
            challenge.algorithm,
          )
        : _hash('$ha1:${challenge.nonce}:$ha2', challenge.algorithm);

    final sb = StringBuffer('Digest ')
      ..write('username="$_username", ')
      ..write('realm="${challenge.realm}", ')
      ..write('nonce="${challenge.nonce}", ')
      ..write('uri="$uri", ');
    if (challenge.qop != null) {
      sb
        ..write('qop=${challenge.qop}, ')
        ..write('nc=$nc, ')
        ..write('cnonce="$cnonce", ');
    }
    sb.write('response="$response"');
    if (challenge.opaque != null) sb.write(', opaque="${challenge.opaque}"');
    if (challenge.algorithm != 'MD5') {
      sb.write(', algorithm=${challenge.algorithm}');
    }
    return sb.toString();
  }

  String _computeHa1(_DigestChallenge challenge, String cnonce) {
    final base = _hash(
      '$_username:${challenge.realm}:$_password',
      challenge.algorithm,
    );
    if (challenge.algorithm.endsWith('-SESS')) {
      return _hash('$base:${challenge.nonce}:$cnonce', challenge.algorithm);
    }
    return base;
  }

  static _DigestChallenge? _parseChallenge(String header) {
    if (!header.trimLeft().toLowerCase().startsWith('digest ')) return null;

    final directives = _parseDirectives(header);
    final realm = directives['realm'];
    final nonce = directives['nonce'];
    if (realm == null || nonce == null) return null;

    // Pick qop=auth if offered; ignore auth-int (requires body hash, out of scope).
    final qopOptions = (directives['qop'] ?? '')
        .split(',')
        .map((s) => s.trim().toLowerCase());
    final qop = qopOptions.contains('auth') ? 'auth' : null;

    final algorithm = (directives['algorithm'] ?? 'MD5').toUpperCase();

    return _DigestChallenge(
      realm: realm,
      nonce: nonce,
      opaque: directives['opaque'],
      qop: qop,
      algorithm: algorithm,
    );
  }

  static Map<String, String> _parseDirectives(String header) {
    // Strip leading "Digest " (case-insensitive).
    final content = header.replaceFirst(
      RegExp(r'^Digest\s+', caseSensitive: false),
      '',
    );
    final result = <String, String>{};
    // Match key="value" (quoted) or key=token (unquoted).
    final pattern = RegExp(r'(\w+)=(?:"([^"]*)"|([\w.+\-/=]+))');
    for (final m in pattern.allMatches(content)) {
      result[m.group(1)!] = m.group(2) ?? m.group(3) ?? '';
    }
    return result;
  }

  static String _hash(String input, String algorithm) {
    final bytes = utf8.encode(input);
    if (algorithm.startsWith('SHA-256')) {
      return sha256.convert(bytes).toString();
    }
    return md5.convert(bytes).toString();
  }

  static String _randomCnonce() {
    final rng = Random.secure();
    return List.generate(
      8,
      (_) => rng.nextInt(256).toRadixString(16).padLeft(2, '0'),
    ).join();
  }
}

final class _DigestChallenge {
  _DigestChallenge({
    required this.realm,
    required this.nonce,
    this.opaque,
    this.qop,
    required this.algorithm,
  });

  final String realm;
  final String nonce;
  final String? opaque;
  final String? qop; // null → legacy digest without qop
  final String algorithm; // MD5 | SHA-256 | MD5-SESS | SHA-256-SESS
  int nc = 0;
}
