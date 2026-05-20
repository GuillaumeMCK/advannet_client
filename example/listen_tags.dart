// Run with: dart example/listen_tags.dart [options] [host]
//
// Connects to a running AdvanReader and streams tag reads and GPI events.
// Press Ctrl+C to stop cleanly.
//
// Options:
//   --port <n>   HTTP port (default: 3161)
//   --tcp <n>    Realtime TCP port (default: 3177)
//   --user <u>   Username for digest auth
//   --pass <p>   Password for digest auth
//   --start      Start the device if it is STOPPED
//   --raw        Dump first 2 KB from TCP port as hex (protocol probe)

import 'dart:async';
import 'dart:io';
import 'dart:typed_data';

import 'package:advannet_client/advannet_client.dart';

Future<void> main(List<String> args) async {
  final opts = _parseArgs(args);

  if (opts.raw) {
    await _rawProbe(opts.host, opts.tcp);
    return;
  }
  final baseUri = Uri(scheme: 'http', host: opts.host, port: opts.port);
  final credentials = switch ((opts.user, opts.pass)) {
    (final u?, final p?) => AdvanNetCredentials.digest(u, p),
    _ => const AdvanNetCredentials.none(),
  };

  print('HTTP  : $baseUri');
  print('TCP   : ${opts.host}:${opts.tcp}');

  final client = AdvanNet.connect(
    baseUri,
    credentials: credentials,
    realtimePort: opts.tcp,
  );

  String? deviceId;
  try {
    final devices = await client.devices.list();
    if (devices.isEmpty) {
      stderr.writeln('No devices found.');
      await client.close();
      exit(1);
    }
    final device = devices.first;
    deviceId = device.id;
    print('Device: $deviceId  status=${device.status ?? "?"}');

    final active = await client.devices.getActiveReadMode(deviceId);
    if (active != null) print('Mode  : $active');
    print('');

    if (device.status != null && !device.status!.isActive) {
      if (opts.start) {
        stderr.writeln('Device is ${device.status} — starting...');
        await client.devices.start(deviceId);
        stderr.writeln('Started.');
      } else {
        stderr.writeln(
          'Warning: device is ${device.status}. '
          'Pass --start to start it, or start it via the webapp first.',
        );
      }
    }
  } on AdvanNetAuthException {
    stderr.writeln('Authentication failed — pass --user / --pass.');
    await client.close();
    exit(1);
  } on AdvanNetException catch (e) {
    stderr.writeln('HTTP error: $e');
    await client.close();
    exit(1);
  }

  try {
    await client.systemInfo.setRealtimeEncoder(RealtimeEncoder.jsonV3);
    stderr.writeln('[TCP] encoder set to JSONV3');
  } on AdvanNetException catch (e) {
    stderr.writeln('[TCP] warning: could not set encoder: $e');
  }

  var count = 0;

  // Subscribe to ALL realtime updates so connection problems and decode errors
  // are visible. Tag reads are printed as they arrive; everything else goes to
  // stderr so it can be redirected separately if needed.
  client.realtime.updates().listen((update) {
    switch (update) {
      case RealtimeStatusUpdate(:final status):
        switch (status) {
          case Connecting():
            stderr.writeln('[TCP] connecting to ${opts.host}:${opts.tcp}…');
          case Connected():
            stderr.writeln('[TCP] connected — waiting for events');
          case Disconnected(:final reason):
            stderr.writeln(
              '[TCP] disconnected'
              '${reason != null ? ": $reason" : ""}',
            );
          case Reconnecting(:final attempt, :final nextDelay):
            stderr.writeln(
              '[TCP] reconnecting (attempt $attempt, '
              'next in ${nextDelay.inSeconds}s)',
            );
          case FrameError(:final cause):
            stderr.writeln('[TCP] frame error: $cause');
          case DecodeError(:final cause):
            stderr.writeln('[TCP] decode error: $cause');
        }
      case RealtimeEventUpdate(:final event):
        switch (event) {
          case TagReadEvent():
            count++;
            final ts =
                (event.serverTs ?? event.receivedAt).toIso8601String();
            print('[$count] $ts  ${event.hexEpc}'
                '${event.antennaPort != null ? "  ant=${event.antennaPort}" : ""}'
                '${event.rssi != null ? "  rssi=${event.rssi}" : ""}');
          case GpiEvent():
            stderr.writeln(
              '[GPI] line=${event.line} '
              '${event.lowToHigh ? "LOW→HIGH" : "HIGH→LOW"}',
            );
          case SystemInfoEvent():
            stderr.writeln('[SYSTEM] ${event.message}');
          case DeviceConnectedEvent():
            stderr.writeln('[DEVICE] connected: ${event.deviceId}');
          case DeviceDisconnectedEvent():
            stderr.writeln('[DEVICE] disconnected: ${event.deviceId}');
          case ReadModeChangeEvent():
            stderr.writeln('[MODE] ${event.deviceId} → ${event.readMode ?? "?"}');
          case DeviceWarnEvent():
            stderr.writeln('[WARN] ${event.message ?? event.raw}');
          case MultiSensorEvent():
            final readings = event.readings
                .map((r) => '${r.desc}=${r.value}${r.unit.isNotEmpty ? " ${r.unit}" : ""}')
                .join('  ');
            stderr.writeln('[SENSOR] $readings');
          case UnknownEvent():
            // The device is sending something we don't recognise — print it
            // so you can report the raw content and we can add support for it.
            stderr.writeln('[UNKNOWN type=${event.type}] raw=${event.raw}');
          default:
            stderr.writeln('[EVENT type=${event.type}]');
        }
    }
  });

  print('Listening… (Ctrl+C to stop)\n');

  await ProcessSignal.sigint.watch().first;
  await client.close();
}

