/// Known sensor identifiers for use with [GpioResource.getSensor].
///
/// Sensor readings are delivered in the `gpioAll` response as elements
/// named `{SENSOR_TYPE}_{featureNumber}`, e.g. `SENSOR_BATTERY_VOLTAGE_4`.
/// [elementPrefix] is the `SENSOR_TYPE` portion — the first element whose
/// name starts with this prefix is returned.
///
/// Sensor values are raw strings; parse with [double.parse] for numeric data.
enum ReaderSensor {
  /// Power-supply voltage (volts).
  supplyVoltage('SENSOR_BATTERY_VOLTAGE'),

  /// Power-supply temperature (°C).
  supplyTemperature('SENSOR_AUX_TEMPERATURE'),

  /// Internal +5 V rail voltage (volts).
  internal5VVoltage('SENSOR_5VCC_VOLTAGE'),

  /// Approximate system power consumption (watts).
  powerConsumption('SENSOR_CONSUMPTION');

  const ReaderSensor(this.elementPrefix);

  /// Prefix of the XML element name in the `gpioAll` response.
  final String elementPrefix;

  @override
  String toString() => elementPrefix;
}
