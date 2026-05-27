import 'dart:async';

import 'event_decoder.dart';
import 'events.dart';
import 'message_parser.dart';
import 'realtime_driver.dart';
import 'status.dart';

final class RealtimeStream {
  RealtimeStream({required RealtimeDriver driver}) : _driver = driver;

  final RealtimeDriver _driver;

  Stream<RealtimeUpdate>? _updates;

  /// Starts the TCP connection immediately, without requiring a listener.
  ///
  /// Useful when you want the connection established before subscribing to
  /// [updates] or any filtered stream. Safe to call multiple times — the
  /// connection is only opened once.
  void connect() {
    _driver.connect();
  }

  Stream<RealtimeUpdate> updates() {
    return _updates ??= _buildUpdates();
  }

  Stream<RealtimeUpdate> _buildUpdates() {
    final frameErrorController = StreamController<RealtimeUpdate>.broadcast();
    final decodeErrorController = StreamController<RealtimeUpdate>.broadcast();

    final parser = AdvanNetMessageParser(
      onFrameError: (cause, bytes) {
        if (!frameErrorController.isClosed) {
          frameErrorController.add(
            RealtimeStatusUpdate(FrameError(cause: cause, bytes: bytes)),
          );
        }
      },
    );

    final decoder = EventDecoder(
      onDecodeError: (cause, message) {
        if (!decodeErrorController.isClosed) {
          decodeErrorController.add(
            RealtimeStatusUpdate(DecodeError(cause: cause, message: message)),
          );
        }
      },
    );

    final eventUpdates = _driver.byteStream
        .transform(parser)
        .transform(decoder);

    final statusUpdates = _driver.statusStream.map(
      (s) => RealtimeStatusUpdate(s) as RealtimeUpdate,
    );

    final controller = StreamController<RealtimeUpdate>.broadcast(
      onCancel: () {
        frameErrorController.close();
        decodeErrorController.close();
      },
    );

    void addTo(RealtimeUpdate u) {
      if (!controller.isClosed) controller.add(u);
    }

    statusUpdates.listen(addTo, onError: controller.addError);
    eventUpdates.listen(addTo, onError: controller.addError);
    frameErrorController.stream.listen(addTo);
    decodeErrorController.stream.listen(addTo);

    return controller.stream;
  }

  Stream<TagReadEvent> tagReads() => updates()
      .where((u) => u is RealtimeEventUpdate && u.event is TagReadEvent)
      .cast<RealtimeEventUpdate>()
      .map((u) => u.event as TagReadEvent);

  Stream<TagDirectionEvent> tagDirections() => updates()
      .where((u) => u is RealtimeEventUpdate && u.event is TagDirectionEvent)
      .cast<RealtimeEventUpdate>()
      .map((u) => u.event as TagDirectionEvent);

  Stream<TagGenericEvent> tagGenerics({String? name}) {
    var s = updates()
        .where((u) => u is RealtimeEventUpdate && u.event is TagGenericEvent)
        .cast<RealtimeEventUpdate>()
        .map((u) => u.event as TagGenericEvent);
    if (name case final name?) s = s.where((e) => e.customEventName == name);
    return s;
  }

  Stream<AlarmEvent> alarms({AlarmKind? kind, int? antennaPort}) {
    var s = updates()
        .where((u) => u is RealtimeEventUpdate && u.event is AlarmEvent)
        .cast<RealtimeEventUpdate>()
        .map((u) => u.event as AlarmEvent);
    if (kind case final kind?) s = s.where((e) => e.kind == kind);
    if (antennaPort case final antennaPort?) {
      s = s.where((e) => e.antennaPort == antennaPort);
    }
    return s;
  }

  Stream<GpiEvent> gpi({int? line, bool? lowToHigh}) {
    var s = updates()
        .where((u) => u is RealtimeEventUpdate && u.event is GpiEvent)
        .cast<RealtimeEventUpdate>()
        .map((u) => u.event as GpiEvent);
    if (line case final line?) s = s.where((e) => e.line == line);
    if (lowToHigh case final lowToHigh?) {
      s = s.where((e) => e.lowToHigh == lowToHigh);
    }
    return s;
  }

  Stream<RealtimeEvent> systemEvents() => updates()
      .where(
        (u) =>
            u is RealtimeEventUpdate &&
            (u.event is SystemInfoEvent ||
                u.event is DeviceConnectedEvent ||
                u.event is DeviceDisconnectedEvent),
      )
      .cast<RealtimeEventUpdate>()
      .map((u) => u.event);

  Stream<UnknownEvent> unknown() => updates()
      .where((u) => u is RealtimeEventUpdate && u.event is UnknownEvent)
      .cast<RealtimeEventUpdate>()
      .map((u) => u.event as UnknownEvent);

  Stream<RealtimeEvent> byType(String type) => updates()
      .where((u) => u is RealtimeEventUpdate && u.event.type == type)
      .cast<RealtimeEventUpdate>()
      .map((u) => u.event);

  Future<void> close() => _driver.close();
}
