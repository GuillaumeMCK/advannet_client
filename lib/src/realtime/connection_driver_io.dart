import 'dart:async';
import 'dart:io';
import 'dart:typed_data';

import 'realtime_driver.dart';
import 'status.dart';

final class IoConnectionDriver implements RealtimeDriver {
  IoConnectionDriver({
    required String host,
    required int port,
    Duration reconnectStep = const Duration(seconds: 1),
    Duration maxReconnectDelay = const Duration(seconds: 5),
    int? maxReconnectAttempts,
  }) : _host = host,
       _port = port,
       _step = reconnectStep,
       _maxDelay = maxReconnectDelay,
       _maxAttempts = maxReconnectAttempts;

  final String _host;
  final int _port;
  final Duration _step;
  final Duration _maxDelay;
  final int? _maxAttempts;

  final _byteController = StreamController<Uint8List>.broadcast();
  final _statusController = StreamController<RealtimeStatus>.broadcast();

  Socket? _socket;
  bool _closed = false;
  bool _started = false;

  @override
  Stream<Uint8List> get byteStream {
    _start();
    return _byteController.stream;
  }

  @override
  Stream<RealtimeStatus> get statusStream {
    _start();
    return _statusController.stream;
  }

  void _start() {
    if (!_started && !_closed) {
      _started = true;
      _connectLoop();
    }
  }

  /// Starts the TCP connection loop without subscribing to any stream.
  ///
  /// Useful when you want the connection to be established eagerly, before
  /// any listener is attached to [byteStream] or [statusStream].
  @override
  void connect() => _start();

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

    while (!_closed) {
      _statusController.add(const Connecting());
      try {
        final socket = await Socket.connect(_host, _port);
        if (_closed) {
          socket.destroy();
          return;
        }
        _socket = socket;
        attempt = 0;
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

        if (_closed) return;
        _statusController.add(Disconnected());
      } catch (err) {
        if (_closed) return;
        _statusController.add(Disconnected(reason: err));
      }

      if (_closed) return;

      final max = _maxAttempts;
      if (max != null && attempt >= max) break;

      // Linear ramp: 1×step, 2×step, 3×step … capped at maxDelay.
      // Deterministic and predictable for local hardware — no jitter needed.
      final nextDelay = Duration(
        milliseconds:
            ((attempt + 1) * _step.inMilliseconds).clamp(
              0,
              _maxDelay.inMilliseconds,
            ),
      );
      attempt++;
      _statusController.add(Reconnecting(attempt: attempt, nextDelay: nextDelay));
      await Future<void>.delayed(nextDelay);
    }

    if (!_closed) {
      _statusController.add(
        Disconnected(reason: 'max reconnect attempts reached'),
      );
      await _byteController.close();
      await _statusController.close();
    }
  }
}
