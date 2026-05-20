enum RealtimeEncoder {
  xmlV23('XML_V2_3'),
  jsonV2('JSONV2'),
  jsonV3('JSONV3');

  const RealtimeEncoder(this.wireName);

  /// The value sent to the device via `PUT /system/parameter/COMM_TCP3177_ENCODER`.
  final String wireName;
}
