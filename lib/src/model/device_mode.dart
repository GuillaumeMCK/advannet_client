/// Known device mode identifiers returned by `GET /devices/{id}/deviceModes`
/// and accepted by `PUT /devices/{id}/activeDeviceMode`.
///
/// These are the `<id>` values from the device modes response.
enum DeviceMode {
  // ── Autonomous ───────────────────────────────────────────────────────────
  autonomous('Autonomous'),

  /// Autonomous mode with multiplexer (AdvanMux / AdvanPhaser) support.
  fastMultiplexing('FAST_MULTIPLEXING'),

  // ── Sequential ───────────────────────────────────────────────────────────
  sequential('Sequential'),

  // ── Alarm modes ──────────────────────────────────────────────────────────

  /// EAS alarm: triggers TAG_ALARM events when an EPC pattern matches.
  epcEasAlarm('EPC_EAS_ALARM'),

  /// Disables the EAS alarm bit on every read tag.
  epcEasDisable('EPC_EAS_DISABLE'),

  /// Enables the EAS alarm bit on every read tag.
  epcEasEnable('EPC_EAS_ENABLE'),

  /// EAS alarm using the NXP EAS bit.
  nxpEasAlarm('NXP_EAS_ALARM'),

  /// Disables the NXP EAS bit on every read tag.
  nxpEasDisable('NXP_EAS_DISABLE'),

  /// Enables the NXP EAS bit on every read tag.
  nxpEasEnable('NXP_EAS_ENABLE'),

  /// EAS mode backed by an SQL database for EPC pattern lookup.
  sqlEasAlarm('SQL_EAS_ALARM'),

  /// EAS mode that triggers alarms when several tags are read simultaneously.
  epcBulkEasAlarm('EPCBULK_EAS_ALARM'),

  // ── Other ─────────────────────────────────────────────────────────────────
  advanPay('AdvanPay');

  const DeviceMode(this.id);

  /// The wire identifier used in REST API requests and responses.
  final String id;

  @override
  String toString() => id;
}
