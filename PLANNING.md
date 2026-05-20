# AdvanNet Dart Client — Implementation Plan

A plan for a Dart 3.11 client library targeting the Keonn AdvanNet REST API exposed by AdvanReader / AdvanSafe / AdvanPay / AdvanFlow devices on TCP port `3161` (plus the realtime feed on `3177`).

This is a *plan*, not code. It is opinionated about the shape of the public API, the layering, what gets generated vs hand-written, and which Dart 3.x language features carry their weight.

---

## 0. Sources, scope, and primary references

The plan is grounded in three layers of source material, ordered by trustworthiness:

1. **Keonn's GitHub org — `github.com/Keonn-Technologies`** — the most current authoritative reference. Two repos are directly relevant: `JavaRestExamples` ("Connect to AdvanNet's REST API using Java", README explicitly notes the included `ADRDAsynch` example "shows how to read continuously data from a reader operating it using REST requests and reading the TCP port 3177") and `CSharpRestExamples` (same surface, C#). Both were updated in 2025, so they reflect current firmware behavior in a way the wiki and PDF do not. `BasicAdvanNetApp` is the closest analog to a Dart client — it's pure JavaScript hitting the same HTTP + TCP surface with no official SDK to lean on. **These three repos are the primary source-of-truth for wire format and idiomatic usage; the plan treats them as required reading before implementation, not optional.**
2. **The Keonn wiki at `wiki.keonn.com/software/advannet/development`** and its descendants — the architectural overview, the catalog of read modes and services, and the worked PUT/GET examples for antennas and service config. Comprehensive on *what exists* but thin on *exact wire format*.
3. **The downloadable PDF — *AdvanNet 2.5.x REST Reference Guide v1.1*, dated 19 November 2019** — the only formal endpoint reference. It is version-pinned to AdvanNet 2.5.x and the live firmware is at 2.10+, so the PDF is the canonical list for the *2.5.x baseline* but every endpoint discovered from it must be validated against current firmware before being promoted to the typed API layer.

### Scope: which devices this library targets

The development page splits Keonn's hardware into two distinct families with fundamentally different software architectures:

- **AdvanReader 70/160 family and derived systems** (AdvanSafe-100/200, AdvanTrack-200, AdvanGuard-100, AdvanPay-110/120/170, AdvanFlow-200, AdvanGo-100, AdvanMirror-300, AdvanFitting-200/300, AdvanLift, etc.). These run an onboard Linux board with AdvanNet, expose the REST API on port 3161, and stream realtime data on port 3177. **This is the entire scope of this library.**
- **AdvanReader 10 family** (AdvanReader-m1-10, -m2-10). No CPU, no Linux, no REST. Talks to a host computer over RS232 serial using ThingMagic's Mercury SDK. **Out of scope.** A future sibling package (`advanreader_10`) could wrap the serial protocol, but it would share none of this library's transport.

This scoping decision is worth stating explicitly because Keonn's GitHub publishes example repos for both families (`JavaRestExamples` and `AdvanReader-10-Java-Examples` are different APIs), and naming the package `advannet_client` rather than `keonn_client` keeps the door open for that sibling without forcing them to share an API surface.

### What the development page adds to the technical picture

Beyond confirming the GitHub org and device taxonomy, the page contributes two facts that shape design:

- **Direct quote: "Asynchronous data, including RFID, sensors, etc. is received at the TCP socket on port 3177."** Port 3177 is not the *tag* stream — it's the *asynchronous data* stream, and tag reads are one source among others (sensors, alarms, system events). This is the textual confirmation that the `UnknownEvent` branch in §8.4 is load-bearing rather than precautionary: even in the documented behavior, the stream carries content beyond what any closed event-type enum can cover.
- **The "integrated services" path** (CSV, HTTP, MQTT, SQL, USB HID, Simple HTTP) is positioned as an alternative to REST clients: rather than connecting to 3177 yourself, you configure the device to *push* events to your endpoint or database. This affects the library design: the typed config models for these services (§9 Stage 2) are not nice-to-have — they're how many real deployments actually consume reader events. A Dart application might configure the reader's MQTT service to publish to a broker the app subscribes to, never opening a 3177 socket at all.

---

## 1. What we are building against

The AdvanNet REST API has properties that matter a lot for the library design:

- **It is not a JSON API.** Requests and responses are **XML** with a `<request>` / `<response>` / `<data>` envelope (the docs show `<entries><entry><class>…</class><def>…</def></entry></entries>` and `<data>…</data>` payloads).
- **The endpoint catalog is in a downloadable PDF** ("REST Reference Guide"), not on the wiki. The wiki shows only fragments: `GET /devices`, `GET /devices/{id}/start`, `GET /devices/{id}/stop`, `PUT /devices/{id}/antennas`, `GET /system/services/byId/{serviceId}`, `PUT /system/services/byId/{serviceId}`, `GET /device/confAllSave`, `GET /system/os/FactoryReset`. The full surface is much wider (services, read modes, GPIO, EAS, etc.).
- **Mixed verbs and semantics.** `GET` is used for actions like `start`, `stop`, `confAllSave`, `FactoryReset` — not just retrieval. The library must not assume REST orthodoxy.
- **Configuration round-trip pattern.** The documented workflow for changing any setting is *GET the current config → mutate one field → PUT it back → GET `/device/confAllSave` to persist → reboot*. This is the dominant interaction shape and deserves a first-class abstraction.
- **Auth is HTTP-level.** Basic or Digest (selected per device), optional HTTPS with self-signed certs ("Ignore any certificates' problem").
- **Realtime data is *not* REST.** It is a raw TCP stream on port `3177`. A complete client library covers it; an HTTP-only library does not.
- **Multi-client support exists** from AdvanNet 2.1.6_05 onward, but only when a specific config block is removed. The library cannot assume concurrent sessions are safe; it must serialize per-device by default and let callers opt out.

