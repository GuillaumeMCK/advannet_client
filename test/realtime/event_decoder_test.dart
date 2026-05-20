import 'dart:convert';
import 'dart:io';
import 'dart:typed_data';

import 'package:advannet_client/advannet_client.dart';
import 'package:advannet_client/advannet_client_testing.dart';
import 'package:test/test.dart';

AdvanNetMessage _msg(String xml) => AdvanNetMessage(
  headers: {
    'content-type': 'text/xml',
    'content-length': '${utf8.encode(xml).length}',
  },
  body: Uint8List.fromList(utf8.encode(xml)),
);

AdvanNetMessage _jsonMsg(String json) => AdvanNetMessage(
  headers: {
    'content-type': 'application/json',
    'content-length': '${utf8.encode(json).length}',
  },
  body: Uint8List.fromList(utf8.encode(json)),
);

Future<List<RealtimeUpdate>> _decodeJson(String json) =>
    Stream.value(_jsonMsg(json)).transform(const EventDecoder()).toList();

final _keepalive = AdvanNetMessage(
  headers: {'content-length': '0'},
  body: Uint8List(0),
);

Future<List<RealtimeUpdate>> _decode(String xml) =>
    Stream.value(_msg(xml)).transform(const EventDecoder()).toList();

String _fixture(String name) => File('test/fixtures/$name').readAsStringSync();

