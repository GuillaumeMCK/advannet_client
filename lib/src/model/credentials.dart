import 'package:meta/meta.dart';

@immutable
sealed class AdvanNetCredentials {
  const AdvanNetCredentials._();

  const factory AdvanNetCredentials.none() = NoAdvanNetCredentials;

  const factory AdvanNetCredentials.basic(String username, String password) =
      BasicAdvanNetCredentials;

  const factory AdvanNetCredentials.digest(String username, String password) =
      DigestAdvanNetCredentials;
}

@immutable
final class NoAdvanNetCredentials extends AdvanNetCredentials {
  const NoAdvanNetCredentials() : super._();
}

@immutable
final class BasicAdvanNetCredentials extends AdvanNetCredentials {
  const BasicAdvanNetCredentials(this.username, this.password) : super._();

  final String username;
  final String password;
}

@immutable
final class DigestAdvanNetCredentials extends AdvanNetCredentials {
  const DigestAdvanNetCredentials(this.username, this.password) : super._();

  final String username;
  final String password;
}
