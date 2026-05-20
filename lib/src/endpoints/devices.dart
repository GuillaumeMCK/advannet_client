import 'package:xml/xml.dart';

import '../errors/advannet_exception.dart';
import '../model/antenna_definition.dart';
import '../model/device.dart';
import '../model/device_mode.dart';
import '../model/reader_param.dart';
import '../raw_resource.dart';
import '../xml/envelope.dart';
import '../xml/xml_extensions.dart';

final class DevicesResource {
  const DevicesResource({required RawResource raw}) : _raw = raw;

  final RawResource _raw;

  Future<List<AdvanNetDevice>> list() async {
    final response = await _raw.get('/devices');
    return switch (response) {
      EntriesResponse(:final entries) => [
        for (final e in entries)
          AdvanNetDevice(
            id: e.defFields.isNotEmpty ? e.defFields.first : e.def,
          ),
      ],
      DataResponse(:final data) => _devicesFromData(data),
      EmptyResponse() => const [],
      ErrorResponse(:final code, :final message) => throw AdvanNetServerError(
        message: message ?? 'Device list failed',
        method: HttpMethod.get,
        path: '/devices',
        code: code,
        serverMessage: message,
      ),
    };
  }

  static List<AdvanNetDevice> _devicesFromData(XmlElement data) => [
    ...?data.child('devices')?.findElements('device').map((e) {
      final id = e.childText('id') ?? '';
      if (id.isEmpty) return null;
      return AdvanNetDevice(
        id: id,
        ip: e.childText('ip'),
        mac: e.childText('mac'),
        serial: e.childText('serial'),
        family: DeviceFamily.fromString(e.childText('family')),
        status: DeviceStatus.fromString(e.childText('status')),
        isAlive: switch (e.childText('isAlive')) {
          'true' => true,
          'false' => false,
          _ => null,
        },
        activeDeviceMode: _nullIfEmpty(e.childText('activeDeviceMode') ?? ''),
        activeReadMode: _nullIfEmpty(e.childText('activeReadMode') ?? ''),
        lastSeen: _nullIfEmpty(e.childText('lastSeen') ?? ''),
      );
    }).whereType<AdvanNetDevice>(),
  ];

  /// Initialises the device connection (SHUTDOWN → STOPPED/CONNECTED).
  Future<void> connect(String deviceId) async {
    final path = '/devices/$deviceId/connect';
    (await _raw.get(path)).throwIfError(method: HttpMethod.get, path: path);
  }

  /// Tears down the device connection (STOPPED/CONNECTED → SHUTDOWN).
  Future<void> shutdown(String deviceId) async {
    final path = '/devices/$deviceId/shutdown';
    (await _raw.get(path)).throwIfError(method: HttpMethod.get, path: path);
  }

  Future<void> start(String deviceId) async {
    final path = '/devices/$deviceId/start';
    (await _raw.get(path)).throwIfError(method: HttpMethod.get, path: path);
  }

  Future<void> stop(String deviceId) async {
    final path = '/devices/$deviceId/stop';
    (await _raw.get(path)).throwIfError(method: HttpMethod.get, path: path);
  }

  /// Returns the antenna port definitions for [deviceId].
  Future<List<AntennaDefinition>> getAntennas(String deviceId) async {
    final path = '/devices/$deviceId/antennas';
    final response = await _raw.get(path);
    return switch (response) {
      EntriesResponse(:final entries) => [
        ...entries.map((e) => AntennaDefinition.fromDef(e.def)),
      ],
      DataResponse(:final data) => _antennasFromData(data),
      EmptyResponse() => const [],
      ErrorResponse(:final code, :final message) => throw AdvanNetServerError(
        message: message ?? 'Get antennas failed',
        method: HttpMethod.get,
        path: path,
        code: code,
        serverMessage: message,
      ),
    };
  }

  // Antennas are returned as <data><entries><entry class="ANTENNA_DEFINITION" def="..."/></entries></data>.
  static List<AntennaDefinition> _antennasFromData(XmlElement data) => [
    ...?data
        .child('entries')
        ?.findElements('entry')
        .map((e) => e.childText('def'))
        .whereType<String>()
        .where((def) => def.isNotEmpty)
        .map(AntennaDefinition.fromDef),
  ];

  // ── Reader RF parameters ──────────────────────────────────────────────────

