import 'package:meta/meta.dart';

enum DeviceStatus {
  running,
  stopped,
  connected,
  shutdown,
  error,
  commLost,
  commError,
  commRecovering,
  unknown;

  static DeviceStatus fromString(String? s) => switch (s?.toUpperCase()) {
    'RUNNING' || 'RF_ON' => running,
    'STOPPED' || 'RF_OFF' => stopped,
    'CONNECTED' => connected,
    'SHUTDOWN' => shutdown,
    'ERROR' => error,
    'COMM_LOST' => commLost,
    'COMM_ERROR' => commError,
    'COMM_RECOVERING' => commRecovering,
    _ => unknown,
  };

  /// Whether the device RF is on.
  bool get isRfOn => this == running;

  /// Whether the device is in a running or RF-on state.
  bool get isActive => this == running || this == connected;

  @override
  String toString() => switch (this) {
    commLost => 'COMM_LOST',
    commError => 'COMM_ERROR',
    commRecovering => 'COMM_RECOVERING',
    _ => name.toUpperCase(),
  };
}

enum DeviceFamily {
  advanReader('AdvanReader'),
  advanSafe('AdvanSafe'),
  advanPay('AdvanPay'),
  advanFlow('AdvanFlow'),
  unknown('unknown');

  const DeviceFamily(this.id);

  /// The wire identifier used in REST API responses.
  final String id;

  static DeviceFamily fromString(String? s) => switch (s) {
    'AdvanReader' => advanReader,
    'AdvanSafe' => advanSafe,
    'AdvanPay' => advanPay,
    'AdvanFlow' => advanFlow,
    _ => unknown,
  };

  @override
  String toString() => id;
}

@immutable
final class AdvanNetDevice {
  const AdvanNetDevice({
    required this.id,
    this.ip,
    this.mac,
    this.serial,
    this.family,
    this.status,
    this.isAlive,
    this.activeDeviceMode,
    this.activeReadMode,
    this.lastSeen,
  });

  final String id;
  final String? ip;
  final String? mac;
  final String? serial;

  /// Device product family.
  final DeviceFamily? family;

  /// Runtime status of the device.
  final DeviceStatus? status;

  /// Whether the device is reachable on the network.
  final bool? isAlive;

  /// Name of the currently active device mode (e.g. `"Autonomous"`).
  final String? activeDeviceMode;

  /// Name of the currently active read mode (e.g. `"AUTONOMOUS"`).
  final String? activeReadMode;

  /// Last-seen timestamp string as returned by the device (device-local format).
  final String? lastSeen;

  @override
  String toString() => 'AdvanNetDevice(id: $id)';

  @override
  bool operator ==(Object other) =>
      identical(this, other) || (other is AdvanNetDevice && other.id == id);

  @override
  int get hashCode => id.hashCode;
}
