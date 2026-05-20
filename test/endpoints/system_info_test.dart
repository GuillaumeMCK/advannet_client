import 'package:advannet_client/advannet_client.dart';
import 'package:advannet_client/advannet_client_testing.dart';
import 'package:test/test.dart';

RawResource _raw(FakeHttpTransport fake) =>
    RawResource(transport: fake, parser: const EnvelopeParser());

SystemInfoResource _sysInfo(FakeHttpTransport fake) =>
    SystemInfoResource(raw: _raw(fake));

void main() {
  group('SystemInfoResource.getStatus()', () {
    test('calls GET /status', () async {
      final fake = FakeHttpTransport()
        ..stubGet('/status', '''
<data>
  <device>
    <id>AdvanReader-m4-160</id>
    <status>RUNNING</status>
  </device>
</data>''');
      await _sysInfo(fake).getStatus();
      expect(fake.calls.single.path, '/status');
      expect(fake.calls.single.method, 'GET');
    });

    test('returns SystemStatus with parsed fields', () async {
      final fake = FakeHttpTransport()
        ..stubGet('/status', '''
<response>
  <status>OK</status>
  <data>
    <device>
      <id>AdvanReader-m4-160</id>
      <ip>192.168.1.100</ip>
      <mac>64:cf:d9:c7:56:1c</mac>
      <serial>0091104::64cfd9c7561c</serial>
      <family>AdvanReader</family>
      <status>RUNNING</status>
      <activeDeviceMode>Autonomous</activeDeviceMode>
      <activeReadMode>AUTONOMOUS</activeReadMode>
    </device>
    <version>2.5.3</version>
    <revision>12</revision>
    <uptime>3600</uptime>
  </data>
</response>''');
      final status = await _sysInfo(fake).getStatus();
      expect(status, isNotNull);
      expect(status!.deviceId, 'AdvanReader-m4-160');
      expect(status.ip, '192.168.1.100');
      expect(status.mac, '64:cf:d9:c7:56:1c');
      expect(status.family, DeviceFamily.advanReader);
      expect(status.status, DeviceStatus.running);
      expect(status.activeDeviceMode, 'Autonomous');
      expect(status.activeReadMode, 'AUTONOMOUS');
      expect(status.advannetVersion, '2.5.3-12');
      expect(status.uptime, '3600');
    });

    test('parses container-style <version> (real device format)', () async {
      final fake = FakeHttpTransport()
        ..stubGet('/status', '''
<data>
  <id>AdvanNet-instance-abc</id>
  <version>
    <class>SW_VERSION</class>
    <version>2.10.33</version>
    <revision>20260317_1530</revision>
    <date/>
  </version>
  <uptime>02h 49m 33s</uptime>
</data>''');
      final status = await _sysInfo(fake).getStatus();
      expect(status!.advannetVersion, '2.10.33-20260317_1530');
      expect(status.uptime, '02h 49m 33s');
    });

    test('returns null on EmptyResponse', () async {
      final fake = FakeHttpTransport()..stubGet('/status', '<response/>');
      expect(await _sysInfo(fake).getStatus(), isNull);
    });

    test('throws AdvanNetServerError on ErrorResponse', () async {
      final fake = FakeHttpTransport()
        ..stubGet(
          '/status',
          '<response><error><code>FORBIDDEN</code></error></response>',
        );
      expect(
        () => _sysInfo(fake).getStatus(),
        throwsA(isA<AdvanNetServerError>()),
      );
    });
  });

  group('SystemInfoResource.getTime()', () {
    test('calls GET /system/time', () async {
      final fake = FakeHttpTransport()
        ..stubGet('/system/time', '<data><time>1706265600000</time></data>');
      await _sysInfo(fake).getTime();
      expect(fake.calls.single.path, '/system/time');
    });

    test('returns the time string', () async {
      final fake = FakeHttpTransport()
        ..stubGet('/system/time', '<data><time>1706265600000</time></data>');
      expect(await _sysInfo(fake).getTime(), '1706265600000');
    });

    test('returns null on EmptyResponse', () async {
      final fake = FakeHttpTransport()..stubGet('/system/time', '<response/>');
      expect(await _sysInfo(fake).getTime(), isNull);
    });
  });

  group('SystemInfoResource.setTime()', () {
    test('calls PUT /system/time with timestamp in body', () async {
      final fake = FakeHttpTransport()..stubPut('/system/time', '<response/>');
      await _sysInfo(fake).setTime(1706265600000);
      expect(fake.calls.single.method, 'PUT');
      expect(fake.calls.single.path, '/system/time');
      expect(fake.calls.single.body, contains('1706265600000'));
    });
  });

  group('SystemInfoResource.setParameter()', () {
    test('calls PUT /system/parameter/{name} with plain string body', () async {
      final fake = FakeHttpTransport()
        ..stubPut('/system/parameter/COMM_TCP3177_ENCODER', '<response/>');
      await _sysInfo(fake).setParameter('COMM_TCP3177_ENCODER', 'XML_V2_3');
      expect(fake.calls.single.method, 'PUT');
      expect(fake.calls.single.path, '/system/parameter/COMM_TCP3177_ENCODER');
      expect(fake.calls.single.body, 'XML_V2_3');
    });
  });
}
