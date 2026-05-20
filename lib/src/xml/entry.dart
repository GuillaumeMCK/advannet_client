import 'package:meta/meta.dart';
import 'package:xml/xml.dart';

@immutable
final class Entry {
  const Entry({required this.className, required this.def, this.conf});

  final String className;

  // Raw comma-separated definition string from the wire; parsed into typed
  // fields by the resource layer, not here.
  final String def;

  final XmlElement? conf;

  List<String> get defFields => def.split(',');
}
