import 'package:xml/xml.dart';

extension XmlNodeQuery on XmlElement? {
  String? childText(String name) =>
      this?.findElements(name).firstOrNull?.innerText.trim();

  XmlElement? child(String name) => this?.findElements(name).firstOrNull;
}

extension NullableStringParsing on String? {
  int? toInt() => switch (this) {
    final s? => int.tryParse(s.trim()),
    _ => null,
  };

  double? toDouble() => switch (this) {
    final s? => double.tryParse(s.trim()),
    _ => null,
  };
}
