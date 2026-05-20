import 'package:advannet_client/advannet_client.dart';
import 'package:advannet_client/advannet_client_testing.dart';
import 'package:test/test.dart';
import 'package:xml/xml.dart';

const _parser = EnvelopeParser();

AdvanNetResponse _parse(String xml) =>
    _parser.parse(xml, method: HttpMethod.get, path: '/test');

void main() {
  group('EnvelopeParser', () {
    group('EmptyResponse', () {
      test('self-closing <response/>', () {
        expect(_parse('<response/>'), isA<EmptyResponse>());
      });

      test('empty <response></response>', () {
        expect(_parse('<response></response>'), isA<EmptyResponse>());
      });
    });

    group('EntriesResponse', () {
      test('single entry parses class and def', () {
        const xml = '''
<response>
  <entries>
    <entry>
      <class>ADRDevice</class>
      <def>device-001</def>
    </entry>
  </entries>
</response>''';
        final response = _parse(xml);
        expect(response, isA<EntriesResponse>());
        final entries = (response as EntriesResponse).entries;
        expect(entries, hasLength(1));
        expect(entries.first.className, 'ADRDevice');
        expect(entries.first.def, 'device-001');
      });

      test('multiple entries', () {
        const xml = '''
<response>
  <entries>
    <entry><class>ADRDevice</class><def>d1</def></entry>
    <entry><class>ADRDevice</class><def>d2</def></entry>
    <entry><class>ADRDevice</class><def>d3</def></entry>
  </entries>
</response>''';
        final entries = (_parse(xml) as EntriesResponse).entries;
        expect(entries, hasLength(3));
        expect(entries.map((e) => e.def), ['d1', 'd2', 'd3']);
      });

      test('entry with <conf> subtree preserves it', () {
        const xml = '''
<response>
  <entries>
    <entry>
      <class>ADRService</class>
      <def>svc1</def>
      <conf><enabled>true</enabled></conf>
    </entry>
  </entries>
</response>''';
        final entry = (_parse(xml) as EntriesResponse).entries.first;
        expect(entry.conf, isNotNull);
        expect(entry.conf!.getElement('enabled')?.innerText, 'true');
      });

      test('entry defFields splits comma-separated values', () {
        const xml = '''
<response>
  <entries>
    <entry><class>X</class><def>a,b,c</def></entry>
  </entries>
</response>''';
        final entry = (_parse(xml) as EntriesResponse).entries.first;
        expect(entry.defFields, ['a', 'b', 'c']);
      });

      test('unwrapped <entries> as root element', () {
        const xml =
            '<entries><entry><class>X</class><def>y</def></entry></entries>';
        final response = _parse(xml);
        expect(response, isA<EntriesResponse>());
        expect((response as EntriesResponse).entries.first.className, 'X');
      });
    });

    group('DataResponse', () {
      test('parses <data> child', () {
        const xml = '''
<response>
  <data>
    <serviceId>42</serviceId>
  </data>
</response>''';
        final response = _parse(xml);
        expect(response, isA<DataResponse>());
        expect(
          (response as DataResponse).data.getElement('serviceId')?.innerText,
          '42',
        );
      });

      test('unwrapped <data> as root', () {
        const xml = '<data><key>val</key></data>';
        expect(_parse(xml), isA<DataResponse>());
      });
    });

    group('ErrorResponse', () {
      test('parses code and message from <error> child', () {
        const xml = '''
<response>
  <error>
    <code>DEVICE_BUSY</code>
    <message>Device is currently reading</message>
  </error>
</response>''';
        final response = _parse(xml);
        expect(response, isA<ErrorResponse>());
        final err = response as ErrorResponse;
        expect(err.code, 'DEVICE_BUSY');
        expect(err.message, 'Device is currently reading');
      });

      test('message is null when absent', () {
        const xml = '<response><error><code>UNKNOWN</code></error></response>';
        final err = _parse(xml) as ErrorResponse;
        expect(err.code, 'UNKNOWN');
        expect(err.message, isNull);
      });

      test('new-style status=ERROR with <op> and <msg>', () {
        const xml = '''
<response>
  <type>response</type>
  <ts>1748217600000</ts>
  <status>ERROR</status>
  <op>info</op>
  <msg>UNKNOWN_OPERATION: Operation [info] unknown.</msg>
</response>''';
        final err = _parse(xml) as ErrorResponse;
        expect(err.code, 'info');
        expect(err.message, 'UNKNOWN_OPERATION: Operation [info] unknown.');
      });
    });

    group('DataResponse with extra siblings in <response>', () {
      test('ignores <type>/<ts> siblings and returns <data>', () {
        const xml = '''
<response>
  <type>response</type>
  <ts>1748217600000</ts>
  <status>OK</status>
  <op>devices</op>
  <data><devices/></data>
</response>''';
        expect(_parse(xml), isA<DataResponse>());
      });
    });

    group('error handling', () {
      test('malformed XML throws AdvanNetProtocolException', () {
        expect(
          () => _parse('<not valid xml'),
          throwsA(isA<AdvanNetProtocolException>()),
        );
      });

      test('AdvanNetProtocolException carries method and path', () {
        try {
          _parse('<bad');
          fail('expected exception');
        } on AdvanNetProtocolException catch (e) {
          expect(e.method, HttpMethod.get);
          expect(e.path, '/test');
        }
      });
    });
  });

  group('EnvelopeParser — non-exported class is const-constructible', () {
    test('two EnvelopeParser instances behave identically', () {
      const p1 = EnvelopeParser();
      const p2 = EnvelopeParser();
      final r1 = p1.parse('<response/>', method: HttpMethod.get, path: '/a');
      final r2 = p2.parse('<response/>', method: HttpMethod.get, path: '/a');
      expect(r1, isA<EmptyResponse>());
      expect(r2, isA<EmptyResponse>());
    });
  });
}
