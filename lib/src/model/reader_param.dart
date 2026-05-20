/// Known reader parameter names for use with [DevicesResource.setReaderParam]
/// and [DevicesResource.getAllReaderParams].
///
/// Values with [readOnly] == true cannot be set via the API.
enum ReaderParam {
  // ── RF ───────────────────────────────────────────────────────────────────
  rfPowerMin('RF_POWER_MIN', readOnly: true),
  rfPowerMax('RF_POWER_MAX', readOnly: true),
  rfWritePowerMin('RF_WRITE_POWER_MIN', readOnly: true),
  rfPortNumber('RF_PORT_NUMBER', readOnly: true),
  rfSensitivityMax('RF_SENSITIVITY_MAX', readOnly: true),
  rfSensitivityMin('RF_SENSITIVITY_MIN', readOnly: true),
  rfRegion('RF_REGION'),
  rfReadPower('RF_READ_POWER'),
  rfWritePower('RF_WRITE_POWER'),
  rfWriteRetries('RF_WRITE_RETRIES'),
  rfAsynchOntime('RF_ASYNCH_ONTIME'),
  rfAsynchOfftime('RF_ASYNCH_OFFTIME'),
  rfSensitivity('RF_SENSITIVITY'),
  rfFreqTable('RF_FREQ_TABLE', readOnly: true),
  rfHopTable('RF_HOP_TABLE'),
  rfFixedAntennaTime('RF_FIXED_ANTENNA_TIME'),

  // ── Tag operation ────────────────────────────────────────────────────────
  tagId('TAG_ID'),
  tagIdLength('TAG_ID_LENGTH'),
  tagIdOffset('TAG_ID_OFFSET'),
  tagOpAntenna('TAG_OP_ANTENNA'),
  tagOpMux1('TAG_OP_MUX1'),
  tagOpMux2('TAG_OP_MUX2'),
  tagOpTimeout('TAG_OP_TIMEOUT'),

  // ── Hardware / data ──────────────────────────────────────────────────────
  dataGpioBidirectional('DATA_GPIO_BIDIRECTIONAL', readOnly: true),
  dataGpioNumber('DATA_GPIO_NUMBER', readOnly: true),
  dataGpoNumber('DATA_GPO_NUMBER', readOnly: true),
  dataGpiNumber('DATA_GPI_NUMBER', readOnly: true),
  dataModuleBaudrate('DATA_MODULE_BAUDRATE', readOnly: true),
  dataIpAddress('DATA_IP_ADDRESS', readOnly: true),
  dataNativeSwitchGpoPorts('DATA_NATIVE_SWITCH_GPO_PORTS'),

  // ── Inventory ────────────────────────────────────────────────────────────
  invTmUseFastSearch('INV_TM_USE_FAST_SEARCH'),
  invAntennas('INV_ANTENNAS'),

  // ── Gen2 ─────────────────────────────────────────────────────────────────
  gen2Session('GEN2_SESSION'),
  gen2Target('GEN2_TARGET'),
  gen2TargetSwitch('GEN2_TARGET_SWITCH'),
  gen2Q('GEN2_Q'),
  gen2Encoding('GEN2_ENCODING'),
  gen2Tari('GEN2_TARI'),
  gen2Blf('GEN2_BLF'),
  gen2ExtImpinjFastid('GEN2_EXT_IMPINJ_FASTID'),

  // ── Other ────────────────────────────────────────────────────────────────
  oemParam('OEM_PARAM');

  const ReaderParam(this.apiName, {this.readOnly = false});

  /// The wire name used in the REST API path and XML responses.
  final String apiName;

  /// Whether the device rejects PUT requests for this parameter.
  final bool readOnly;

  @override
  String toString() => apiName;
}
