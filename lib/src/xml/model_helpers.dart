import 'package:xml/xml.dart';

import 'xml_extensions.dart';

// Shared XML param helpers used by typed config model classes (services,
// read modes, etc.). Supports two wire shapes:
//   Shape 1 — direct child:  <data><fieldName>value</fieldName></data>
//   Shape 2 — entry list:    <data><conf><parameters><entry><class>fieldName</class><def>value</def>…

String? xmlParamValue(XmlElement root, String name) =>
    root.childText(name) ??
    root
        .child('conf')
        ?.child('parameters')
        ?.findElements('entry')
        .where((e) => e.childText('class') == name)
        .firstOrNull
        ?.childText('def');

bool? xmlBoolParam(XmlElement root, String name) =>
    switch (xmlParamValue(root, name)) {
      final v? => v.toLowerCase() == 'true',
      _ => null,
    };

int? xmlIntParam(XmlElement root, String name) =>
    xmlParamValue(root, name).toInt();

void xmlSetParam(XmlElement root, String name, String value) {
  if (root.child(name) case final direct?) {
    direct.innerText = value;
    return;
  }
  if (root
          .child('conf')
          ?.child('parameters')
          ?.findElements('entry')
          .where((e) => e.childText('class') == name)
          .firstOrNull
          ?.child('def')
      case final def?) {
    def.innerText = value;
  }
}