  /// Returns the current RF reader parameters for [deviceId] as a name→value map.
  ///
  /// Each entry in the response (e.g. `RF_READ_POWER`, `RF_SENSITIVITY`) maps
  /// to its current string value.
  Future<Map<String, String>> getReaderParams(String deviceId) async {
    final path = '/devices/$deviceId/reader';
    final response = await _raw.get(path);
    return switch (response) {
      DataResponse(:final data) => _parseParamMap(data),
      EmptyResponse() => {},
      ErrorResponse(:final code, :final message) => throw AdvanNetServerError(
        message: message ?? 'Failed to get reader params',
        method: HttpMethod.get,
        path: path,
        code: code,
        serverMessage: message,
      ),
      _ => {},
    };
  }

  /// Returns all reader parameter key-value pairs for [deviceId].
  Future<Map<String, String>> getAllReaderParams(String deviceId) async {
    final path = '/devices/$deviceId/reader/params';
    final response = await _raw.get(path);
    return switch (response) {
      DataResponse(:final data) => _parseParamMap(data),
      EmptyResponse() => {},
      ErrorResponse(:final code, :final message) => throw AdvanNetServerError(
        message: message ?? 'Failed to get all reader params',
        method: HttpMethod.get,
        path: path,
        code: code,
        serverMessage: message,
      ),
      _ => {},
    };
  }

  // Parses three response shapes from /devices/{id}/reader and similar endpoints:
  //
  // Shape A — top-level entries container:
  //   <data><entries><entry><class>K</class><def>V</def></entry>…</entries></data>
  //
  // Shape B — mixed: a sub-container (e.g. <params>) with entry children, plus
  //   flat sibling fields:
  //   <data><params><entry><class>K</class><def><value>V</value>…</def></entry>…</params>
  //         <ip>/dev/ttyO1</ip><model>…</model>…</data>
  //
  // Shape C — per-parameter element:
  //   <data><RF_READ_POWER><result>31.5</result></RF_READ_POWER>…</data>
  static Map<String, String> _parseParamMap(XmlElement data) {
    final result = <String, String>{};

    // Shape A
    final topEntries = data.child('entries');
    if (topEntries != null) {
      for (final entry in topEntries.findElements('entry')) {
        final key = entry.childText('class') ?? '';
        final defEl = entry.child('def');
        final val =
            defEl?.childText('value') ??
            entry.childText('def') ??
            entry.childText('result') ??
            '';
        if (key.isNotEmpty) result[key] = val;
      }
      return result;
    }

    // Shapes B and C
    for (final child in data.childElements) {
      final key = child.name.local;

      final childEls = child.childElements.toList();

      if (childEls.isNotEmpty) {
        // Shape B-entry: sub-container whose direct children are <entry> elements
        if (childEls.every((c) => c.name.local == 'entry')) {
          for (final entry in childEls) {
            final entryKey = entry.childText('class') ?? '';
            final defEl = entry.child('def');
            final val =
                defEl?.childText('value') ??
                defEl?.childText('result') ??
                entry.childText('def') ??
                entry.childText('result') ??
                '';
            if (entryKey.isNotEmpty) result[entryKey] = val;
          }
          continue;
        }

        // Shape B-named: sub-container whose children are named-parameter elements
        // e.g. <params><RF_READ_POWER><result>31.5</result>...</RF_READ_POWER>...</params>
        if (childEls.any((c) => c.childElements.isNotEmpty)) {
          for (final param in childEls) {
            final paramKey = param.name.local;
            final val =
                param.childText('result') ??
                param.childText('value') ??
                param.innerText.trim();
            if (paramKey.isNotEmpty && val.isNotEmpty) result[paramKey] = val;
          }
          continue;
        }
      }

      // Shape C: <PARAM><result>val</result></PARAM> or <PARAM>val</PARAM>
      final val = child.childText('result') ?? child.innerText.trim();
      if (key.isNotEmpty && val.isNotEmpty) result[key] = val;
    }
    return result;
  }

  /// Sets a single reader [param] to [value] for [deviceId].
  Future<void> setReaderParam(
    String deviceId,
    ReaderParam param,
    String value,
  ) async {
    final path = '/devices/$deviceId/reader/parameter/${param.apiName}';
    (await _raw.put(
      path,
      bodyString: value,
    )).throwIfError(method: HttpMethod.put, path: path);
  }

  // ── Device modes ──────────────────────────────────────────────────────────

