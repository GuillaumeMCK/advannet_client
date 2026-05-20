import 'dart:convert';

import 'package:advannet_client/advannet_client.dart';
import 'package:http/http.dart' as http;
import 'package:http/testing.dart';
import 'package:test/test.dart';

DefaultHttpTransport _transport({
  AdvanNetCredentials credentials = const AdvanNetCredentials.none(),
  required http.Client client,
}) => DefaultHttpTransport(
  baseUri: Uri.parse('http://device.local:3161'),
  credentials: credentials,
  client: client,
);

void main() {
  group('DefaultHttpTransport — GET', () {
    test('sets Accept: application/xml header', () async {
      http.BaseRequest? captured;
      final client = MockClient((req) async {
        captured = req;
        return http.Response('<response/>', 200);
      });
      await _transport(client: client).get('/devices');
      expect(captured?.headers['Accept'], 'application/xml');
    });

    test('applies Basic auth header correctly', () async {
      http.BaseRequest? captured;
      final client = MockClient((req) async {
        captured = req;
        return http.Response('<response/>', 200);
      });
      await _transport(
        credentials: const AdvanNetCredentials.basic('admin', 's3cr3t'),
        client: client,
      ).get('/devices');
      final auth = captured?.headers['Authorization'] ?? '';
      expect(auth, startsWith('Basic '));
      final decoded = utf8.decode(base64Decode(auth.substring(6)));
      expect(decoded, 'admin:s3cr3t');
    });

    test('returns response body on 200', () async {
      final client = MockClient((_) async => http.Response('<response/>', 200));
      final body = await _transport(client: client).get('/devices');
      expect(body, '<response/>');
    });

    test('throws AdvanNetAuthException on 401', () async {
      final client = MockClient((_) async => http.Response('', 401));
      expect(
        () => _transport(client: client).get('/devices'),
        throwsA(
          isA<AdvanNetAuthException>().having(
            (e) => e.statusCode,
            'statusCode',
            401,
          ),
        ),
      );
    });

    test('throws AdvanNetAuthException on 403', () async {
      final client = MockClient((_) async => http.Response('', 403));
      expect(
        () => _transport(client: client).get('/devices'),
        throwsA(
          isA<AdvanNetAuthException>().having(
            (e) => e.statusCode,
            'statusCode',
            403,
          ),
        ),
      );
    });

    test('throws AdvanNetServerError on 500', () async {
      final client = MockClient((_) async => http.Response('', 500));
      expect(
        () => _transport(client: client).get('/devices'),
        throwsA(isA<AdvanNetServerError>()),
      );
    });

    test('throws AdvanNetTransportException on network error', () async {
      final client = MockClient((_) async => throw Exception('no network'));
      expect(
        () => _transport(client: client).get('/devices'),
        throwsA(isA<AdvanNetTransportException>()),
      );
    });

    test('exception carries method and path', () async {
      final client = MockClient((_) async => http.Response('', 401));
      try {
        await _transport(client: client).get('/devices');
        fail('expected exception');
      } on AdvanNetAuthException catch (e) {
        expect(e.method, HttpMethod.get);
        expect(e.path, '/devices');
      }
    });
  });

  group('DefaultHttpTransport — PUT', () {
    test('sends body with Content-Type: application/xml', () async {
      http.BaseRequest? captured;
      final client = MockClient((req) async {
        captured = req;
        return http.Response('<response/>', 200);
      });
      await _transport(client: client).put('/antennas', body: '<data/>');
      expect(captured?.headers['Content-Type'], contains('application/xml'));
    });

    test('omits Content-Type when body is null', () async {
      http.BaseRequest? captured;
      final client = MockClient((req) async {
        captured = req;
        return http.Response('<response/>', 200);
      });
      await _transport(client: client).put('/save');
      expect(captured?.headers['Content-Type'], isNull);
    });
  });

  group('DefaultHttpTransport — URI building', () {
    test('rejects path with ".." segment', () {
      final client = MockClient((_) async => http.Response('', 200));
      expect(
        () => _transport(client: client).get('/../secret'),
        throwsArgumentError,
      );
    });

    test('prepends "/" when missing', () async {
      http.BaseRequest? captured;
      final client = MockClient((req) async {
        captured = req;
        return http.Response('<response/>', 200);
      });
      await _transport(client: client).get('devices');
      expect(captured?.url.path, '/devices');
    });
  });

  group('Digest auth integration', () {
    test('retries with Authorization header after 401 challenge', () async {
      var callCount = 0;
      http.BaseRequest? secondRequest;
      final client = MockClient((req) async {
        callCount++;
        if (callCount == 1) {
          return http.Response(
            '',
            401,
            headers: {
              'www-authenticate':
                  'Digest realm="AdvanNet", qop="auth", nonce="abc123"',
            },
          );
        }
        secondRequest = req;
        return http.Response('<response/>', 200);
      });
      final body = await _transport(
        credentials: const AdvanNetCredentials.digest('admin', 'admin'),
        client: client,
      ).get('/devices');
      expect(body, '<response/>');
      expect(callCount, 2);
      expect(secondRequest?.headers['Authorization'], startsWith('Digest '));
    });

    test(
      'throws AdvanNetAuthException if second attempt also returns 401',
      () async {
        final client = MockClient(
          (_) async => http.Response(
            '',
            401,
            headers: {
              'www-authenticate':
                  'Digest realm="AdvanNet", qop="auth", nonce="abc123"',
            },
          ),
        );
        expect(
          () => _transport(
            credentials: const AdvanNetCredentials.digest('admin', 'wrong'),
            client: client,
          ).get('/devices'),
          throwsA(isA<AdvanNetAuthException>()),
        );
      },
    );

    test(
      'sends proactive header on second request using cached nonce',
      () async {
        var callCount = 0;
        http.BaseRequest? thirdRequest;
        final client = MockClient((req) async {
          callCount++;
          if (callCount == 1) {
            return http.Response(
              '',
              401,
              headers: {
                'www-authenticate':
                    'Digest realm="AdvanNet", qop="auth", nonce="abc123"',
              },
            );
          }
          if (callCount == 3) thirdRequest = req;
          return http.Response('<response/>', 200);
        });
        final transport = _transport(
          credentials: const AdvanNetCredentials.digest('admin', 'admin'),
          client: client,
        );
        await transport.get('/devices'); // triggers challenge
        await transport.get('/devices'); // should use cached nonce proactively
        expect(callCount, 3); // no extra 401 round-trip on second call
        expect(thirdRequest?.headers['Authorization'], startsWith('Digest '));
      },
    );
  });
}
