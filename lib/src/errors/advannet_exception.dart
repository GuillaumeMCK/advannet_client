import 'package:meta/meta.dart';

enum HttpMethod {
  get,
  put;

  @override
  String toString() => name.toUpperCase();
}

@immutable
sealed class AdvanNetException implements Exception {
  const AdvanNetException({
    required this.message,
    required this.method,
    required this.path,
  });

  final String message;
  final HttpMethod method;
  final String path;

  @override
  String toString() => '$runtimeType: [$method $path] $message';
}

@immutable
final class AdvanNetTransportException extends AdvanNetException {
  const AdvanNetTransportException({
    required super.message,
    required super.method,
    required super.path,
    this.cause,
  });

  final Object? cause;

  @override
  String toString() =>
      '${super.toString()}${switch (cause) {
        final c? => ' (cause: $c)',
        _ => '',
      }}';
}

@immutable
final class AdvanNetAuthException extends AdvanNetException {
  const AdvanNetAuthException({
    required super.message,
    required super.method,
    required super.path,
    required this.statusCode,
  });

  final int statusCode;
}

@immutable
final class AdvanNetProtocolException extends AdvanNetException {
  const AdvanNetProtocolException({
    required super.message,
    required super.method,
    required super.path,
    this.cause,
  });

  final Object? cause;
}

@immutable
final class AdvanNetServerError extends AdvanNetException {
  const AdvanNetServerError({
    required super.message,
    required super.method,
    required super.path,
    this.code,
    this.serverMessage,
  });

  final String? code;
  final String? serverMessage;
}

@immutable
final class AdvanNetDeviceBusyException extends AdvanNetException {
  const AdvanNetDeviceBusyException({
    required super.message,
    required super.method,
    required super.path,
  });
}

@immutable
final class AdvanNetUnsupportedException extends AdvanNetException {
  const AdvanNetUnsupportedException({
    required super.message,
    required super.method,
    required super.path,
  });
}
