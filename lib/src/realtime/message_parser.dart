import 'dart:async';
import 'dart:convert';
import 'dart:typed_data';

import 'advannet_message.dart';

// Wire prefix that begins every ADVANNET frame status line.
// Accepts any version (1.0, 1.1, 2.x …) — only the literal prefix is checked.
const _kPrefix = [
  0x41, 0x44, 0x56, 0x41, 0x4E, 0x4E, 0x45, 0x54, 0x2F, // "ADVANNET/"
];

enum _State { statusLine, headers, body }

// ── public transformer ────────────────────────────────────────────────────────

final class AdvanNetMessageParser
    extends StreamTransformerBase<Uint8List, AdvanNetMessage> {
  const AdvanNetMessageParser({
    this.maxBodySize = 1024 * 1024,
    this.onFrameError,
  });

  final int maxBodySize;
  final void Function(Object cause, Uint8List? bytes)? onFrameError;

  @override
  Stream<AdvanNetMessage> bind(Stream<Uint8List> stream) {
    final controller = StreamController<AdvanNetMessage>();
    final parser = _FrameParser(
      maxBodySize: maxBodySize,
      onMessage: controller.add,
      onFrameError: onFrameError ?? (_, _) {},
    );
    stream.listen(
      parser.push,
      onError: controller.addError,
      onDone: controller.close,
      cancelOnError: false,
    );
    return controller.stream;
  }
}

// ── state machine ─────────────────────────────────────────────────────────────

final class _FrameParser {
  _FrameParser({
    required this.maxBodySize,
    required this.onMessage,
    required this.onFrameError,
  });

  final int maxBodySize;
  final void Function(AdvanNetMessage) onMessage;
  final void Function(Object, Uint8List?) onFrameError;

  final _buf = _Buffer();
  final _headers = <String, String>{};
  var _state = _State.statusLine;
  var _bodyLength = 0;

  void push(Uint8List chunk) {
    _buf.append(chunk);
    _drain();
  }

  void _drain() {
    while (true) {
      switch (_state) {
        case _State.statusLine:
          if (!_readStatusLine()) return;
        case _State.headers:
          if (!_readHeaders()) return;
        case _State.body:
          if (!_readBody()) return;
      }
    }
  }

  bool _readStatusLine() {
    final pos = _buf.indexOfCrLf();
    if (pos < 0) return false;

    if (pos == 0) {
      // Empty line — device appends \r\n\r\n after each body as a separator.
      _buf.consume(2);
      return _buf.available > 0;
    }

    final line = _buf.view(pos);
    _buf.consume(pos + 2);

    if (!_startsWith(line, _kPrefix)) {
      final copy = Uint8List.fromList(line);
      onFrameError(
        'Bad status line: ${utf8.decode(line, allowMalformed: true)}',
        copy,
      );
      _buf.realign(_kPrefix);
      return _buf.available > 0;
    }

    _state = _State.headers;
    _headers.clear();
    return true;
  }

  bool _readHeaders() {
    while (true) {
      final pos = _buf.indexOfCrLf();
      if (pos < 0) return false;

      if (pos == 0) {
        _buf.consume(2);
        return _transitionToBody();
      }

      final line = utf8.decode(_buf.view(pos), allowMalformed: true);
      _buf.consume(pos + 2);
      final colon = line.indexOf(':');
      if (colon > 0) {
        final key = line.substring(0, colon).trim().toLowerCase();
        _headers[key] = line.substring(colon + 1).trim();
      }
    }
  }

  bool _transitionToBody() {
    final raw = _headers['content-length'];
    final cl = raw != null ? int.tryParse(raw.trim()) : null;

    if (cl == null || cl < 0) {
      onFrameError('Missing or invalid Content-Length: $raw', null);
      _state = _State.statusLine;
      _buf.realign(_kPrefix);
      return _buf.available > 0;
    }
    if (cl > maxBodySize) {
      onFrameError('Body too large: $cl > $maxBodySize bytes', null);
      _state = _State.statusLine;
      _buf.realign(_kPrefix);
      return _buf.available > 0;
    }

    _bodyLength = cl;
    _state = _State.body;
    return true;
  }

  bool _readBody() {
    if (_buf.available < _bodyLength) return false;
    onMessage(
      AdvanNetMessage(
        headers: Map.unmodifiable(Map.of(_headers)),
        body: _buf.copy(_bodyLength),
      ),
    );
    _buf.consume(_bodyLength);
    _state = _State.statusLine;
    _headers.clear();
    _bodyLength = 0;
    return true;
  }
}

// ── contiguous byte buffer ────────────────────────────────────────────────────

final class _Buffer {
  static const _kInitial = 8192;

  Uint8List _data = Uint8List(_kInitial);
  int _rpos = 0; // first unread byte
  int _wpos = 0; // next write position

  int get available => _wpos - _rpos;

  void append(Uint8List bytes) {
    if (bytes.isEmpty) return;
    _reserve(bytes.length);
    _data.setRange(_wpos, _wpos + bytes.length, bytes);
    _wpos += bytes.length;
  }

  /// Advance the read cursor by [count] bytes (zero-copy).
  void consume(int count) {
    assert(count >= 0 && count <= available);
    _rpos += count;
    // Compact once we've consumed more than half the backing store.
    if (_rpos > _data.length >> 1) _compact();
  }

  /// Zero-copy view of the next [length] bytes. Valid until the next [append].
  Uint8List view(int length) =>
      Uint8List.sublistView(_data, _rpos, _rpos + length);

  /// Copy of the next [length] bytes (safe to store beyond the next [append]).
  Uint8List copy(int length) =>
      Uint8List.fromList(Uint8List.sublistView(_data, _rpos, _rpos + length));

  /// Returns the offset (from the read cursor) of the first \r\n, or -1.
  int indexOfCrLf() {
    final end = _wpos - 1;
    for (var i = _rpos; i < end; i++) {
      if (_data[i] == 0x0D && _data[i + 1] == 0x0A) return i - _rpos;
    }
    return -1;
  }

  /// Consume everything before the first occurrence of [prefix], so that
  /// the buffer starts with [prefix]. Discards all content if not found.
  void realign(List<int> prefix) {
    final end = _wpos - prefix.length + 1;
    for (var i = _rpos; i < end; i++) {
      if (_data[i] != prefix[0]) continue;
      var match = true;
      for (var j = 1; j < prefix.length; j++) {
        if (_data[i + j] != prefix[j]) {
          match = false;
          break;
        }
      }
      if (match) {
        _rpos = i;
        return;
      }
    }
    _rpos = _wpos = 0; // nothing found — discard everything
  }

  // ── internal ──────────────────────────────────────────────────────────────

  void _reserve(int extra) {
    if (_wpos + extra <= _data.length) return;
    _compact();
    if (_wpos + extra <= _data.length) return;
    var size = _data.length;
    while (_wpos + extra > size) {
      size *= 2;
    }
    final next = Uint8List(size);
    next.setRange(0, _wpos, _data);
    _data = next;
  }

  void _compact() {
    if (_rpos == 0) return;
    final len = available;
    _data.setRange(0, len, _data, _rpos);
    _rpos = 0;
    _wpos = len;
  }
}

// ── helpers ───────────────────────────────────────────────────────────────────

bool _startsWith(Uint8List a, List<int> prefix) {
  if (a.length < prefix.length) return false;
  for (var i = 0; i < prefix.length; i++) {
    if (a[i] != prefix[i]) return false;
  }
  return true;
}
