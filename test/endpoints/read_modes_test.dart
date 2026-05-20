import 'package:advannet_client/advannet_client.dart';
import 'package:advannet_client/advannet_client_testing.dart';
import 'package:test/test.dart';

RawResource _raw(FakeHttpTransport fake) =>
    RawResource(transport: fake, parser: const EnvelopeParser());

SystemResource _system(FakeHttpTransport fake) =>
    SystemResource(raw: _raw(fake));

ReadModesResource _readModes(FakeHttpTransport fake) =>
    ReadModesResource(raw: _raw(fake), system: _system(fake));

const _asynchModeXml = '''
<data>
  <enabled>true</enabled>
  <eventsTTL>0</eventsTTL>
  <direction>false</direction>
  <customEvent>false</customEvent>
  <customEvent2>false</customEvent2>
</data>''';

void main() {
  group('ReadModesResource.getById()', () {
    test('calls correct path', () async {
      final fake = FakeHttpTransport()
        ..stubGet('/system/readmodes/byId/AdvanNetAsyncRead', _asynchModeXml);
      await _readModes(fake).getById('AdvanNetAsyncRead');
      expect(
        fake.calls.single.path,
        '/system/readmodes/byId/AdvanNetAsyncRead',
      );
    });

    test('returns DataResponse', () async {
      final fake = FakeHttpTransport()
        ..stubGet('/system/readmodes/byId/AdvanNetAsyncRead', _asynchModeXml);
      final response = await _readModes(fake).getById('AdvanNetAsyncRead');
      expect(response, isA<DataResponse>());
    });
  });

  group('ReadModesResource.getActive()', () {
    test('returns the active mode id from <data><id>…</id></data>', () async {
      final fake = FakeHttpTransport()
        ..stubGet(
          '/system/readmodes/active',
          '<data><id>AdvanNetAsyncRead</id></data>',
        );
      final id = await _readModes(fake).getActive();
      expect(id, 'AdvanNetAsyncRead');
    });

    test('throws AdvanNetServerError on ErrorResponse', () async {
      final fake = FakeHttpTransport()
        ..stubGet(
          '/system/readmodes/active',
          '<response><error><code>NOT_FOUND</code></error></response>',
        );
      expect(
        () => _readModes(fake).getActive(),
        throwsA(isA<AdvanNetServerError>()),
      );
    });

    test(
      'throws AdvanNetProtocolException when id element is missing',
      () async {
        final fake = FakeHttpTransport()
          ..stubGet(
            '/system/readmodes/active',
            '<data><other>x</other></data>',
          );
        expect(
          () => _readModes(fake).getActive(),
          throwsA(isA<AdvanNetProtocolException>()),
        );
      },
    );
  });

  group('ReadModesResource.setActive()', () {
    test('calls PUT /system/readmodes/active', () async {
      final fake = FakeHttpTransport()
        ..stubPut('/system/readmodes/active', '<response/>');
      await _readModes(fake).setActive('AdvanNetScanRead');
      expect(fake.calls.single.method, 'PUT');
      expect(fake.calls.single.path, '/system/readmodes/active');
    });

    test('PUT body contains the mode id', () async {
      final fake = FakeHttpTransport()
        ..stubPut('/system/readmodes/active', '<response/>');
      await _readModes(fake).setActive('AdvanNetScanRead');
      expect(fake.calls.single.body, contains('AdvanNetScanRead'));
    });
  });

  group('ReadModesResource.update()', () {
    test('calls GET then PUT on the mode path', () async {
      final fake = FakeHttpTransport()
        ..stubGet('/system/readmodes/byId/AdvanNetAsyncRead', _asynchModeXml)
        ..stubPut('/system/readmodes/byId/AdvanNetAsyncRead', '<response/>');

      await _readModes(fake).update<AsynchReadMode>(
        modeId: 'AdvanNetAsyncRead',
        fromXml: AsynchReadMode.fromXml,
        mutator: (m) => m.copyWith(eventsTTL: 500),
      );

      expect(fake.calls[0].method, 'GET');
      expect(fake.calls[0].path, '/system/readmodes/byId/AdvanNetAsyncRead');
      expect(fake.calls[1].method, 'PUT');
      expect(fake.calls[1].path, '/system/readmodes/byId/AdvanNetAsyncRead');
    });

    test('returns the mutated model', () async {
      final fake = FakeHttpTransport()
        ..stubGet('/system/readmodes/byId/AdvanNetAsyncRead', _asynchModeXml)
        ..stubPut('/system/readmodes/byId/AdvanNetAsyncRead', '<response/>');

      final result = await _readModes(fake).update<AsynchReadMode>(
        modeId: 'AdvanNetAsyncRead',
        fromXml: AsynchReadMode.fromXml,
        mutator: (m) => m.copyWith(eventsTTL: 250),
      );

      expect(result.eventsTTL, 250);
    });

    test('calls confAllSave when persist=true', () async {
      final fake = FakeHttpTransport()
        ..stubGet('/system/readmodes/byId/AdvanNetAsyncRead', _asynchModeXml)
        ..stubPut('/system/readmodes/byId/AdvanNetAsyncRead', '<response/>')
        ..stubGet('/conf/save', '<response/>');

      await _readModes(fake).update<AsynchReadMode>(
        modeId: 'AdvanNetAsyncRead',
        fromXml: AsynchReadMode.fromXml,
        mutator: (m) => m,
        persist: true,
      );

      expect(fake.calls.any((c) => c.path == '/conf/save'), isTrue);
    });

    test('does not call confAllSave when persist=false (default)', () async {
      final fake = FakeHttpTransport()
        ..stubGet('/system/readmodes/byId/AdvanNetAsyncRead', _asynchModeXml)
        ..stubPut('/system/readmodes/byId/AdvanNetAsyncRead', '<response/>');

      await _readModes(fake).update<AsynchReadMode>(
        modeId: 'AdvanNetAsyncRead',
        fromXml: AsynchReadMode.fromXml,
        mutator: (m) => m,
      );

      expect(fake.calls.any((c) => c.path == '/conf/save'), isFalse);
    });

    test('throws AdvanNetServerError when GET returns ErrorResponse', () async {
      final fake = FakeHttpTransport()
        ..stubGet(
          '/system/readmodes/byId/AdvanNetAsyncRead',
          '<response><error><code>NOT_FOUND</code></error></response>',
        );

      expect(
        () => _readModes(fake).update<AsynchReadMode>(
          modeId: 'AdvanNetAsyncRead',
          fromXml: AsynchReadMode.fromXml,
          mutator: (m) => m,
        ),
        throwsA(isA<AdvanNetServerError>()),
      );
    });

    test(
      'throws AdvanNetProtocolException when GET returns EntriesResponse',
      () async {
        final fake = FakeHttpTransport()
          ..stubGet(
            '/system/readmodes/byId/AdvanNetAsyncRead',
            '<response><entries><entry><class>X</class><def>y</def></entry></entries></response>',
          );

        expect(
          () => _readModes(fake).update<AsynchReadMode>(
            modeId: 'AdvanNetAsyncRead',
            fromXml: AsynchReadMode.fromXml,
            mutator: (m) => m,
          ),
          throwsA(isA<AdvanNetProtocolException>()),
        );
      },
    );
  });
}
