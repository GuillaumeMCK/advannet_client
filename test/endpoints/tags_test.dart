import 'package:advannet_client/advannet_client.dart';
import 'package:advannet_client/advannet_client_testing.dart';
import 'package:test/test.dart';

RawResource _raw(FakeHttpTransport fake) =>
    RawResource(transport: fake, parser: const EnvelopeParser());

TagsResource _tags(FakeHttpTransport fake) => TagsResource(raw: _raw(fake));

void main() {
  group('TagsResource.list()', () {
    test('calls GET /devices/{id}/tags', () async {
      final fake = FakeHttpTransport()
        ..stubGet('/devices/r1/tags', '<response/>');
      await _tags(fake).list('r1');
      expect(fake.calls.single.path, '/devices/r1/tags');
      expect(fake.calls.single.method, 'GET');
    });

    test('returns EPCs from entries response', () async {
      final fake = FakeHttpTransport()
        ..stubGet('/devices/r1/tags', '''
<response>
  <entries>
    <entry>
      <class>TagRecord</class>
      <def>E200001659190060,1706265600000</def>
    </entry>
  </entries>
</response>''');
      final tags = await _tags(fake).list('r1');
      expect(tags, ['E200001659190060']);
    });

    test('returns empty list when cache is empty', () async {
      final fake = FakeHttpTransport()
        ..stubGet('/devices/r1/tags', '<response/>');
      expect(await _tags(fake).list('r1'), isEmpty);
    });

    test('throws AdvanNetServerError on ErrorResponse', () async {
      final fake = FakeHttpTransport()
        ..stubGet(
          '/devices/r1/tags',
          '<response><error><code>DEVICE_ERROR</code></error></response>',
        );
      expect(() => _tags(fake).list('r1'), throwsA(isA<AdvanNetServerError>()));
    });
  });

  group('TagsResource.clear()', () {
    test('calls GET /devices/{id}/tags/clear', () async {
      final fake = FakeHttpTransport()
        ..stubGet('/devices/r1/tags/clear', '<response/>');
      await _tags(fake).clear('r1');
      expect(fake.calls.single.path, '/devices/r1/tags/clear');
      expect(fake.calls.single.method, 'GET');
    });

    test('returns void on success', () async {
      final fake = FakeHttpTransport()
        ..stubGet('/devices/r1/tags/clear', '<response/>');
      await expectLater(_tags(fake).clear('r1'), completes);
    });

    test('throws AdvanNetServerError on ErrorResponse', () async {
      final fake = FakeHttpTransport()
        ..stubGet(
          '/devices/r1/tags/clear',
          '<response><error><code>BUSY</code></error></response>',
        );
      expect(
        () => _tags(fake).clear('r1'),
        throwsA(isA<AdvanNetServerError>()),
      );
    });
  });

  group('TagsResource.count()', () {
    test('calls GET /devices/{id}/tags/count', () async {
      final fake = FakeHttpTransport()
        ..stubGet('/devices/r1/tags/count', '<data><count>42</count></data>');
      await _tags(fake).count('r1');
      expect(fake.calls.single.path, '/devices/r1/tags/count');
    });

    test('returns parsed integer count', () async {
      final fake = FakeHttpTransport()
        ..stubGet('/devices/r1/tags/count', '<data><count>7</count></data>');
      expect(await _tags(fake).count('r1'), 7);
    });

    test('returns 0 on EmptyResponse', () async {
      final fake = FakeHttpTransport()
        ..stubGet('/devices/r1/tags/count', '<response/>');
      expect(await _tags(fake).count('r1'), 0);
    });
  });
}
