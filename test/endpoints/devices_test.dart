import 'package:advannet_client/advannet_client.dart';
import 'package:advannet_client/advannet_client_testing.dart';
import 'package:test/test.dart';

RawResource _rawWith(FakeHttpTransport fake) =>
    RawResource(transport: fake, parser: const EnvelopeParser());

DevicesResource _devices(FakeHttpTransport fake) =>
    DevicesResource(raw: _rawWith(fake));

void main() {
  group('DevicesResource.list()', () {
    test('returns empty list on EmptyResponse', () async {
      final fake = FakeHttpTransport()..stubGet('/devices', '<response/>');
      final devices = await _devices(fake).list();
      expect(devices, isEmpty);
    });

    test('returns single device with parsed id', () async {
      final fake = FakeHttpTransport()
        ..stubGet('/devices', '''
<response>
  <entries>
    <entry><class>ADRDevice</class><def>reader-01</def></entry>
  </entries>
</response>''');
      final devices = await _devices(fake).list();
      expect(devices, hasLength(1));
      expect(devices.first.id, 'reader-01');
    });

    test('returns multiple devices', () async {
      final fake = FakeHttpTransport()
        ..stubGet('/devices', '''
<response>
  <entries>
    <entry><class>ADRDevice</class><def>r1</def></entry>
    <entry><class>ADRDevice</class><def>r2</def></entry>
  </entries>
</response>''');
      final devices = await _devices(fake).list();
      expect(devices.map((d) => d.id), ['r1', 'r2']);
    });

    test('parses first comma-separated field as device id', () async {
      final fake = FakeHttpTransport()
        ..stubGet('/devices', '''
<response>
  <entries>
    <entry><class>ADRDevice</class><def>device-1,extra,fields</def></entry>
  </entries>
</response>''');
      final devices = await _devices(fake).list();
      expect(devices.first.id, 'device-1');
    });

    test('throws AdvanNetServerError on ErrorResponse', () async {
      final fake = FakeHttpTransport()
        ..stubGet('/devices', '''
<response>
  <error><code>FORBIDDEN</code><message>Not allowed</message></error>
</response>''');
      expect(
        () => _devices(fake).list(),
        throwsA(
          isA<AdvanNetServerError>().having((e) => e.code, 'code', 'FORBIDDEN'),
        ),
      );
    });

    test('returns devices from new-style data response', () async {
      final fake = FakeHttpTransport()
        ..stubGet('/devices', '''
<response>
  <type>response</type>
  <status>OK</status>
  <op>devices</op>
  <data>
    <devices>
      <device>
        <id>AdvanReader-m4-160</id>
        <ip>192.168.26.120</ip>
        <mac>64:cf:d9:c7:56:1c</mac>
        <serial>0091104::64cfd9c7561c</serial>
        <family>AdvanReader</family>
        <status>RUNNING</status>
      </device>
      <device><id>AdvanReader-m4-161</id></device>
    </devices>
  </data>
</response>''');
      final devices = await _devices(fake).list();
      expect(devices, hasLength(2));
      expect(devices[0].id, 'AdvanReader-m4-160');
      expect(devices[0].ip, '192.168.26.120');
      expect(devices[0].mac, '64:cf:d9:c7:56:1c');
      expect(devices[0].serial, '0091104::64cfd9c7561c');
      expect(devices[0].family, DeviceFamily.advanReader);
      expect(devices[0].status, DeviceStatus.running);
      expect(devices[1].id, 'AdvanReader-m4-161');
      expect(devices[1].ip, isNull);
    });

    test(
      'parses isAlive, activeDeviceMode, activeReadMode, lastSeen',
      () async {
        final fake = FakeHttpTransport()
          ..stubGet('/devices', '''
<response>
  <status>OK</status>
  <data>
    <devices>
      <device>
        <id>AdvanReader-m4-150</id>
        <isAlive>true</isAlive>
        <activeDeviceMode>Autonomous</activeDeviceMode>
        <activeReadMode>AUTONOMOUS</activeReadMode>
        <lastSeen>20150316 1445.29</lastSeen>
        <status>STOPPED</status>
      </device>
    </devices>
  </data>
</response>''');
        final device = (await _devices(fake).list()).first;
        expect(device.isAlive, isTrue);
        expect(device.activeDeviceMode, 'Autonomous');
        expect(device.activeReadMode, 'AUTONOMOUS');
        expect(device.lastSeen, '20150316 1445.29');
      },
    );

    test('isAlive is null when element absent', () async {
      final fake = FakeHttpTransport()
        ..stubGet('/devices', '''
<response><status>OK</status><data><devices>
  <device><id>r1</id></device>
</devices></data></response>''');
      final device = (await _devices(fake).list()).first;
      expect(device.isAlive, isNull);
      expect(device.activeDeviceMode, isNull);
      expect(device.activeReadMode, isNull);
    });

    test('returns empty list when <data> has no <devices> element', () async {
      final fake = FakeHttpTransport()
        ..stubGet('/devices', '<response><data><x/></data></response>');
      expect(await _devices(fake).list(), isEmpty);
    });

    test(
      'throws AdvanNetServerError on new-style status=ERROR response',
      () async {
        final fake = FakeHttpTransport()
          ..stubGet('/devices', '''
<response>
  <status>ERROR</status>
  <op>devices</op>
  <msg>UNKNOWN_OPERATION: Operation [devices] unknown.</msg>
</response>''');
        expect(
          () => _devices(fake).list(),
          throwsA(isA<AdvanNetServerError>()),
        );
      },
    );
  });

  group('DevicesResource.start()', () {
    test('calls GET /devices/{id}/start', () async {
      final fake = FakeHttpTransport()
        ..stubGet('/devices/reader-01/start', '<response/>');
      await _devices(fake).start('reader-01');
      expect(fake.calls.single.path, '/devices/reader-01/start');
      expect(fake.calls.single.method, 'GET');
    });

    test('throws AdvanNetServerError on ErrorResponse', () async {
      final fake = FakeHttpTransport()
        ..stubGet('/devices/r1/start', '''
<response>
  <error><code>BUSY</code></error>
</response>''');
      expect(
        () => _devices(fake).start('r1'),
        throwsA(
          isA<AdvanNetServerError>().having((e) => e.code, 'code', 'BUSY'),
        ),
      );
    });
  });

  group('DevicesResource.stop()', () {
    test('calls GET /devices/{id}/stop', () async {
      final fake = FakeHttpTransport()
        ..stubGet('/devices/reader-01/stop', '<response/>');
      await _devices(fake).stop('reader-01');
      expect(fake.calls.single.path, '/devices/reader-01/stop');
    });

    test('throws AdvanNetServerError on ErrorResponse', () async {
      final fake = FakeHttpTransport()
        ..stubGet('/devices/r1/stop', '''
<response>
  <error><code>NOT_FOUND</code></error>
</response>''');
      expect(
        () => _devices(fake).stop('r1'),
        throwsA(isA<AdvanNetServerError>()),
      );
    });
  });

  group('AdvanNetDevice', () {
    test('equality is based on id', () {
      expect(
        const AdvanNetDevice(id: 'x'),
        equals(const AdvanNetDevice(id: 'x')),
      );
      expect(
        const AdvanNetDevice(id: 'x'),
        isNot(equals(const AdvanNetDevice(id: 'y'))),
      );
    });
  });

  group('DevicesResource reader params', () {
    test('getReaderParams calls GET /devices/{id}/reader', () async {
      final fake = FakeHttpTransport()
        ..stubGet(
          '/devices/r1/reader',
          '<data><RF_READ_POWER><result>20</result></RF_READ_POWER></data>',
        );
      final params = await _devices(fake).getReaderParams('r1');
      expect(fake.calls.single.path, '/devices/r1/reader');
      expect(fake.calls.single.method, 'GET');
      expect(params['RF_READ_POWER'], '20');
    });

    test(
      'getReaderParams parses <params> sub-container (real device format)',
      () async {
        final fake = FakeHttpTransport()
          ..stubGet('/devices/r1/reader', '''
<data>
  <params>
    <RF_READ_POWER><result>31.5</result><read-only>false</read-only></RF_READ_POWER>
    <RF_SENSITIVITY><result>-82.0</result><read-only>false</read-only></RF_SENSITIVITY>
    <RF_PORT_NUMBER><result>4</result><read-only>true</read-only></RF_PORT_NUMBER>
  </params>
  <ip>/dev/ttyO1</ip>
  <model>M6e</model>
</data>''');
        final params = await _devices(fake).getReaderParams('r1');
        expect(params['RF_READ_POWER'], '31.5');
        expect(params['RF_SENSITIVITY'], '-82.0');
        expect(params['RF_PORT_NUMBER'], '4');
        expect(params['ip'], '/dev/ttyO1');
        expect(params['model'], 'M6e');
      },
    );

    test('getReaderParams returns empty map on EmptyResponse', () async {
      final fake = FakeHttpTransport()
        ..stubGet('/devices/r1/reader', '<response/>');
      expect(await _devices(fake).getReaderParams('r1'), isEmpty);
    });

    test('getAllReaderParams calls GET /devices/{id}/reader/params', () async {
      final fake = FakeHttpTransport()
        ..stubGet('/devices/r1/reader/params', '<data/>');
      await _devices(fake).getAllReaderParams('r1');
      expect(fake.calls.single.path, '/devices/r1/reader/params');
    });

    test(
      'setReaderParam calls PUT /devices/{id}/reader/parameter/{name}',
      () async {
        final fake = FakeHttpTransport()
          ..stubPut(
            '/devices/r1/reader/parameter/RF_READ_POWER',
            '<response/>',
          );
        await _devices(
          fake,
        ).setReaderParam('r1', ReaderParam.rfReadPower, '20');
        expect(fake.calls.single.method, 'PUT');
        expect(
          fake.calls.single.path,
          '/devices/r1/reader/parameter/RF_READ_POWER',
        );
        expect(fake.calls.single.body, '20');
      },
    );
  });

  group('DevicesResource device modes', () {
    test('getDeviceModes returns empty list on EmptyResponse', () async {
      final fake = FakeHttpTransport()
        ..stubGet('/devices/r1/deviceModes', '<response/>');
      expect(await _devices(fake).getDeviceModes('r1'), isEmpty);
    });

    test('getDeviceModes parses EntriesResponse def fields', () async {
      final fake = FakeHttpTransport()
        ..stubGet('/devices/r1/deviceModes', '''
<response>
  <entries>
    <entry><class>ADRMode</class><def>AdvanNetAsyncRead</def></entry>
    <entry><class>ADRMode</class><def>AdvanNetScan</def></entry>
  </entries>
</response>''');
      final modes = await _devices(fake).getDeviceModes('r1');
      expect(modes, ['AdvanNetAsyncRead', 'AdvanNetScan']);
    });

    test('getDeviceModes parses real device data-wrapped entries', () async {
      final fake = FakeHttpTransport()
        ..stubGet('/devices/r1/deviceModes', '''
<response>
  <status>OK</status>
  <op>deviceModes</op>
  <data>
    <entries>
      <entry>
        <id>Autonomous</id>
        <defaultReadMode>AUTONOMOUS</defaultReadMode>
      </entry>
      <entry>
        <id>Sequential</id>
        <defaultReadMode>SEQUENTIAL</defaultReadMode>
      </entry>
      <entry>
        <id>Alarm mode</id>
        <defaultReadMode>EPC_EAS_ALARM</defaultReadMode>
      </entry>
    </entries>
  </data>
</response>''');
      final modes = await _devices(fake).getDeviceModes('r1');
      expect(modes, ['Autonomous', 'Sequential', 'Alarm mode']);
    });

    test('getActiveReadMode calls GET /devices/{id}/activeReadMode', () async {
      final fake = FakeHttpTransport()
        ..stubGet(
          '/devices/r1/activeReadMode',
          '<data><name>AdvanNetAsyncRead</name></data>',
        );
      final mode = await _devices(fake).getActiveReadMode('r1');
      expect(mode, 'AdvanNetAsyncRead');
      expect(fake.calls.single.path, '/devices/r1/activeReadMode');
    });

    test('getActiveReadMode returns null on EmptyResponse', () async {
      final fake = FakeHttpTransport()
        ..stubGet('/devices/r1/activeReadMode', '<response/>');
      expect(await _devices(fake).getActiveReadMode('r1'), isNull);
    });

    test(
      'setActiveDeviceMode calls PUT /devices/{id}/activeDeviceMode',
      () async {
        final fake = FakeHttpTransport()
          ..stubPut('/devices/r1/activeDeviceMode', '<response/>');
        await _devices(fake).setActiveDeviceMode('r1', DeviceMode.autonomous);
        expect(fake.calls.single.method, 'PUT');
        expect(fake.calls.single.path, '/devices/r1/activeDeviceMode');
        expect(fake.calls.single.body, DeviceMode.autonomous.id);
      },
    );

    test(
      'getActiveDeviceMode calls GET /devices/{id}/activeDeviceMode',
      () async {
        final fake = FakeHttpTransport()
          ..stubGet(
            '/devices/r1/activeDeviceMode',
            '<data><result>Autonomous</result></data>',
          );
        final mode = await _devices(fake).getActiveDeviceMode('r1');
        expect(mode, 'Autonomous');
        expect(fake.calls.single.path, '/devices/r1/activeDeviceMode');
      },
    );

    test('getActiveDeviceMode returns null on EmptyResponse', () async {
      final fake = FakeHttpTransport()
        ..stubGet('/devices/r1/activeDeviceMode', '<response/>');
      expect(await _devices(fake).getActiveDeviceMode('r1'), isNull);
    });

    test('setActiveReadMode calls PUT /devices/{id}/activeReadMode', () async {
      final fake = FakeHttpTransport()
        ..stubPut('/devices/r1/activeReadMode', '<response/>');
      await _devices(fake).setActiveReadMode('r1', 'AUTONOMOUS');
      expect(fake.calls.single.method, 'PUT');
      expect(fake.calls.single.path, '/devices/r1/activeReadMode');
      expect(fake.calls.single.body, 'AUTONOMOUS');
    });
  });

  group('DevicesResource lifecycle (connect/shutdown)', () {
    test('connect calls GET /devices/{id}/connect', () async {
      final fake = FakeHttpTransport()
        ..stubGet('/devices/r1/connect', '<response/>');
      await _devices(fake).connect('r1');
      expect(fake.calls.single.path, '/devices/r1/connect');
      expect(fake.calls.single.method, 'GET');
    });

    test('shutdown calls GET /devices/{id}/shutdown', () async {
      final fake = FakeHttpTransport()
        ..stubGet('/devices/r1/shutdown', '<response/>');
      await _devices(fake).shutdown('r1');
      expect(fake.calls.single.path, '/devices/r1/shutdown');
    });

    test('connect throws AdvanNetServerError on ErrorResponse', () async {
      final fake = FakeHttpTransport()
        ..stubGet(
          '/devices/r1/connect',
          '<response><error><code>COMM_ERROR</code></error></response>',
        );
      expect(
        () => _devices(fake).connect('r1'),
        throwsA(isA<AdvanNetServerError>()),
      );
    });
  });

  group('DevicesResource inventory', () {
    test('getInventory calls GET /devices/{id}/inventory', () async {
      final fake = FakeHttpTransport()
        ..stubGet('/devices/r1/inventory', '<data><tags/></data>');
      final data = await _devices(fake).getInventory('r1');
      expect(fake.calls.single.path, '/devices/r1/inventory');
      expect(data, isNotNull);
    });

    test('getInventory returns null on EmptyResponse', () async {
      final fake = FakeHttpTransport()
        ..stubGet('/devices/r1/inventory', '<response/>');
      expect(await _devices(fake).getInventory('r1'), isNull);
    });

    test('getLocation calls GET /devices/{id}/location', () async {
      final fake = FakeHttpTransport()
        ..stubGet('/devices/r1/location', '<data/>');
      await _devices(fake).getLocation('r1');
      expect(fake.calls.single.path, '/devices/r1/location');
    });
  });

  group('DevicesResource GPI trigger', () {
    test(
      'getGpiTrigger calls GET /devices/{id}/reader/parameter/TRIGGER_CONF',
      () async {
        final fake = FakeHttpTransport()
          ..stubGet(
            '/devices/r1/reader/parameter/TRIGGER_CONF',
            '<data><result>{"onTime":3500}</result></data>',
          );
        final json = await _devices(fake).getGpiTrigger('r1');
        expect(
          fake.calls.single.path,
          '/devices/r1/reader/parameter/TRIGGER_CONF',
        );
        expect(fake.calls.single.method, 'GET');
        expect(json, '{"onTime":3500}');
      },
    );

    test('getGpiTrigger returns null on EmptyResponse', () async {
      final fake = FakeHttpTransport()
        ..stubGet('/devices/r1/reader/parameter/TRIGGER_CONF', '<response/>');
      expect(await _devices(fake).getGpiTrigger('r1'), isNull);
    });

    test('setGpiTrigger calls PUT with JSON body', () async {
      final fake = FakeHttpTransport()
        ..stubPut('/devices/r1/reader/parameter/TRIGGER_CONF', '<response/>');
      const json =
          '{"onTime":3500,"trigger":[{"gpi":1,"conf":{"antennas":"1,2"}}]}';
      await _devices(fake).setGpiTrigger('r1', json);
      expect(fake.calls.single.method, 'PUT');
      expect(
        fake.calls.single.path,
        '/devices/r1/reader/parameter/TRIGGER_CONF',
      );
      expect(fake.calls.single.body, json);
    });

    test('setGpiTrigger throws AdvanNetServerError on ErrorResponse', () async {
      final fake = FakeHttpTransport()
        ..stubPut(
          '/devices/r1/reader/parameter/TRIGGER_CONF',
          '<response><error><code>BAD_REQUEST</code></error></response>',
        );
      expect(
        () => _devices(fake).setGpiTrigger('r1', '{}'),
        throwsA(isA<AdvanNetServerError>()),
      );
    });
  });

  group('DevicesResource MCU / time', () {
    test(
      'getDatetime calls GET /devices/{id}/MCU/parameter/MCU_DATETIME',
      () async {
        final fake = FakeHttpTransport()
          ..stubGet(
            '/devices/r1/MCU/parameter/MCU_DATETIME',
            '<data>2024-01-26T12:00:00Z</data>',
          );
        final dt = await _devices(fake).getDatetime('r1');
        expect(dt, '2024-01-26T12:00:00Z');
        expect(
          fake.calls.single.path,
          '/devices/r1/MCU/parameter/MCU_DATETIME',
        );
      },
    );

    test('getDatetime returns null on EmptyResponse', () async {
      final fake = FakeHttpTransport()
        ..stubGet('/devices/r1/MCU/parameter/MCU_DATETIME', '<response/>');
      expect(await _devices(fake).getDatetime('r1'), isNull);
    });

    test(
      'setDatetime calls PUT /devices/{id}/MCU/parameter/MCU_DATETIME',
      () async {
        final fake = FakeHttpTransport()
          ..stubPut('/devices/r1/MCU/parameter/MCU_DATETIME', '<response/>');
        await _devices(fake).setDatetime('r1', '2024-01-26T12:00:00Z');
        expect(fake.calls.single.method, 'PUT');
        expect(
          fake.calls.single.path,
          '/devices/r1/MCU/parameter/MCU_DATETIME',
        );
        expect(fake.calls.single.body, '2024-01-26T12:00:00Z');
      },
    );

    test(
      'setTimezone calls PUT /devices/{id}/MCU/parameter/MCU_TIMEZONE',
      () async {
        final fake = FakeHttpTransport()
          ..stubPut('/devices/r1/MCU/parameter/MCU_TIMEZONE', '<response/>');
        await _devices(fake).setTimezone('r1', 'Europe/Paris');
        expect(
          fake.calls.single.path,
          '/devices/r1/MCU/parameter/MCU_TIMEZONE',
        );
        expect(fake.calls.single.body, 'Europe/Paris');
      },
    );

    test('getTimezoneList returns sorted list of timezone strings', () async {
      final fake = FakeHttpTransport()
        ..stubGet(
          '/devices/r1/MCU/parameter/MCU_TIMEZONE_LIST',
          '<data><result>Europe/Paris,America/New_York,Africa/Abidjan</result></data>',
        );
      final zones = await _devices(fake).getTimezoneList('r1');
      expect(zones, ['Africa/Abidjan', 'America/New_York', 'Europe/Paris']);
    });

    test('getTimezoneList returns empty list on EmptyResponse', () async {
      final fake = FakeHttpTransport()
        ..stubGet('/devices/r1/MCU/parameter/MCU_TIMEZONE_LIST', '<response/>');
      expect(await _devices(fake).getTimezoneList('r1'), isEmpty);
    });
  });
}
