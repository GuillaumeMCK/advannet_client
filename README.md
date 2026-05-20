# advannet_client

Dart client library for the [Keonn AdvanNet](https://keonn.com/software-product/advannet/) REST + realtime API.  
Supports AdvanReader, AdvanSafe, AdvanPay, and AdvanFlow devices.

## Installation

```yaml
dependencies:
  advannet_client: ^0.1.0
```

## Quick start

```dart
import 'package:advannet_client/advannet_client.dart';

final client = AdvanNet.connect(
  Uri.parse('http://192.168.1.100:3161'),
  credentials: AdvanNetCredentials.digest('admin', 'admin'),
);

// List connected readers
final devices = await client.devices.list();
print(devices.map((d) => '${d.id}  ${d.status}').join('\n'));

// Start a reader
await client.devices.start(devices.first.id);

// Stream tag reads in real time
client.realtime.tagReads().listen((e) {
  print('EPC ${e.hexEpc}  ant=${e.antennaPort}  rssi=${e.rssi}');
});

await client.close();
```

`AdvanNet.connect` returns immediately — no network I/O happens until you make a call.  
HTTP calls are serialized internally (the AdvanNet server is single-threaded).  
The realtime TCP connection (port 3177) starts lazily when you first call `updates()` or any filtered stream method such as `tagReads()`.

## Authentication

```dart
AdvanNetCredentials.none()                       // open device
AdvanNetCredentials.digest('admin', 'admin')     // HTTP Digest auth
```

Digest credentials are cached after the first challenge so subsequent calls
send the `Authorization` header proactively without an extra round-trip.

## Resources

| Accessor              | What it controls                                           |
|-----------------------|------------------------------------------------------------|
| `client.devices`      | list, lifecycle, RF params, modes, antennas, inventory, MCU |
| `client.gpio`         | GPO lines, GPI lines, sensors, buzzer, speaker             |
| `client.services`     | REST / MQTT / HTTP-notify / CSV service config             |
| `client.readModes`    | AsynchRead, ScanRead, EasRead config                       |
| `client.system`       | `confAllSave`, `reboot`, `factoryReset`                    |
| `client.systemInfo`   | system status, time, network, encoder setting              |
| `client.tags`         | tag read / write operations                                |
| `client.raw`          | direct GET/PUT returning `AdvanNetResponse`                |
| `client.realtime`     | real-time event stream over TCP port 3177                  |

## Realtime stream

The realtime stream delivers typed events for tag reads, alarms, GPI changes, sensor readings, and device lifecycle notifications.

```dart
// Switch to the recommended JSON encoding before connecting
await client.systemInfo.setRealtimeEncoder(RealtimeEncoder.jsonV3);

// Subscribe to all updates (events + connection status)
client.realtime.updates().listen((update) {
  switch (update) {
    case RealtimeStatusUpdate(:final status):
      print('[status] $status');
    case RealtimeEventUpdate(:final event):
      switch (event) {
        case TagReadEvent():
          print('TAG  ${event.hexEpc}  ant=${event.antennaPort}');
        case GpiEvent():
          print('GPI  line=${event.line}  ${event.lowToHigh ? "↑" : "↓"}');
        case AlarmEvent():
          print('ALARM  ${event.epc}  kind=${event.kind}');
        case MultiSensorEvent():
          for (final r in event.readings) print('${r.desc}: ${r.value} ${r.unit}');
        default:
          print('[${event.type}]');
      }
  }
});
```

Filtered helpers are also available: `tagReads()`, `alarms()`, `gpi()`, `tagDirections()`, `tagGenerics()`, `systemEvents()`, `unknown()`, `byType(String)`.

## Error handling

All exceptions extend `AdvanNetException`.

```dart
try {
  await client.devices.start('reader-01');
} on AdvanNetServerError catch (e) {
  print('${e.code}: ${e.serverMessage}');
} on AdvanNetAuthException {
  print('Check credentials');
} on AdvanNetException catch (e) {
  print('Error: $e');
}
```

| Exception                     | Cause                                        |
|-------------------------------|----------------------------------------------|
| `AdvanNetServerError`         | Device returned an error (`code`, `serverMessage`) |
| `AdvanNetAuthException`       | HTTP 401 / 403                               |
| `AdvanNetTransportException`  | Network / socket error                       |
| `AdvanNetProtocolException`   | Unexpected response shape                    |
| `AdvanNetDeviceBusyException` | Device is busy processing another command    |
| `AdvanNetUnsupportedException`| Operation not supported by this firmware     |

## Persisting configuration changes

Most PUT operations take effect immediately but are lost on reboot.  
Call `client.system.confAllSave()` after any change you want to survive a restart.

```dart
await client.devices.setActiveDeviceMode(deviceId, DeviceMode.autonomous);
await client.system.confAllSave();
```

## Testing

The library ships a testing companion in `advannet_client_testing.dart`:

```dart
import 'package:advannet_client/advannet_client_testing.dart';

final fake = FakeHttpTransport()
  ..stubGet('/devices', '<response><entries>'
      '<entry><class>ADRDevice</class><def>reader-01</def></entry>'
      '</entries></response>');

final raw     = RawResource(transport: fake, parser: const EnvelopeParser());
final devices = DevicesResource(raw: raw);

expect((await devices.list()).first.id, 'reader-01');
```

See [DOCS.md](DOCS.md) for the complete API reference.
