import '../model/sensor_reading.dart';

sealed class RealtimeEvent {
  const RealtimeEvent({
    required this.type,
    required this.deviceId,
    required this.receivedAt,
    this.serverTs,
  });

  final String type;
  final String deviceId;
  final DateTime receivedAt;
  final DateTime? serverTs;
}

final class LocationData {
  const LocationData({required this.x, required this.y, required this.z});

  final double x;
  final double y;
  final double z;

  @override
  bool operator ==(Object other) =>
      other is LocationData && other.x == x && other.y == y && other.z == z;

  @override
  int get hashCode => Object.hash(x, y, z);

  @override
  String toString() => 'LocationData($x, $y, $z)';
}

final class TagReadEvent extends RealtimeEvent {
  const TagReadEvent({
    required super.type,
    required super.deviceId,
    required super.receivedAt,
    super.serverTs,
    required this.epc,
    required this.hexEpc,
    this.tid,
    this.rssi,
    this.rfPhase,
    this.antennaPort,
    this.mux1,
    this.mux2,
    this.freqKHz,
    this.gpiSnapshot,
    this.location,
    this.raw = const {},
  });

  final String epc;
  final String hexEpc;
  final String? tid;
  final int? rssi;
  final int? rfPhase;
  final int? antennaPort;
  final int? mux1;
  final int? mux2;
  final int? freqKHz;
  final List<int>? gpiSnapshot;
  final LocationData? location;
  final Map<String, String> raw;
}

final class TagDirectionEvent extends RealtimeEvent {
  const TagDirectionEvent({
    required super.type,
    required super.deviceId,
    required super.receivedAt,
    super.serverTs,
    required this.epc,
    this.direction,
    this.antennaPort,
    this.raw = const {},
  });

  final String epc;
  final String? direction;
  final int? antennaPort;
  final Map<String, String> raw;
}

final class TagGenericEvent extends RealtimeEvent {
  const TagGenericEvent({
    required super.type,
    required super.deviceId,
    required super.receivedAt,
    super.serverTs,
    required this.epc,
    required this.customEventName,
    this.raw = const {},
  });

  final String epc;
  final String customEventName;
  final Map<String, String> raw;
}

enum AlarmKind { global, perAntenna, enabled, disabled }

enum AlarmType { epcEas, nxpEas, epcBulkEas, unknown }

final class AlarmEvent extends RealtimeEvent {
  const AlarmEvent({
    required super.type,
    required super.deviceId,
    required super.receivedAt,
    super.serverTs,
    required this.epc,
    required this.kind,
    this.tid,
    this.antennaPort,
    this.alarmType = AlarmType.unknown,
    this.raw = const {},
  });

  final String epc;

  /// Tag identifier (TID memory bank), present when the reader reads it alongside the EPC.
  final String? tid;
  final AlarmKind kind;
  final int? antennaPort;
  final AlarmType alarmType;
  final Map<String, String> raw;
}

final class GpiEvent extends RealtimeEvent {
  const GpiEvent({
    required super.type,
    required super.deviceId,
    required super.receivedAt,
    super.serverTs,
    required this.line,
    required this.lowToHigh,
    this.duration,
    this.raw = const {},
  });

  final int line;
  final bool lowToHigh;

  /// How long the GPI line was in the previous state before this transition, in milliseconds.
  /// Only present in JSON mode (JSONV2/JSONV3).
  final int? duration;
  final Map<String, String> raw;
}

final class SystemInfoEvent extends RealtimeEvent {
  const SystemInfoEvent({
    required super.type,
    required super.deviceId,
    required super.receivedAt,
    super.serverTs,
    required this.message,
    required this.advanNetId,
    this.raw = const {},
  });

  final String message;
  final String advanNetId;
  final Map<String, String> raw;
}

final class DeviceConnectedEvent extends RealtimeEvent {
  const DeviceConnectedEvent({
    required super.type,
    required super.deviceId,
    required super.receivedAt,
    super.serverTs,
    required this.advanNetId,
    this.raw = const {},
  });

  final String advanNetId;
  final Map<String, String> raw;
}

final class DeviceDisconnectedEvent extends RealtimeEvent {
  const DeviceDisconnectedEvent({
    required super.type,
    required super.deviceId,
    required super.receivedAt,
    super.serverTs,
    required this.advanNetId,
    this.raw = const {},
  });

  final String advanNetId;
  final Map<String, String> raw;
}

final class ErrorEventMessage extends RealtimeEvent {
  const ErrorEventMessage({
    required super.type,
    required super.deviceId,
    required super.receivedAt,
    super.serverTs,
    this.code,
    this.message,
    this.raw = const {},
  });

  final String? code;
  final String? message;
  final Map<String, String> raw;
}

/// Fired when the device changes its active read mode (`DEVICE_READMODE_CHANGE`).
final class ReadModeChangeEvent extends RealtimeEvent {
  const ReadModeChangeEvent({
    required super.type,
    required super.deviceId,
    required super.receivedAt,
    super.serverTs,
    this.readMode,
    this.raw = const {},
  });

  final String? readMode;
  final Map<String, String> raw;
}

/// Fired for device-level warning / informational notifications (`DEVICE_WARN`, `DEVICE_INFO`).
final class DeviceWarnEvent extends RealtimeEvent {
  const DeviceWarnEvent({
    required super.type,
    required super.deviceId,
    required super.receivedAt,
    super.serverTs,
    this.message,
    this.raw = const {},
  });

  final String? message;
  final Map<String, String> raw;
}

final class MultiSensorEvent extends RealtimeEvent {
  const MultiSensorEvent({
    required super.type,
    required super.deviceId,
    required super.receivedAt,
    super.serverTs,
    required this.readings,
    this.raw = const {},
  });

  final List<SensorReading> readings;
  final Map<String, String> raw;
}

final class UnknownEvent extends RealtimeEvent {
  const UnknownEvent({
    required super.type,
    required super.deviceId,
    required super.receivedAt,
    super.serverTs,
    this.raw = const {},
  });

  final Map<String, String> raw;
}