The plan accordingly splits the library into a stable hand-written *core* and a *generated* endpoint layer that can grow as the PDF reference is mined.

---

## 2. Package layout

A single pub package, `advannet_client`, with internal libraries exported selectively:

```
advannet_client/
├── pubspec.yaml
├── lib/
│   ├── advannet_client.dart          # public barrel
│   ├── src/
│   │   ├── transport/                # HTTP + TCP, auth, retries
│   │   ├── xml/                      # envelope (de)serialization
│   │   ├── model/                    # sealed/value types
│   │   ├── errors/                   # sealed error hierarchy
│   │   ├── endpoints/                # one file per resource group
│   │   ├── realtime/                 # port 3177 stream
│   │   ├── config/                   # GET-mutate-PUT-save flow
│   │   └── discovery/                # /devices listing & probing
│   └── advannet_client_testing.dart  # fakes for downstream tests
├── test/                             # unit + golden XML
├── integration_test/                 # opt-in, real device
└── example/
```

The split between `advannet_client.dart` and `advannet_client_testing.dart` matters: downstream apps that want to unit-test their own code against a fake device should not have to depend on `http` or `package:test` transitively.

---

## 3. Dependencies

Minimal and conventional:

- `http` — request transport. Wrapped behind an interface so it can be swapped for a fake in tests (and so a `dio` or `cronet_http` adapter can be added later without breaking the public API).
- `xml` — pull-style XML parsing; the envelope is small and regular, so we don't need a full data binding.
- `meta` — `@immutable`, `@sealed` where the language doesn't already cover it.
- `crypto` — Digest auth (the `http` package does not implement it; this has to be hand-rolled, see §6).
- (dev) `test`, `mocktail`, `coverage`, `lints` (or `very_good_analysis`).

No code generation tooling in the runtime dependency set. Codegen (§9) runs as a dev-time `build_runner` task.

---

## 4. Public API shape

Two layers, both exported:

### 4.1 High-level resource API (the default)

A `AdvanNet` root client, constructed once per device, exposing typed resource groups:

```
final reader = AdvanNet.connect(
  Uri.parse('http://192.168.1.173:3161'),
  credentials: AdvanNetCredentials.digest('admin', 'admin'),
);

final devices = await reader.devices.list();
await reader.devices.start(devices.first.id);
await reader.devices.stop(devices.first.id);
```

Resource groups (mirroring the wiki taxonomy):

- `reader.devices` — list, start/stop, status, antenna definitions
- `reader.services` — `byId(...)`, list, enable/disable, generic config get/put
- `reader.readModes` — switch between Asynch / Scan / AdvanFlow / Dynamic Inventory / EAS / AdvanGo / Track Missing
- `reader.system` — `confAllSave`, `factoryReset`, reboot, time, version
- `reader.gpio` — GPO state, buzzer, speaker (see "Remote control GPO, buzzer and speaker")
- `reader.eas` — alarm config (SQL / HTTP variants)
- `reader.tags` — tag DB queries when the device caches them
- `reader.realtime` — opens a `Stream<TagEvent>` from port 3177

### 4.2 Low-level escape hatch (always available)

Because the wiki page is incomplete and the device firmware varies by AdvanNet version, the typed surface will never be 100% complete. The client always exposes:

```
final xml = await reader.raw.get('/some/undocumented/path');
await reader.raw.put('/some/path', body: someXmlElement);
```

This is the load-bearing decision that lets the library ship at v1 without waiting for full PDF coverage.

---

## 5. Modeling the envelope with Dart 3 features

The XML envelope is a tagged union: a response is either an `entries` list, a single `data` block, an error, or empty. This is the textbook case for **sealed classes + pattern matching**, which is exactly what Dart 3 added.

```
sealed class AdvanNetResponse {
  const AdvanNetResponse();
}

final class EntriesResponse extends AdvanNetResponse {
  final List<Entry> entries;
  const EntriesResponse(this.entries);
}

final class DataResponse extends AdvanNetResponse {
  final XmlElement data;
  const DataResponse(this.data);
}

final class EmptyResponse extends AdvanNetResponse { const EmptyResponse(); }

final class ErrorResponse extends AdvanNetResponse {
  final String code;
  final String? message;
  const ErrorResponse(this.code, this.message);
}
```

Callers consume with exhaustive switch expressions:

```
final summary = switch (response) {
  EntriesResponse(:final entries) => 'got ${entries.length} entries',
  DataResponse(:final data)       => 'config: ${data.name.local}',
  EmptyResponse()                 => 'ok',
  ErrorResponse(:final code)      => throw AdvanNetServerError(code),
};
```