  /// Returns the list of available device mode names for [deviceId].
  Future<List<String>> getDeviceModes(String deviceId) async {
    final path = '/devices/$deviceId/deviceModes';
    final response = await _raw.get(path);
    return switch (response) {
      EntriesResponse(:final entries) => [
        ...entries.map((e) => e.def.isNotEmpty ? e.def : e.className),
      ],
      // Real device: <data><entries><entry><id>Autonomous</id>...</entry></entries></data>
      DataResponse(:final data) => [
        ...(data.child('entries') ?? data)
            .findElements('entry')
            .map((e) => e.childText('id'))
            .whereType<String>()
            .where((s) => s.isNotEmpty),
      ],
      EmptyResponse() => const [],
      ErrorResponse(:final code, :final message) => throw AdvanNetServerError(
        message: message ?? 'Failed to get device modes',
        method: HttpMethod.get,
        path: path,
        code: code,
        serverMessage: message,
      ),
    };
  }

  /// Returns the name of the currently active read mode for [deviceId].
  Future<String?> getActiveReadMode(String deviceId) async {
    final path = '/devices/$deviceId/activeReadMode';
    final response = await _raw.get(path);
    return switch (response) {
      DataResponse(:final data) => _nullIfEmpty(
        data.childText('name') ?? data.innerText.trim(),
      ),
      EmptyResponse() => null,
      ErrorResponse(:final code, :final message) => throw AdvanNetServerError(
        message: message ?? 'Failed to get active read mode',
        method: HttpMethod.get,
        path: path,
        code: code,
        serverMessage: message,
      ),
      _ => null,
    };
  }

  /// Returns the name of the currently active device mode for [deviceId].
  Future<String?> getActiveDeviceMode(String deviceId) async {
    final path = '/devices/$deviceId/activeDeviceMode';
    final response = await _raw.get(path);
    return switch (response) {
      DataResponse(:final data) => _nullIfEmpty(
        data.childText('result') ?? data.innerText.trim(),
      ),
      EmptyResponse() => null,
      ErrorResponse(:final code, :final message) => throw AdvanNetServerError(
        message: message ?? 'Failed to get active device mode',
        method: HttpMethod.get,
        path: path,
        code: code,
        serverMessage: message,
      ),
      _ => null,
    };
  }

  /// Sets the active device mode for [deviceId].
  Future<void> setActiveDeviceMode(String deviceId, DeviceMode mode) async {
    final path = '/devices/$deviceId/activeDeviceMode';
    (await _raw.put(
      path,
      bodyString: mode.id,
    )).throwIfError(method: HttpMethod.put, path: path);
  }

  /// Sets the active read mode by name for [deviceId] (e.g. `"AUTONOMOUS"`).
  Future<void> setActiveReadMode(String deviceId, String readMode) async {
    final path = '/devices/$deviceId/activeReadMode';
    (await _raw.put(
      path,
      bodyString: readMode,
    )).throwIfError(method: HttpMethod.put, path: path);
  }

  // ── Inventory ────────────────────────────────────────────────────────────

  /// Returns the current RFID tag inventory for [deviceId].
  ///
  /// Returns the raw `<data>` element. Use `/devices/{id}/jsonMinLocation`
  /// for a structured JSON inventory.
  Future<XmlElement?> getInventory(String deviceId) async {
    final path = '/devices/$deviceId/inventory';
    final response = await _raw.get(path);
    return switch (response) {
      DataResponse(:final data) => data,
      EmptyResponse() => null,
      ErrorResponse(:final code, :final message) => throw AdvanNetServerError(
        message: message ?? 'Failed to get inventory',
        method: HttpMethod.get,
        path: path,
        code: code,
        serverMessage: message,
      ),
      _ => null,
    };
  }

  /// Returns inventory with location data for [deviceId].
  ///
  /// Returns the raw `<data>` element.
  Future<XmlElement?> getLocation(String deviceId) async {
    final path = '/devices/$deviceId/location';
    final response = await _raw.get(path);
    return switch (response) {
      DataResponse(:final data) => data,
      EmptyResponse() => null,
      ErrorResponse(:final code, :final message) => throw AdvanNetServerError(
        message: message ?? 'Failed to get location',
        method: HttpMethod.get,
        path: path,
        code: code,
        serverMessage: message,
      ),
      _ => null,
    };
  }

  // ── MCU / time ────────────────────────────────────────────────────────────

  /// Returns the current datetime on [deviceId] as an ISO-8601 string.
  Future<String?> getDatetime(String deviceId) async {
    final path = '/devices/$deviceId/MCU/parameter/MCU_DATETIME';
    final response = await _raw.get(path);
    return switch (response) {
      DataResponse(:final data) => _nullIfEmpty(data.innerText.trim()),
      EmptyResponse() => null,
      ErrorResponse(:final code, :final message) => throw AdvanNetServerError(
        message: message ?? 'Failed to get device datetime',
        method: HttpMethod.get,
        path: path,
        code: code,
        serverMessage: message,
      ),
      _ => null,
    };
  }

