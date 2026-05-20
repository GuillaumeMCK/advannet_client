import 'dart:convert';
import 'dart:typed_data';

import 'package:advannet_client/advannet_client_testing.dart';
import 'package:test/test.dart';

// Helpers to build framed messages.
Uint8List _frame(
  String body, {
  String contentType = 'text/xml',
  String version = '1.1',
}) {
  final bodyBytes = utf8.encode(body);
  final header =
      'ADVANNET/$version\r\n'
      'Content-Length:${bodyBytes.length}\r\n'
      'Content-Type:$contentType\r\n'
      '\r\n';
  return Uint8List.fromList([...utf8.encode(header), ...bodyBytes]);
}

Uint8List _keepalive({String version = '1.1'}) {
  final header = 'ADVANNET/$version\r\nContent-Length:0\r\n\r\n';
  return Uint8List.fromList(utf8.encode(header));
}

Stream<AdvanNetMessage> _parse(
  List<Uint8List> chunks, {
  void Function(Object, Uint8List?)? onFrameError,
}) {
  return Stream.fromIterable(
    chunks,
  ).transform(AdvanNetMessageParser(onFrameError: onFrameError));
}

void main() {
  group('AdvanNetMessageParser — basic framing', () {
    test('parses a single complete frame', () async {
      final msg = await _parse([_frame('<data/>')]).single;
      expect(utf8.decode(msg.body), '<data/>');
    });

    test('sets Content-Type header', () async {
      final msg = await _parse([_frame('<data/>')]).single;
      expect(msg.contentType, 'text/xml');
    });

    test('sets Content-Length correctly', () async {
      final body = '<hello/>';
      final msg = await _parse([_frame(body)]).single;
      expect(msg.contentLength, utf8.encode(body).length);
    });

    test('parses two frames in the same chunk', () async {
      final combined = Uint8List.fromList([
        ..._frame('<a/>'),
        ..._frame('<b/>'),
      ]);
      final msgs = await _parse([combined]).toList();
      expect(msgs, hasLength(2));
      expect(utf8.decode(msgs[0].body), '<a/>');
      expect(utf8.decode(msgs[1].body), '<b/>');
    });

    test('reassembles a frame split across multiple chunks', () async {
      final full = _frame('<split/>');
      final chunks = [
        Uint8List.sublistView(full, 0, 10),
        Uint8List.sublistView(full, 10, 20),
        Uint8List.sublistView(full, 20),
      ];
      final msg = await _parse(chunks).single;
      expect(utf8.decode(msg.body), '<split/>');
    });

    test('body containing CRLF is read by byte count, not newline', () async {
      const body = 'line1\r\nline2\r\n';
      final msg = await _parse([_frame(body)]).single;
      expect(utf8.decode(msg.body), body);
    });

    test('header keys are lowercased', () async {
      final msg = await _parse([_frame('<x/>')]).single;
      expect(msg.headers.containsKey('content-length'), isTrue);
      expect(msg.headers.containsKey('content-type'), isTrue);
    });
  });

  group('AdvanNetMessageParser — byte-by-byte streaming', () {
    test('reassembles when each byte arrives separately', () async {
      final full = _frame('<tiny/>');
      final chunks = full.map((b) => Uint8List.fromList([b])).toList();
      final msg = await _parse(chunks).single;
      expect(utf8.decode(msg.body), '<tiny/>');
    });
  });

  group('AdvanNetMessageParser — error handling', () {
    test('calls onFrameError on bad status line', () async {
      final bad = Uint8List.fromList(utf8.encode('HTTP/1.1 200 OK\r\n\r\n'));
      Object? captured;
      final msgs = await _parse([
        bad,
      ], onFrameError: (err, _) => captured = err).toList();
      expect(msgs, isEmpty);
      expect(captured, isNotNull);
    });

    test('calls onFrameError when Content-Length is missing', () async {
      final raw = utf8.encode(
        'ADVANNET/1.1\r\nContent-Type:text/xml\r\n\r\nbody',
      );
      Object? captured;
      await _parse([
        Uint8List.fromList(raw),
      ], onFrameError: (err, _) => captured = err).toList();
      expect(captured, isNotNull);
    });

    test('calls onFrameError when body exceeds maxBodySize', () async {
      final body = 'x' * 10;
      final frame = _frame(body);
      Object? captured;
      await Stream.fromIterable([frame])
          .transform(
            AdvanNetMessageParser(
              maxBodySize: 5,
              onFrameError: (err, _) => captured = err,
            ),
          )
          .toList();
      expect(captured, isNotNull);
    });

    test('resumes parsing after a bad frame when good frame follows', () async {
      final bad = Uint8List.fromList(utf8.encode('GARBAGE\r\n'));
      final good = _frame('<ok/>');
      final combined = Uint8List.fromList([...bad, ...good]);
      final msgs = await _parse([
        combined,
      ], onFrameError: (err, bytes) {}).toList();
      expect(msgs, hasLength(1));
      expect(utf8.decode(msgs[0].body), '<ok/>');
    });
  });

  group('AdvanNetMessageParser — protocol version', () {
    test('accepts ADVANNET/1.0 (legacy firmware)', () async {
      final msg = await _parse([_frame('<data/>', version: '1.0')]).single;
      expect(utf8.decode(msg.body), '<data/>');
    });

    test('accepts ADVANNET/1.1 (current firmware)', () async {
      final msg = await _parse([_frame('<data/>', version: '1.1')]).single;
      expect(utf8.decode(msg.body), '<data/>');
    });

    test('parses keepalive frame (Content-Length: 0) without error', () async {
      final msgs = await _parse([_keepalive()]).toList();
      expect(msgs, hasLength(1));
      expect(msgs.single.body, isEmpty);
    });

    test('keepalive followed by real frame yields both messages', () async {
      final combined = Uint8List.fromList([
        ..._keepalive(),
        ..._frame('<ok/>'),
      ]);
      final msgs = await _parse([combined]).toList();
      expect(msgs, hasLength(2));
      expect(msgs[0].body, isEmpty);
      expect(utf8.decode(msgs[1].body), '<ok/>');
    });
  });

  group('AdvanNetMessageParser — multi-frame sequences', () {
    test('parses 10 sequential frames correctly', () async {
      final chunks = List.generate(10, (i) => _frame('<item id="$i"/>'));
      final combined = Uint8List.fromList(chunks.expand((c) => c).toList());
      final msgs = await _parse([combined]).toList();
      expect(msgs, hasLength(10));
      for (var i = 0; i < 10; i++) {
        expect(utf8.decode(msgs[i].body), '<item id="$i"/>');
      }
    });
  });
}
