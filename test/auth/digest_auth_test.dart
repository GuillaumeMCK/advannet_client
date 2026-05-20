import 'package:advannet_client/src/auth/digest_auth.dart';
import 'package:test/test.dart';

// RFC 2617 §3.5 example values for deterministic testing.
const _rfc2617Username = 'Mufasa';
const _rfc2617Realm = 'testrealm@host.com';
const _rfc2617Password = 'Circle Of Life';
const _rfc2617Nonce = 'dcd98b7102dd2f0e8b11d0f600bfb0c093';
const _rfc2617Cnonce = '0a4f113b';
const _rfc2617Uri = '/dir/index.html';
// Expected: HA1=939e7578…, HA2=39aff3a2…, response=6629fae4…
const _rfc2617Response = '6629fae49393a05397450978507c4ef1';

DigestAuthHelper _helper({String cnonce = _rfc2617Cnonce}) => DigestAuthHelper(
  username: _rfc2617Username,
  password: _rfc2617Password,
  cnonceGenerator: () => cnonce,
);

String _wwwAuthenticate({
  String realm = _rfc2617Realm,
  String nonce = _rfc2617Nonce,
  String qop = 'auth',
}) => 'Digest realm="$realm", qop="$qop", nonce="$nonce"';

void main() {
  group('DigestAuthHelper', () {
    group('processChallenge', () {
      test('returns null for non-Digest header', () {
        final helper = _helper();
        expect(helper.processChallenge('Basic realm="X"', 'GET', '/'), isNull);
      });

      test('returns null when header is null', () {
        expect(_helper().processChallenge(null, 'GET', '/'), isNull);
      });

      test('returns Authorization header for valid Digest challenge', () {
        final auth = _helper().processChallenge(
          _wwwAuthenticate(),
          'GET',
          _rfc2617Uri,
        );
        expect(auth, isNotNull);
        expect(auth, startsWith('Digest '));
      });

      test('Authorization header contains required fields', () {
        final auth = _helper().processChallenge(
          _wwwAuthenticate(),
          'GET',
          _rfc2617Uri,
        )!;
        expect(auth, contains('username="$_rfc2617Username"'));
        expect(auth, contains('realm="$_rfc2617Realm"'));
        expect(auth, contains('nonce="$_rfc2617Nonce"'));
        expect(auth, contains('uri="$_rfc2617Uri"'));
        expect(auth, contains('qop=auth'));
        expect(auth, contains('response="'));
      });

      test('matches RFC 2617 §3.5 test vector', () {
        final auth = _helper().processChallenge(
          _wwwAuthenticate(),
          'GET',
          _rfc2617Uri,
        )!;
        expect(auth, contains('response="$_rfc2617Response"'));
      });

      test('nc is 00000001 on first call', () {
        final auth = _helper().processChallenge(
          _wwwAuthenticate(),
          'GET',
          _rfc2617Uri,
        )!;
        expect(auth, contains('nc=00000001'));
      });

      test('challenge with qop-list picks auth over auth-int', () {
        final auth = _helper().processChallenge(
          'Digest realm="R", nonce="N", qop="auth-int, auth"',
          'GET',
          '/',
        )!;
        expect(auth, contains('qop=auth'));
      });
    });

    group('proactiveHeader', () {
      test('returns null before any challenge', () {
        expect(_helper().proactiveHeader('GET', '/'), isNull);
      });

      test('returns header after processChallenge', () {
        final helper = _helper();
        helper.processChallenge(_wwwAuthenticate(), 'GET', '/first');
        expect(helper.proactiveHeader('GET', '/second'), isNotNull);
      });

      test('nc increments across calls', () {
        final helper = _helper();
        helper.processChallenge(_wwwAuthenticate(), 'GET', '/');
        final h1 = helper.proactiveHeader('GET', '/')!;
        final h2 = helper.proactiveHeader('GET', '/')!;
        expect(h1, contains('nc=00000002'));
        expect(h2, contains('nc=00000003'));
      });
    });

    group('challenge without qop (legacy)', () {
      test('produces response without nc/cnonce/qop fields', () {
        final auth = _helper().processChallenge(
          'Digest realm="R", nonce="N"',
          'GET',
          '/',
        )!;
        expect(auth, isNot(contains('qop=')));
        expect(auth, isNot(contains('nc=')));
        expect(auth, isNot(contains('cnonce=')));
      });
    });
  });
}
