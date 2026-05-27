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
  });

  @override
  Stream<Uint8List> get byteStream => Stream.error(
    UnsupportedError(
      'Raw TCP realtime stream is not supported on the web platform.',
    ),
  );

  @override
  Stream<RealtimeStatus> get statusStream => const Stream.empty();

  @override
  void connect() {}

  @override
  Future<void> close() async {}
}
