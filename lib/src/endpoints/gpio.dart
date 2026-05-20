import 'dart:convert';

import 'package:xml/xml.dart';

import '../errors/advannet_exception.dart';
import '../model/sensor_reading.dart';
import '../raw_resource.dart';
import '../xml/envelope.dart';
import '../xml/xml_extensions.dart';

/// Controls digital I/O (GPO/GPI lines), buzzer, speaker, and sensors on a device.
final class GpioResource {
  const GpioResource({required RawResource raw}) : _raw = raw;

  final RawResource _raw;

  /// GPO index of the relay output (OMRON G5V-1 5DC, 24 VDC / 0.5 A resistive load).
  static const int relayOutput = 9;

  /// GPO index that enables or disables the +5 V external supply pin (200 mA max).
  static const int powerSupply5VOutput = 10;

  // ── GPO ─────────────────────────────────────────────────────────────────────

  /// Returns the current state of all GPO output lines for [deviceId].
  ///
  /// Lines are indexed from 1. Returns a map of `{lineNumber: active}`.
  /// Only lines named `GPO<N>` in the response are included.
  Future<Map<int, bool>> getOutputs(String deviceId) async {
    final path = '/devices/$deviceId/gpioAll';
    final response = await _raw.get(path);
    return switch (response) {
      DataResponse(:final data) => _parseGpio(data, 'GPO'),
      EmptyResponse() => {},
      ErrorResponse(:final code, :final message) => throw AdvanNetServerError(
        message: message ?? 'Failed to get GPIO state',
        method: HttpMethod.get,
        path: path,
        code: code,
        serverMessage: message,
      ),
      _ => throw AdvanNetProtocolException(
        message: 'Unexpected response for GPIO state',
        method: HttpMethod.get,
        path: path,
      ),
    };
  }

  /// Sets a single GPO output line via `GET /devices/{id}/setGPO/{gpo}/{state}`.
  Future<void> setOutput(String deviceId, int gpo, {required bool active}) =>
      _sendCommand('/devices/$deviceId/setGPO/$gpo/$active');

  /// Sets multiple GPO output lines by calling [setOutput] for each entry.
  Future<void> setOutputs(String deviceId, Map<int, bool> outputs) async {
    for (final entry in outputs.entries) {
      await setOutput(deviceId, entry.key, active: entry.value);
    }
  }

  // ── GPI ─────────────────────────────────────────────────────────────────────

  /// Returns the current state of all GPI input lines for [deviceId].
  ///
  /// Lines are indexed from 1. Returns a map of `{lineNumber: active}`.
  /// Only lines named `GPI<N>` in the response are included.
  Future<Map<int, bool>> getInputs(String deviceId) async {
    final path = '/devices/$deviceId/gpioAll';
    final response = await _raw.get(path);
    return switch (response) {
      DataResponse(:final data) => _parseGpio(data, 'GPI'),
      EmptyResponse() => {},
      ErrorResponse(:final code, :final message) => throw AdvanNetServerError(
        message: message ?? 'Failed to get GPI state',
        method: HttpMethod.get,
        path: path,
        code: code,
        serverMessage: message,
      ),
      _ => throw AdvanNetProtocolException(
        message: 'Unexpected response for GPI state',
        method: HttpMethod.get,
        path: path,
      ),
    };
  }

  /// Returns the current state of a single GPI [line] (1-based).
  ///
  /// Uses `GET /devices/{id}/getGPI/{line}`.
  Future<bool> getGPILine(String deviceId, int line) async {
    final path = '/devices/$deviceId/getGPI/$line';
    final response = await _raw.get(path);
    return switch (response) {
      DataResponse(:final data) =>
        data.childText('result')?.toLowerCase() == 'true',
      EmptyResponse() => false,
      ErrorResponse(:final code, :final message) => throw AdvanNetServerError(
        message: message ?? 'Failed to get GPI line $line',
        method: HttpMethod.get,
        path: path,
        code: code,
        serverMessage: message,
      ),
      _ => false,
    };
  }

  /// Returns the state of all GPI lines as `{lineNumber: active}` (1-based).
  ///
  /// Uses `GET /devices/{id}/getGPIAll`. Index 0 in the response = line 1.
  Future<Map<int, bool>> getGPIAll(String deviceId) async {
    final path = '/devices/$deviceId/getGPIAll';
    final response = await _raw.get(path);
    return switch (response) {
      DataResponse(:final data) => {
        for (final entry in (data.child('entries') ?? data).findElements(
          'entry',
        ))
          if (entry.childText('index').toInt() case final idx?)
            idx + 1: entry.childText('result')?.toLowerCase() == 'true',
      },
      EmptyResponse() => {},
      ErrorResponse(:final code, :final message) => throw AdvanNetServerError(
        message: message ?? 'Failed to get GPI state',
        method: HttpMethod.get,
        path: path,
        code: code,
        serverMessage: message,
      ),
      _ => {},
    };
  }

  // ── Sensors ──────────────────────────────────────────────────────────────────

