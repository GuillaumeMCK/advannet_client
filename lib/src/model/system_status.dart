import 'package:meta/meta.dart';

import 'device.dart';

@immutable
final class SystemStatus {
  const SystemStatus({
    required this.deviceId,
    this.ip,
    this.mac,
    this.serial,
    this.family,
    this.status,
    this.activeDeviceMode,
    this.activeReadMode,
    this.advannetVersion,
    this.uptime,
    this.firmwareVersion,
  });

  final String deviceId;
  final String? ip;
  final String? mac;
  final String? serial;
  final DeviceFamily? family;
  final DeviceStatus? status;
  final String? activeDeviceMode;
  final String? activeReadMode;
  final String? advannetVersion;
  final String? uptime;
  final String? firmwareVersion;

  @override
  String toString() => 'SystemStatus(deviceId: $deviceId, status: $status)';
}
