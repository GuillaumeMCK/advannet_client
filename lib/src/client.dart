import 'dart:async';

import 'endpoints/devices.dart';
import 'endpoints/system_info.dart';
import 'endpoints/tags.dart';
import 'endpoints/gpio.dart';
import 'endpoints/read_modes.dart';
import 'endpoints/services.dart';
import 'endpoints/system.dart';
import 'model/credentials.dart';
import 'raw_resource.dart';
import 'realtime/connection_driver.dart';
import 'realtime/realtime_stream.dart';
import 'transport/http_transport.dart';
import 'xml/envelope.dart';

final class AdvanNet {
  AdvanNet._({
    required this.devices,
    required this.services,
    required this.system,
    required this.readModes,
    required this.gpio,
    required this.tags,
    required this.systemInfo,
    required this.raw,
    required this.realtime,
  });

  final DevicesResource devices;
  final ServicesResource services;
  final SystemResource system;
  final ReadModesResource readModes;
  final GpioResource gpio;
  final TagsResource tags;
  final SystemInfoResource systemInfo;
  final RawResource raw;
  final RealtimeStream realtime;

  factory AdvanNet.connect(
    Uri baseUri, {
    AdvanNetCredentials credentials = const AdvanNetCredentials.none(),
    Duration requestTimeout = const Duration(seconds: 10),
    int realtimePort = 3177,
  }) {
    final base = DefaultHttpTransport(
      baseUri: baseUri,
      credentials: credentials,
      timeout: requestTimeout,
    );
    final transport = _SerializedTransport(base, _AsyncMutex());
    const parser = EnvelopeParser();
    final raw = RawResource(transport: transport, parser: parser);
    final system = SystemResource(raw: raw);
    final driver = IoConnectionDriver(host: baseUri.host, port: realtimePort);
    return AdvanNet._(
      devices: DevicesResource(raw: raw),
      services: ServicesResource(raw: raw, system: system),
      system: system,
      readModes: ReadModesResource(raw: raw, system: system),
      gpio: GpioResource(raw: raw),
      tags: TagsResource(raw: raw),
      systemInfo: SystemInfoResource(raw: raw),
      raw: raw,
      realtime: RealtimeStream(driver: driver),
    );
  }

  Future<void> close() => realtime.close();
}

final class _SerializedTransport implements HttpTransport {
  _SerializedTransport(this._inner, this._mutex);

  final HttpTransport _inner;
  final _AsyncMutex _mutex;

  @override
  Future<String> get(String path) => _mutex.protect(() => _inner.get(path));

  @override
  Future<String> put(String path, {String? body}) =>
      _mutex.protect(() => _inner.put(path, body: body));
}

final class _AsyncMutex {
  Future<void> _chain = Future.value();

  Future<T> protect<T>(Future<T> Function() fn) async {
    final previous = _chain;
    final completer = Completer<void>();
    _chain = completer.future;
    await previous;
    try {
      return await fn();
    } finally {
      completer.complete();
    }
  }
}
