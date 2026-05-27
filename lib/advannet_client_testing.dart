import 'dart:async';
import 'dart:typed_data';

import 'src/realtime/realtime_driver.dart';
import 'src/realtime/status.dart';
import 'src/transport/http_transport.dart';

export 'src/raw_resource.dart' show RawResource;
export 'src/realtime/advannet_message.dart' show AdvanNetMessage;
export 'src/realtime/event_decoder.dart' show EventDecoder;
export 'src/realtime/message_parser.dart' show AdvanNetMessageParser;
export 'src/realtime/realtime_driver.dart' show RealtimeDriver;
export 'src/realtime/status.dart'
    show
        RealtimeStatus,
        Connecting,
        Connected,
        Disconnected,
        Reconnecting,
        FrameError,
        DecodeError;
export 'src/transport/http_transport.dart' show HttpTransport;
export 'src/xml/entry.dart' show Entry;
export 'src/xml/envelope.dart' show EnvelopeParser;

/// Fake [HttpTransport] for use in downstream tests.
///
/// Seed canned XML responses with [stubGet] / [stubPut], then inspect [calls]
/// to assert which paths were hit and in what order.
final class FakeHttpTransport implements HttpTransport {
  final Map<String, String> _stubs = {};
  final List<({String method, String path, String? body})> calls = [];

  void stubGet(String path, String response) => _stubs['GET:$path'] = response;

  void stubPut(String path, String response) => _stubs['PUT:$path'] = response;

  void clearCalls() => calls.clear();

  @override
  Future<String> get(String path) async {
    calls.add((method: 'GET', path: path, body: null));
    final stub = _stubs['GET:$path'];
    if (stub == null) {
      throw StateError('FakeHttpTransport: no stub for GET $path');
    }
    return stub;
  }

  @override
  Future<String> put(String path, {String? body}) async {
    calls.add((method: 'PUT', path: path, body: body));
    final stub = _stubs['PUT:$path'];
    if (stub == null) {
      throw StateError('FakeHttpTransport: no stub for PUT $path');
    }
    return stub;
  }
}

/// Fake [RealtimeDriver] for use in downstream tests.
///
/// Push synthetic bytes via [addBytes] and status transitions via [addStatus].
/// Call [done] when the stream should complete.
final class FakeConnectionDriver implements RealtimeDriver {
  final _byteController = StreamController<Uint8List>.broadcast();
  final _statusController = StreamController<RealtimeStatus>.broadcast();

  @override
  Stream<Uint8List> get byteStream => _byteController.stream;

  @override
  Stream<RealtimeStatus> get statusStream => _statusController.stream;

  void addBytes(Uint8List bytes) => _byteController.add(bytes);

  void addStatus(RealtimeStatus status) => _statusController.add(status);

  void done() {
    _byteController.close();
    _statusController.close();
  }

  @override
  void connect() {}

  @override
  Future<void> close() async => done();
}