void main() {
  group('EventDecoder — inventory', () {
    test('decodes two items from inventory fixture', () async {
      final updates = await _decode(_fixture('inventory.xml'));
      expect(updates, hasLength(2));
      expect(updates[0], isA<RealtimeEventUpdate>());
      final first = (updates[0] as RealtimeEventUpdate).event as TagReadEvent;
      expect(first.epc, 'E20000165919006017520009');
      expect(first.rssi, -67);
      expect(first.antennaPort, 1);
      expect(first.freqKHz, 865700);
      expect(first.location, isNotNull);
      expect(first.location!.x, 1.0);
      expect(first.location!.y, 2.5);
      expect(first.deviceId, 'r1');
      expect(first.gpiSnapshot, [0, 0, 0, 0]);
    });

    test('second inventory item has no locationData', () async {
      final updates = await _decode(_fixture('inventory.xml'));
      final second = (updates[1] as RealtimeEventUpdate).event as TagReadEvent;
      expect(second.location, isNull);
      expect(second.antennaPort, 2);
    });

    test('inventory items have type INVENTORY', () async {
      final updates = await _decode(_fixture('inventory.xml'));
      final first = (updates[0] as RealtimeEventUpdate).event;
      expect(first.type, 'INVENTORY');
    });
  });

  group('EventDecoder — inventory (nested, AdvanReader-m4 format)', () {
    test('decodes two items from nested inventory fixture', () async {
      final updates = await _decode(_fixture('inventory_nested.xml'));
      expect(updates, hasLength(2));
      final first = (updates[0] as RealtimeEventUpdate).event as TagReadEvent;
      expect(first.epc, 'bd01fac6');
      expect(first.hexEpc, 'bd01fac6');
      expect(first.rssi, -22);
      expect(first.antennaPort, 4);
      expect(first.freqKHz, 867500);
      expect(first.rfPhase, 5);
      expect(first.mux1, 0);
      expect(first.mux2, 0);
      expect(first.deviceId, 'AdvanReader-m4-160');
      expect(
        first.serverTs,
        DateTime.fromMillisecondsSinceEpoch(1779868346683),
      );
      expect(first.gpiSnapshot, [0, 0, 0, 0]);
      expect(first.tid, isNull);
    });

    test('second nested item has correct RSSI, port, and TID', () async {
      final updates = await _decode(_fixture('inventory_nested.xml'));
      final second = (updates[1] as RealtimeEventUpdate).event as TagReadEvent;
      expect(second.epc, 'bd01fac7');
      expect(second.rssi, -21);
      expect(second.antennaPort, 2);
      expect(second.tid, 'E2806894200040201890B41A');
      expect(second.gpiSnapshot, [1, 0, 0, 1]);
    });

    test('nested inventory items have type INVENTORY', () async {
      final updates = await _decode(_fixture('inventory_nested.xml'));
      expect((updates[0] as RealtimeEventUpdate).event.type, 'INVENTORY');
    });
  });

  group('EventDecoder — TAG_ALARM (global)', () {
    test('decodes TAG_ALARM fixture to AlarmEvent with kind=global', () async {
      final updates = await _decode(_fixture('tag_alarm.xml'));
      expect(updates, hasLength(1));
      final event = (updates[0] as RealtimeEventUpdate).event as AlarmEvent;
      expect(event.type, 'TAG_ALARM');
      expect(event.kind, AlarmKind.global);
      expect(event.epc, 'E20000165919006017520009');
      expect(event.alarmType, AlarmType.epcEas);
      expect(event.deviceId, 'r1');
      expect(
        event.serverTs,
        DateTime.fromMillisecondsSinceEpoch(1706265600000),
      );
    });
  });

  group('EventDecoder — TAG_ALARM_ANTENNA_1 (per-antenna)', () {
    test('decodes per-antenna alarm with correct port', () async {
      final updates = await _decode(_fixture('tag_alarm_antenna_1.xml'));
      final event = (updates[0] as RealtimeEventUpdate).event as AlarmEvent;
      expect(event.kind, AlarmKind.perAntenna);
      expect(event.antennaPort, 1);
      expect(event.alarmType, AlarmType.nxpEas);
    });
  });

  group('EventDecoder — TAG_ALARM_DISABLED', () {
    test('decodes to AlarmEvent with kind=disabled', () async {
      final updates = await _decode(_fixture('tag_alarm_disabled.xml'));
      final event = (updates[0] as RealtimeEventUpdate).event as AlarmEvent;
      expect(event.kind, AlarmKind.disabled);
      expect(event.epc, 'E20000165919006017520009');
    });
  });

  group('EventDecoder — TAG_ALARM_ENABLED', () {
    test('decodes to AlarmEvent with kind=enabled', () async {
      final updates = await _decode(_fixture('tag_alarm_enabled.xml'));
      final event = (updates[0] as RealtimeEventUpdate).event as AlarmEvent;
      expect(event.kind, AlarmKind.enabled);
    });
  });

  group('EventDecoder — GPI', () {
    test('decodes GPI fixture to GpiEvent', () async {
      final updates = await _decode(_fixture('gpi.xml'));
      final event = (updates[0] as RealtimeEventUpdate).event as GpiEvent;
      expect(event.type, 'GPI');
      expect(event.line, 2);
      expect(event.lowToHigh, isTrue);
      expect(event.deviceId, 'r1');
    });
  });

  group('EventDecoder — ADVANNET_INFO', () {
    test('decodes to SystemInfoEvent', () async {
      final updates = await _decode(_fixture('advannet_info.xml'));
      final event =
          (updates[0] as RealtimeEventUpdate).event as SystemInfoEvent;
      expect(event.type, 'ADVANNET_INFO');
      expect(event.message, 'Reader started successfully');
      expect(event.advanNetId, 'AdvanNet1');
    });
  });

  group('EventDecoder — ADVANNET_DEVICE_CONNECTED', () {
    test('decodes to DeviceConnectedEvent', () async {
      final updates = await _decode(_fixture('device_connected.xml'));
      final event =
          (updates[0] as RealtimeEventUpdate).event as DeviceConnectedEvent;
      expect(event.type, 'ADVANNET_DEVICE_CONNECTED');
      expect(event.advanNetId, 'AdvanNet1');
      expect(event.deviceId, 'r1');
    });
  });

  group('EventDecoder — ADVANNET_DEVICE_DISCONNECTED', () {
    test('decodes to DeviceDisconnectedEvent', () async {
      final updates = await _decode(_fixture('device_disconnected.xml'));
      final event =
          (updates[0] as RealtimeEventUpdate).event as DeviceDisconnectedEvent;
      expect(event.type, 'ADVANNET_DEVICE_DISCONNECTED');
      expect(event.deviceId, 'r1');
    });
  });

  group('EventDecoder — keepalive', () {
    test('silently drops empty-body keepalive frames', () async {
      final updates = await Stream.value(
        _keepalive,
      ).transform(const EventDecoder()).toList();
      expect(updates, isEmpty);
    });

    test(
      'keepalive between real frames does not interrupt the stream',
      () async {
        final xml =
            '<eventMessage><advanNetId>AN-1</advanNetId>'
            '<event><type>ADVANNET_INFO</type><message>ok</message>'
            '<deviceId>r1</deviceId></event></eventMessage>';
        final updates = await Stream.fromIterable([
          _keepalive,
          _msg(xml),
          _keepalive,
        ]).transform(const EventDecoder()).toList();
        expect(updates, hasLength(1));
        expect(
          (updates[0] as RealtimeEventUpdate).event,
          isA<SystemInfoEvent>(),
        );
      },
    );
  });

  group('EventDecoder — error handling', () {
    test('emits DecodeError status on garbage XML without crashing', () async {
      final garbage = AdvanNetMessage(
        headers: {'content-type': 'text/xml', 'content-length': '5'},
        body: Uint8List.fromList(utf8.encode('<<BAD')),
      );
      Object? captured;
      final updates = await Stream.value(garbage)
          .transform(EventDecoder(onDecodeError: (err, _) => captured = err))
          .toList();
      expect(updates, hasLength(1));
      expect(updates[0], isA<RealtimeStatusUpdate>());
      final status = (updates[0] as RealtimeStatusUpdate).status;
      expect(status, isA<DecodeError>());
      expect(captured, isNotNull);
    });

    test('emits DecodeError on unknown root element', () async {
      final updates = await _decode('<weirdRoot><stuff/></weirdRoot>');
      expect(updates[0], isA<RealtimeStatusUpdate>());
      expect((updates[0] as RealtimeStatusUpdate).status, isA<DecodeError>());
    });

    test('continues processing after a decode error', () async {
      final bad = _msg('<<BAD');
      final good = _msg(_fixture('gpi.xml'));
      final updates = await Stream.fromIterable([
        bad,
        good,
      ]).transform(const EventDecoder()).toList();
      expect(updates, hasLength(2));
      expect(updates[0], isA<RealtimeStatusUpdate>());
      expect(updates[1], isA<RealtimeEventUpdate>());
    });

    test('decodes unknown event type to UnknownEvent', () async {
      const xml = '''<deviceEventMessage>
        <deviceId>r1</deviceId>
        <event>
          <type>FUTURE_EVENT</type>
        </event>
      </deviceEventMessage>''';
      final updates = await _decode(xml);
      final event = (updates[0] as RealtimeEventUpdate).event;
      expect(event, isA<UnknownEvent>());
      expect(event.type, 'FUTURE_EVENT');
    });
  });

  group('EventDecoder — TAG_READ from deviceEventMessage', () {
    test('parses TAG_READ with typed fields', () async {
      const xml = '''<deviceEventMessage>
        <deviceId>r1</deviceId>
        <advanNetId>AdvanNet1</advanNetId>
        <event>
          <type>TAG_READ</type>
          <epc>E20000165919006017520009</epc>
          <hexepc>E20000165919006017520009</hexepc>
          <rssi>-55</rssi>
          <antennaPort>3</antennaPort>
          <ts>1706265600000</ts>
        </event>
      </deviceEventMessage>''';
      final updates = await _decode(xml);
      final event = (updates[0] as RealtimeEventUpdate).event as TagReadEvent;
      expect(event.epc, 'E20000165919006017520009');
      expect(event.rssi, -55);
      expect(event.antennaPort, 3);
    });

    test('tolerates missing optional fields without throwing', () async {
      const xml = '''<deviceEventMessage>
        <deviceId>r1</deviceId>
        <event>
          <type>TAG_READ</type>
          <epc>ABC</epc>
        </event>
      </deviceEventMessage>''';
      final updates = await _decode(xml);
      final event = (updates[0] as RealtimeEventUpdate).event as TagReadEvent;
      expect(event.rssi, isNull);
      expect(event.antennaPort, isNull);
    });
  });

  group('EventDecoder — TAG_DIRECTION', () {
    test('decodes TAG_DIRECTION', () async {
      const xml = '''<deviceEventMessage>
        <deviceId>r1</deviceId>
        <event>
          <type>TAG_DIRECTION</type>
          <epc>E200ABC</epc>
          <direction>IN</direction>
          <antennaPort>1</antennaPort>
          <ts>1706265600000</ts>
        </event>
      </deviceEventMessage>''';
      final updates = await _decode(xml);
      final event =
          (updates[0] as RealtimeEventUpdate).event as TagDirectionEvent;
      expect(event.epc, 'E200ABC');
      expect(event.direction, 'IN');
      expect(event.antennaPort, 1);
    });
  });

  // ── JSON (JSONV2 / JSONV3) ──────────────────────────────────────────────────

  group('EventDecoder — JSON TAG_READ (v2)', () {
    const payload =
        '{"type":"inv","ver":"v2","id":"1","status":"OK",'
        '"ts":1706265600000,"devid":"r1","data":{"epc":"E20000165919006017520009",'
        '"uri":"","usermem":"","port":1,"mux1":0,"mux2":0,"rc":0,"rssi":-67,'
        '"freq":865700,"phase":12,"gpi":"0000","loc":null}}';

    test('decodes to TagReadEvent with correct fields', () async {
      final updates = await _decodeJson(payload);
      expect(updates, hasLength(1));
      final event = (updates[0] as RealtimeEventUpdate).event as TagReadEvent;
      expect(event.epc, 'E20000165919006017520009');
      expect(event.rssi, -67);
      expect(event.antennaPort, 1);
      expect(event.freqKHz, 865700);
      expect(event.rfPhase, 12);
      expect(event.mux1, 0);
      expect(event.mux2, 0);
      expect(event.deviceId, 'r1');
      expect(
        event.serverTs,
        DateTime.fromMillisecondsSinceEpoch(1706265600000),
      );
      expect(event.type, 'INVENTORY');
    });

    test('parses gpi snapshot string "0000"', () async {
      final updates = await _decodeJson(payload);
      final event = (updates[0] as RealtimeEventUpdate).event as TagReadEvent;
      expect(event.gpiSnapshot, [0, 0, 0, 0]);
    });
  });

  group('EventDecoder — JSON TAG_READ (v3)', () {
    const payload =
        '{"type":"inv","ver":"v3","id":"2","status":"OK",'
        '"ts":1706265600000,"devid":"r1","data":{"epc":"AABBCC","port":2,"rssi":-55,'
        '"loc":{"x":1.0,"y":2.5,"z":0.0}}}';

    test('decodes v3 minimal fields', () async {
      final updates = await _decodeJson(payload);
      final event = (updates[0] as RealtimeEventUpdate).event as TagReadEvent;
      expect(event.epc, 'AABBCC');
      expect(event.rssi, -55);
      expect(event.antennaPort, 2);
      expect(event.mux1, isNull);
      expect(event.freqKHz, isNull);
    });

    test('decodes loc object to LocationData', () async {
      final updates = await _decodeJson(payload);
      final event = (updates[0] as RealtimeEventUpdate).event as TagReadEvent;
      expect(event.location, isNotNull);
      expect(event.location!.x, 1.0);
      expect(event.location!.y, 2.5);
      expect(event.location!.z, 0.0);
    });
  });

  group('EventDecoder — JSON GPI', () {
    test('decodes lowToHigh=true (boolean)', () async {
      const payload =
          '{"type":"gpi","ver":"v2","id":"3","ts":1706265600000,'
          '"devid":"r1","data":{"line":2,"lowToHigh":true,"duration":50}}';
      final updates = await _decodeJson(payload);
      final event = (updates[0] as RealtimeEventUpdate).event as GpiEvent;
      expect(event.line, 2);
      expect(event.lowToHigh, isTrue);
      expect(event.deviceId, 'r1');
    });

    test('decodes lowToHigh=0 (integer false)', () async {
      const payload =
          '{"type":"gpi","ver":"v3","id":"4","ts":1706265600001,'
          '"devid":"r2","data":{"line":1,"lowToHigh":0,"duration":10}}';
      final updates = await _decodeJson(payload);
      final event = (updates[0] as RealtimeEventUpdate).event as GpiEvent;
      expect(event.lowToHigh, isFalse);
      expect(event.line, 1);
    });
  });

  group('EventDecoder — JSON TAG_ALARM', () {
    test('decodes alarm with port as perAntenna', () async {
      const payload =
          '{"type":"alarm","ver":"v2","id":"5","ts":1706265600000,'
          '"devid":"r1","data":{"type":"EPC_EAS","epc":"E20000165919006017520009",'
          '"tid":"","port":1}}';
      final updates = await _decodeJson(payload);
      final event = (updates[0] as RealtimeEventUpdate).event as AlarmEvent;
      expect(event.epc, 'E20000165919006017520009');
      expect(event.alarmType, AlarmType.epcEas);
      expect(event.kind, AlarmKind.perAntenna);
      expect(event.antennaPort, 1);
    });

    test('decodes alarm without port as global', () async {
      const payload =
          '{"type":"alarm","ver":"v3","id":"6","ts":1706265600000,'
          '"devid":"r1","data":{"type":"NXP_EAS","epc":"AABBCC","tid":""}}';
      final updates = await _decodeJson(payload);
      final event = (updates[0] as RealtimeEventUpdate).event as AlarmEvent;
      expect(event.kind, AlarmKind.global);
      expect(event.alarmType, AlarmType.nxpEas);
      expect(event.antennaPort, isNull);
    });
  });

  group('EventDecoder — JSON TAG_DIRECTION', () {
    test('decodes direction string', () async {
      const payload =
          '{"type":"direction","ver":"v2","id":"7","ts":1706265600000,'
          '"devid":"r1","data":{"epc":"E200ABC","direction":"IN"}}';
      final updates = await _decodeJson(payload);
      final event =
          (updates[0] as RealtimeEventUpdate).event as TagDirectionEvent;
      expect(event.epc, 'E200ABC');
      expect(event.direction, 'IN');
      expect(event.deviceId, 'r1');
    });

    test('decodes direction integer (0/1)', () async {
      const payload =
          '{"type":"direction","ver":"v3","id":"8","ts":1706265600000,'
          '"devid":"r2","data":{"epc":"FFEEDD","direction":1}}';
      final updates = await _decodeJson(payload);
      final event =
          (updates[0] as RealtimeEventUpdate).event as TagDirectionEvent;
      expect(event.direction, '1');
    });
  });

  group('EventDecoder — JSON ETC event', () {
    test('flattens Map data into raw fields', () async {
      const payload =
          '{"type":"event","ver":"v2","id":"9","ts":1706265600000,'
          '"devid":"r1","data":{"key":"value","msg":"hello"}}';
      final updates = await _decodeJson(payload);
      final event = (updates[0] as RealtimeEventUpdate).event as UnknownEvent;
      expect(event.type, 'event');
      expect(event.deviceId, 'r1');
      expect(event.raw['key'], 'value');
      expect(event.raw['msg'], 'hello');
    });

    test('stores scalar data under "data" key', () async {
      const payload =
          '{"type":"event","ver":"v2","id":"9","ts":1706265600000,'
          '"devid":"r1","data":"some string"}';
      final updates = await _decodeJson(payload);
      final event = (updates[0] as RealtimeEventUpdate).event as UnknownEvent;
      expect(event.raw['data'], 'some string');
    });

    test('decodes INFO data into DeviceWarnEvent', () async {
      const payload =
          '{"type":"event","devid":"r1","ts":1706265600000,'
          '"data":{"type":"INFO","subType":"RFStatusChange","msg":"RUNNING"}}';
      final updates = await _decodeJson(payload);
      final event =
          (updates[0] as RealtimeEventUpdate).event as DeviceWarnEvent;
      expect(event.deviceId, 'r1');
      expect(event.message, 'RUNNING');
    });

    test('decodes SENSOR data into MultiSensorEvent', () async {
      const payload =
          '{"type":"event","devid":"r1","ts":1706265600000,'
          '"data":{"type":"SENSOR","info":['
          '{"id":"PoE Voltage","unit":"V","value":-12.27},'
          '{"id":"Consumption","unit":"W","value":3.76},'
          '{"id":"PS Temperature","unit":"C","value":45.05}'
          ']}}';
      final updates = await _decodeJson(payload);
      final event =
          (updates[0] as RealtimeEventUpdate).event as MultiSensorEvent;
      expect(event.deviceId, 'r1');
      expect(event.readings, hasLength(3));
      expect(event.readings[0].desc, 'PoE Voltage');
      expect(event.readings[0].unit, 'V');
      expect(event.readings[0].value, closeTo(-12.27, 0.001));
      expect(event.readings[0].line, 1);
      expect(event.readings[1].desc, 'Consumption');
      expect(event.readings[2].desc, 'PS Temperature');
    });
  });

  group('EventDecoder — JSON keepalive and errors', () {
    test('silently drops empty-body keepalive (JSON content-type)', () async {
      final msg = AdvanNetMessage(
        headers: {'content-type': 'application/json', 'content-length': '0'},
        body: Uint8List(0),
      );
      final updates = await Stream.value(
        msg,
      ).transform(const EventDecoder()).toList();
      expect(updates, isEmpty);
    });

    test('emits DecodeError on malformed JSON', () async {
      final msg = _jsonMsg('{bad json}');
      final updates = await Stream.value(
        msg,
      ).transform(const EventDecoder()).toList();
      expect(updates, hasLength(1));
      expect((updates[0] as RealtimeStatusUpdate).status, isA<DecodeError>());
    });
  });

  group('EventDecoder — TAG_GENERIC', () {
    test('decodes TAG_GENERIC with customEventName=customEvent', () async {
      const xml = '''<deviceEventMessage>
        <deviceId>r1</deviceId>
        <event>
          <type>TAG_GENERIC</type>
          <epc>E200ABC</epc>
          <ts>1706265600000</ts>
        </event>
      </deviceEventMessage>''';
      final updates = await _decode(xml);
      final event =
          (updates[0] as RealtimeEventUpdate).event as TagGenericEvent;
      expect(event.customEventName, 'customEvent');
    });

    test('decodes TAG_GENERIC_2 with customEventName=customEvent2', () async {
      const xml = '''<deviceEventMessage>
        <deviceId>r1</deviceId>
        <event>
          <type>TAG_GENERIC_2</type>
          <epc>E200ABC</epc>
          <ts>1706265600000</ts>
        </event>
      </deviceEventMessage>''';
      final updates = await _decode(xml);
      final event =
          (updates[0] as RealtimeEventUpdate).event as TagGenericEvent;
      expect(event.customEventName, 'customEvent2');
    });
  });
}
