// Run with: dart example/discover_device_info.dart [options] [host]
//
// Prints hardware info, RF parameters, sensor readings, and GPI state for
// every device found on an AdvanNet reader.
//
// Options:
//   --port <n>   HTTP port (default: 3161)
//   --user <u>   Username for digest auth
//   --pass <p>   Password for digest auth
//
// Examples:
//   dart example/discover_device_info.dart 192.168.1.10
//   dart example/discover_device_info.dart --user admin --pass admin 192.168.1.10

import 'dart:io';

import 'package:advannet_client/advannet_client.dart';

Future<void> main(List<String> args) async {
  final opts = _parseArgs(args);
  final baseUri = Uri(scheme: 'http', host: opts.host, port: opts.port);
  final credentials = switch ((opts.user, opts.pass)) {
    (final u?, final p?) => AdvanNetCredentials.digest(u, p),
    _ => const AdvanNetCredentials.none(),
  };

  print('Connecting to $baseUri …\n');
  final client = AdvanNet.connect(baseUri, credentials: credentials);

  try {
    await _inspect(client);
  } on AdvanNetAuthException {
    stderr.writeln('Authentication failed — pass --user / --pass.');
    exit(1);
  } on AdvanNetException catch (e) {
    stderr.writeln('Error: $e');
    exit(1);
  } finally {
    await client.close();
  }
}

// ── inspection ────────────────────────────────────────────────────────────────

Future<void> _inspect(AdvanNet client) async {
  _section('AdvanNet system');
  final sysStatus = await client.systemInfo.getStatus();
  if (sysStatus != null) {
    _row('Device ID', sysStatus.deviceId);
    _row('Version', sysStatus.advannetVersion);
    _row('Uptime', sysStatus.uptime);
    _row('Firmware', sysStatus.firmwareVersion);
    if (sysStatus.status case final s? when s != DeviceStatus.unknown) {
      _row('Status', s.toString());
    }
  }

  final devices = await client.devices.list();
  _section('Devices (${devices.length})');
  if (devices.isEmpty) {
    print('  No devices found.');
    return;
  }

  for (final device in devices) {
    print('\n  ${device.id}');
    _row('Family', device.family?.toString());
    _row('IP', device.ip);
    _row('MAC', device.mac);
    _row('Serial', device.serial);
    if (device.status case final s? when s != DeviceStatus.unknown) {
      _row('Status', s.toString());
    }

    await _antennas(client, device.id);
    await _rfParams(client, device.id);
    await _modes(client, device.id);
    await _sensors(client, device.id);
    await _gpiState(client, device.id);
    await _deviceTime(client, device.id);
  }
}

Future<void> _antennas(AdvanNet client, String id) async {
  try {
    final antennas = await client.devices.getAntennas(id);
    if (antennas.isEmpty) {
      _row('Antennas', 'none configured');
      return;
    }
    print('  Antennas (${antennas.length}):');
    for (final a in antennas) {
      print(
        '    port ${a.port}  mux=${a.mux}  mux2=${a.mux2}'
        '  orient=${a.orientation.name}  loc=${a.loc}  pos=(${a.x}, ${a.y}, ${a.z})',
      );
    }
  } on AdvanNetException catch (e) {
    _row('Antennas', 'unavailable ($e)');
  }
}

Future<void> _rfParams(AdvanNet client, String id) async {
  try {
    final params = await client.devices.getReaderParams(id);
    if (params.isNotEmpty) {
      print('  RF params:');
      for (final e in params.entries) {
        _row('  ${e.key}', e.value);
      }
    }
  } on AdvanNetException {
    // endpoint not available on all firmware versions
  }
}

Future<void> _modes(AdvanNet client, String id) async {
  try {
    final modes = await client.devices.getDeviceModes(id);
    final active = await client.devices.getActiveReadMode(id);
    if (modes.isNotEmpty) _row('Device modes', modes.join(', '));
    if (active != null) _row('Active mode', active);
  } on AdvanNetException {
    // optional
  }
}

Future<void> _sensors(AdvanNet client, String id) async {
  try {
    final sensors = await client.gpio.getSensors(id);
    if (sensors.isEmpty) return;
    print('  Sensors:');
    for (final s in sensors) {
      print('    ${s.desc}: ${s.value} ${s.unit}');
    }
  } on AdvanNetException {
    // optional
  }
}

Future<void> _gpiState(AdvanNet client, String id) async {
  try {
    final inputs = await client.gpio.getInputs(id);
    if (inputs.isEmpty) return;
    final states = inputs.entries
        .toList()
      ..sort((a, b) => a.key.compareTo(b.key));
    _row(
      'GPI state',
      states.map((e) => 'GPI#${e.key}=${e.value ? 'HIGH' : 'LOW'}').join('  '),
    );
  } on AdvanNetException {
    // optional
  }
}

Future<void> _deviceTime(AdvanNet client, String id) async {
  try {
    final dt = await client.devices.getDatetime(id);
    if (dt != null) _row('Device time', dt);
  } on AdvanNetException {
    // optional
  }
}

// ── output helpers ────────────────────────────────────────────────────────────

void _section(String title) {
  final fill = '─' * (52 - title.length).clamp(1, 52);
  print('── $title $fill');
}

void _row(String label, String? value) {
  if (value == null || value.isEmpty) return;
  print('  ${label.padRight(14)} $value');
}

// ── arg parser ────────────────────────────────────────────────────────────────

({String host, int port, String? user, String? pass}) _parseArgs(
  List<String> args,
) {
  String host = '192.168.26.121';
  int port = 3161;
  String? user;
  String? pass;

  final rest = <String>[];
  for (var i = 0; i < args.length; i++) {
    switch (args[i]) {
      case '--port':
        port = int.parse(args[++i]);
      case '--user':
        user = args[++i];
      case '--pass':
        pass = args[++i];
      default:
        rest.add(args[i]);
    }
  }
  if (rest.isNotEmpty) host = rest.first;
  return (host: host, port: port, user: user, pass: pass);
}
