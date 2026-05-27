# advannet_client — API Reference

Complete reference for `advannet_client`. For installation and quick-start see [README.md](README.md).

---

## Table of contents

- [Client](#client)
- [Devices](#devices)
  - [List and lifecycle](#list-and-lifecycle)
  - [RF parameters](#rf-parameters)
  - [Device modes](#device-modes)
  - [Antennas](#antennas)
  - [Inventory](#inventory)
  - [GPI trigger](#gpi-trigger)
  - [MCU / time](#mcu--time)
- [GPIO](#gpio)
  - [GPO outputs](#gpo-outputs)
  - [GPI inputs](#gpi-inputs)
  - [Sensors](#sensors)
  - [Buzzer and speaker](#buzzer-and-speaker)
- [Services](#services)
- [Read modes](#read-modes)
- [System info](#system-info)
- [System actions](#system-actions)
- [Tags](#tags)
- [Raw access](#raw-access)
- [Realtime stream](#realtime-stream)
  - [Encoding](#encoding)
  - [Connection lifecycle](#connection-lifecycle)
  - [Events reference](#events-reference)
  - [Filtered streams](#filtered-streams)
- [Response types](#response-types)
- [Error handling](#error-handling)
- [Testing](#testing)

---

## Client

```dart
final client = AdvanNet.connect(
  Uri.parse('http://192.168.1.100:3161'),
  credentials: AdvanNetCredentials.digest('admin', 'admin'),
  requestTimeout: const Duration(seconds: 10),  // default
  realtimePort: 3177,                            // default
);

await client.close();  // closes the TCP realtime connection
```

`AdvanNet.connect` does not open any connection. All HTTP calls are serialized through an internal mutex — the AdvanNet HTTP server is single-threaded and rejects concurrent requests.

**Credentials**

```dart
AdvanNetCredentials.none()                   // open device
AdvanNetCredentials.digest('user', 'pass')   // HTTP Digest auth
```

Digest auth caches the nonce after the first 401 challenge. Subsequent requests send the `Authorization` header proactively.

---

## Devices

`client.devices` — `DevicesResource`

### List and lifecycle

```dart
List<AdvanNetDevice> devices = await client.devices.list();
```

**`AdvanNetDevice` fields**

| Field              | Type             | Description                                   |
|--------------------|------------------|-----------------------------------------------|
| `id`               | `String`         | Device identifier, e.g. `"AdvanReader-m4-160"` |
| `ip`               | `String?`        | IP address                                    |
| `mac`              | `String?`        | MAC address                                   |
| `serial`           | `String?`        | Serial number                                 |
| `family`           | `DeviceFamily?`  | `advanReader`, `advanSafe`, `advanPay`, `advanFlow` |
| `status`           | `DeviceStatus?`  | See below                                     |
| `isAlive`          | `bool?`          | Whether the device is reachable               |
| `activeDeviceMode` | `String?`        | Active device mode name, e.g. `"Autonomous"`  |
| `activeReadMode`   | `String?`        | Active read mode name, e.g. `"AUTONOMOUS"`    |
| `lastSeen`         | `String?`        | Last-seen timestamp (device-local format)     |

**`DeviceStatus` values**

`running` · `stopped` · `connected` · `shutdown` · `error` · `commLost` · `commError` · `commRecovering` · `unknown`

```dart
device.status?.isActive   // true when running or connected
device.status?.isRfOn     // true only when running
```

**Lifecycle methods**

```dart
await client.devices.connect(deviceId);   // SHUTDOWN → STOPPED/CONNECTED
await client.devices.shutdown(deviceId);  // STOPPED/CONNECTED → SHUTDOWN
await client.devices.start(deviceId);     // STOPPED → RUNNING (RF on)
await client.devices.stop(deviceId);      // RUNNING → STOPPED (RF off)
```

### RF parameters

```dart
// Returns all current RF parameters as a name→value map
Map<String, String> params = await client.devices.getReaderParams(deviceId);
// e.g. {"RF_READ_POWER": "31.5", "GEN2_SESSION": "0", ...}

// Extended parameter set (more fields than getReaderParams)
Map<String, String> all = await client.devices.getAllReaderParams(deviceId);

// Set a single parameter using the ReaderParam enum
await client.devices.setReaderParam(deviceId, ReaderParam.rfReadPower, '20');
await client.devices.setReaderParam(deviceId, ReaderParam.rfSensitivity, '-70');
await client.devices.setReaderParam(deviceId, ReaderParam.gen2Session, '0');
```

**`ReaderParam` enum** (selected values)

| Enum value           | Wire name             | Read-only |
|----------------------|-----------------------|-----------|
| `rfReadPower`        | `RF_READ_POWER`       |           |
| `rfWritePower`       | `RF_WRITE_POWER`      |           |
| `rfSensitivity`      | `RF_SENSITIVITY`      |           |
| `rfRegion`           | `RF_REGION`           |           |
| `rfAsynchOntime`     | `RF_ASYNCH_ONTIME`    |           |
| `rfAsynchOfftime`    | `RF_ASYNCH_OFFTIME`   |           |
| `rfHopTable`         | `RF_HOP_TABLE`        |           |
| `rfFixedAntennaTime` | `RF_FIXED_ANTENNA_TIME` |         |
| `gen2Session`        | `GEN2_SESSION`        |           |
| `gen2Target`         | `GEN2_TARGET`         |           |
| `gen2Q`              | `GEN2_Q`              |           |
| `gen2Encoding`       | `GEN2_ENCODING`       |           |
| `gen2Blf`            | `GEN2_BLF`            |           |
| `invAntennas`        | `INV_ANTENNAS`        |           |
| `rfPowerMin`         | `RF_POWER_MIN`        | yes       |
| `rfPowerMax`         | `RF_POWER_MAX`        | yes       |
| `rfPortNumber`       | `RF_PORT_NUMBER`      | yes       |
| `rfFreqTable`        | `RF_FREQ_TABLE`       | yes       |
| `dataGpioNumber`     | `DATA_GPIO_NUMBER`    | yes       |
| `dataGpoNumber`      | `DATA_GPO_NUMBER`     | yes       |
| `dataGpiNumber`      | `DATA_GPI_NUMBER`     | yes       |

### Device modes

```dart
// Available device modes on this device
List<String> modes = await client.devices.getDeviceModes(deviceId);
// e.g. ["Autonomous", "Sequential", "EPC_EAS_ALARM"]

// Currently active modes
String? readMode   = await client.devices.getActiveReadMode(deviceId);
String? deviceMode = await client.devices.getActiveDeviceMode(deviceId);

// Change the active device mode (stop device first; call confAllSave to persist)
await client.devices.setActiveDeviceMode(deviceId, DeviceMode.autonomous);
await client.devices.setActiveReadMode(deviceId, 'AUTONOMOUS');
await client.system.confAllSave();
```

**`DeviceMode` enum**

| Value                | Wire id             | Description                                  |
|----------------------|---------------------|----------------------------------------------|
| `autonomous`         | `Autonomous`        | Continuous reading                           |
| `fastMultiplexing`   | `FAST_MULTIPLEXING` | Autonomous with AdvanMux/AdvanPhaser support |
| `sequential`         | `Sequential`        | Sequential antenna cycling                   |
| `epcEasAlarm`        | `EPC_EAS_ALARM`     | EAS alarm on EPC pattern match               |
| `epcEasDisable`      | `EPC_EAS_DISABLE`   | Disable EAS bit on every read tag            |
| `epcEasEnable`       | `EPC_EAS_ENABLE`    | Enable EAS bit on every read tag             |
| `nxpEasAlarm`        | `NXP_EAS_ALARM`     | EAS alarm using NXP EAS bit                  |
| `nxpEasDisable`      | `NXP_EAS_DISABLE`   | Disable NXP EAS bit                          |
| `nxpEasEnable`       | `NXP_EAS_ENABLE`    | Enable NXP EAS bit                           |
| `sqlEasAlarm`        | `SQL_EAS_ALARM`     | EAS alarm backed by SQL EPC lookup           |
| `epcBulkEasAlarm`    | `EPCBULK_EAS_ALARM` | Bulk EAS alarm (multiple simultaneous tags)  |
| `advanPay`           | `AdvanPay`          | Payment mode                                 |

### Antennas

```dart
List<AntennaDefinition> antennas = await client.devices.getAntennas(deviceId);

// AntennaDefinition fields
antenna.deviceId    // reader device id
antenna.board       // board index (0-based)
antenna.port        // physical port (0-based)
antenna.mux         // multiplexer index
antenna.subMux      // sub-multiplexer index
antenna.orientation // AntennaOrientation enum
antenna.loc         // location label, e.g. "antenna1"
antenna.x           // position in mm
antenna.y
antenna.z

// Parse and serialise the 9-field CSV def
String csv = antenna.toDef();                        // "deviceId,1,0,0,0,antenna1,100,0,0"
AntennaDefinition a = AntennaDefinition.fromDef(csv);

// Replace all antennas (stop device first; persist with confAllSave)
await client.devices.setAntennas(deviceId, antennas);
await client.system.confAllSave();
```

### Inventory

```dart
// Current RFID tag inventory — returns the raw <data> XML element
XmlElement? inv = await client.devices.getInventory(deviceId);

// Inventory with location data
XmlElement? loc = await client.devices.getLocation(deviceId);
```

### GPI trigger

Configures which GPI line edges start RF reading and for how long.

```dart
// Read current trigger config (returns JSON string or null)
String? config = await client.devices.getGpiTrigger(deviceId);

// Set trigger: start antennas 1&2 on GPI#1 rise, antenna 2 on GPI#2, active 15 s
await client.devices.setGpiTrigger(deviceId, '{'
    '"onTime":15000,'
    '"trigger":['
      '{"gpi":1,"conf":{"antennas":"1,2"}},'
      '{"gpi":2,"conf":{"antennas":"2"}}'
    ']}');

// Clear trigger
await client.devices.setGpiTrigger(deviceId, '{}');
```

### MCU / time

```dart
String? dt = await client.devices.getDatetime(deviceId);  // ISO-8601
await client.devices.setDatetime(deviceId, '2024-01-26T12:00:00Z');

List<String> tzList = await client.devices.getTimezoneList(deviceId);
await client.devices.setTimezone(deviceId, 'Europe/Paris');
```

---

## GPIO

`client.gpio` — `GpioResource`

### GPO outputs

```dart
// Read all GPO line states — {lineNumber: active}
Map<int, bool> state = await client.gpio.getOutputs(deviceId);

// Set a single GPO line (GET /devices/{id}/setGPO/{gpo}/{state})
await client.gpio.setOutput(deviceId, 1, active: true);

// Set multiple GPO lines
await client.gpio.setOutputs(deviceId, {1: true, 2: false});
```

Two named constants are defined for special GPO lines:

```dart
GpioResource.relayOutput          // 9 — OMRON relay (24 VDC / 0.5 A)
GpioResource.powerSupply5VOutput  // 10 — 5 V external supply pin (200 mA)
```

### GPI inputs

```dart
// All GPI line states from /devices/{id}/gpioAll — {lineNumber: active}
Map<int, bool> inputs = await client.gpio.getInputs(deviceId);

// All GPI line states from /devices/{id}/getGPIAll (separate endpoint)
Map<int, bool> all = await client.gpio.getGPIAll(deviceId);

// Single GPI line (1-based)
bool active = await client.gpio.getGPILine(deviceId, 1);
```

### Sensors

```dart
// Structured sensor readings (from /devices/{id}/gpioAllJSON)
List<SensorReading> readings = await client.gpio.getSensors(deviceId);
// SensorReading.line, .desc, .unit, .value

// Raw sensor readings by key (from PUT /devices/{id}/sensorAll)
Map<String, double> raw = await client.gpio.getSensorReadings(deviceId);
// e.g. {"SENSOR_POE_VOLTAGE": -12.27, "SENSOR_CONSUMPTION": 3.76}

// Single sensor by integer ID (from PUT /devices/{id}/sensor/{id})
double? value = await client.gpio.getSensorReading(deviceId, 0);
```

### Buzzer and speaker

```dart
await client.gpio.activateBuzzer(
  deviceId,
  timeOnMs: 500,          // beep duration (default 500)
  timeOffMs: 100,         // pause between beeps (default 100)
  totalDurationMs: 500,   // total buzz duration (default 500)
);

await client.gpio.activateSpeaker(
  deviceId,
  frequencyHz: 1000,      // 1000–5000 in steps of 500 (default 1000)
  volume: 10,             // 1–10 (default 10)
  timeOnMs: 500,          // tone duration (default 500)
  timeOffMs: 0,           // silent pause (default 0)
  totalDurationMs: 500,   // total playback duration (default 500)
);
```

---

## Services

`client.services` — `ServicesResource`

```dart
// List of service IDs in registration order
List<String> ids = await client.services.listIds();

// Enabled status per index (index matches listIds order)
Map<int, bool> statuses = await client.services.getStatuses();

// Raw XML access
AdvanNetResponse xml = await client.services.getById('AdvanNetRestService');
await client.services.putById('AdvanNetRestService', xmlElement);

// High-level typed round-trip: GET → mutate → PUT
await client.services.update<AdvanNetRestService>(
  serviceId: 'AdvanNetRestService',
  fromXml: AdvanNetRestService.fromXml,
  mutator: (s) => s.copyWith(serveStatic: true, enabled: true),
  persist: true,   // calls confAllSave
  reboot: false,   // calls reboot after confAllSave
);
```

**Service types and their fields**

`AdvanNetRestService` — HTTP server on port 3161

| Field         | Type   | Description                      |
|---------------|--------|----------------------------------|
| `enabled`     | `bool` | Service enabled                  |
| `serveStatic` | `bool` | Serve web UI static files        |

`AdvanNetMqttService` — MQTT tag-event publisher

| Field      | Type      | Description               |
|------------|-----------|---------------------------|
| `enabled`  | `bool`    |                           |
| `host`     | `String`  | MQTT broker hostname      |
| `port`     | `int`     | Default 1883              |
| `topic`    | `String`  | Publish topic             |
| `username` | `String?` |                           |
| `password` | `String?` |                           |

`AdvanNetHttpNotifyService` — HTTP POST on tag events

| Field     | Type     | Description               |
|-----------|----------|---------------------------|
| `enabled` | `bool`   |                           |
| `url`     | `String` | Endpoint to POST to       |
| `method`  | `String` | Default `"POST"`          |

`AdvanNetCsvService` — CSV file logging

| Field       | Type     | Description               |
|-------------|----------|---------------------------|
| `enabled`   | `bool`   |                           |
| `path`      | `String` | File path on device       |
| `separator` | `String` | Default `","`             |

All service models follow the same pattern: `fromXml(XmlElement)` to parse, `copyWith(...)` to mutate immutably, `toXml()` to serialise back. Unknown XML fields are preserved transparently.

---

## Read modes

`client.readModes` — `ReadModesResource`

```dart
// Active read mode ID
String activeId = await client.readModes.getActive();
// e.g. "AdvanNetAsyncRead"

await client.readModes.setActive('AdvanNetScanRead');

// Raw XML access
AdvanNetResponse xml = await client.readModes.getById('AdvanNetAsyncRead');
await client.readModes.putById('AdvanNetAsyncRead', xmlElement);

// High-level typed round-trip: GET → mutate → PUT
await client.readModes.update<AsynchReadMode>(
  modeId: 'AdvanNetAsyncRead',
  fromXml: AsynchReadMode.fromXml,
  mutator: (m) => m.copyWith(eventsTTL: 500, direction: true),
  persist: true,
);
```

**`AsynchReadMode`** — `GET /system/readmodes/byId/AdvanNetAsyncRead`

Continuous reading mode. Pushes `TAG_READ`, `TAG_DIRECTION`, and optional `TAG_GENERIC` events to the realtime stream.

| Field          | Type   | Description                                               |
|----------------|--------|-----------------------------------------------------------|
| `enabled`      | `bool` |                                                           |
| `eventsTTL`    | `int`  | Min ms before same EPC is re-reported (0 = no dedup)     |
| `direction`    | `bool` | Emit `TAG_DIRECTION` events                               |
| `customEvent`  | `bool` | Emit `TAG_GENERIC` events                                 |
| `customEvent2` | `bool` | Emit `TAG_GENERIC_2` events                               |

**`ScanReadMode`** — `GET /system/readmodes/byId/AdvanNetScanRead`

Periodic inventory scan. Pushes batched `<inventory>` results.

| Field      | Type   | Description                             |
|------------|--------|-----------------------------------------|
| `enabled`  | `bool` |                                         |
| `period`   | `int`  | Scan interval in milliseconds           |
| `dynamicQ` | `bool` | Dynamic Q algorithm for inventory tuning|

**`EasReadMode`** — `GET /system/readmodes/byId/AdvanNetEasRead`

EAS alarm mode. Pushes `TAG_ALARM` events.

| Field            | Type   | Description                             |
|------------------|--------|-----------------------------------------|
| `enabled`        | `bool` |                                         |
| `perAntennaAlarm`| `bool` | Emit `TAG_ALARM_ANTENNA_N` events       |
| `alarmTTL`       | `int`  | Alarm debounce in milliseconds          |

---

## System info

`client.systemInfo` — `SystemInfoResource`

```dart
// Overall system status (version, running devices, etc.)
SystemStatus? status = await client.systemInfo.getStatus();
```

**`SystemStatus` fields**

| Field              | Type          | Description                          |
|--------------------|---------------|--------------------------------------|
| `deviceId`         | `String`      | Primary device identifier            |
| `ip`               | `String?`     | IP address                           |
| `mac`              | `String?`     | MAC address                          |
| `serial`           | `String?`     | Serial number                        |
| `family`           | `DeviceFamily?` |                                    |
| `status`           | `DeviceStatus?` |                                    |
| `advannetVersion`  | `String?`     | Firmware version, e.g. `"2.10.33-20260317_1530"` |
| `firmwareVersion`  | `String?`     | RF firmware version                  |
| `activeDeviceMode` | `String?`     |                                      |
| `activeReadMode`   | `String?`     |                                      |
| `uptime`           | `String?`     | Uptime string                        |

```dart
// System time (returns millisecond epoch as a string)
String? epochMs = await client.systemInfo.getTime();

// Set system time
await client.systemInfo.setTime(DateTime.now().millisecondsSinceEpoch);

// Set any named system parameter
await client.systemInfo.setParameter('SOME_PARAM', 'value');

// Set the TCP 3177 realtime frame encoding
await client.systemInfo.setRealtimeEncoder(RealtimeEncoder.jsonV3);
```

**`RealtimeEncoder` values**

| Value     | Wire value  | Description                              |
|-----------|-------------|------------------------------------------|
| `xmlV23`  | `XML_V2_3`  | Default. Full XML with all fields        |
| `jsonV2`  | `JSONV2`    | JSON with extended tag-read fields       |
| `jsonV3`  | `JSONV3`    | JSON with compact tag-read frames        |

Call `setRealtimeEncoder` before subscribing to `updates()` — the TCP connection starts lazily, so the first connection uses the new encoding.

---

## System actions

`client.system` — `SystemResource`

```dart
await client.system.confAllSave();   // persist config to non-volatile storage
await client.system.reboot();        // reboot the AdvanNet controller
await client.system.factoryReset();  // restore factory defaults (irreversible)
```

Call `confAllSave()` after any configuration change you want to survive a reboot.

---

## Tags

`client.tags` — `TagsResource`

Low-level tag memory access. Returns raw `AdvanNetResponse` for you to parse.

```dart
AdvanNetResponse r = await client.tags.read(deviceId, epc: 'E2003411B802011816460000');
```

---

## Raw access

`client.raw` — `RawResource`

Bypass the typed resources and issue arbitrary GET/PUT calls.

```dart
AdvanNetResponse r = await client.raw.get('/some/path');
AdvanNetResponse r = await client.raw.put('/some/path', bodyString: 'value');
AdvanNetResponse r = await client.raw.put('/some/path', body: xmlElement);
```

---

## Realtime stream

`client.realtime` — `RealtimeStream`

Connects to TCP port 3177 and decodes frames into typed `RealtimeEvent` objects.

Call `connect()` to open the TCP socket immediately, or let it open on first use when you subscribe to `updates()` or a filtered stream.

```dart
// Option A — eager (connection starts now, before any listener)
client.realtime.connect();

// Option B — on first subscription (default)
client.realtime.tagReads().listen(...);
```

On disconnect the driver automatically retries with a linear ramp:  
1 s → 2 s → 3 s → 4 s → 5 s → 5 s → … (capped at 5 s, deterministic — no jitter).

### Encoding

By default the device sends XML frames. Switch to JSONV3 (recommended) for more compact frames:

```dart
await client.systemInfo.setRealtimeEncoder(RealtimeEncoder.jsonV3);
// Then subscribe — first TCP connection uses JSONV3
client.realtime.updates().listen(...);
```

### Connection lifecycle

`updates()` returns a `Stream<RealtimeUpdate>` that carries both connection status changes and decoded events.

```dart
client.realtime.updates().listen((update) {
  switch (update) {
    case RealtimeStatusUpdate(:final status):
      // connection state changed
    case RealtimeEventUpdate(:final event):
      // decoded event arrived
  }
});
```

**`RealtimeStatus` subtypes**

| Subtype       | Fields                         | Meaning                        |
|---------------|--------------------------------|--------------------------------|
| `Connecting`  | —                              | Opening TCP socket             |
| `Connected`   | —                              | Socket open, frames flowing    |
| `Disconnected`| `reason`                       | Closed by `close()`            |
| `Reconnecting`| `attempt`, `nextDelay`         | Auto-reconnect in progress     |
| `FrameError`  | `cause`, `bytes`               | Malformed frame (non-fatal)    |
| `DecodeError` | `cause`, `message`             | Event parse failed (non-fatal) |

### Events reference

All events extend `RealtimeEvent` and share these base fields:

| Field        | Type        | Description                         |
|--------------|-------------|-------------------------------------|
| `type`       | `String`    | Raw event type string               |
| `deviceId`   | `String`    | Source device identifier            |
| `receivedAt` | `DateTime`  | Local time the frame was received   |
| `serverTs`   | `DateTime?` | Device timestamp (when present)     |

---

**`TagReadEvent`** — emitted in AsynchRead mode for each tag read

```dart
event.epc           // "E2003411B802011816460000" — EPC bytes as hex
event.hexEpc        // same value (JSON mode) or normalised hex (XML mode)
event.tid           // TID memory bank bytes, if the reader was configured to read it
event.antennaPort   // int? — 1-based port number
event.rssi          // int? — signal strength in dBm
event.rfPhase       // int?
event.mux1          // int? — multiplexer port 1
event.mux2          // int? — multiplexer port 2
event.freqKHz       // int? — read frequency
event.gpiSnapshot   // List<int>? — GPI line states at read time
event.location      // LocationData? — x/y/z position (mm)
event.raw           // Map<String, String> — all raw key-value pairs from the frame
```

---

**`TagDirectionEvent`** — emitted when tag movement direction is detected (AsynchRead with `direction: true`)

```dart
event.epc           // String
event.direction     // String? — e.g. "IN", "OUT"
event.antennaPort   // int?
event.raw           // Map<String, String>
```

---

**`TagGenericEvent`** — custom application event (AsynchRead with `customEvent` or `customEvent2` enabled)

```dart
event.epc              // String
event.customEventName  // "customEvent" or "customEvent2"
event.raw              // Map<String, String>
```

---

**`AlarmEvent`** — EAS alarm triggered (EasRead mode)

```dart
event.epc         // String
event.tid         // String? — TID memory bank if available
event.kind        // AlarmKind — see below
event.antennaPort // int? — present when kind == perAntenna
event.alarmType   // AlarmType — see below
event.raw         // Map<String, String>
```

**`AlarmKind`** values: `global`, `perAntenna`, `enabled`, `disabled`

**`AlarmType`** values: `epcEas`, `nxpEas`, `epcBulkEas`, `unknown`

---

**`GpiEvent`** — digital input state transition

```dart
event.line       // int — 1-based GPI line number
event.lowToHigh  // bool — true = LOW→HIGH transition
event.duration   // int? — ms the line was in the previous state (JSON mode only)
event.raw        // Map<String, String>
```

---

**`MultiSensorEvent`** — periodic power/voltage/temperature sensor readings

```dart
event.readings   // List<SensorReading>
// SensorReading fields:
reading.line     // int — feature index (1-based)
reading.desc     // String — e.g. "PoE Voltage", "Consumption"
reading.unit     // String — e.g. "V", "W", "C"
reading.value    // double
```

---

**`SystemInfoEvent`** — system-level heartbeat (`ADVANNET_INFO`)

```dart
event.message     // String — e.g. "RUNNING"
event.advanNetId  // String
event.raw         // Map<String, String>
```

---

**`DeviceConnectedEvent`** — device appeared on the network (`ADVANNET_DEVICE_CONNECTED`, `DEVICE_START`)

```dart
event.advanNetId  // String
event.raw         // Map<String, String>
```

---

**`DeviceDisconnectedEvent`** — device left the network (`ADVANNET_DEVICE_DISCONNECTED`, `DEVICE_STOP`)

```dart
event.advanNetId  // String
event.raw         // Map<String, String>
```

---

**`ReadModeChangeEvent`** — active read mode changed on the device (`DEVICE_READMODE_CHANGE`)

```dart
event.readMode  // String? — new read mode name
event.raw       // Map<String, String>
```

---

**`DeviceWarnEvent`** — device-level warning or informational message (`DEVICE_WARN`, `DEVICE_INFO`)

```dart
event.message  // String? — human-readable message
event.raw      // Map<String, String>
```

---

**`ErrorEventMessage`** — server-side error notification

```dart
event.code     // String?
event.message  // String?
event.raw      // Map<String, String>
```

---

**`UnknownEvent`** — frame type not recognised by the library

```dart
event.type  // String — raw type string
event.raw   // Map<String, String> — all raw fields
```

Inspect `event.type` and `event.raw` and open an issue if you see one of these in production.

---

### Filtered streams

All helpers wrap `updates()` and apply a type filter. They connect to the same underlying TCP stream.

```dart
Stream<TagReadEvent>      client.realtime.tagReads()
Stream<TagDirectionEvent> client.realtime.tagDirections()
Stream<TagGenericEvent>   client.realtime.tagGenerics({String? name})
Stream<AlarmEvent>        client.realtime.alarms({AlarmKind? kind, int? antennaPort})
Stream<GpiEvent>          client.realtime.gpi({int? line, bool? lowToHigh})
Stream<RealtimeEvent>     client.realtime.systemEvents()   // SystemInfo + Connected + Disconnected
Stream<UnknownEvent>      client.realtime.unknown()
Stream<RealtimeEvent>     client.realtime.byType(String type)
```

---

## Response types

`RawResource.get/put` and a few endpoints return the sealed `AdvanNetResponse` class directly.

```dart
switch (response) {
  case DataResponse(:final data):
    // data is XmlElement — the <data> payload
    final value = data.getElement('field')?.innerText.trim();

  case EntriesResponse(:final entries):
    // entries is List<Entry>
    for (final e in entries) {
      print('${e.className}: ${e.def}');
      // e.defFields splits the def CSV into a List<String>
    }

  case EmptyResponse():
    // HTTP 200 with no body, or <response><status>OK</status></response>

  case ErrorResponse(:final code, :final message):
    // Device returned an error
    throw Exception('$code: $message');
}
```

---

## Error handling

All exceptions extend `AdvanNetException` and carry `method`, `path`, and `message`.

| Exception                      | When                                            |
|--------------------------------|-------------------------------------------------|
| `AdvanNetServerError`          | Device responded with an error status — check `code` and `serverMessage` |
| `AdvanNetAuthException`        | HTTP 401 or 403                                 |
| `AdvanNetTransportException`   | Socket / network error — check `cause`          |
| `AdvanNetProtocolException`    | Response did not match the expected shape       |
| `AdvanNetDeviceBusyException`  | Device rejected the call as busy                |
| `AdvanNetUnsupportedException` | Firmware does not support this operation        |

```dart
try {
  await client.devices.start('reader-01');
} on AdvanNetServerError catch (e) {
  print('${e.code}: ${e.serverMessage}');
} on AdvanNetAuthException {
  print('Check --user / --pass');
} on AdvanNetTransportException catch (e) {
  print('Network error: ${e.cause}');
} on AdvanNetException catch (e) {
  print('$e');
}
```

---

## Testing

The testing companion exposes `FakeHttpTransport` and the internal `EventDecoder` for unit tests without a real device.

```yaml
dev_dependencies:
  advannet_client: { path: . }   # or the published package
```

```dart
import 'package:advannet_client/advannet_client_testing.dart';
```

**`FakeHttpTransport`** — stub GET and PUT responses

```dart
final fake = FakeHttpTransport()
  ..stubGet('/devices', '''
      <response><entries>
        <entry><class>ADRDevice</class><def>reader-01</def></entry>
      </entries></response>''')
  ..stubPut('/devices/reader-01/start', '<response/>');

final raw     = RawResource(transport: fake, parser: const EnvelopeParser());
final devices = DevicesResource(raw: raw);

final list = await devices.list();
expect(list.first.id, 'reader-01');

// Inspect recorded calls
expect(fake.calls, hasLength(1));
expect(fake.calls.single.method, 'GET');
expect(fake.calls.single.path, '/devices');
```

**`EventDecoder` and `FakeRealtimeDriver`** — inject realtime frames

```dart
import 'dart:convert';
import 'dart:typed_data';
import 'package:advannet_client/advannet_client_testing.dart';

// Decode a raw message directly
final message = AdvanNetMessage(
  headers: {'content-type': 'text/xml', 'content-length': '...'},
  body: Uint8List.fromList(utf8.encode(xmlString)),
);
final updates = await Stream.value(message)
    .transform(const EventDecoder())
    .toList();
final event = (updates.single as RealtimeEventUpdate).event as TagReadEvent;
```