`Entry` itself is a small record-flavored value type holding `class`, `def`, and an optional `conf` subtree, since `<entry>` always carries a `<class>` discriminator and a comma-separated `<def>`. The `def` string (e.g. `deviceID,1,2,0,-1,loc_antenna1,10,20,30`) is parsed into a typed `AntennaDefinition` record by the resource layer, not at the envelope layer — the envelope stays dumb on purpose.

Dart 3 features being used here, and why:

- **Sealed classes** — the response variants are closed; exhaustiveness checking is the whole point.
- **Pattern matching with destructuring** — callers want to pull fields out of variants without `is` casts.
- **Records** — perfect for the tuple-like `<def>` decoded payloads (`(int board, int port, int mux, int subMux, String loc, int x, int y, int z)`) without inventing a class per resource.
- **Class modifiers (`final`, `interface`, `base`)** — `final class` on every concrete model prevents downstream subclassing, which is the right default for a wire-format library. The transport abstraction is `interface class HttpTransport` so adapters can implement but not extend.

---

## 6. Transport layer

A thin `HttpTransport` interface plus a default implementation backed by `package:http`.

Responsibilities:

- Build `Uri` from base + path; reject path-traversal.
- Set `Content-Type: application/xml` and `Accept: application/xml`.
- Serialize an `XmlDocument` body when present.
- Apply auth (see below).
- Trust override for HTTPS (the wiki explicitly tells users to ignore cert problems). The library exposes this as an opt-in `allowSelfSignedCertificates: true` flag — never silently on.
- Map HTTP status → `AdvanNetError` subtype.
- Time out per request (configurable, default 10s).
- Retry policy: idempotent verbs (`GET`, `PUT` of config in our usage) retry on transient network errors with exponential backoff + jitter; action endpoints (`/start`, `/stop`, `/FactoryReset`, `/confAllSave`) never retry automatically.

Auth handling needs care:

- **Basic** is one header; trivial.
- **Digest** requires a challenge round-trip (`401 WWW-Authenticate` → recompute `Authorization` with nonce/cnonce/qop). `package:http` does not handle this. The plan is a small hand-written digest helper using `package:crypto` for MD5/SHA-256, with a per-`HttpTransport` instance nonce cache so we don't re-challenge on every call.
- **None** — pass-through.

`AdvanNetCredentials` is a sealed class with `none`, `basic`, and `digest` variants; the transport picks the strategy by pattern match.

### 6.1 Per-device serialization

Because concurrent REST clients are only safe in newer AdvanNet versions and only after a config tweak, the default `AdvanNet` client wraps every request in a per-instance `Pool(1)` (or hand-rolled mutex). Concurrency is exposed as `AdvanNet.connect(..., maxConcurrency: 4)` so users on patched firmware can opt in.

---

## 7. The configuration round-trip helper

The "GET → mutate → PUT → confAllSave → reboot" sequence is everywhere in the docs (re-enabling the UI, antenna definitions, service config). The library codifies it:

```
await reader.services.updateById<AdvanNetRestService>(
  'AdvanNetRestService',
  (current) => current.copyWith(serveStatic: true),
  persist: true,
  reboot: false,
);
```

Internally this:

1. GETs `/system/services/byId/{id}`.
2. Parses the `<data>` block into the typed model `T`.
3. Runs the user's pure mutator (no I/O inside the callback — enforced by being a plain `T Function(T)`).
4. Re-serializes and PUTs it back.
5. If `persist`, GETs `/device/confAllSave`.
6. If `reboot`, calls the reboot endpoint.

This is the single most useful affordance of the library and the main reason to use it over hand-rolling against `dart:io`. The pattern is generic and reusable: `Resource.update<T>(id, T Function(T) mutator)`.

---

## 8. Realtime TCP stream (port 3177)

This is the second half of the library and deserves its own architecture. The wiki confirms a handful of anchors, and the design has to be explicit about what's confirmed vs what must be discovered against a device.

### 8.1 What the wiki tells us (now with the wire format confirmed)

The AdvanReader-150 product page documents the realtime protocol in full, which removes most of the previous "must be discovered" uncertainty. What is now confirmed:

- The reader streams realtime data on **TCP port 3177**.
- **The protocol is HTTP-like, not raw newline-delimited text.** Each message has the structure:

  ```
  ADVANNET/1.0
  Content-Length:488
  Content-Type:text/xml
  <CRLF>
  <?xml version="1.0" encoding="UTF-8"?>
  <deviceEventMessage>...</deviceEventMessage>
  ```

    - Status line: literal `ADVANNET/1.0`.
    - Headers: `Content-Length` (byte count of the body) and `Content-Type` (typically `text/xml`).
    - **Header lines are strictly CRLF-delimited.** A single empty CRLF line separates headers from body. The body itself may contain any line separators and must be read by *byte count*, not by scanning for a delimiter.

- **Two top-level XML body shapes** are documented:
    - `<deviceEventMessage>` — single discrete events (alarms, GPI transitions, connect/disconnect, etc.).
    - `<inventory>` — batches of tag reads, each `<item>` being a `READ_EVENT` with `epc`, `hexepc`, `tid`, a `<props>` block (`TIME_STAMP`, `RSSI`, `RF_PHASE`, `ANTENNA_PORT`, `MUX1`, `MUX2`, `FREQ`, `GPI`), and an optional `<locationData>` block.

