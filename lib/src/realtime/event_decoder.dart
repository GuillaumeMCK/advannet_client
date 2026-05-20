import 'dart:async';
import 'dart:convert';

import 'package:xml/xml.dart';

import '../model/sensor_reading.dart';
import '../xml/xml_extensions.dart';
import 'advannet_message.dart';
import 'events.dart';
import 'status.dart';

// ── extensions ────────────────────────────────────────────────────────────────

extension on String? {
  AlarmType toAlarmType() => switch (this?.trim()) {
    'EPC_EAS' => AlarmType.epcEas,
    'NXP_EAS' => AlarmType.nxpEas,
    'EPCBULK_EAS' => AlarmType.epcBulkEas,
    _ => AlarmType.unknown,
  };
}

// ── decoder ───────────────────────────────────────────────────────────────────

final class EventDecoder
    extends StreamTransformerBase<AdvanNetMessage, RealtimeUpdate> {
  const EventDecoder({this.onDecodeError});

  final void Function(Object cause, AdvanNetMessage? message)? onDecodeError;

  @override
  Stream<RealtimeUpdate> bind(Stream<AdvanNetMessage> stream) {
    final controller = StreamController<RealtimeUpdate>();
    stream.listen(
      (msg) {
        try {
          final updates = _decode(msg);
          for (final u in updates) {
            controller.add(u);
          }
        } catch (err) {
          final status = DecodeError(cause: err, message: msg);
          controller.add(RealtimeStatusUpdate(status));
          onDecodeError?.call(err, msg);
        }
      },
      onError: controller.addError,
      onDone: controller.close,
      cancelOnError: false,
    );
    return controller.stream;
  }

  List<RealtimeUpdate> _decode(AdvanNetMessage msg) {
    if (msg.body.isEmpty) return const []; // keepalive frame
    if (msg.contentType?.contains('application/json') == true) {
      return _decodeJson(msg);
    }
    final xml = utf8.decode(msg.body, allowMalformed: true);
    final doc = XmlDocument.parse(xml);
    final root = doc.rootElement;
    final now = DateTime.now();

    switch (root.name.local) {
      case 'inventory':
        return _decodeInventory(root, now);
      case 'deviceEventMessage':
        final event = _decodeDeviceEvent(root, now);
        return [RealtimeEventUpdate(event)];
      case 'eventMessage':
        final event = _decodeSystemEvent(root, now);
        return [RealtimeEventUpdate(event)];
      default:
        throw FormatException('Unknown root element: ${root.name.local}');
    }
  }

  // ── JSON decoder (JSONV2 / JSONV3) ────────────────────────────────────────

  List<RealtimeUpdate> _decodeJson(AdvanNetMessage msg) {
    final jsonStr = utf8.decode(msg.body, allowMalformed: true);
    final map = jsonDecode(jsonStr) as Map<String, dynamic>;
    final type = map['type'] as String? ?? '';
    final deviceId = map['devid'] as String? ?? '';
    final now = DateTime.now();
    final serverTs = _tsFromJson(map['ts']);
    final data = map['data'];

    final RealtimeEvent event;
    switch (type) {
      case 'inv':
        event = _decodeJsonInv(
          data as Map<String, dynamic>,
          deviceId,
          serverTs,
          now,
        );
      case 'gpi':
        event = _decodeJsonGpi(
          data as Map<String, dynamic>,
          deviceId,
          serverTs,
          now,
        );
      case 'alarm':
        event = _decodeJsonAlarm(
          data as Map<String, dynamic>,
          deviceId,
          serverTs,
          now,
        );
      case 'direction':
        event = _decodeJsonDirection(
          data as Map<String, dynamic>,
          deviceId,
          serverTs,
          now,
        );
      case 'event':
        event = _decodeJsonEtcEvent(map, deviceId, serverTs, now);
      default:
        event = UnknownEvent(
          type: type,
          deviceId: deviceId,
          receivedAt: now,
          serverTs: serverTs,
        );
    }
    return [RealtimeEventUpdate(event)];
  }

  TagReadEvent _decodeJsonInv(
    Map<String, dynamic> data,
    String deviceId,
    DateTime? serverTs,
    DateTime now,
  ) {
    final epc = data['epc'] as String? ?? '';
    final port = _intFromJson(data['port']);
    final rssi = _intFromJson(data['rssi']);
    final mux1 = _intFromJson(data['mux1']);
    final mux2 = _intFromJson(data['mux2']);
    final freqKHz = _intFromJson(data['freq']);
    final rfPhase = _intFromJson(data['phase']);

    List<int>? gpiSnapshot;
    if (data['gpi'] case final String gpiStr when gpiStr.isNotEmpty) {
      if (gpiStr.startsWith('{')) {
        final inner = gpiStr.replaceAll('{', '').replaceAll('}', '');
        gpiSnapshot = inner
            .split(':')
            .map((s) => int.tryParse(s.trim()) ?? 0)
            .toList();
      } else {
        gpiSnapshot = [...gpiStr.split('').map((c) => c == '1' ? 1 : 0)];
      }
    }

    LocationData? location;
    if (data['loc'] case final Map<String, dynamic> loc) {
      final lx = _doubleFromJson(loc['x']);
      final ly = _doubleFromJson(loc['y']);
      final lz = _doubleFromJson(loc['z']);
      if (lx != null && ly != null && lz != null) {
        location = LocationData(x: lx, y: ly, z: lz);
      }
    }

    // Populate raw with all v2-only fields so callers can access them.
    final raw = <String, String>{
      if (data['uri'] case final String u when u.isNotEmpty) 'uri': u,
      if (data['usermem'] case final String u when u.isNotEmpty) 'usermem': u,
      if (data['rc'] != null) 'rc': '${data['rc']}',
    };

    return TagReadEvent(
      type: 'INVENTORY',
      deviceId: deviceId,
      receivedAt: now,
      serverTs: serverTs,
      epc: epc,
      hexEpc: epc,
      rssi: rssi,
      rfPhase: rfPhase,
      antennaPort: port,
      mux1: mux1,
      mux2: mux2,
      freqKHz: freqKHz,
      gpiSnapshot: gpiSnapshot,
      location: location,
      raw: raw,
    );
  }

  GpiEvent _decodeJsonGpi(
    Map<String, dynamic> data,
    String deviceId,
    DateTime? serverTs,
    DateTime now,
  ) {
    final line = _intFromJson(data['line']) ?? 1;
    final rawLth = data['lowToHigh'];
    final lowToHigh = rawLth is bool ? rawLth : (rawLth == 1 || rawLth == '1');
    final duration = _intFromJson(data['duration']);
    return GpiEvent(
      type: 'GPI',
      deviceId: deviceId,
      receivedAt: now,
      serverTs: serverTs,
      line: line,
      lowToHigh: lowToHigh,
      duration: duration,
    );
  }

  AlarmEvent _decodeJsonAlarm(
    Map<String, dynamic> data,
    String deviceId,
    DateTime? serverTs,
    DateTime now,
  ) {
    final epc = data['epc'] as String? ?? '';
    final tid = data['tid'] as String?;
    final port = _intFromJson(data['port']);
    final alarmTypeStr = data['type'] as String?;
    final kind = port != null ? AlarmKind.perAntenna : AlarmKind.global;
    return AlarmEvent(
      type: 'TAG_ALARM',
      deviceId: deviceId,
      receivedAt: now,
      serverTs: serverTs,
      epc: epc,
      tid: tid,
      kind: kind,
      antennaPort: port,
      alarmType: alarmTypeStr.toAlarmType(),
    );
  }

  TagDirectionEvent _decodeJsonDirection(
    Map<String, dynamic> data,
    String deviceId,
    DateTime? serverTs,
    DateTime now,
  ) {
    final epc = data['epc'] as String? ?? '';
    final rawDir = data['direction'];
    final direction = rawDir != null ? '$rawDir' : null;
    return TagDirectionEvent(
      type: 'TAG_DIRECTION',
      deviceId: deviceId,
      receivedAt: now,
      serverTs: serverTs,
      epc: epc,
      direction: direction,
    );
  }

  // The ETC "event" type carries system/device notifications. If the data
  // sub-type is "SENSOR", decode the info array as a MultiSensorEvent.
  // Otherwise flatten data fields into raw and return an UnknownEvent.
  RealtimeEvent _decodeJsonEtcEvent(
    Map<String, dynamic> map,
    String deviceId,
    DateTime? serverTs,
    DateTime now,
  ) {
    final rawData = map['data'];
    if (rawData is Map<String, dynamic>) {
      switch (rawData['type'] as String?) {
        case 'SENSOR':
          return MultiSensorEvent(
            type: 'MULTI_SENSOR',
            deviceId: deviceId,
            receivedAt: now,
            serverTs: serverTs,
            readings: _parseJsonSensorInfo(rawData['info']),
          );
        case 'INFO':
          return DeviceWarnEvent(
            type: 'DEVICE_INFO',
            deviceId: deviceId,
            receivedAt: now,
            serverTs: serverTs,
            message: rawData['msg'] as String?,
          );
      }
    }
    final raw = <String, String>{};
    if (rawData is Map<String, dynamic>) {
      for (final entry in rawData.entries) {
        if (entry.value != null) raw[entry.key] = '${entry.value}';
      }
    } else if (rawData != null) {
      raw['data'] = '$rawData';
    }
    return UnknownEvent(
      type: 'event',
      deviceId: deviceId,
      receivedAt: now,
      serverTs: serverTs,
      raw: raw,
    );
  }

  static List<SensorReading> _parseJsonSensorInfo(dynamic info) {
    if (info is! List) return const [];
    final result = <SensorReading>[];
    for (var i = 0; i < info.length; i++) {
      final entry = info[i];
      if (entry is! Map<String, dynamic>) continue;
      final desc = entry['id'] as String? ?? '';
      if (desc.isEmpty) continue;
      final unit = entry['unit'] as String? ?? '';
      final value = _doubleFromJson(entry['value']) ?? double.nan;
      result.add(
        SensorReading(line: i + 1, desc: desc, unit: unit, value: value),
      );
    }
    return result;
  }

  // ── JSON helpers ──────────────────────────────────────────────────────────

  static DateTime? _tsFromJson(dynamic v) {
    if (v is int) return DateTime.fromMillisecondsSinceEpoch(v);
    if (v is String) {
      final n = int.tryParse(v);
      if (n != null) return DateTime.fromMillisecondsSinceEpoch(n);
    }
    return null;
  }

  static int? _intFromJson(dynamic v) {
    if (v is int) return v;
    if (v is double) return v.toInt();
    if (v is String) return int.tryParse(v);
    return null;
  }

  static double? _doubleFromJson(dynamic v) {
    if (v is double) return v;
    if (v is int) return v.toDouble();
    if (v is String) return double.tryParse(v);
    return null;
  }

  List<RealtimeUpdate> _decodeInventory(XmlElement root, DateTime now) {
    // Two wire formats exist for the <inventory> root element:
    //
    // Flat (older firmware):
    //   <inventory><deviceId>…<items><item>…
    //
    // Nested (AdvanReader-m4, msg-version 2.3.x):
    //   <inventory><data><deviceId>…<inventory><items><item>…
    //
    // Try the flat path first; fall back to the nested path.
    final dataEl = root.child('data');
    final deviceId =
        root.childText('deviceId') ?? dataEl.childText('deviceId') ?? '';
    final itemsEl =
        root.child('items') ?? dataEl.child('inventory').child('items');
    final items = itemsEl?.findElements('item');
    if (items == null) return [];
    return [
      for (final item in items)
        RealtimeEventUpdate(_decodeInventoryItem(item, deviceId, now)),
    ];
  }

  TagReadEvent _decodeInventoryItem(
    XmlElement item,
    String deviceId,
    DateTime now,
  ) {
    final epc = item.childText('epc') ?? '';

    // Nested format wraps tag fields inside an <item><data> element;
    // flat format has them as direct children of <item>.
    final dataEl = item.child('data');

    final hexEpc =
        item.childText('hexepc') ?? dataEl.childText('hexepc') ?? epc;
    final rawTid = item.childText('tid') ?? dataEl.childText('tid');
    final tid = rawTid?.isNotEmpty == true ? rawTid : null;

    final props = item.child('props') ?? dataEl.child('props');

    final raw = <String, String>{};
    int? rssi, rfPhase, antennaPort, mux1, mux2, freqKHz;
    DateTime? serverTs;
    List<int>? gpiSnapshot;

    if (props != null) {
      // Nested format: <prop>KEY:VALUE</prop> entries.
      // Flat format: <KEY>VALUE</KEY> child elements.
      final propEls = props.findElements('prop').toList();
      if (propEls.isNotEmpty) {
        for (final prop in propEls) {
          final text = prop.innerText;
          final colon = text.indexOf(':');
          if (colon > 0) {
            raw[text.substring(0, colon)] = text.substring(colon + 1);
          }
        }
      } else {
        for (final child in props.childElements) {
          raw[child.name.local] = child.innerText;
        }
      }

      rssi = raw['RSSI'].toInt();
      rfPhase = raw['RF_PHASE'].toInt();
      antennaPort = raw['ANTENNA_PORT'].toInt();
      mux1 = raw['MUX1'].toInt();
      mux2 = raw['MUX2'].toInt();
      freqKHz = raw['FREQ'].toInt();
      if (raw['TIME_STAMP'].toInt() case final ts?) {
        serverTs = DateTime.fromMillisecondsSinceEpoch(ts);
      }
      if (raw['GPI'] case final gpiStr?) {
        if (gpiStr.startsWith('{')) {
          // Nested format: {0:0:0:0}
          final inner = gpiStr.replaceAll('{', '').replaceAll('}', '');
          gpiSnapshot = inner
              .split(':')
              .map((s) => int.tryParse(s.trim()) ?? 0)
              .toList();
        } else {
          // Flat format: "0000"
          gpiSnapshot = [...gpiStr.split('').map((c) => c == '1' ? 1 : 0)];
        }
      }
    }

    // Nested format has a direct <ts> in <item>; use it when props had no TIME_STAMP.
    if (serverTs == null) {
      if (item.childText('ts').toInt() case final ts?) {
        serverTs = DateTime.fromMillisecondsSinceEpoch(ts);
      }
    }

    LocationData? location;
    if (item.child('locationData') case final locEl?) {
      final lx = locEl.childText('x').toDouble();
      final ly = locEl.childText('y').toDouble();
      final lz = locEl.childText('z').toDouble();
      if ((lx, ly, lz) case (final lx?, final ly?, final lz?)) {
        location = LocationData(x: lx, y: ly, z: lz);
      }
    }

    return TagReadEvent(
      type: 'INVENTORY',
      deviceId: item.childText('deviceId') ?? deviceId,
      receivedAt: now,
      serverTs: serverTs,
      epc: epc,
      hexEpc: hexEpc,
      tid: tid,
      rssi: rssi,
      rfPhase: rfPhase,
      antennaPort: antennaPort,
      mux1: mux1,
      mux2: mux2,
      freqKHz: freqKHz,
      gpiSnapshot: gpiSnapshot,
      location: location,
      raw: raw,
    );
  }

  RealtimeEvent _decodeDeviceEvent(XmlElement root, DateTime now) {
    final deviceId = root.childText('deviceId') ?? '';
    final eventEl = root.child('event');
    if (eventEl == null) {
      throw FormatException('Missing <event> in deviceEventMessage');
    }
    final type = eventEl.childText('type') ?? '';
    final serverTs = switch (eventEl.childText('ts').toInt()) {
      final ts? => DateTime.fromMillisecondsSinceEpoch(ts),
      _ => null,
    };

    final raw = <String, String>{};
    for (final child in eventEl.childElements) {
      if (child.name.local != 'type') raw[child.name.local] = child.innerText;
    }

    switch (type) {
      case 'TAG_READ':
        return TagReadEvent(
          type: type,
          deviceId: deviceId,
          receivedAt: now,
          serverTs: serverTs,
          epc: raw['epc'] ?? '',
          hexEpc: raw['hexepc'] ?? raw['epc'] ?? '',
          tid: raw['tid'],
          rssi: raw['rssi'].toInt(),
          rfPhase: raw['rfPhase'].toInt(),
          antennaPort: raw['antennaPort'].toInt(),
          mux1: raw['mux1'].toInt(),
          mux2: raw['mux2'].toInt(),
          freqKHz: raw['freq'].toInt(),
          raw: raw,
        );

      case 'TAG_DIRECTION':
        return TagDirectionEvent(
          type: type,
          deviceId: deviceId,
          receivedAt: now,
          serverTs: serverTs,
          epc: raw['epc'] ?? '',
          direction: raw['direction'],
          antennaPort: raw['antennaPort'].toInt(),
          raw: raw,
        );

      case 'TAG_GENERIC':
      case 'TAG_GENERIC_2':
        return TagGenericEvent(
          type: type,
          deviceId: deviceId,
          receivedAt: now,
          serverTs: serverTs,
          epc: raw['epc'] ?? '',
          customEventName: type == 'TAG_GENERIC_2'
              ? 'customEvent2'
              : 'customEvent',
          raw: raw,
        );

      case 'TAG_ALARM':
        return AlarmEvent(
          type: type,
          deviceId: deviceId,
          receivedAt: now,
          serverTs: serverTs,
          epc: raw['epc'] ?? '',
          kind: AlarmKind.global,
          alarmType: raw['alarmType'].toAlarmType(),
          raw: raw,
        );

      case 'TAG_ALARM_ANTENNA_1':
      case 'TAG_ALARM_ANTENNA_2':
      case 'TAG_ALARM_ANTENNA_3':
      case 'TAG_ALARM_ANTENNA_4':
        final port = int.tryParse(type.substring(type.length - 1));
        return AlarmEvent(
          type: type,
          deviceId: deviceId,
          receivedAt: now,
          serverTs: serverTs,
          epc: raw['epc'] ?? '',
          kind: AlarmKind.perAntenna,
          antennaPort: port,
          alarmType: raw['alarmType'].toAlarmType(),
          raw: raw,
        );

      case 'TAG_ALARM_DISABLED':
        return AlarmEvent(
          type: type,
          deviceId: deviceId,
          receivedAt: now,
          serverTs: serverTs,
          epc: raw['epc'] ?? '',
          kind: AlarmKind.disabled,
          raw: raw,
        );

      case 'TAG_ALARM_ENABLED':
        return AlarmEvent(
          type: type,
          deviceId: deviceId,
          receivedAt: now,
          serverTs: serverTs,
          epc: raw['epc'] ?? '',
          kind: AlarmKind.enabled,
          raw: raw,
        );

      case 'GPI':
        return GpiEvent(
          type: type,
          deviceId: deviceId,
          receivedAt: now,
          serverTs: serverTs,
          line: raw['line'].toInt() ?? 1,
          lowToHigh: (raw['value'] ?? '0') == '1',
          raw: raw,
        );

      case 'MULTI_SENSOR':
        return MultiSensorEvent(
          type: type,
          deviceId: deviceId,
          receivedAt: now,
          serverTs: serverTs,
          readings: _parseSensorEntries(eventEl),
          raw: raw,
        );

      case 'DEVICE_START':
      case 'DEVICE_STOP':
        return DeviceConnectedEvent(
          type: type,
          deviceId: deviceId,
          receivedAt: now,
          serverTs: serverTs,
          advanNetId: raw['advanNetId'] ?? '',
          raw: raw,
        );

      case 'DEVICE_READMODE_CHANGE':
        return ReadModeChangeEvent(
          type: type,
          deviceId: deviceId,
          receivedAt: now,
          serverTs: serverTs,
          readMode: raw['readMode'] ?? raw['activeReadMode'],
          raw: raw,
        );

      case 'DEVICE_WARN':
      case 'DEVICE_INFO':
        return DeviceWarnEvent(
          type: type,
          deviceId: deviceId,
          receivedAt: now,
          serverTs: serverTs,
          message: raw['infos']?.trim(),
          raw: raw,
        );

      default:
        if (type.startsWith('ERROR') || type.contains('_ERROR')) {
          return ErrorEventMessage(
            type: type,
            deviceId: deviceId,
            receivedAt: now,
            serverTs: serverTs,
            code: raw['code'],
            message: raw['message'],
            raw: raw,
          );
        }
        return UnknownEvent(
          type: type,
          deviceId: deviceId,
          receivedAt: now,
          serverTs: serverTs,
          raw: raw,
        );
    }
  }

  // ── MULTI_SENSOR parsing ──────────────────────────────────────────────────

  // Parses <sensors><entry>…</entry>…</sensors> from a deviceEventMessage.
  // The per-entry structure wraps desc/unit info in a nested element whose
  // name is firmware-defined; we do a depth-first search for known fields.
  static List<SensorReading> _parseSensorEntries(XmlElement eventEl) {
    final sensorsEl = eventEl.child('sensors');
    if (sensorsEl == null) return const [];
    return [
      for (final entry in sensorsEl.findElements('entry'))
        ?_parseSensorEntry(entry),
    ];
  }

  static SensorReading? _parseSensorEntry(XmlElement entry) {
    final line = entry.childText('index').toInt() ?? 0;
    final desc = _findFirst(entry, 'desc') ?? '';
    if (desc.isEmpty) return null;
    final unit =
        _findFirst(entry, 'unitShort') ?? _findFirst(entry, 'unit') ?? '';
    final value = entry.childText('value').toDouble() ?? double.nan;
    return SensorReading(line: line, desc: desc, unit: unit, value: value);
  }

  // Depth-first search for the first element with [name].
  static String? _findFirst(XmlElement el, String name) {
    final direct = el.childText(name);
    if (direct != null) return direct;
    for (final child in el.childElements) {
      final found = _findFirst(child, name);
      if (found != null) return found;
    }
    return null;
  }

  RealtimeEvent _decodeSystemEvent(XmlElement root, DateTime now) {
    final advanNetId = root.childText('advanNetId') ?? '';
    final eventEl = root.child('event');
    if (eventEl == null) {
      throw FormatException('Missing <event> in eventMessage');
    }
    final type = eventEl.childText('type') ?? '';
    final serverTs = switch (eventEl.childText('ts').toInt()) {
      final ts? => DateTime.fromMillisecondsSinceEpoch(ts),
      _ => null,
    };

    final raw = <String, String>{};
    for (final child in eventEl.childElements) {
      if (child.name.local != 'type') raw[child.name.local] = child.innerText;
    }

    switch (type) {
      case 'ADVANNET_INFO':
        return SystemInfoEvent(
          type: type,
          deviceId: raw['deviceId'] ?? '',
          receivedAt: now,
          serverTs: serverTs,
          message: raw['msg'] ?? raw['message'] ?? '',
          advanNetId: advanNetId,
          raw: raw,
        );

      case 'ADVANNET_DEVICE_CONNECTED':
        return DeviceConnectedEvent(
          type: type,
          deviceId: raw['deviceId'] ?? '',
          receivedAt: now,
          serverTs: serverTs,
          advanNetId: advanNetId,
          raw: raw,
        );

      case 'ADVANNET_DEVICE_DISCONNECTED':
        return DeviceDisconnectedEvent(
          type: type,
          deviceId: raw['deviceId'] ?? '',
          receivedAt: now,
          serverTs: serverTs,
          advanNetId: advanNetId,
          raw: raw,
        );

      default:
        return UnknownEvent(
          type: type,
          deviceId: raw['deviceId'] ?? '',
          receivedAt: now,
          serverTs: serverTs,
          raw: raw,
        );
    }
  }
}
