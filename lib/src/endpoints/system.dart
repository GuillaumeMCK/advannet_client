import '../errors/advannet_exception.dart';
import '../raw_resource.dart';
import '../xml/envelope.dart';

final class SystemResource {
  const SystemResource({required RawResource raw}) : _raw = raw;

  final RawResource _raw;

  /// Persists the current in-memory configuration to flash storage.
  /// Must be called after any PUT that should survive a reboot.
  Future<void> confAllSave() => _action('/conf/save');

  /// Restores factory defaults. Irreversible — device will reboot.
  Future<void> factoryReset() => _action('/system/os/FactoryReset');

  /// Reboots the device.
  Future<void> reboot() => _action('/system/os/Reboot');

  Future<void> _action(String path) async {
    final response = await _raw.get(path);
    if (response case ErrorResponse(:final code, :final message)) {
      throw AdvanNetServerError(
        message: message ?? 'System command failed',
        method: HttpMethod.get,
        path: path,
        code: code,
        serverMessage: message,
      );
    }
  }
}
