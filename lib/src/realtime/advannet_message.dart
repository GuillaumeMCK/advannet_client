import 'dart:typed_data';

final class AdvanNetMessage {
  const AdvanNetMessage({required this.headers, required this.body});

  final Map<String, String> headers;
  final Uint8List body;

  String? get contentType => headers['content-type'];

  int? get contentLength {
    final val = headers['content-length'];
    if (val == null) return null;
    return int.tryParse(val.trim());
  }
}