  /// Sets the datetime on [deviceId]. [datetime] must be ISO-8601 format.
  Future<void> setDatetime(String deviceId, String datetime) async {
    final path = '/devices/$deviceId/MCU/parameter/MCU_DATETIME';
    (await _raw.put(
      path,
      bodyString: datetime,
    )).throwIfError(method: HttpMethod.put, path: path);
  }

  /// Returns the list of available timezone strings for [deviceId].
  Future<List<String>> getTimezoneList(String deviceId) async {
    final path = '/devices/$deviceId/MCU/parameter/MCU_TIMEZONE_LIST';
    final response = await _raw.get(path);
    return switch (response) {
      DataResponse(:final data) =>
        (data.childText('result') ?? '')
            .split(',')
            .map((s) => s.trim())
            .where((s) => s.isNotEmpty)
            .toList()
          ..sort(),
      EmptyResponse() => const [],
      ErrorResponse(:final code, :final message) => throw AdvanNetServerError(
        message: message ?? 'Failed to get timezone list',
        method: HttpMethod.get,
        path: path,
        code: code,
        serverMessage: message,
      ),
      _ => const [],
    };
  }

  /// Sets the timezone on [deviceId]. [timezone] must be a valid TZ string.
  Future<void> setTimezone(String deviceId, String timezone) async {
    final path = '/devices/$deviceId/MCU/parameter/MCU_TIMEZONE';
    (await _raw.put(
      path,
      bodyString: timezone,
    )).throwIfError(method: HttpMethod.put, path: path);
  }

  // ── GPI trigger ───────────────────────────────────────────────────────────

  /// Returns the current GPI trigger configuration for [deviceId] as a JSON string.
  ///
  /// Returns `null` if no trigger is configured.
  Future<String?> getGpiTrigger(String deviceId) async {
    final path = '/devices/$deviceId/reader/parameter/TRIGGER_CONF';
    final response = await _raw.get(path);
    return switch (response) {
      DataResponse(:final data) => _nullIfEmpty(
        data.childText('result') ?? data.innerText.trim(),
      ),
      EmptyResponse() => null,
      ErrorResponse(:final code, :final message) => throw AdvanNetServerError(
        message: message ?? 'Failed to get GPI trigger config',
        method: HttpMethod.get,
        path: path,
        code: code,
        serverMessage: message,
      ),
      _ => null,
    };
  }

  /// Sets the GPI trigger configuration for [deviceId].
  ///
  /// [triggerJson] is a JSON string describing which GPI lines start RF and for
  /// how long. Example — start antennas 1 & 2 on GPI#1 rise, antenna 2 only on
  /// GPI#2 rise, active for 15 s:
  /// ```
  /// {"onTime":15000,"trigger":[{"gpi":1,"conf":{"antennas":"1,2"}},{"gpi":2,"conf":{"antennas":"2"}}]}
  /// ```
  /// Pass `"{}"` to clear the trigger configuration.
  Future<void> setGpiTrigger(String deviceId, String triggerJson) async {
    final path = '/devices/$deviceId/reader/parameter/TRIGGER_CONF';
    (await _raw.put(
      path,
      bodyString: triggerJson,
    )).throwIfError(method: HttpMethod.put, path: path);
  }

  // ── Antennas ──────────────────────────────────────────────────────────────

  /// Replaces the antenna port definitions for [deviceId].
  ///
  /// The device must be stopped before calling this method.
  /// Call [SystemResource.confAllSave] afterward to persist.
  Future<void> setAntennas(
    String deviceId,
    List<AntennaDefinition> antennas,
  ) async {
    final path = '/devices/$deviceId/antennas';
    final body = _buildAntennasXml(antennas);
    (await _raw.put(
      path,
      body: body,
    )).throwIfError(method: HttpMethod.put, path: path);
  }

  // ── helpers ───────────────────────────────────────────────────────────────

  static String? _nullIfEmpty(String s) => s.isEmpty ? null : s;

  static XmlElement _buildAntennasXml(List<AntennaDefinition> antennas) {
    final builder = XmlBuilder();
    builder.element(
      'entries',
      nest: () {
        for (final a in antennas) {
          builder.element(
            'entry',
            nest: () {
              builder.element(
                'class',
                nest: () => builder.text('ANTENNA_DEFINITION'),
              );
              builder.element('def', nest: () => builder.text(a.toDef()));
            },
          );
        }
      },
    );
    return builder.buildDocument().rootElement;
  }
}
