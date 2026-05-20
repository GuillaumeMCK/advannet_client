import 'dart:convert';
import 'dart:typed_data';

import 'package:advannet_client/advannet_client.dart';
import 'package:advannet_client/advannet_client_testing.dart';
import 'package:test/test.dart';

Uint8List _frame(String body) {
  final bodyBytes = utf8.encode(body);
  final header =
      'ADVANNET/1.0\r\n'
      'Content-Length:${bodyBytes.length}\r\n'
      'Content-Type:text/xml\r\n'
      '\r\n';
  return Uint8List.fromList([...utf8.encode(header), ...bodyBytes]);
}

const _tagAlarmXml = '''<?xml version="1.0" encoding="UTF-8"?>
<deviceEventMessage>
  <deviceId>r1</deviceId>
  <advanNetId>AdvanNet1</advanNetId>
  <event>
    <type>TAG_ALARM</type>
    <epc>E200001234</epc>
    <ts>1706265600000</ts>
    <alarmType>EPC_EAS</alarmType>
  </event>
</deviceEventMessage>''';

const _gpiXml = '''<?xml version="1.0" encoding="UTF-8"?>
<deviceEventMessage>
  <deviceId>r1</deviceId>
  <event>
    <type>GPI</type>
    <line>1</line>
    <value>1</value>
    <ts>1706265600000</ts>
  </event>
</deviceEventMessage>''';

void main() {
  late FakeConnectionDriver driver;
  late RealtimeStream stream;

  setUp(() {
    driver = FakeConnectionDriver();
    stream = RealtimeStream(driver: driver);
  });

  tearDown(() => driver.done());

  group('RealtimeStream — status forwarding', () {
    test('forwards Connecting status from driver', () async {
      final updates = stream.updates().take(1).toList();
      driver.addStatus(const Connecting());
      driver.done();
      final result = await updates;
      expect(result.single, isA<RealtimeStatusUpdate>());
      expect((result.single as RealtimeStatusUpdate).status, isA<Connecting>());
    });

    test('forwards Connected then Disconnected status', () async {
      final updates = stream.updates().take(2).toList();
      driver.addStatus(const Connected());
      driver.addStatus(const Disconnected());
      driver.done();
      final result = await updates;
      expect((result[0] as RealtimeStatusUpdate).status, isA<Connected>());
      expect((result[1] as RealtimeStatusUpdate).status, isA<Disconnected>());
    });
  });

  group('RealtimeStream — event forwarding', () {
    test('forwards TagReadEvent from framed bytes', () async {
      const xml = '''<?xml version="1.0" encoding="UTF-8"?>
<deviceEventMessage>
  <deviceId>r1</deviceId>
  <event>
    <type>TAG_READ</type>
    <epc>DEADBEEF</epc>
    <hexepc>DEADBEEF</hexepc>
    <ts>1706265600000</ts>
  </event>
</deviceEventMessage>''';
      final eventsFuture = stream
          .updates()
          .where((u) => u is RealtimeEventUpdate)
          .take(1)
          .toList();
      driver.addBytes(_frame(xml));
      driver.done();
      final events = await eventsFuture;
      final event =
          (events.single as RealtimeEventUpdate).event as TagReadEvent;
      expect(event.epc, 'DEADBEEF');
      expect(event.deviceId, 'r1');
    });

    test('emits FrameError status on bad framing', () async {
      final statusFuture = stream
          .updates()
          .where((u) => u is RealtimeStatusUpdate && u.status is FrameError)
          .take(1)
          .toList();
      driver.addBytes(Uint8List.fromList(utf8.encode('GARBAGE\r\n')));
      driver.done();
      final status = await statusFuture;
      expect(status.single, isA<RealtimeStatusUpdate>());
    });
  });

  group('RealtimeStream — filtered streams', () {
    test('tagReads() returns only TagReadEvent', () async {
      const xml = '''<inventory>
  <deviceId>r1</deviceId>
  <advanNetId>AdvanNet1</advanNetId>
  <items>
    <item>
      <event>READ_EVENT</event>
      <epc>TAG001</epc>
      <hexepc>TAG001</hexepc>
      <props>
        <TIME_STAMP>1706265600000</TIME_STAMP>
        <RSSI>-60</RSSI>
        <RF_PHASE>0</RF_PHASE>
        <ANTENNA_PORT>1</ANTENNA_PORT>
        <MUX1>0</MUX1>
        <MUX2>0</MUX2>
        <FREQ>865700</FREQ>
        <GPI>0000</GPI>
      </props>
    </item>
  </items>
</inventory>''';
      final readsFuture = stream.tagReads().take(1).toList();
      driver.addBytes(_frame(xml));
      driver.done();
      final reads = await readsFuture;
      expect(reads.single.epc, 'TAG001');
    });

    test('alarms() filters by kind', () async {
      final alarmsFuture = stream
          .alarms(kind: AlarmKind.global)
          .take(1)
          .toList();
      driver.addBytes(_frame(_tagAlarmXml));
      driver.done();
      final alarms = await alarmsFuture;
      expect(alarms.single.kind, AlarmKind.global);
    });

    test('gpi() returns only GpiEvent', () async {
      final gpiFuture = stream.gpi().take(1).toList();
      driver.addBytes(_frame(_gpiXml));
      driver.done();
      final events = await gpiFuture;
      expect(events.single.line, 1);
      expect(events.single.lowToHigh, isTrue);
    });

    test('gpi(line: 2) filters by line number', () async {
      final gpiFuture = stream
          .gpi(line: 2)
          .take(1)
          .timeout(
            const Duration(milliseconds: 200),
            onTimeout: (sink) => sink.close(),
          );
      driver.addBytes(_frame(_gpiXml)); // line=1
      driver.done();
      final events = await gpiFuture.toList();
      expect(events, isEmpty); // line 1 does not match filter line 2
    });

    test('byType() returns only events matching the type string', () async {
      final future = stream.byType('GPI').take(1).toList();
      driver.addBytes(_frame(_gpiXml));
      driver.done();
      final events = await future;
      expect(events.single.type, 'GPI');
    });
  });
}
