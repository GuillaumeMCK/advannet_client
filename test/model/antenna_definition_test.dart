import 'package:advannet_client/advannet_client.dart';
import 'package:advannet_client/advannet_client_testing.dart';
import 'package:test/test.dart';

const _sampleDef = 'device-1,1,2,0,-1,loc_antenna1,10,20,30';
const _sample = AntennaDefinition(
  deviceId: 'device-1',
  port: 1,
  mux: 2,
  mux2: 0,
  orientation: AntennaOrientation.inbound,
  loc: 'loc_antenna1',
  x: 10,
  y: 20,
  z: 30,
);

void main() {
  group('AntennaDefinition.fromDef()', () {
    test('parses all nine fields', () {
      final a = AntennaDefinition.fromDef(_sampleDef);
      expect(a.deviceId, 'device-1');
      expect(a.port, 1);
      expect(a.mux, 2);
      expect(a.mux2, 0);
      expect(a.orientation, AntennaOrientation.inbound);
      expect(a.loc, 'loc_antenna1');
      expect(a.x, 10);
      expect(a.y, 20);
      expect(a.z, 30);
    });

    test('toDef round-trips to the same string', () {
      expect(AntennaDefinition.fromDef(_sampleDef).toDef(), _sampleDef);
    });

    test('throws FormatException on too few fields', () {
      expect(
        () => AntennaDefinition.fromDef('device-1,1,2'),
        throwsA(isA<FormatException>()),
      );
    });
  });

  group('AntennaDefinition.toDef()', () {
    test('serialises all fields comma-separated', () {
      expect(_sample.toDef(), _sampleDef);
    });
  });

  group('AntennaDefinition equality', () {
    test('equal when all fields match', () {
      expect(_sample, equals(AntennaDefinition.fromDef(_sampleDef)));
    });

    test('not equal when mux differs', () {
      expect(_sample, isNot(equals(_sample.copyWith(mux: 3))));
    });
  });

  group('AntennaOrientation', () {
    test('fromInt maps -1 to inbound', () {
      expect(AntennaOrientation.fromInt(-1), AntennaOrientation.inbound);
    });

    test('fromInt maps 1 to outbound', () {
      expect(AntennaOrientation.fromInt(1), AntennaOrientation.outbound);
    });

    test('fromInt maps 0 to none', () {
      expect(AntennaOrientation.fromInt(0), AntennaOrientation.none);
    });

    test('fromInt maps unknown values to none', () {
      expect(AntennaOrientation.fromInt(99), AntennaOrientation.none);
    });

    test('value round-trips through fromInt', () {
      for (final o in AntennaOrientation.values) {
        expect(AntennaOrientation.fromInt(o.value), o);
      }
    });
  });

  group('DevicesResource antennas', () {
    RawResource raw(FakeHttpTransport fake) =>
        RawResource(transport: fake, parser: const EnvelopeParser());

    DevicesResource devices(FakeHttpTransport fake) =>
        DevicesResource(raw: raw(fake));

    test('getAntennas parses entry def into AntennaDefinition list', () async {
      final fake = FakeHttpTransport()
        ..stubGet('/devices/r1/antennas', '''
<response>
  <entries>
    <entry>
      <class>ADRAntennaPort</class>
      <def>device-1,1,2,0,-1,loc_antenna1,10,20,30</def>
    </entry>
    <entry>
      <class>ADRAntennaPort</class>
      <def>device-1,1,3,0,-1,loc_antenna2,10,21,30</def>
    </entry>
  </entries>
</response>''');
      final result = await devices(fake).getAntennas('r1');
      expect(result, hasLength(2));
      expect(result.first.mux, 2);
      expect(result.last.mux, 3);
    });

    test(
      'getAntennas parses data-wrapped entries (real device format)',
      () async {
        final fake = FakeHttpTransport()
          ..stubGet('/devices/r1/antennas', '''
<response>
  <type>response</type>
  <status>OK</status>
  <op>antennas</op>
  <data>
    <entries>
      <entry>
        <class>ANTENNA_DEFINITION</class>
        <def>AdvanReader-m4-160,1,0,0,0,antenna1,1,0,0</def>
      </entry>
    </entries>
  </data>
</response>''');
        final result = await devices(fake).getAntennas('r1');
        expect(result, hasLength(1));
        expect(result.first.deviceId, 'AdvanReader-m4-160');
        expect(result.first.port, 1);
        expect(result.first.mux, 0);
        expect(result.first.loc, 'antenna1');
      },
    );

    test('getAntennas returns empty list on EmptyResponse', () async {
      final fake = FakeHttpTransport()
        ..stubGet('/devices/r1/antennas', '<response/>');
      expect(await devices(fake).getAntennas('r1'), isEmpty);
    });

    test('setAntennas calls PUT with XML body', () async {
      final fake = FakeHttpTransport()
        ..stubPut('/devices/r1/antennas', '<response/>');
      await devices(fake).setAntennas('r1', [_sample]);
      final call = fake.calls.single;
      expect(call.method, 'PUT');
      expect(call.path, '/devices/r1/antennas');
      expect(call.body, contains(_sampleDef));
    });

    test('setAntennas body XML contains <entries> and <entry>', () async {
      final fake = FakeHttpTransport()
        ..stubPut('/devices/r1/antennas', '<response/>');
      await devices(fake).setAntennas('r1', [_sample]);
      expect(fake.calls.single.body, contains('<entries>'));
      expect(fake.calls.single.body, contains('<entry>'));
    });

    test('setAntennas uses ANTENNA_DEFINITION class name', () async {
      final fake = FakeHttpTransport()
        ..stubPut('/devices/r1/antennas', '<response/>');
      await devices(fake).setAntennas('r1', [_sample]);
      expect(fake.calls.single.body, contains('ANTENNA_DEFINITION'));
    });
  });
}
