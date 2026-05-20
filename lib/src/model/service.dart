import 'package:xml/xml.dart';

import '../xml/model_helpers.dart';

/// Common contract for typed AdvanNet service configuration models.
///
/// Each concrete service type (e.g. [AdvanNetRestService]) implements this
/// interface, providing round-trip XML serialisation and an immutable
/// [copyWith]-style mutation. The [ServicesResource.update] helper relies on
/// this interface to implement the GET → mutate → PUT → confAllSave sequence.
abstract interface class AdvanNetService {
  String get serviceId;
  XmlElement toXml();
}

/// Typed configuration model for the built-in AdvanNet REST service
/// (`AdvanNetRestService`), which controls the HTTP server on port 3161.
///
/// Wraps the raw `<data>` element returned by
/// `GET /system/services/byId/AdvanNetRestService` and exposes parsed fields
/// as typed getters. Unknown fields are preserved in [rawData] so a round-trip
/// never loses configuration the library doesn't know about.
///
final class AdvanNetRestService implements AdvanNetService {
  const AdvanNetRestService._({required this.rawData});

  /// The raw `<data>` element from the GET response.
  final XmlElement rawData;

  @override
  String get serviceId => 'AdvanNetRestService';

  /// Whether the REST service serves static files (web UI).
  bool get serveStatic => xmlBoolParam(rawData, 'serveStatic') ?? false;

  /// Whether the service is currently enabled.
  bool get enabled => xmlBoolParam(rawData, 'enabled') ?? true;

  /// Constructs an instance from the `<data>` element of a service GET response.
  static AdvanNetRestService fromXml(XmlElement data) =>
      AdvanNetRestService._(rawData: data);

  /// Returns a copy with the specified fields replaced.
  AdvanNetRestService copyWith({bool? serveStatic, bool? enabled}) {
    final clone = rawData.copy();
    if (serveStatic case final v?) xmlSetParam(clone, 'serveStatic', '$v');
    if (enabled case final v?) xmlSetParam(clone, 'enabled', '$v');
    return AdvanNetRestService._(rawData: clone);
  }

  @override
  XmlElement toXml() => rawData;
}

// ── AdvanNetMqttService ──────────────────────────────────────────────────────

/// Typed configuration for the MQTT integration service.
///
/// When enabled the device publishes tag-read events to an MQTT broker.
final class AdvanNetMqttService implements AdvanNetService {
  const AdvanNetMqttService._({required this.rawData});

  final XmlElement rawData;

  @override
  String get serviceId => 'AdvanNetMqttService';

  bool get enabled => xmlBoolParam(rawData, 'enabled') ?? false;
  String get host => xmlParamValue(rawData, 'host') ?? '';
  int get port => xmlIntParam(rawData, 'port') ?? 1883;
  String get topic => xmlParamValue(rawData, 'topic') ?? '';
  String? get username => xmlParamValue(rawData, 'username');
  String? get password => xmlParamValue(rawData, 'password');

  static AdvanNetMqttService fromXml(XmlElement data) =>
      AdvanNetMqttService._(rawData: data);

  AdvanNetMqttService copyWith({
    bool? enabled,
    String? host,
    int? port,
    String? topic,
    String? username,
    String? password,
  }) {
    final clone = rawData.copy();
    if (enabled case final v?) xmlSetParam(clone, 'enabled', '$v');
    if (host case final v?) xmlSetParam(clone, 'host', v);
    if (port case final v?) xmlSetParam(clone, 'port', '$v');
    if (topic case final v?) xmlSetParam(clone, 'topic', v);
    if (username case final v?) xmlSetParam(clone, 'username', v);
    if (password case final v?) xmlSetParam(clone, 'password', v);
    return AdvanNetMqttService._(rawData: clone);
  }

  @override
  XmlElement toXml() => rawData;
}

// ── AdvanNetHttpNotifyService ────────────────────────────────────────────────

/// Typed configuration for the HTTP notification service.
///
/// When enabled the device POSTs tag-read events to a configurable URL.
final class AdvanNetHttpNotifyService implements AdvanNetService {
  const AdvanNetHttpNotifyService._({required this.rawData});

  final XmlElement rawData;

  @override
  String get serviceId => 'AdvanNetHttpService';

  bool get enabled => xmlBoolParam(rawData, 'enabled') ?? false;
  String get url => xmlParamValue(rawData, 'url') ?? '';
  String get method => xmlParamValue(rawData, 'method') ?? 'POST';

  static AdvanNetHttpNotifyService fromXml(XmlElement data) =>
      AdvanNetHttpNotifyService._(rawData: data);

  AdvanNetHttpNotifyService copyWith({
    bool? enabled,
    String? url,
    String? method,
  }) {
    final clone = rawData.copy();
    if (enabled case final v?) xmlSetParam(clone, 'enabled', '$v');
    if (url case final v?) xmlSetParam(clone, 'url', v);
    if (method case final v?) xmlSetParam(clone, 'method', v);
    return AdvanNetHttpNotifyService._(rawData: clone);
  }

  @override
  XmlElement toXml() => rawData;
}

// ── AdvanNetCsvService ───────────────────────────────────────────────────────

/// Typed configuration for the CSV file logging service.
///
/// When enabled the device appends tag-read events to a CSV file on the
/// device's local filesystem.
final class AdvanNetCsvService implements AdvanNetService {
  const AdvanNetCsvService._({required this.rawData});

  final XmlElement rawData;

  @override
  String get serviceId => 'AdvanNetCsvService';

  bool get enabled => xmlBoolParam(rawData, 'enabled') ?? false;
  String get path => xmlParamValue(rawData, 'path') ?? '';
  String get separator => xmlParamValue(rawData, 'separator') ?? ',';

  static AdvanNetCsvService fromXml(XmlElement data) =>
      AdvanNetCsvService._(rawData: data);

  AdvanNetCsvService copyWith({
    bool? enabled,
    String? path,
    String? separator,
  }) {
    final clone = rawData.copy();
    if (enabled case final v?) xmlSetParam(clone, 'enabled', '$v');
    if (path case final v?) xmlSetParam(clone, 'path', v);
    if (separator case final v?) xmlSetParam(clone, 'separator', v);
    return AdvanNetCsvService._(rawData: clone);
  }

  @override
  XmlElement toXml() => rawData;
}
