import 'package:advannet_client/advannet_client.dart';
import 'package:test/test.dart';
import 'package:xml/xml.dart';

XmlElement _parse(String xml) => XmlDocument.parse(xml).rootElement;

void main() {
  group('AsynchReadMode', () {
    test('fromXml reads enabled field', () {
      final m = AsynchReadMode.fromXml(
        _parse('<data><enabled>false</enabled></data>'),
      );
      expect(m.enabled, isFalse);
    });

    test('enabled defaults to true when element absent', () {
      final m = AsynchReadMode.fromXml(_parse('<data/>'));
      expect(m.enabled, isTrue);
    });

    test('fromXml reads eventsTTL', () {
      final m = AsynchReadMode.fromXml(
        _parse('<data><eventsTTL>500</eventsTTL></data>'),
      );
      expect(m.eventsTTL, 500);
    });

    test('eventsTTL defaults to 0 when absent', () {
      expect(AsynchReadMode.fromXml(_parse('<data/>')).eventsTTL, 0);
    });

    test('fromXml reads direction flag', () {
      final m = AsynchReadMode.fromXml(
        _parse('<data><direction>true</direction></data>'),
      );
      expect(m.direction, isTrue);
    });

    test('fromXml reads customEvent and customEvent2', () {
      final m = AsynchReadMode.fromXml(
        _parse(
          '<data><customEvent>true</customEvent><customEvent2>true</customEvent2></data>',
        ),
      );
      expect(m.customEvent, isTrue);
      expect(m.customEvent2, isTrue);
    });

    test('copyWith updates eventsTTL', () {
      final original = AsynchReadMode.fromXml(
        _parse('<data><eventsTTL>0</eventsTTL></data>'),
      );
      final updated = original.copyWith(eventsTTL: 1000);
      expect(updated.eventsTTL, 1000);
      expect(original.eventsTTL, 0);
    });

    test('copyWith updates direction without touching other fields', () {
      final original = AsynchReadMode.fromXml(
        _parse(
          '<data><enabled>true</enabled><direction>false</direction></data>',
        ),
      );
      final updated = original.copyWith(direction: true);
      expect(updated.direction, isTrue);
      expect(updated.enabled, isTrue);
    });

    test('toXml returns the raw element', () {
      final m = AsynchReadMode.fromXml(
        _parse('<data><eventsTTL>250</eventsTTL></data>'),
      );
      expect(m.toXml().getElement('eventsTTL')?.innerText, '250');
    });

    test('modeId is AdvanNetAsyncRead', () {
      expect(
        AsynchReadMode.fromXml(_parse('<data/>')).modeId,
        'AdvanNetAsyncRead',
      );
    });
  });

  group('ScanReadMode', () {
    test('fromXml reads period', () {
      final m = ScanReadMode.fromXml(
        _parse('<data><period>2000</period></data>'),
      );
      expect(m.period, 2000);
    });

    test('period defaults to 1000 when absent', () {
      expect(ScanReadMode.fromXml(_parse('<data/>')).period, 1000);
    });

    test('fromXml reads dynamicQ', () {
      final m = ScanReadMode.fromXml(
        _parse('<data><dynamicQ>false</dynamicQ></data>'),
      );
      expect(m.dynamicQ, isFalse);
    });

    test('copyWith updates period', () {
      final original = ScanReadMode.fromXml(
        _parse('<data><period>1000</period></data>'),
      );
      final updated = original.copyWith(period: 500);
      expect(updated.period, 500);
      expect(original.period, 1000);
    });

    test('modeId is AdvanNetScanRead', () {
      expect(
        ScanReadMode.fromXml(_parse('<data/>')).modeId,
        'AdvanNetScanRead',
      );
    });
  });

  group('EasReadMode', () {
    test('fromXml reads perAntennaAlarm', () {
      final m = EasReadMode.fromXml(
        _parse('<data><perAntennaAlarm>true</perAntennaAlarm></data>'),
      );
      expect(m.perAntennaAlarm, isTrue);
    });

    test('fromXml reads alarmTTL', () {
      final m = EasReadMode.fromXml(
        _parse('<data><alarmTTL>300</alarmTTL></data>'),
      );
      expect(m.alarmTTL, 300);
    });

    test('copyWith updates alarmTTL', () {
      final original = EasReadMode.fromXml(
        _parse('<data><alarmTTL>0</alarmTTL></data>'),
      );
      final updated = original.copyWith(alarmTTL: 200);
      expect(updated.alarmTTL, 200);
      expect(original.alarmTTL, 0);
    });

    test('modeId is AdvanNetEasRead', () {
      expect(EasReadMode.fromXml(_parse('<data/>')).modeId, 'AdvanNetEasRead');
    });
  });
}