- **Confirmed event-type vocabulary** from the 150 page alone, joining what was already documented elsewhere:
    - From Asynch ReadMode: `TAG_READ`, `TAG_DIRECTION`.
    - From Custom Events (2.10.40+): `TAG_GENERIC`, `TAG_GENERIC_2`.
    - From the 150 product page: `INVENTORY`, `TAG_ALARM`, `TAG_ALARM_ANTENNA_1`…`TAG_ALARM_ANTENNA_4`, `TAG_ALARM_DISABLED`, `TAG_ALARM_ENABLED`, `GPI`, `ADVANNET_INFO`, `ADVANNET_DEVICE_CONNECTED`, `ADVANNET_DEVICE_DISCONNECTED`.
    - Plus "several error messages" the wiki acknowledges without enumerating.

- **Tag-alarm payloads carry an `alarmType` discriminator** (`EPC_EAS`, `NXP_EAS`, `EPCBULK_EAS`) inside the event — alarms are not a separate event-type axis, they're one event type with a sub-discriminator. The library needs to model this as a field on `AlarmEvent`, not as separate sealed branches.

- Server-side debouncing exists: the **Events TTL** setting throttles repeated `TAG_READ` for the same EPC. The client does *not* need to deduplicate by default.

- The Java `ADRDAsynch` example in `Keonn-Technologies/JavaRestExamples` is still the canonical reference for *how* to parse this in practice, but no longer carries the burden of being the spec.

### 8.2 What is still *not* confirmed and must be discovered

Three smaller items remain, none of them blocking:

1. **Whether the stream pushes immediately on connect or requires a handshake/subscribe command.** No handshake is shown in any example, so connect-and-listen is the working assumption — but verify against `ADRDAsynch` or a real device.
2. **Keepalive behavior.** Whether the device sends periodic heartbeats (perhaps an `ADVANNET_INFO` message) or relies on TCP keepalive. Determines how aggressively the client should treat silent sockets as broken.
3. **Multi-client semantics on the realtime port.** REST has a documented "concurrent clients" caveat from AdvanNet 2.1.6_05+; 3177 may or may not have an equivalent. Verify by opening two sockets against a single device.

### 8.3 Subsystem layering

Four layers, each independently testable:

```
RealtimeEvent / RealtimeStatus  ← public stream output (sealed types)
        ↑
  EventDecoder                   ← XML body → typed event
        ↑
  AdvanNetMessageParser          ← byte stream → framed (headers, body) tuples
        ↑
  ConnectionDriver               ← Socket lifecycle, reconnect, keepalive
        ↑
  dart:io Socket                 ← (web stub throws UnsupportedError)
```

**`ConnectionDriver`** owns the `Socket`, the reconnect loop, exponential-backoff-with-jitter timing, and surfaces lifecycle as a stream of `(Uint8List bytes | DriverStatus status)` records. It does not understand frames, let alone events. This keeps reconnection logic separate from parsing logic — important because reconnection bugs are subtle and we want to test them with a fake byte stream.

**`AdvanNetMessageParser`** is a `StreamTransformer<Uint8List, AdvanNetMessage>` implementing the HTTP-like wire format. State machine with three states:

- `READING_STATUS_LINE` — accumulate bytes until CRLF, verify the line equals `ADVANNET/1.0` (anything else is a `FrameError` status emission, then realignment by scanning forward for the next `ADVANNET/1.0` token).
- `READING_HEADERS` — accumulate CRLF-delimited header lines until an empty line. Parse `Content-Length` (mandatory) and `Content-Type` (advisory). Unknown headers are preserved in a map but otherwise ignored — protocol-level forward compatibility.
- `READING_BODY` — read **exactly `Content-Length` bytes** regardless of their contents (the body can contain any line separators, so length-based reading is mandatory, not scan-based). Emit `AdvanNetMessage(headers, bodyBytes)` and return to `READING_STATUS_LINE`.

`AdvanNetMessage` is `final class AdvanNetMessage { final Map<String, String> headers; final Uint8List body; }`. The parser exposes a `maxBodySize` guard (default 1 MiB) to refuse pathological `Content-Length` values rather than allocating arbitrarily.

The parser is **not pluggable in the same way the earlier draft made `FrameSplitter` pluggable** — `ADVANNET/1.0` is the protocol, and trying to abstract over it would create a footgun. What *is* pluggable is the `EventDecoder` above it: if Keonn ever ships a JSON-bodied variant, only the decoder changes.

**`EventDecoder`** is a `StreamTransformer<AdvanNetMessage, RealtimeEvent>`. For `Content-Type: text/xml` (the default), it parses the body once with `package:xml` and dispatches on the root element name:

- `<inventory>` → emit one `TagReadEvent` per `<item>`, attributing the `<deviceId>` and `<advanNetId>` from the parent.
- `<deviceEventMessage>` → emit a single event whose subtype is determined by `<event><type>`.
- `<eventMessage>` → same, for system-level events (`ADVANNET_INFO` and friends).

Decoder errors emit a `DecodeError` status; they never crash the stream.

