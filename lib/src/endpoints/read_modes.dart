import 'package:xml/xml.dart';

import '../errors/advannet_exception.dart';
import '../model/read_mode.dart';
import '../raw_resource.dart';
import '../xml/envelope.dart';
import '../xml/xml_extensions.dart';
import 'system.dart';

final class ReadModesResource {
  const ReadModesResource({
    required RawResource raw,
    required SystemResource system,
  }) : _raw = raw,
       _system = system;

  final RawResource _raw;
  final SystemResource _system;

  static const _base = '/system/readmodes';

  /// Returns the raw XML response for a read mode's current configuration.
  Future<AdvanNetResponse> getById(String modeId) =>
      _raw.get('$_base/byId/$modeId');

  /// Replaces a read mode configuration with a raw XML element.
  Future<void> putById(String modeId, XmlElement data) =>
      _raw.put('$_base/byId/$modeId', body: data);

  /// Returns the identifier of the currently active read mode.
  ///
  /// Calls `GET /system/readmodes/active` which returns a `<data><id>…</id></data>` block.
  Future<String> getActive() async {
    final response = await _raw.get('$_base/active');
    return switch (response) {
      DataResponse(:final data) =>
        data.childText('id') ??
            (throw AdvanNetProtocolException(
              message: 'Active read mode response missing <id> element',
              method: HttpMethod.get,
              path: '$_base/active',
            )),
      ErrorResponse(:final code, :final message) => throw AdvanNetServerError(
        message: message ?? 'Failed to get active read mode',
        method: HttpMethod.get,
        path: '$_base/active',
        code: code,
        serverMessage: message,
      ),
      _ => throw AdvanNetProtocolException(
        message: 'Expected <data> response for active read mode',
        method: HttpMethod.get,
        path: '$_base/active',
      ),
    };
  }

  /// Sets the active read mode by ID.
  ///
  /// Calls `PUT /system/readmodes/active` with `<data><id>{modeId}</id></data>`.
  Future<void> setActive(String modeId) async {
    final el = XmlDocument.parse(
      '<data><id>$modeId</id></data>',
    ).rootElement.copy();
    await _raw.put('$_base/active', body: el);
  }

  /// High-level read mode config round-trip: GET → [fromXml] → [mutator] → PUT.
  ///
  /// If [persist] is true, calls [SystemResource.confAllSave] so the change
  /// survives a reboot. If [reboot] is true, reboots after saving.
  ///
  /// ```dart
  /// await reader.readModes.update<AsynchReadMode>(
  ///   modeId: 'AdvanNetAsyncRead',
  ///   fromXml: AsynchReadMode.fromXml,
  ///   mutator: (m) => m.copyWith(eventsTTL: 500),
  ///   persist: true,
  /// );
  /// ```
  Future<T> update<T extends AdvanNetReadMode>({
    required String modeId,
    required T Function(XmlElement) fromXml,
    required T Function(T) mutator,
    bool persist = false,
    bool reboot = false,
  }) async {
    final response = await getById(modeId);
    final XmlElement data = switch (response) {
      DataResponse(:final data) => data,
      ErrorResponse(:final code, :final message) => throw AdvanNetServerError(
        message: message ?? 'Failed to get read mode config',
        method: HttpMethod.get,
        path: '$_base/byId/$modeId',
        code: code,
        serverMessage: message,
      ),
      _ => throw AdvanNetProtocolException(
        message: 'Expected <data> response for read mode config',
        method: HttpMethod.get,
        path: '$_base/byId/$modeId',
      ),
    };

    final updated = mutator(fromXml(data));
    await putById(modeId, updated.toXml());

    if (persist || reboot) await _system.confAllSave();
    if (reboot) await _system.reboot();

    return updated;
  }
}
