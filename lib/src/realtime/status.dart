import 'dart:typed_data';

import 'advannet_message.dart';
import 'events.dart';

sealed class RealtimeStatus {
  const RealtimeStatus();
}

final class Connecting extends RealtimeStatus {
  const Connecting();
}

final class Connected extends RealtimeStatus {
  const Connected();
}

final class Disconnected extends RealtimeStatus {
  const Disconnected({this.reason});
  final Object? reason;
}

final class Reconnecting extends RealtimeStatus {
  const Reconnecting({required this.attempt, required this.nextDelay});
  final int attempt;
  final Duration nextDelay;
}

final class FrameError extends RealtimeStatus {
  const FrameError({required this.cause, this.bytes});
  final Object cause;
  final Uint8List? bytes;
}

final class DecodeError extends RealtimeStatus {
  const DecodeError({required this.cause, this.message});
  final Object cause;
  final AdvanNetMessage? message;
}

sealed class RealtimeUpdate {
  const RealtimeUpdate();
}

final class RealtimeEventUpdate extends RealtimeUpdate {
  const RealtimeEventUpdate(this.event);
  final RealtimeEvent event;
}

final class RealtimeStatusUpdate extends RealtimeUpdate {
  const RealtimeStatusUpdate(this.status);
  final RealtimeStatus status;
}