**Public stream** is `Stream<RealtimeEvent>`, a broadcast stream so multiple listeners share one socket.

### 8.4 Event modeling — sealed for the known set, open for the rest

`RealtimeEvent` is a sealed class. The known set now reflects the full vocabulary from the wiki:

```
sealed class RealtimeEvent {
  String get type;            // raw type string from the wire
  String get deviceId;        // from <deviceId>
  DateTime get receivedAt;    // local arrival timestamp
  DateTime get serverTs;      // parsed from <ts> (milliseconds since epoch)
  Map<String, String> get raw;
}

// Tag events
final class TagReadEvent extends RealtimeEvent {
  final String epc;
  final String hexEpc;
  final String? tid;
  final int? rssi;            // dBm
  final int? rfPhase;
  final int? antennaPort;     // 1..4
  final int? mux1;
  final int? mux2;
  final int? freqKHz;
  final List<int>? gpiSnapshot;       // [1,0,1,1] at the moment of read
  final LocationData? location;        // optional <locationData>
}

final class TagDirectionEvent extends RealtimeEvent { /* epc, direction, antennaPort, ... */ }

final class TagGenericEvent extends RealtimeEvent {
  final String epc;
  final String customEventName;        // "customEvent" or "customEvent2"
}

// Alarm events — one sealed class, alarm sub-type as a field
final class AlarmEvent extends RealtimeEvent {
  final String epc;
  final AlarmKind kind;                // PER_ANTENNA, GLOBAL, ENABLED, DISABLED
  final int? antennaPort;              // 1..4, null when kind == GLOBAL
  final AlarmType alarmType;           // EPC_EAS, NXP_EAS, EPCBULK_EAS
}

enum AlarmKind { global, perAntenna, enabled, disabled }
enum AlarmType { epcEas, nxpEas, epcBulkEas, unknown }

// GPIO events
final class GpiEvent extends RealtimeEvent {
  final int line;                      // 1..N
  final bool lowToHigh;                // direction of transition
}

// System events
final class SystemInfoEvent extends RealtimeEvent {
  final String message;
  final String advanNetId;
}

final class DeviceConnectedEvent extends RealtimeEvent { final String advanNetId; }
final class DeviceDisconnectedEvent extends RealtimeEvent { final String advanNetId; }

// Error event — the wiki acknowledges "several error messages" without enumerating them
final class ErrorEventMessage extends RealtimeEvent {
  final String? code;
  final String? message;
}

// Open hatch — anything not yet modeled
final class UnknownEvent extends RealtimeEvent { /* type + raw map */ }
```

A few decisions worth flagging:

- **`AlarmEvent` is one sealed branch with an `AlarmKind` enum**, not five separate branches for `TAG_ALARM` / `TAG_ALARM_ANTENNA_1`…`_4`. The per-antenna variants only differ by which port fired; modeling them as separate types would force callers to write five `case` clauses for what is logically one event.
- **`AlarmType` is a separate enum** because `alarmType` is an orthogonal discriminator inside the alarm event (`EPC_EAS`, `NXP_EAS`, `EPCBULK_EAS`). It has an `unknown` member for forward compatibility; new alarm types do not break decoding.
- **`TagReadEvent` carries the full `<props>` set as typed fields, plus `raw` for everything else**. The wiki props list (`TIME_STAMP`, `RSSI`, `RF_PHASE`, `ANTENNA_PORT`, `MUX1`, `MUX2`, `FREQ`, `GPI`) is closed enough to type, but firmware may add more — the `raw` map preserves them.
- **`UnknownEvent` is still load-bearing.** Even with the wiki's expanded vocabulary, the page acknowledges "several error messages" without listing them, and the Custom Events page hints at additional types being added in 2.10.40+. Closed-only modeling would force a library update for every firmware bump.

Consumer code uses exhaustive pattern matching:

```
stream.listen((event) {
  switch (event) {
    case TagReadEvent(:final epc, :final rssi, :final antennaPort):  /* … */
    case TagDirectionEvent(:final epc, :final direction):            /* … */
    case TagGenericEvent(:final epc, :final customEventName):        /* … */
    case AlarmEvent(:final epc, kind: AlarmKind.perAntenna, :final antennaPort, :final alarmType):
      /* per-antenna alarm */
    case AlarmEvent(:final epc, :final alarmType):                   /* global / state-change */
    case GpiEvent(:final line, :final lowToHigh):                    /* … */
    case SystemInfoEvent(:final message):                            /* … */
    case DeviceConnectedEvent() || DeviceDisconnectedEvent():        /* … */
    case ErrorEventMessage(:final message):                          /* log */
    case UnknownEvent(type: 'SOMETHING_NEW', :final raw):            /* graceful */
    case UnknownEvent():                                              /* ignored */
  }
});
```

Typed fields are parsed lazily and conservatively: if the wire says `RSSI:-67`, the typed getter returns `-67`; if it says `RSSI:foo`, the typed getter returns `null` and `raw['RSSI']` still returns `'foo'`. The library never throws on malformed individual fields — only on framing failures.

### 8.5 The public stream surface