  /// Returns all sensor readings for [deviceId].
  ///
  /// Each [SensorReading] includes a human-readable [SensorReading.desc],
  /// physical [SensorReading.unit], feature [SensorReading.line], and
  /// numeric [SensorReading.value].
  Future<List<SensorReading>> getSensors(String deviceId) async {
    final path = '/devices/$deviceId/gpioAllJSON';
    final response = await _raw.get(path);
    return switch (response) {
      DataResponse(:final data) => _parseSensorsJson(data),
      EmptyResponse() => const [],
      ErrorResponse(:final code, :final message) => throw AdvanNetServerError(
        message: message ?? 'Failed to get sensor readings',
        method: HttpMethod.get,
        path: path,
        code: code,
        serverMessage: message,
      ),
      _ => const [],
    };
  }

  /// Returns all sensor readings via `PUT /devices/{id}/sensorAll`.
  ///
  /// Returns a map of sensor-type key (e.g. `"SENSOR_AUX_TEMPERATURE_2"`) to
  /// its floating-point value. `NaN` values are represented as
  /// [double.nan].
  Future<Map<String, double>> getSensorReadings(String deviceId) async {
    final path = '/devices/$deviceId/sensorAll';
    final response = await _raw.put(path);
    return switch (response) {
      DataResponse(:final data) => {
        for (final child in data.childElements)
          child.name.local: ?double.tryParse(child.innerText.trim()),
      },
      EmptyResponse() => {},
      ErrorResponse(:final code, :final message) => throw AdvanNetServerError(
        message: message ?? 'Failed to get sensor readings',
        method: HttpMethod.put,
        path: path,
        code: code,
        serverMessage: message,
      ),
      _ => {},
    };
  }

  /// Returns the reading of a single sensor by [sensorId].
  ///
  /// Uses `PUT /devices/{id}/sensor/{sensorId}`. The [sensorId] is the
  /// integer id from the device description's `<sensors>` list.
  Future<double?> getSensorReading(String deviceId, int sensorId) async {
    final path = '/devices/$deviceId/sensor/$sensorId';
    final response = await _raw.put(path);
    return switch (response) {
      DataResponse(:final data) => data.childText('result').toDouble(),
      EmptyResponse() => null,
      ErrorResponse(:final code, :final message) => throw AdvanNetServerError(
        message: message ?? 'Failed to get sensor $sensorId',
        method: HttpMethod.put,
        path: path,
        code: code,
        serverMessage: message,
      ),
      _ => null,
    };
  }

  // ── Buzzer ──────────────────────────────────────────────────────────────────

  /// Activates the buzzer on [deviceId].
  ///
  /// [timeOnMs] — duration of each beep in milliseconds.
  /// [timeOffMs] — pause between beeps in milliseconds.
  /// [totalDurationMs] — total buzz duration in milliseconds.
  Future<void> activateBuzzer(
    String deviceId, {
    int timeOnMs = 500,
    int timeOffMs = 100,
    int totalDurationMs = 500,
  }) => _sendCommand(
    '/devices/$deviceId/buzz/$timeOnMs/$timeOffMs/$totalDurationMs',
  );

  // ── Speaker ─────────────────────────────────────────────────────────────────

  /// Activates the speaker on [deviceId].
  ///
  /// [frequencyHz] — tone frequency in Hz. Valid values: 1000, 1500, 2000, 2500,
  ///   3000, 3500, 4000, 4500, 5000.
  /// [volume] — volume level (1–10).
  /// [timeOffMs] — silent pause between tones in milliseconds.
  /// [timeOnMs] — duration of each tone in milliseconds.
  /// [totalDurationMs] — total playback duration in milliseconds.
  Future<void> activateSpeaker(
    String deviceId, {
    int frequencyHz = 1000,
    int volume = 10,
    int timeOffMs = 0,
    int timeOnMs = 500,
    int totalDurationMs = 500,
  }) => _sendCommand(
    '/devices/$deviceId/speak/$frequencyHz/$volume/$timeOnMs/$timeOffMs/$totalDurationMs',
  );

  // ── helpers ─────────────────────────────────────────────────────────────────

  Future<void> _sendCommand(String path) async {
    (await _raw.get(path)).throwIfError(method: HttpMethod.get, path: path);
  }

  static Map<int, bool> _parseGpio(XmlElement data, String prefix) {
    final result = <int, bool>{};
    for (final child in data.childElements) {
      final name = child.name.local;
      if (name.startsWith(prefix)) {
        if (int.tryParse(name.substring(prefix.length)) case final line?) {
          result[line] = child.innerText.trim().toLowerCase() == 'true';
        }
      }
    }
    return result;
  }

  static List<SensorReading> _parseSensorsJson(XmlElement data) {
    final jsonStr = data.childText('result');
    if (jsonStr == null || jsonStr.isEmpty) return const [];
    try {
      final map = jsonDecode(jsonStr) as Map<String, dynamic>;
      final sensors = map['sensors'] as List<dynamic>?;
      if (sensors == null) return const [];
      return [
        for (final s in sensors)
          SensorReading(
            line: (s['line'] as num).toInt(),
            desc: s['desc'] as String,
            unit: s['unit'] as String,
            value: (s['value'] as num).toDouble(),
          ),
      ];
    } on FormatException {
      return const [];
    }
  }
}
