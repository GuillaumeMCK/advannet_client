import 'package:xml/xml.dart';

import '../errors/advannet_exception.dart';
import '../model/service.dart';
import '../raw_resource.dart';
import '../xml/envelope.dart';
import '../xml/xml_extensions.dart';
import 'system.dart';

final class ServicesResource {
  const ServicesResource({
    required RawResource raw,
    required SystemResource system,
  }) : _raw = raw,
       _system = system;

  final RawResource _raw;
  final SystemResource _system;

  /// Returns the ordered list of service names from `GET /system/services/ids`.
  Future<List<String>> listIds() async {
    const path = '/system/services/ids';
    final response = await _raw.get(path);
    return switch (response) {
      DataResponse(:final data) => [
        for (final entry in (data.child('entries') ?? data).findElements(
          'entry',
        ))
          ?_nullIfEmpty(entry.childText('result') ?? ''),
      ],
      EmptyResponse() => const [],
      ErrorResponse(:final code, :final message) => throw AdvanNetServerError(
        message: message ?? 'Failed to list service IDs',
        method: HttpMethod.get,
        path: path,
        code: code,
        serverMessage: message,
      ),
      _ => const [],
    };
  }

  /// Returns the enabled/disabled status for each service, keyed by 0-based
  /// index (matching the order returned by [listIds]).
  ///
  /// Uses `GET /system/services/status`.
  Future<Map<int, bool>> getStatuses() async {
    const path = '/system/services/status';
    final response = await _raw.get(path);
    return switch (response) {
      DataResponse(:final data) => {
        for (final entry in (data.child('entries') ?? data).findElements(
          'entry',
        ))
          ?entry.childText('index').toInt(): entry.childText('result')?.toLowerCase() == 'true',
      },
      EmptyResponse() => {},
      ErrorResponse(:final code, :final message) => throw AdvanNetServerError(
        message: message ?? 'Failed to get service statuses',
        method: HttpMethod.get,
        path: path,
        code: code,
        serverMessage: message,
      ),
      _ => {},
    };
  }

  /// Returns the raw XML response for a service's current configuration.
  Future<AdvanNetResponse> getById(String serviceId) =>
      _raw.get('/system/services/byId/$serviceId');

  /// Replaces a service configuration with a raw XML element.
  Future<void> putById(String serviceId, XmlElement data) =>
      _raw.put('/system/services/byId/$serviceId', body: data);

  /// High-level config round-trip: GET → [fromXml] → [mutator] → PUT.
  ///
  /// If [persist] is true, calls [SystemResource.confAllSave] so the change
  /// survives a reboot. If [reboot] is true, reboots after saving (implies
  /// [persist]).
  ///
  /// ```dart
  /// await reader.services.update<AdvanNetRestService>(
  ///   serviceId: 'AdvanNetRestService',
  ///   fromXml: AdvanNetRestService.fromXml,
  ///   mutator: (svc) => svc.copyWith(serveStatic: true),
  ///   persist: true,
  /// );
  /// ```
  Future<T> update<T extends AdvanNetService>({
    required String serviceId,
    required T Function(XmlElement) fromXml,
    required T Function(T) mutator,
    bool persist = false,
    bool reboot = false,
  }) async {
    final response = await getById(serviceId);
    final XmlElement data = switch (response) {
      DataResponse(:final data) => data,
      ErrorResponse(:final code, :final message) => throw AdvanNetServerError(
        message: message ?? 'Failed to get service config',
        method: HttpMethod.get,
        path: '/system/services/byId/$serviceId',
        code: code,
        serverMessage: message,
      ),
      _ => throw AdvanNetProtocolException(
        message: 'Expected <data> response for service config',
        method: HttpMethod.get,
        path: '/system/services/byId/$serviceId',
      ),
    };

    final updated = mutator(fromXml(data));
    await putById(serviceId, updated.toXml());

    if (persist || reboot) await _system.confAllSave();
    if (reboot) await _system.reboot();

    return updated;
  }
}

String? _nullIfEmpty(String s) => s.isEmpty ? null : s;
