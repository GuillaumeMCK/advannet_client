import 'package:meta/meta.dart';

@immutable
final class SensorReading {
  const SensorReading({
    required this.line,
    required this.desc,
    required this.unit,
    required this.value,
  });

  /// Feature index on the device (1-based).
  final int line;

  /// Human-readable sensor description (e.g. `"Consumption"`, `"Internal Voltage"`).
  final String desc;

  /// Physical unit string (e.g. `"W"`, `"V"`, `"C"`).
  final String unit;

  /// Sensor reading.
  final double value;

  @override
  String toString() => '$desc: $value $unit';
}
