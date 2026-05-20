import 'dart:typed_data';

import 'status.dart';

abstract interface class RealtimeDriver {
  Stream<Uint8List> get byteStream;
  Stream<RealtimeStatus> get statusStream;
  Future<void> close();
}
