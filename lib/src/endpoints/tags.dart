import 'package:xml/xml.dart';

import '../errors/advannet_exception.dart';
import '../raw_resource.dart';
import '../xml/envelope.dart';
import '../xml/xml_extensions.dart';

final class TagsResource {
  const TagsResource({required RawResource raw}) : _raw = raw;
  final RawResource _raw;

  /// Returns the EPC strings of all tags currently in the device's inventory cache.
  Future<List<String>> list(String deviceId) async {
    final path = '/devices/$deviceId/tags';
    final response = await _raw.get(path);
    return switch (response) {
      EntriesResponse(:final entries) => [
        for (final e in entries)
          if (e.defFields.isNotEmpty)
            e.defFields.first
          else if (e.def.isNotEmpty)
            e.def,
      ],
      DataResponse(:final data) => [
        ...data
            .findElements('entry')
            .map((e) => e.childText('def'))
            .whereType<String>()
            .map((def) => def.split(',').first)
            .where((s) => s.isNotEmpty),
      ],
      EmptyResponse() => const [],
      ErrorResponse(:final code, :final message) => throw AdvanNetServerError(
        message: message ?? 'Failed to list tags',
        method: HttpMethod.get,
        path: path,
        code: code,
        serverMessage: message,
      ),
    };
  }

  /// Clears the device's tag inventory cache.
  Future<void> clear(String deviceId) async {
    final path = '/devices/$deviceId/tags/clear';
    (await _raw.get(path)).throwIfError(method: HttpMethod.get, path: path);
  }

  /// Returns the number of tags currently in the device's inventory cache.
  Future<int> count(String deviceId) async {
    final path = '/devices/$deviceId/tags/count';
    final response = await _raw.get(path);
    return switch (response) {
      DataResponse(:final data) =>
        int.tryParse(
              data.childText('count') ??
                  data.childText('result') ??
                  data.innerText.trim(),
            ) ??
            0,
      EmptyResponse() => 0,
      ErrorResponse(:final code, :final message) => throw AdvanNetServerError(
        message: message ?? 'Failed to get tag count',
        method: HttpMethod.get,
        path: path,
        code: code,
        serverMessage: message,
      ),
      _ => 0,
    };
  }
}
