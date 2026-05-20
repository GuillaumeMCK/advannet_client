import 'package:xml/xml.dart';

import '../errors/advannet_exception.dart';
import '../model/device.dart';
import '../model/realtime_encoder.dart';
import '../model/system_status.dart';
import '../raw_resource.dart';
import '../xml/envelope.dart';
import '../xml/xml_extensions.dart';

final class SystemInfoResource {
  const SystemInfoResource({required RawResource raw}) : _raw = raw;
  final RawResource _raw;

  /// Returns the overall AdvanNet status (running devices, version, etc.).
  Future<SystemStatus?> getStatus() async {
    const path = '/status';
    final response = await _raw.get(path);
    return switch (response) {
      DataResponse(:final data) => _parseStatus(data),
      EmptyResponse() => null,
      ErrorResponse(:final code, :final message) => throw AdvanNetServerError(
        message: message ?? 'Failed to get status',
        method: HttpMethod.get,
        path: path,
        code: code,
        serverMessage: message,
      ),
      _ => null,
    };
  }

  static SystemStatus? _parseStatus(XmlElement data) {
    final deviceEl = data.child('device') ?? data;
    final id = deviceEl.childText('id') ?? '';
    if (id.isEmpty) return null;

    String? text(String tag) => deviceEl.childText(tag) ?? data.childText(tag);

    // <version> is a container: <class>SW_VERSION</class><version>x.y.z</version><revision>build</revision>
    // Some older firmware may use <def> instead of nested <version>, or a plain text element.
    final versionEl = data.child('version');
    final version =
        versionEl?.childText('version') ??
        versionEl?.childText('def') ??
        (versionEl?.childElements.isEmpty == true
            ? versionEl?.innerText.trim()
            : null);
    final revision =
        versionEl?.childText('revision') ??
        versionEl?.childText('date') ??
        text('revision');
    final advannetVersion = switch ((version, revision)) {
      (final v?, final r?) when v.isNotEmpty && r.isNotEmpty => '$v-$r',
      (final v?, _) when v.isNotEmpty => v,
      (_, final r?) when r.isNotEmpty => r,
      _ => null,
    };

    return SystemStatus(
      deviceId: id,
      ip: text('ip'),
      mac: text('mac'),
      serial: text('serial'),
      family: DeviceFamily.fromString(text('family')),
      status: DeviceStatus.fromString(text('status')),
      activeDeviceMode: text('activeDeviceMode'),
      activeReadMode: text('activeReadMode'),
      advannetVersion: advannetVersion,
      uptime: data.childText('uptime'),
      // <rf-firmware> is nested inside <devices><device>, so requires recursive search
      firmwareVersion: data
          .findAllElements('rf-firmware')
          .firstOrNull
          ?.childText('version'),
    );
  }

  /// Returns the current system time as a millisecond epoch string.
  Future<String?> getTime() async {
    const path = '/system/time';
    final response = await _raw.get(path);
    return switch (response) {
      DataResponse(:final data) =>
        data.childText('time') ?? data.innerText.trim(),
      EmptyResponse() => null,
      ErrorResponse(:final code, :final message) => throw AdvanNetServerError(
        message: message ?? 'Failed to get system time',
        method: HttpMethod.get,
        path: path,
        code: code,
        serverMessage: message,
      ),
      _ => null,
    };
  }

  /// Sets the system time. [timestampMs] is milliseconds since Unix epoch.
  Future<void> setTime(int timestampMs) async {
    const path = '/system/time';
    (await _raw.put(
      path,
      bodyString: '<data><time>$timestampMs</time></data>',
    )).throwIfError(method: HttpMethod.put, path: path);
  }

  /// Sets a system-level parameter by name.
  Future<void> setParameter(String name, String value) async {
    final path = '/system/parameter/$name';
    (await _raw.put(
      path,
      bodyString: value,
    )).throwIfError(method: HttpMethod.put, path: path);
  }

  /// Sets the TCP 3177 realtime stream encoding.
  ///
  /// Takes effect immediately for new connections; existing TCP clients must
  /// reconnect to receive frames in the new format.
  ///
  /// [RealtimeEncoder.xmlV23] is the default. [RealtimeEncoder.jsonV3] is the
  /// recommended format for new integrations (shorter frames than jsonV2).
  Future<void> setRealtimeEncoder(RealtimeEncoder encoder) =>
      setParameter('COMM_TCP3177_ENCODER', encoder.wireName);
}
