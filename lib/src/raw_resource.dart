import 'package:xml/xml.dart';

import 'errors/advannet_exception.dart';
import 'transport/http_transport.dart';
import 'xml/envelope.dart';

final class RawResource {
  const RawResource({
    required HttpTransport transport,
    required EnvelopeParser parser,
  }) : _transport = transport,
       _parser = parser;

  final HttpTransport _transport;
  final EnvelopeParser _parser;

  Future<AdvanNetResponse> get(String path) async {
    final xml = await _transport.get(path);
    if (xml.trim().isEmpty) return const EmptyResponse();
    return _parser.parse(xml, method: HttpMethod.get, path: path);
  }

  Future<AdvanNetResponse> put(
    String path, {
    XmlElement? body,
    String? bodyString,
  }) async {
    final bodyStr = body?.toXmlString(pretty: false) ?? bodyString;
    final xml = await _transport.put(path, body: bodyStr);
    if (xml.trim().isEmpty) return const EmptyResponse();
    return _parser.parse(xml, method: HttpMethod.put, path: path);
  }
}
