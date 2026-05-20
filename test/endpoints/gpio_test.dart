import 'package:advannet_client/advannet_client.dart';
import 'package:advannet_client/advannet_client_testing.dart';
import 'package:test/test.dart';

RawResource _raw(FakeHttpTransport fake) =>
    RawResource(transport: fake, parser: const EnvelopeParser());

GpioResource _gpio(FakeHttpTransport fake) => GpioResource(raw: _raw(fake));

void main() {
  group('GpioResource.getOutputs()', () {
    test('calls GET /devices/{id}/gpioAll', () async {
      final fake = FakeHttpTransport()
        ..stubGet(
          '/devices/r1/gpioAll',
          '<data><GPO1>false</GPO1><GPO2>true</GPO2></data>',
        );
      await _gpio(fake).getOutputs('r1');
      expect(fake.calls.single.path, '/devices/r1/gpioAll');
      expect(fake.calls.single.method, 'GET');
    });

    test('parses GPO states into a map', () async {
      final fake = FakeHttpTransport()
        ..stubGet(
          '/devices/r1/gpioAll',
          '<data><GPO1>false</GPO1><GPO2>true</GPO2></data>',
        );
      final outputs = await _gpio(fake).getOutputs('r1');
      expect(outputs[1], isFalse);
      expect(outputs[2], isTrue);
    });

    test('returns empty map on EmptyResponse', () async {
      final fake = FakeHttpTransport()
        ..stubGet('/devices/r1/gpioAll', '<response/>');
      expect(await _gpio(fake).getOutputs('r1'), isEmpty);
    });

    test('throws AdvanNetServerError on ErrorResponse', () async {
      final fake = FakeHttpTransport()
        ..stubGet(
          '/devices/r1/gpioAll',
          '<response><error><code>NOT_FOUND</code></error></response>',
        );
      expect(
        () => _gpio(fake).getOutputs('r1'),
        throwsA(isA<AdvanNetServerError>()),
      );
    });
  });

  group('GpioResource.setOutput()', () {
    test('calls GET /devices/{id}/setGPO/{gpo}/{state}', () async {
      final fake = FakeHttpTransport()
        ..stubGet('/devices/r1/setGPO/1/true', '<response/>');
      await _gpio(fake).setOutput('r1', 1, active: true);
      expect(fake.calls.single.method, 'GET');
      expect(fake.calls.single.path, '/devices/r1/setGPO/1/true');
    });

    test('encodes active=false as false in path', () async {
      final fake = FakeHttpTransport()
        ..stubGet('/devices/r1/setGPO/2/false', '<response/>');
      await _gpio(fake).setOutput('r1', 2, active: false);
      expect(fake.calls.single.path, '/devices/r1/setGPO/2/false');
    });
  });

  group('GpioResource.setOutputs()', () {
    test('calls setOutput for each entry', () async {
      final fake = FakeHttpTransport()
        ..stubGet('/devices/r1/setGPO/1/true', '<response/>')
        ..stubGet('/devices/r1/setGPO/2/false', '<response/>');
      await _gpio(fake).setOutputs('r1', {1: true, 2: false});
      expect(fake.calls, hasLength(2));
      expect(fake.calls[0].path, '/devices/r1/setGPO/1/true');
      expect(fake.calls[1].path, '/devices/r1/setGPO/2/false');
    });
  });

  group('GpioResource.activateBuzzer()', () {
    test('calls GET /devices/{id}/buzz/{timeOn}/{timeOff}/{total}', () async {
      final fake = FakeHttpTransport()
        ..stubGet('/devices/r1/buzz/500/100/500', '<response/>');
      await _gpio(fake).activateBuzzer('r1');
      expect(fake.calls.single.method, 'GET');
      expect(fake.calls.single.path, '/devices/r1/buzz/500/100/500');
    });

    test('uses provided time parameters', () async {
      final fake = FakeHttpTransport()
        ..stubGet('/devices/r1/buzz/300/50/1000', '<response/>');
      await _gpio(fake).activateBuzzer(
        'r1',
        timeOnMs: 300,
        timeOffMs: 50,
        totalDurationMs: 1000,
      );
      expect(fake.calls.single.path, '/devices/r1/buzz/300/50/1000');
    });
  });

  group('GpioResource.activateSpeaker()', () {
    test('calls GET /devices/{id}/speak/... with default parameters', () async {
      final fake = FakeHttpTransport()
        ..stubGet('/devices/r1/speak/1000/10/500/0/500', '<response/>');
      await _gpio(fake).activateSpeaker('r1');
      expect(fake.calls.single.method, 'GET');
      expect(fake.calls.single.path, '/devices/r1/speak/1000/10/500/0/500');
    });

    test('uses provided parameters', () async {
      final fake = FakeHttpTransport()
        ..stubGet('/devices/r1/speak/500/8/200/100/1000', '<response/>');
      await _gpio(fake).activateSpeaker(
        'r1',
        frequencyHz: 500,
        volume: 8,
        timeOffMs: 100,
        timeOnMs: 200,
        totalDurationMs: 1000,
      );
      expect(fake.calls.single.path, '/devices/r1/speak/500/8/200/100/1000');
    });
  });

  group('GpioResource.getInputs()', () {
    test('calls GET /devices/{id}/gpioAll', () async {
      final fake = FakeHttpTransport()
        ..stubGet(
          '/devices/r1/gpioAll',
          '<data><GPI1>false</GPI1><GPI2>true</GPI2></data>',
        );
      await _gpio(fake).getInputs('r1');
      expect(fake.calls.single.path, '/devices/r1/gpioAll');
      expect(fake.calls.single.method, 'GET');
    });

    test('parses GPI states into a map', () async {
      final fake = FakeHttpTransport()
        ..stubGet(
          '/devices/r1/gpioAll',
          '<data><GPI1>false</GPI1><GPI2>true</GPI2></data>',
        );
      final inputs = await _gpio(fake).getInputs('r1');
      expect(inputs[1], isFalse);
      expect(inputs[2], isTrue);
    });

    test('ignores GPO elements', () async {
      final fake = FakeHttpTransport()
        ..stubGet(
          '/devices/r1/gpioAll',
          '<data><GPI1>true</GPI1><GPO1>false</GPO1></data>',
        );
      final inputs = await _gpio(fake).getInputs('r1');
      expect(inputs.keys, [1]);
    });

    test('returns empty map on EmptyResponse', () async {
      final fake = FakeHttpTransport()
        ..stubGet('/devices/r1/gpioAll', '<response/>');
      expect(await _gpio(fake).getInputs('r1'), isEmpty);
    });

    test('throws AdvanNetServerError on ErrorResponse', () async {
      final fake = FakeHttpTransport()
        ..stubGet(
          '/devices/r1/gpioAll',
          '<response><error><code>NOT_FOUND</code></error></response>',
        );
      expect(
        () => _gpio(fake).getInputs('r1'),
        throwsA(isA<AdvanNetServerError>()),
      );
    });
  });

  group('GpioResource.getSensors()', () {
    const sensorJson =
        '{"sensors":['
        '{"unit":"W","line":7,"value":9.46,"desc":"Consumption"},'
        '{"unit":"C","line":2,"value":44.27,"desc":"PS Temperature"},'
        '{"unit":"V","line":5,"value":5.05,"desc":"Internal Voltage"}'
        '],"gpis":[],"gpos":[]}';

    test('calls GET /devices/{id}/gpioAllJSON', () async {
      final fake = FakeHttpTransport()
        ..stubGet(
          '/devices/r1/gpioAllJSON',
          '<data><result>$sensorJson</result></data>',
        );
      await _gpio(fake).getSensors('r1');
      expect(fake.calls.single.path, '/devices/r1/gpioAllJSON');
    });

    test('parses sensor list with desc, unit, line and value', () async {
      final fake = FakeHttpTransport()
        ..stubGet(
          '/devices/r1/gpioAllJSON',
          '<data><result>$sensorJson</result></data>',
        );
      final sensors = await _gpio(fake).getSensors('r1');
      expect(sensors, hasLength(3));
      final c = sensors.firstWhere((s) => s.desc == 'Consumption');
      expect(c.value, 9.46);
      expect(c.unit, 'W');
      expect(c.line, 7);
    });

    test('returns empty list on EmptyResponse', () async {
      final fake = FakeHttpTransport()
        ..stubGet('/devices/r1/gpioAllJSON', '<response/>');
      expect(await _gpio(fake).getSensors('r1'), isEmpty);
    });

    test('throws AdvanNetServerError on ErrorResponse', () async {
      final fake = FakeHttpTransport()
        ..stubGet(
          '/devices/r1/gpioAllJSON',
          '<response><error><code>NOT_FOUND</code></error></response>',
        );
      expect(
        () => _gpio(fake).getSensors('r1'),
        throwsA(isA<AdvanNetServerError>()),
      );
    });
  });

  group('GpioResource.getGPILine()', () {
    test('calls GET /devices/{id}/getGPI/{line}', () async {
      final fake = FakeHttpTransport()
        ..stubGet('/devices/r1/getGPI/3', '<data><result>true</result></data>');
      final state = await _gpio(fake).getGPILine('r1', 3);
      expect(state, isTrue);
      expect(fake.calls.single.path, '/devices/r1/getGPI/3');
    });

    test('returns false for false result', () async {
      final fake = FakeHttpTransport()
        ..stubGet(
          '/devices/r1/getGPI/1',
          '<data><result>false</result></data>',
        );
      expect(await _gpio(fake).getGPILine('r1', 1), isFalse);
    });

    test('throws AdvanNetServerError on ErrorResponse', () async {
      final fake = FakeHttpTransport()
        ..stubGet(
          '/devices/r1/getGPI/99',
          '<response><error><code>INVALID_GPI_NUMBER</code></error></response>',
        );
      expect(
        () => _gpio(fake).getGPILine('r1', 99),
        throwsA(isA<AdvanNetServerError>()),
      );
    });
  });

  group('GpioResource.getGPIAll()', () {
    test('calls GET /devices/{id}/getGPIAll', () async {
      final fake = FakeHttpTransport()
        ..stubGet('/devices/r1/getGPIAll', '''
<data>
  <entries>
    <entry><index>0</index><result>false</result></entry>
    <entry><index>1</index><result>true</result></entry>
  </entries>
</data>''');
      final gpi = await _gpio(fake).getGPIAll('r1');
      expect(fake.calls.single.path, '/devices/r1/getGPIAll');
      expect(gpi[1], isFalse);
      expect(gpi[2], isTrue);
    });

    test('returns empty map on EmptyResponse', () async {
      final fake = FakeHttpTransport()
        ..stubGet('/devices/r1/getGPIAll', '<response/>');
      expect(await _gpio(fake).getGPIAll('r1'), isEmpty);
    });
  });

  group('GpioResource.getSensorReadings()', () {
    test('calls PUT /devices/{id}/sensorAll', () async {
      final fake = FakeHttpTransport()
        ..stubPut('/devices/r1/sensorAll', '''
<data>
  <SENSOR_AUX_TEMPERATURE_2>35.0</SENSOR_AUX_TEMPERATURE_2>
  <SENSOR_LIGHT_7>NaN</SENSOR_LIGHT_7>
  <SENSOR_VOLTAGE_5>0.02</SENSOR_VOLTAGE_5>
</data>''');
      final readings = await _gpio(fake).getSensorReadings('r1');
      expect(fake.calls.single.path, '/devices/r1/sensorAll');
      expect(fake.calls.single.method, 'PUT');
      expect(readings['SENSOR_AUX_TEMPERATURE_2'], 35.0);
      expect(readings['SENSOR_LIGHT_7']?.isNaN, isTrue);
      expect(readings['SENSOR_VOLTAGE_5'], 0.02);
    });

    test('returns empty map on EmptyResponse', () async {
      final fake = FakeHttpTransport()
        ..stubPut('/devices/r1/sensorAll', '<response/>');
      expect(await _gpio(fake).getSensorReadings('r1'), isEmpty);
    });
  });

  group('GpioResource.getSensorReading()', () {
    test('calls PUT /devices/{id}/sensor/{id}', () async {
      final fake = FakeHttpTransport()
        ..stubPut('/devices/r1/sensor/3', '<data><result>36.5</result></data>');
      final reading = await _gpio(fake).getSensorReading('r1', 3);
      expect(reading, 36.5);
      expect(fake.calls.single.path, '/devices/r1/sensor/3');
      expect(fake.calls.single.method, 'PUT');
    });

    test('returns null on EmptyResponse', () async {
      final fake = FakeHttpTransport()
        ..stubPut('/devices/r1/sensor/1', '<response/>');
      expect(await _gpio(fake).getSensorReading('r1', 1), isNull);
    });
  });

  group('GpioResource constants', () {
    test('relayOutput is 9', () => expect(GpioResource.relayOutput, 9));
    test(
      'powerSupply5VOutput is 10',
      () => expect(GpioResource.powerSupply5VOutput, 10),
    );
  });
}
