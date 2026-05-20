import 'package:xml/xml.dart';

import '../xml/model_helpers.dart';

/// Common contract for typed AdvanNet read mode configuration models.
///
/// Each concrete read mode (e.g. [AsynchReadMode]) implements this interface,
/// providing round-trip XML serialisation via [toXml] and an immutable
/// `copyWith`-style mutation. [ReadModesResource.update] relies on this
/// interface to implement the GET → mutate → PUT sequence.
abstract interface class AdvanNetReadMode {
  /// The service-side identifier used in `/system/readmodes/byId/{modeId}`.
  String get modeId;
  XmlElement toXml();
}

// ── AsynchReadMode ───────────────────────────────────────────────────────────

/// Typed configuration for the Asynch read mode (`AdvanNetAsyncRead`).
///
/// In Asynch mode the reader continuously reads tags and pushes events to the
/// TCP realtime stream on port 3177 (TAG_READ, TAG_DIRECTION events).
final class AsynchReadMode implements AdvanNetReadMode {
  const AsynchReadMode._({required this.rawData});

  final XmlElement rawData;

  @override
  String get modeId => 'AdvanNetAsyncRead';

  /// Whether this read mode is active/enabled.
  bool get enabled => xmlBoolParam(rawData, 'enabled') ?? true;

  /// Minimum interval (ms) before the same EPC is re-reported (0 = no TTL).
  int get eventsTTL => xmlIntParam(rawData, 'eventsTTL') ?? 0;

  /// Whether to emit TAG_DIRECTION events when tag movement direction is known.
  bool get direction => xmlBoolParam(rawData, 'direction') ?? false;

  /// Whether to emit TAG_GENERIC custom events.
  bool get customEvent => xmlBoolParam(rawData, 'customEvent') ?? false;

  /// Whether to emit TAG_GENERIC_2 custom events.
  bool get customEvent2 => xmlBoolParam(rawData, 'customEvent2') ?? false;

  static AsynchReadMode fromXml(XmlElement data) =>
      AsynchReadMode._(rawData: data);

  AsynchReadMode copyWith({
    bool? enabled,
    int? eventsTTL,
    bool? direction,
    bool? customEvent,
    bool? customEvent2,
  }) {
    final clone = rawData.copy();
    if (enabled != null) xmlSetParam(clone, 'enabled', '$enabled');
    if (eventsTTL != null) xmlSetParam(clone, 'eventsTTL', '$eventsTTL');
    if (direction != null) xmlSetParam(clone, 'direction', '$direction');
    if (customEvent != null) xmlSetParam(clone, 'customEvent', '$customEvent');
    if (customEvent2 != null) {
      xmlSetParam(clone, 'customEvent2', '$customEvent2');
    }
    return AsynchReadMode._(rawData: clone);
  }

  @override
  XmlElement toXml() => rawData;
}

// ── ScanReadMode ─────────────────────────────────────────────────────────────

/// Typed configuration for the Scan read mode (`AdvanNetScanRead`).
///
/// In Scan mode the reader performs periodic inventory scans and reports the
/// results as `<inventory>` batches on port 3177.
final class ScanReadMode implements AdvanNetReadMode {
  const ScanReadMode._({required this.rawData});

  final XmlElement rawData;

  @override
  String get modeId => 'AdvanNetScanRead';

  bool get enabled => xmlBoolParam(rawData, 'enabled') ?? true;

  /// Scan period in milliseconds.
  int get period => xmlIntParam(rawData, 'period') ?? 1000;

  /// Whether to use the dynamic Q algorithm to tune RF inventory rounds.
  bool get dynamicQ => xmlBoolParam(rawData, 'dynamicQ') ?? true;

  static ScanReadMode fromXml(XmlElement data) => ScanReadMode._(rawData: data);

  ScanReadMode copyWith({bool? enabled, int? period, bool? dynamicQ}) {
    final clone = rawData.copy();
    if (enabled != null) xmlSetParam(clone, 'enabled', '$enabled');
    if (period != null) xmlSetParam(clone, 'period', '$period');
    if (dynamicQ != null) xmlSetParam(clone, 'dynamicQ', '$dynamicQ');
    return ScanReadMode._(rawData: clone);
  }

  @override
  XmlElement toXml() => rawData;
}

// ── EasReadMode ──────────────────────────────────────────────────────────────

/// Typed configuration for the EAS read mode (`AdvanNetEasRead`).
///
/// In EAS mode the reader checks for EAS alarm bits and emits TAG_ALARM events.
final class EasReadMode implements AdvanNetReadMode {
  const EasReadMode._({required this.rawData});

  final XmlElement rawData;

  @override
  String get modeId => 'AdvanNetEasRead';

  bool get enabled => xmlBoolParam(rawData, 'enabled') ?? true;

  /// Whether per-antenna alarms are enabled (TAG_ALARM_ANTENNA_N events).
  bool get perAntennaAlarm => xmlBoolParam(rawData, 'perAntennaAlarm') ?? false;

  /// Alarm debounce interval in milliseconds.
  int get alarmTTL => xmlIntParam(rawData, 'alarmTTL') ?? 0;

  static EasReadMode fromXml(XmlElement data) => EasReadMode._(rawData: data);

  EasReadMode copyWith({bool? enabled, bool? perAntennaAlarm, int? alarmTTL}) {
    final clone = rawData.copy();
    if (enabled != null) xmlSetParam(clone, 'enabled', '$enabled');
    if (perAntennaAlarm != null) {
      xmlSetParam(clone, 'perAntennaAlarm', '$perAntennaAlarm');
    }
    if (alarmTTL != null) xmlSetParam(clone, 'alarmTTL', '$alarmTTL');
    return EasReadMode._(rawData: clone);
  }

  @override
  XmlElement toXml() => rawData;
}