// ── raw TCP hex probe ──────────────────────────────────────────────────────────

Future<void> _rawProbe(String host, int port) async {
  print('Raw probe: connecting to $host:$port …');
  final socket = await Socket.connect(host, port);
  print('Connected. Capturing first 2 KB (Ctrl+C to stop early)…\n');

  final buf = BytesBuilder();
  final sigintFuture = ProcessSignal.sigint.watch().first;
  final done = Completer<void>();

  socket.listen(
    (bytes) {
      buf.add(bytes);
      if (buf.length >= 2048 && !done.isCompleted) done.complete();
    },
    onDone: () { if (!done.isCompleted) done.complete(); },
    onError: (Object e) { if (!done.isCompleted) done.completeError(e); },
    cancelOnError: false,
  );

  await Future.any([done.future, sigintFuture]);
  await socket.close();

  final data = buf.toBytes();
  print('--- ${data.length} bytes received ---');
  for (var i = 0; i < data.length; i += 16) {
    final end = (i + 16).clamp(0, data.length);
    final chunk = data.sublist(i, end);
    final hex = chunk.map((b) => b.toRadixString(16).padLeft(2, '0')).join(' ');
    final pad = '   ' * (16 - chunk.length);
    final ascii = String.fromCharCodes(
      chunk.map((b) => b >= 32 && b < 127 ? b : 46 /* '.' */),
    );
    print('${i.toRadixString(16).padLeft(6, '0')}  $hex$pad  |$ascii|');
  }
}

// ── arg parser ────────────────────────────────────────────────────────────────

({String host, int port, int tcp, String? user, String? pass, bool start, bool raw})
_parseArgs(List<String> args) {
  String host = '192.168.26.121';
  int port = 3161;
  int tcp = 3177;
  String? user;
  String? pass;
  bool start = false;
  bool raw = false;

  final rest = <String>[];
  for (var i = 0; i < args.length; i++) {
    switch (args[i]) {
      case '--port':
        port = int.parse(args[++i]);
      case '--tcp':
        tcp = int.parse(args[++i]);
      case '--user':
        user = args[++i];
      case '--pass':
        pass = args[++i];
      case '--start':
        start = true;
      case '--raw':
        raw = true;
      default:
        rest.add(args[i]);
    }
  }
  if (rest.isNotEmpty) host = rest.first;
  return (host: host, port: port, tcp: tcp, user: user, pass: pass, start: start, raw: raw);
}
