import 'package:advannet_client/advannet_client.dart';
import 'package:advannet_client/advannet_client_testing.dart';
import 'package:test/test.dart';
import 'package:xml/xml.dart';

RawResource _raw(FakeHttpTransport fake) =>
    RawResource(transport: fake, parser: const EnvelopeParser());

SystemResource _system(FakeHttpTransport fake) =>
    SystemResource(raw: _raw(fake));

ServicesResource _services(FakeHttpTransport fake) =>
    ServicesResource(raw: _raw(fake), system: _system(fake));

XmlElement parseXml(String s) => XmlDocument.parse(s).rootElement;

const _restServiceXml = '''
<data>
  <serveStatic>false</serveStatic>
  <enabled>true</enabled>
</data>''';

void main() {
  group('ServicesResource.listIds()', () {
    test('calls GET /system/services/ids', () async {
      final fake = FakeHttpTransport()
        ..stubGet('/system/services/ids', '''
<response><status>OK</status><data>
  <entries>
    <entry><index>0</index><result>Scheduler</result></entry>
    <entry><index>1</index><result>HTTPService</result></entry>
    <entry><index>2</index><result>MQTTService</result></entry>
  </entries>
</data></response>''');
      final ids = await _services(fake).listIds();
      expect(fake.calls.single.path, '/system/services/ids');
      expect(ids, ['Scheduler', 'HTTPService', 'MQTTService']);
    });

    test('returns empty list on EmptyResponse', () async {
      final fake = FakeHttpTransport()
        ..stubGet('/system/services/ids', '<response/>');
      expect(await _services(fake).listIds(), isEmpty);
    });
  });

  group('ServicesResource.getStatuses()', () {
    test('calls GET /system/services/status', () async {
      final fake = FakeHttpTransport()
        ..stubGet('/system/services/status', '''
<response><status>OK</status><data>
  <entries>
    <entry><index>0</index><result>true</result></entry>
    <entry><index>1</index><result>false</result></entry>
    <entry><index>2</index><result>true</result></entry>
  </entries>
</data></response>''');
      final statuses = await _services(fake).getStatuses();
      expect(fake.calls.single.path, '/system/services/status');
      expect(statuses[0], isTrue);
      expect(statuses[1], isFalse);
      expect(statuses[2], isTrue);
    });

    test('returns empty map on EmptyResponse', () async {
      final fake = FakeHttpTransport()
        ..stubGet('/system/services/status', '<response/>');
      expect(await _services(fake).getStatuses(), isEmpty);
    });
  });

  group('ServicesResource.getById()', () {
    test('calls correct path', () async {
      final fake = FakeHttpTransport()
        ..stubGet('/system/services/byId/AdvanNetRestService', _restServiceXml);
      await _services(fake).getById('AdvanNetRestService');
      expect(
        fake.calls.single.path,
        '/system/services/byId/AdvanNetRestService',
      );
    });

    test('returns DataResponse', () async {
      final fake = FakeHttpTransport()
        ..stubGet('/system/services/byId/AdvanNetRestService', _restServiceXml);
      final response = await _services(fake).getById('AdvanNetRestService');
      expect(response, isA<DataResponse>());
    });
  });

  group('ServicesResource.update()', () {
    test('calls GET then PUT on the service path', () async {
      final fake = FakeHttpTransport()
        ..stubGet('/system/services/byId/AdvanNetRestService', _restServiceXml)
        ..stubPut('/system/services/byId/AdvanNetRestService', '<response/>');

      await _services(fake).update<AdvanNetRestService>(
        serviceId: 'AdvanNetRestService',
        fromXml: AdvanNetRestService.fromXml,
        mutator: (s) => s.copyWith(serveStatic: true),
      );

      expect(fake.calls[0].method, 'GET');
      expect(fake.calls[0].path, '/system/services/byId/AdvanNetRestService');
      expect(fake.calls[1].method, 'PUT');
      expect(fake.calls[1].path, '/system/services/byId/AdvanNetRestService');
    });

    test('returns the mutated service model', () async {
      final fake = FakeHttpTransport()
        ..stubGet('/system/services/byId/AdvanNetRestService', _restServiceXml)
        ..stubPut('/system/services/byId/AdvanNetRestService', '<response/>');

      final result = await _services(fake).update<AdvanNetRestService>(
        serviceId: 'AdvanNetRestService',
        fromXml: AdvanNetRestService.fromXml,
        mutator: (s) => s.copyWith(serveStatic: true),
      );

      expect(result.serveStatic, isTrue);
    });

    test('calls confAllSave when persist=true', () async {
      final fake = FakeHttpTransport()
        ..stubGet('/system/services/byId/AdvanNetRestService', _restServiceXml)
        ..stubPut('/system/services/byId/AdvanNetRestService', '<response/>')
        ..stubGet('/conf/save', '<response/>');

      await _services(fake).update<AdvanNetRestService>(
        serviceId: 'AdvanNetRestService',
        fromXml: AdvanNetRestService.fromXml,
        mutator: (s) => s,
        persist: true,
      );

      expect(fake.calls.any((c) => c.path == '/conf/save'), isTrue);
    });

    test('does not call confAllSave when persist=false (default)', () async {
      final fake = FakeHttpTransport()
        ..stubGet('/system/services/byId/AdvanNetRestService', _restServiceXml)
        ..stubPut('/system/services/byId/AdvanNetRestService', '<response/>');

      await _services(fake).update<AdvanNetRestService>(
        serviceId: 'AdvanNetRestService',
        fromXml: AdvanNetRestService.fromXml,
        mutator: (s) => s,
      );

      expect(fake.calls.any((c) => c.path == '/conf/save'), isFalse);
    });

    test('throws AdvanNetServerError when GET returns ErrorResponse', () async {
      final fake = FakeHttpTransport()
        ..stubGet(
          '/system/services/byId/AdvanNetRestService',
          '<response><error><code>NOT_FOUND</code></error></response>',
        );

      expect(
        () => _services(fake).update<AdvanNetRestService>(
          serviceId: 'AdvanNetRestService',
          fromXml: AdvanNetRestService.fromXml,
          mutator: (s) => s,
        ),
        throwsA(isA<AdvanNetServerError>()),
      );
    });

    test(
      'throws AdvanNetProtocolException when GET returns EntriesResponse',
      () async {
        final fake = FakeHttpTransport()
          ..stubGet(
            '/system/services/byId/AdvanNetRestService',
            '<response><entries><entry><class>X</class><def>y</def></entry></entries></response>',
          );

        expect(
          () => _services(fake).update<AdvanNetRestService>(
            serviceId: 'AdvanNetRestService',
            fromXml: AdvanNetRestService.fromXml,
            mutator: (s) => s,
          ),
          throwsA(isA<AdvanNetProtocolException>()),
        );
      },
    );
  });

  group('AdvanNetRestService', () {
    test('fromXml + serveStatic reads direct child element', () {
      final svc = AdvanNetRestService.fromXml(
        parseXml('<data><serveStatic>true</serveStatic></data>'),
      );
      expect(svc.serveStatic, isTrue);
    });

    test('fromXml + enabled defaults to true when element absent', () {
      final svc = AdvanNetRestService.fromXml(parseXml('<data></data>'));
      expect(svc.enabled, isTrue);
    });

    test('copyWith updates serveStatic', () {
      final original = AdvanNetRestService.fromXml(
        parseXml('<data><serveStatic>false</serveStatic></data>'),
      );
      final updated = original.copyWith(serveStatic: true);
      expect(updated.serveStatic, isTrue);
      expect(original.serveStatic, isFalse); // original unchanged
    });

    test('toXml returns the (possibly mutated) raw element', () {
      final svc = AdvanNetRestService.fromXml(
        parseXml('<data><serveStatic>false</serveStatic></data>'),
      );
      final updated = svc.copyWith(serveStatic: true);
      expect(updated.toXml().getElement('serveStatic')?.innerText, 'true');
    });

    test('serviceId is AdvanNetRestService', () {
      final svc = AdvanNetRestService.fromXml(parseXml('<data/>'));
      expect(svc.serviceId, 'AdvanNetRestService');
    });
  });

  group('AdvanNetMqttService', () {
    test('fromXml reads host and port', () {
      final svc = AdvanNetMqttService.fromXml(
        parseXml('<data><host>mqtt.example.com</host><port>1883</port></data>'),
      );
      expect(svc.host, 'mqtt.example.com');
      expect(svc.port, 1883);
    });

    test('enabled defaults to false when absent', () {
      expect(AdvanNetMqttService.fromXml(parseXml('<data/>')).enabled, isFalse);
    });

    test('port defaults to 1883 when absent', () {
      expect(AdvanNetMqttService.fromXml(parseXml('<data/>')).port, 1883);
    });

    test('copyWith updates host and topic', () {
      final original = AdvanNetMqttService.fromXml(
        parseXml('<data><host>old</host><topic>t1</topic></data>'),
      );
      final updated = original.copyWith(host: 'newhost', topic: 'rfid/reads');
      expect(updated.host, 'newhost');
      expect(updated.topic, 'rfid/reads');
      expect(original.host, 'old');
    });

    test('serviceId is AdvanNetMqttService', () {
      expect(
        AdvanNetMqttService.fromXml(parseXml('<data/>')).serviceId,
        'AdvanNetMqttService',
      );
    });
  });

  group('AdvanNetHttpNotifyService', () {
    test('fromXml reads url and method', () {
      final svc = AdvanNetHttpNotifyService.fromXml(
        parseXml(
          '<data><url>http://example.com</url><method>POST</method></data>',
        ),
      );
      expect(svc.url, 'http://example.com');
      expect(svc.method, 'POST');
    });

    test('method defaults to POST when absent', () {
      expect(
        AdvanNetHttpNotifyService.fromXml(parseXml('<data/>')).method,
        'POST',
      );
    });

    test('copyWith updates url', () {
      final original = AdvanNetHttpNotifyService.fromXml(
        parseXml('<data><url>http://old</url></data>'),
      );
      final updated = original.copyWith(url: 'http://new');
      expect(updated.url, 'http://new');
      expect(original.url, 'http://old');
    });

    test('serviceId is AdvanNetHttpService', () {
      expect(
        AdvanNetHttpNotifyService.fromXml(parseXml('<data/>')).serviceId,
        'AdvanNetHttpService',
      );
    });
  });

  group('AdvanNetCsvService', () {
    test('fromXml reads path and separator', () {
      final svc = AdvanNetCsvService.fromXml(
        parseXml(
          '<data><path>/data/rfid.csv</path><separator>;</separator></data>',
        ),
      );
      expect(svc.path, '/data/rfid.csv');
      expect(svc.separator, ';');
    });

    test('separator defaults to comma when absent', () {
      expect(AdvanNetCsvService.fromXml(parseXml('<data/>')).separator, ',');
    });

    test('copyWith updates path', () {
      final original = AdvanNetCsvService.fromXml(
        parseXml('<data><path>/old.csv</path></data>'),
      );
      final updated = original.copyWith(path: '/new.csv');
      expect(updated.path, '/new.csv');
      expect(original.path, '/old.csv');
    });

    test('serviceId is AdvanNetCsvService', () {
      expect(
        AdvanNetCsvService.fromXml(parseXml('<data/>')).serviceId,
        'AdvanNetCsvService',
      );
    });
  });
}