```
final realtime = reader.realtime;

// One broadcast stream, all event types interleaved with status.
final Stream<RealtimeUpdate> updates = realtime.updates();

// Convenience filters — typed sub-streams:
final Stream<TagReadEvent>      reads      = realtime.tagReads();
final Stream<TagDirectionEvent> directions = realtime.tagDirections();
final Stream<TagGenericEvent>   generics   = realtime.tagGenerics(name: 'customEvent2');
final Stream<AlarmEvent>        alarms     = realtime.alarms(kind: AlarmKind.perAntenna, antennaPort: 1);
final Stream<GpiEvent>          gpiEdges   = realtime.gpi(line: 1, lowToHigh: true);
final Stream<RealtimeEvent>     system     = realtime.systemEvents();

// Open hatch for unknown / future event types:
final Stream<UnknownEvent>      unknown    = realtime.unknown();
final Stream<RealtimeEvent>     byType     = realtime.byType('SOMETHING_NEW');
```

`RealtimeUpdate` is itself a sealed union:

```
sealed class RealtimeUpdate {}
final class RealtimeEventUpdate  extends RealtimeUpdate { final RealtimeEvent event; }
final class RealtimeStatusUpdate extends RealtimeUpdate { final RealtimeStatus status; }
```

…and `RealtimeStatus` is sealed too: `Connecting`, `Connected`, `Disconnected(reason)`, `Reconnecting(attempt, nextDelay)`, `FrameError(bytes, error)`, `DecodeError(message, error)`. Surfacing these as events on the same stream — rather than as side-channel callbacks — is what makes the realtime API testable: a fake driver emits status and event updates in deterministic order and the consumer's switch covers both.

### 8.6 Backpressure and buffering

The native `Socket` is uncontrolled — bytes arrive as fast as the device sends them, and Dart streams have no built-in flow control. The plan:

