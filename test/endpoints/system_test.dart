import 'package:advannet_client/advannet_client.dart';
import 'package:advannet_client/advannet_client_testing.dart';
import 'package:test/test.dart';

RawResource _raw(FakeHttpTransport fake) =>
    RawResource(transport: fake, parser: const EnvelopeParser());

SystemResource _system(FakeHttpTransport fake) =>
    SystemResource(raw: _raw(fake));

void main() {
  group('SystemResource.confAllSave()', () {
    test('calls GET /conf/save', () async {
      final fake = FakeHttpTransport()..stubGet('/conf/save', '<response/>');
      await _system(fake).confAllSave();
      expect(fake.calls.single.path, '/conf/save');
      expect(fake.calls.single.method, 'GET');
    });

    test('does not throw on empty response', () async {
      final fake = FakeHttpTransport()..stubGet('/conf/save', '<response/>');
      await expectLater(_system(fake).confAllSave(), completes);
    });

    test('throws AdvanNetServerError on ErrorResponse', () async {
      final fake = FakeHttpTransport()
        ..stubGet(
          '/conf/save',
          '<response><error><code>BUSY</code></error></response>',
        );
      expect(
        () => _system(fake).confAllSave(),
        throwsA(
          isA<AdvanNetServerError>().having((e) => e.code, 'code', 'BUSY'),
        ),
      );
    });
  });

  group('SystemResource.factoryReset()', () {
    test('calls GET /system/os/FactoryReset', () async {
      final fake = FakeHttpTransport()
        ..stubGet('/system/os/FactoryReset', '<response/>');
      await _system(fake).factoryReset();
      expect(fake.calls.single.path, '/system/os/FactoryReset');
    });
  });

  group('SystemResource.reboot()', () {
    test('calls GET /system/os/Reboot', () async {
      final fake = FakeHttpTransport()
        ..stubGet('/system/os/Reboot', '<response/>');
      await _system(fake).reboot();
      expect(fake.calls.single.path, '/system/os/Reboot');
    });

    test('throws AdvanNetServerError on ErrorResponse', () async {
      final fake = FakeHttpTransport()
        ..stubGet(
          '/system/os/Reboot',
          '<response><error><code>UNSUPPORTED</code></error></response>',
        );
      expect(() => _system(fake).reboot(), throwsA(isA<AdvanNetServerError>()));
    });
  });
}
