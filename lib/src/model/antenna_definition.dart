import 'package:meta/meta.dart';

/// Direction hint for an antenna, encoded as an integer in the def string.
enum AntennaOrientation {
  none(0),
  inbound(-1),
  outbound(1);

  const AntennaOrientation(this.value);

  /// The integer encoded in the def string.
  final int value;

  static AntennaOrientation fromInt(int v) => switch (v) {
    -1 => inbound,
    1 => outbound,
    _ => none,
  };
}

/// Typed representation of a single RFID antenna port definition.
///
/// The wire format is a comma-separated `def` string:
/// `deviceId,port,mux,mux2,orientation,loc,x,y,z`
///
@immutable
final class AntennaDefinition {
  const AntennaDefinition({
    required this.deviceId,
    required this.port,
    required this.mux,
    required this.mux2,
    required this.orientation,
    required this.loc,
    required this.x,
    required this.y,
    required this.z,
  });

  final String deviceId;
  final int port; // physical antenna port (1..numPorts)
  final int mux; // first multiplexer channel (0 = none, 1..16)
  final int mux2; // second multiplexer channel (0 = none, 1..16)
  final AntennaOrientation orientation;
  final String loc; // location label (e.g. "loc_antenna1")
  final int x; // position in mm
  final int y;
  final int z;

  /// Parses a `def` string from an `<entry>` element.
  static AntennaDefinition fromDef(String def) {
    final f = def.split(',');
    if (f.length < 9) {
      throw FormatException(
        'AntennaDefinition def requires 9 fields, got ${f.length}: $def',
      );
    }
    return AntennaDefinition(
      deviceId: f[0],
      port: int.parse(f[1]),
      mux: int.parse(f[2]),
      mux2: int.parse(f[3]),
      orientation: AntennaOrientation.fromInt(int.parse(f[4])),
      loc: f[5],
      x: int.parse(f[6]),
      y: int.parse(f[7]),
      z: int.parse(f[8]),
    );
  }

  /// Serialises back to a comma-separated `def` string for PUT requests.
  String toDef() =>
      '$deviceId,$port,$mux,$mux2,${orientation.value},$loc,$x,$y,$z';

  AntennaDefinition copyWith({
    String? deviceId,
    int? port,
    int? mux,
    int? mux2,
    AntennaOrientation? orientation,
    String? loc,
    int? x,
    int? y,
    int? z,
  }) => AntennaDefinition(
    deviceId: deviceId ?? this.deviceId,
    port: port ?? this.port,
    mux: mux ?? this.mux,
    mux2: mux2 ?? this.mux2,
    orientation: orientation ?? this.orientation,
    loc: loc ?? this.loc,
    x: x ?? this.x,
    y: y ?? this.y,
    z: z ?? this.z,
  );

  @override
  bool operator ==(Object other) =>
      identical(this, other) ||
      other is AntennaDefinition &&
          other.deviceId == deviceId &&
          other.port == port &&
          other.mux == mux &&
          other.mux2 == mux2 &&
          other.orientation == orientation &&
          other.loc == loc &&
          other.x == x &&
          other.y == y &&
          other.z == z;

  @override
  int get hashCode =>
      Object.hash(deviceId, port, mux, mux2, orientation, loc, x, y, z);

  @override
  String toString() => 'AntennaDefinition(${toDef()})';
}
