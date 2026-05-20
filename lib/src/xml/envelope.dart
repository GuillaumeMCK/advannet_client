import 'package:xml/xml.dart';

import '../errors/advannet_exception.dart';
import 'entry.dart';
import 'xml_extensions.dart';

sealed class AdvanNetResponse {
  const AdvanNetResponse();

  void throwIfError({required HttpMethod method, required String path}) {
    if (this case ErrorResponse(:final code, :final message)) {
      throw AdvanNetServerError(
        message: message ?? 'Command failed',
        method: method,
        path: path,
        code: code,
        serverMessage: message,
      );
    }
  }
}

final class EntriesResponse extends AdvanNetResponse {
  const EntriesResponse(this.entries);
  final List<Entry> entries;
}

final class DataResponse extends AdvanNetResponse {
  const DataResponse(this.data);
  final XmlElement data;
}

final class EmptyResponse extends AdvanNetResponse {
  const EmptyResponse();
}

final class ErrorResponse extends AdvanNetResponse {
  const ErrorResponse(this.code, this.message);
  final String code;
  final String? message;
}

final class EnvelopeParser {
  const EnvelopeParser();

  AdvanNetResponse parse(
    String xmlBody, {
    required HttpMethod method,
    required String path,
  }) {
    late XmlDocument doc;
    try {
      doc = XmlDocument.parse(xmlBody);
    } catch (err) {
      throw AdvanNetProtocolException(
        message: 'Failed to parse XML response',
        method: method,
        path: path,
        cause: err,
      );
    }
    return _parseElement(doc.rootElement, method: method, path: path);
  }

  AdvanNetResponse _parseElement(
    XmlElement root, {
    required HttpMethod method,
    required String path,
  }) {
    if (root.name.local == 'response') {
      // New-style envelope: <status>OK|ERROR</status> with optional <data>/<msg>.
      final status = root.childText('status');
      if (status == 'ERROR') {
        final msg = root.childText('msg');
        final code = root.childText('op') ?? 'ERROR';
        return ErrorResponse(code, msg);
      }

      // Look up content children by name so extra siblings (e.g. <type>, <ts>)
      // are ignored regardless of their position.
      if (root.child('data') case final dataEl?) {
        return DataResponse(dataEl);
      }
      if (root.child('entries') case final entriesEl?) {
        return _parseEntries(entriesEl);
      }
      if (root.child('error') case final errorEl?) {
        return _parseError(errorEl);
      }

      return const EmptyResponse();
    }

    return switch (root.name.local) {
      'error' => _parseError(root),
      'entries' => _parseEntries(root),
      'data' => DataResponse(root),
      _ => const EmptyResponse(),
    };
  }

  ErrorResponse _parseError(XmlElement el) =>
      ErrorResponse(el.childText('code') ?? 'UNKNOWN', el.childText('message'));

  EntriesResponse _parseEntries(XmlElement el) =>
      EntriesResponse([...el.findElements('entry').map(_parseEntry)]);

  Entry _parseEntry(XmlElement el) => Entry(
    className: el.childText('class') ?? '',
    def: el.childText('def') ?? '',
    conf: el.child('conf'),
  );
}
