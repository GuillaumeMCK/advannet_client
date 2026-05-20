import 'dart:async';
import 'dart:io';
import 'dart:math';
import 'dart:typed_data';

import 'realtime_driver.dart';
import 'status.dart';

final class IoConnectionDriver implements RealtimeDriver {
  IoConnectionDriver({
    required String host,
    required int port,
    Duration initialReconnectDelay = const Duration(seconds: 1),
    Duration maxReconnectDelay = const Duration(seconds: 30),
    int? maxReconnectAttempts,
    Random? random,
  }) : _host = host,
       _port = port,
       _initialDelay = initialReconnectDelay,
       _maxDelay = maxReconnectDelay,
       _maxAttempts = maxReconnectAttempts,
       _random = random ?? Random();

  final String _host;
  final int _port;
  final Duration _initialDelay;
  final Duration _maxDelay;
  final int? _maxAttempts;
  final Random _random;

  final _byteController = StreamController<Uint8List>.broadcast();
  final _statusController = StreamController<RealtimeStatus>.broadcast();

  Socket? _socket;
  bool _closed = false;
  bool _started = false;

  @override
  Stream<Uint8List> get byteStream {
    _lazyStart();
    return _byteController.stream;
  }

  @override
  Stream<RealtimeStatus> get statusStream {
    _lazyStart();
    return _statusController.stream;
  }

  void _lazyStart() {
    if (!_started && !_closed) {
      _started = true;
      _connectLoop();
    }
  }

  @override
  Future<void> close() async {
    _closed = true;
    await _socket?.close();
    _socket = null;
    await _byteController.close();
    await _statusController.close();
  }

  Future<void> _connectLoop() async {
    var attempt = 0;
    var delay = _initialDelay;

    while (!_closed) {
      _statusController.add(const Connecting());
      try {
        final socket = await Socket.connect(_host, _port);
        if (_closed) {
          socket.destroy();
          return;
        }
        _socket = socket;
        _statusController.add(const Connected());

        final done = Completer<void>();
        socket.listen(
          (bytes) {
            if (!_closed) _byteController.add(bytes);
          },
          onError: (Object err) {
            if (!done.isCompleted) done.complete();
          },
          onDone: () {
            if (!done.isCompleted) done.complete();
          },
          cancelOnError: false,
        );

        await done.future;
        _socket = null;
        attempt = 0;
        delay = _initialDelay;

        if (_closed) return;
        _statusController.add(Disconnected());
      } catch (err) {
        if (_closed) return;
        _statusController.add(Disconnected(reason: err));
      }

      if (_closed) return;

      final max = _maxAttempts;
      if (max != null && attempt >= max) break;

      final jitter = (_random.nextDouble() * 0.5 - 0.25) * delay.inMilliseconds;
      final jitteredMs = (delay.inMilliseconds + jitter).round().clamp(
        0,
        _maxDelay.inMilliseconds,
      );
      final nextDelay = Duration(milliseconds: jitteredMs);
      attempt++;
      _statusController.add(
        Reconnecting(attempt: attempt, nextDelay: nextDelay),
      );

      await Future<void>.delayed(nextDelay);

      final doubled = Duration(milliseconds: delay.inMilliseconds * 2);
      delay = doubled > _maxDelay ? _maxDelay : doubled;
    }

    if (!_closed) {
      _statusController.add(
        Disconnected(reason: 'Max reconnect attempts reached'),
      );
      await _byteController.close();
      await _statusController.close();
    }
  }
}