- Default: pass-through. Most apps consume faster than the device produces.
- Optional buffered mode: `AdvanNet.connect(..., realtimeBuffer: RealtimeBuffer.bounded(1024, onOverflow: OnOverflow.dropOldest))`. Three strategies: `dropOldest`, `dropNewest`, `block` (which back-pressures the *driver*, but cannot back-pressure the device itself; once the OS receive buffer fills the device's TCP send will block).
- Overflow events go on the status stream as `RealtimeStatusUpdate(BufferOverflow(droppedCount))`. The library never silently drops events.

### 8.7 Reconnection

- Exponential backoff starting at 1s, doubling to 30s, with ±25% jitter.
- Reconnect attempts are unbounded by default; cap exposed as `maxReconnectAttempts`.
- On reconnect, the library does not replay missed events — there is no replay protocol on 3177. It does emit a `Reconnected(missedDuration)` status so the consumer can decide whether to do a REST inventory pull to reconcile.
- Cancelling the last subscription closes the socket. Re-subscribing reopens it (or, for a broadcast stream with `singleConnection: true`, keeps it open between subscribers — configurable).

### 8.8 Lifecycle and resource ownership

The realtime stream is owned by the `AdvanNet` client and shares its lifecycle. `AdvanNet.close()` closes the socket and completes the stream. The stream is lazy: no socket is opened until the first listener subscribes. This matters for tests and for apps that construct an `AdvanNet` before they've decided they need realtime.

### 8.9 Cross-platform story

- `dart:io` (VM / Flutter mobile / Flutter desktop / server): full support.
- `dart:html` / web: `realtime.updates()` throws `UnsupportedError` synchronously on first listen, with a message pointing at the limitation. The realtime subsystem is behind a conditional import (`realtime_io.dart` / `realtime_web.dart`) so the web bundle doesn't include `dart:io` code.

### 8.10 Testing the stream

The wiki publishes complete worked XML payloads for `INVENTORY`, `TAG_ALARM`, `TAG_ALARM_ANTENNA_1`, `TAG_ALARM_DISABLED`, `TAG_ALARM_ENABLED`, `GPI`, `ADVANNET_INFO`, `ADVANNET_DEVICE_CONNECTED`, and `ADVANNET_DEVICE_DISCONNECTED`. These become **the v0.1 golden test fixtures** — they're authoritative payloads from Keonn themselves, copied verbatim into `test/fixtures/`. The decoder must handle every one of them on day one.

- **Parser tests**: fixtures exercise the `ADVANNET/1.0` framing — status line, headers, CRLF empty line, body. Edge cases: bodies containing literal CRLF; `Content-Length` mismatches; missing `Content-Length`; bad status line; oversize body (must trip `maxBodySize`); partial reads split across socket chunks at every byte boundary (property test).
- **Decoder tests**: one fixture per wiki-documented event type. Each must round-trip to the right sealed subclass with the right typed fields. Plus a "garbage XML" fixture (→ `DecodeError` status, stream stays alive) and an "unknown event type" fixture (→ `UnknownEvent`, never an exception).
- **Driver tests** use a `FakeConnectionDriver` that emits scripted bytes and status transitions; reconnect timing is tested with `package:fake_async`.
- **`FakeRealtime`** in `advannet_client_testing.dart` lets downstream apps push synthetic events into their tests: `fake.realtime.emit(TagReadEvent(epc: 'E2…'));`.
- **Integration tests** against a real reader or the Keonn simulator verify that what we *think* the wire looks like still matches what comes out of current firmware.

### 8.11 Remaining open questions (much smaller now)

The wiki's 150 page resolved the big ones. What's left:

1. **Handshake on connect** — appears to be none; verify against `ADRDAsynch` and a real socket.
2. **Keepalive** — whether the device sends periodic `ADVANNET_INFO` or relies on TCP keepalive; affects the silent-socket-is-dead heuristic.
3. **Multi-client semantics on 3177** — open two sockets to one device and see.

These are small enough that they don't shape the architecture — they only tune defaults (idle timeout, single-vs-multi-client warning). The framer, decoder, and event model are all locked.

---

## 9. Endpoint coverage strategy

The wiki does not enumerate endpoints. The plan is staged, with the **first mining source being Keonn's own example repos**, not the 2019 PDF:

**Stage 0 — Mine the GitHub examples.** Before writing typed Dart, walk `Keonn-Technologies/JavaRestExamples`, `CSharpRestExamples`, and `BasicAdvanNetApp` end-to-end and extract: every URL hit, every HTTP verb, every request/response XML shape, every TCP 3177 frame the `ADRDAsynch` example shows being parsed. This is the cheapest path to a high-confidence catalog because the code runs against real devices and is maintained (last touched 2025). The output is a checked-in YAML descriptor in `tool/endpoints/from_github.yaml` with a citation back to the file + line for each entry.

**Stage 1 — Hand-written core (everything the wiki shows directly):**
`/devices`, `/devices/{id}/start`, `/devices/{id}/stop`, `/devices/{id}/antennas` (GET + PUT), `/system/services/byId/{id}` (GET + PUT), `/device/confAllSave`, `/system/os/FactoryReset`. These ship in v0.1 and are enough to do useful work. Anything Stage 0 surfaced that overlaps gets cross-validated here.

**Stage 2 — Read modes and services from the wiki sub-pages:** each of the Read Modes pages (Asynch, Scan, AdvanFlow, EAS variants, AdvanGo, Dynamic Inventory, Autonomous Track Missing) and Services pages (CSV, HTTP, MQTT, SQL, USB HID, Simple HTTP, Watchdog, Hamachi) has a payload shape. These become typed config models with `freezed`-style `copyWith` (but hand-written; we don't pull in `freezed` for the runtime). One file per service. Service models matter especially because the wiki positions integrated services (HTTP, MQTT, SQL) as a first-class alternative to direct REST/3177 usage — a Dart app may configure the reader's MQTT service to publish to a broker the app already listens to, with no socket connection from the app to the reader at runtime.

**Stage 3 — PDF-driven generation as the final pass.** The *AdvanNet 2.5.x REST Reference Guide v1.1* (Nov 2019) gets parsed offline into the same YAML descriptor format used in Stage 0, merged with priority to Stage 0 on conflicts (since the PDF is older). A `build_runner` builder emits the typed resource methods + models under `lib/src/endpoints/generated/`. Generated files are checked in (so consumers don't run codegen) and re-emitted whenever the YAML changes. The generator is small — it only needs to emit method stubs that delegate to `raw.get/put` and parse `<data>` into the model — because all the hard work (transport, auth, envelope) is below it.

This staging means **v0.1 is useful, v1.0 is complete**, and we never block on PDF mining. It also means the PDF's age is no longer a critical-path risk: by the time we read it, the surface is already 80% covered from current example code.

---

## 10. Error model

A sealed hierarchy, rooted at `AdvanNetException implements Exception`:

- `AdvanNetTransportException` — network, DNS, TLS, timeout. Wraps the original.
- `AdvanNetAuthException` — 401/403, with the challenged scheme.
- `AdvanNetProtocolException` — XML parse failure, unexpected envelope shape, missing required field.
- `AdvanNetServerError` — server returned an `<error>` response or non-2xx with a parseable body. Carries `code`, `message`.
- `AdvanNetDeviceBusyException` — specifically for "device is reading, cannot apply config" type errors (the docs note many PUTs require `stop` first); we sniff for this and surface a distinct type so callers can recover.
- `AdvanNetUnsupportedException` — feature not available on this firmware version.

All thrown exceptions carry the request context (`method`, `path`, sanitized body) for logging. None of them carry credentials.

---

## 11. Logging and observability

A `void Function(AdvanNetLogRecord)` hook on the client, defaulting to no-op. Records are themselves a sealed type (`Request`, `Response`, `Retry`, `RealtimeStatus`). The hook is intentionally not `package:logging`-coupled — users can adapt to whatever logger they have.

Sensitive material (Authorization header, password fields in service config) is redacted at the source, not at the sink.

---

## 12. Testing strategy

- **Unit tests** against a `FakeHttpTransport` that returns canned XML. Covers envelope (de)serialization, the config round-trip helper, retry/backoff, Digest auth challenge math, and error mapping.
- **Golden tests** for serialized XML: the exact byte output of, e.g., an antenna-definitions PUT must match a fixture. This catches accidental whitespace / attribute-order regressions that real devices may or may not tolerate.
- **Integration tests** in `integration_test/`, opt-in via `--dart-define=ADVANNET_DEVICE_URL=...`, that run against a real reader or the Keonn-provided simulator (AdvanReader / AdvanSafe). These are CI-skipped by default.
- **A published in-memory fake** in `advannet_client_testing.dart`: `FakeAdvanNet` implements the same public interface as `AdvanNet`, with mutable in-memory state for devices, services, and a controllable realtime stream. Downstream apps can write their own tests without mocking HTTP.

---

## 13. Platform support

- **Dart VM / Flutter mobile / Flutter desktop**: full support, including realtime.
- **Flutter web**: REST works (CORS permitting; AdvanNet does not set CORS headers by default, so this is a known limitation worth documenting). Realtime over raw TCP is unsupported; the library throws on construction. A future WebSocket adapter could exist if Keonn ever adds one.

---

## 14. Versioning and stability

- **0.x** while the endpoint surface is still being mined from the PDF.
- **1.0** once Stage 3 generation is complete and at least one real-device integration test suite passes for each resource group.
- The low-level `raw.get/put` escape hatch is **stable from 0.1** — this is the explicit promise that lets early adopters build against the library without fearing churn in the typed layer.
- Generated typed methods are additive; renames go through a deprecation cycle of at least one minor version.

---

## 15. Open questions worth resolving before coding

These should be answered against the actual PDF reference and a physical device, not guessed at:

1. **Does the API ever return JSON?** The wiki shows only XML, but newer firmwares may negotiate. Decide whether `Accept` should be `application/xml` strictly, or whether to also support JSON if offered.
2. **Exact framing of the port 3177 stream.** Line-delimited? Length-prefixed? XML fragments? The plan assumes line-delimited text; this must be verified.
3. **Which endpoints require the device to be stopped first?** The antenna-definitions example says so explicitly. Are there others? This determines where `AdvanNetDeviceBusyException` recovery is wired in vs. where the library proactively stops/starts around a config change.
4. **Digest qop variants in use** (`auth` vs `auth-int`). Affects the digest helper.
5. **Reboot endpoint path** — not shown on the wiki page, but referenced repeatedly ("reboot the unit"). Likely `/system/os/Reboot` by analogy with `FactoryReset`, but to be confirmed.
6. **Idempotency of `/start` and `/stop`.** If calling `/start` twice is an error, the retry policy on transient failures must be tightened further for those endpoints.

---

## 16. Milestones

- **M0 — Source mining (week 0, parallel with M1):** read `JavaRestExamples` (including `ADRDAsynch`), `CSharpRestExamples`, and `BasicAdvanNetApp` end-to-end. Output: `tool/endpoints/from_github.yaml`. With the wire format now documented on the wiki, this milestone is no longer on the critical path for the realtime subsystem — it's still essential for REST endpoint coverage but it stops blocking everything else.
- **M1 — Skeleton (week 1):** package layout, `HttpTransport`, Basic auth, envelope parser, `devices.list/start/stop`, error hierarchy, fake transport, first 20 unit tests.
- **M2 — Config round-trip (week 2):** Digest auth, `services.byId`, generic `update<T>` helper, `AdvanNetRestService` typed model, `confAllSave`, antenna definitions GET/PUT with typed records.
- **M3 — Realtime (week 3, moved earlier):** `AdvanNetMessageParser`, `EventDecoder`, full event sealed hierarchy, port 3177 connection driver with reconnect, broadcast stream, web stub. Golden tests built directly from the wiki's published payloads. Can start as soon as M1 lands because the spec is fully documented.
- **M4 — Read modes & services breadth (weeks 4–5):** hand-written coverage of every wiki-documented read mode and service, prioritized by what `from_github.yaml` shows being used.
- **M5 — PDF-driven generation (weeks 6–7):** merge the 2019 PDF reference into the descriptor (Stage-0 entries take priority on conflict), generate stubs, golden tests.
- **M6 — 1.0 (week 8):** integration tests against a real reader, docs, example app (a Dart port of `BasicAdvanNetApp`), pub.dev publish.

---

## 17. Summary of load-bearing decisions

1. **Sealed envelope types + pattern matching** as the parsing backbone — leans on Dart 3 exhaustiveness.
2. **A `raw.get/put` escape hatch is part of the public API forever** — decouples shipping from PDF mining.
3. **The GET-mutate-PUT-save sequence is a first-class `update<T>(mutator)` primitive** — it's the dominant interaction shape and hand-rolling it is where users would otherwise make mistakes.
4. **Realtime is in the same package but conditionally compiled out on web** — keeps the import story simple while being honest about platform limits.
5. **Codegen produces methods, not transport** — the hand-written core stays small and auditable; the wide surface is generated.
6. **Per-device serialization by default** — safe against older firmware; opt-in concurrency for those who know they can.
7. **The 3177 parser implements `ADVANNET/1.0` directly, not an abstract framer.** The protocol is well-defined: status line, CRLF-delimited headers, `Content-Length`-counted body. The pluggable seam moves up one layer to `EventDecoder` (in case Keonn ever ships a JSON-bodied variant), where it actually does useful work.
8. **`AlarmEvent` is one sealed branch with two orthogonal discriminator enums** (`AlarmKind` and `AlarmType`), not five branches per antenna times three branches per alarm type. Keeps consumer pattern-matching tractable.
9. **`UnknownEvent` is a permanent first-class variant**, not a development-time placeholder. The wiki itself acknowledges undocumented "error messages" exist, and the firmware adds event types between releases.