# Landmark artifact receiver V2 — delivery hardening, HOLD only

27 September2026. Separate source-only successor to root receive.mjs. Root V1,
prepared harness, browser exporter, original capture files, production/main/GPU
and Git remain unchanged. All testservers shut down after each suite.

```powershell
node tools/godot/map_editor_landmark_receiver_v2/test_receiver.mjs
node tools/godot/map_editor_landmark_receiver_v2/test_actual_capture.mjs
node tools/godot/map_editor_landmark_receiver_v2/test_connection_cleanup.mjs
```

**151 checks PASS**:44 negative/header+HTTP,100 actual stored-byte checks,7
connection/slow-progress checks. Approximately0.42+2.99+1.31seconds respectively.
Run only outside Coordinator21's explicit game GPU/performance measurement
windows. No browser/native game/GPU was launched by these tests.

## API/source closure

Exports same `MAX_BYTES`, `parseTar(bytes)`,
`validateBundle(bytes,sourceBytes,closureBytes,expectedCaptureSha256)`, and
`startReceiver(preparedAbsoluteDirectory,existingOutputRoot,expectedCaptureSha256)`.
CLI accepts those three host arguments. Source/closure pins remain mandatory.
It imports the pure `parserTar` from the existing browser bundle module, not
source factories; retain that explicit dependency in a staged source package.

The capture pin is a host-supplied **already observed** original canonical receipt
SHA, not an input accepted from the incoming HTTP body:
614c65a7a209946125dbc5fcd0632bb575df66cdf080cf6d083d300b914f4a32.
It binds all original image SHA, slot dimensions/order, recipe/sampler/font
metadata. Arbitrary new self-consistent client receipts cannot pass this pin.
The receiver still does not approve native fonts, GPU sampler/IBL, gameplay
owners, importer baseline or production installation.

## Changes from root V1

1. Receiver bound70MiB remains checked BEFORE the browser shared parser. Exact
   browser canonical USTAR headers/87 entries are now mandatory, including uname/
   reserved zeros, size octal, strict paths, checksum and exactly2 zero blocks.
   Existing source/provenance and root receipt/image checks still run afterward.
   The prior uname-header divergence now rejects in both parsers.
2. Every refusal emits Connection:close, destroys the request after the error
   response flush, or closes already destroyed/sent response safely. A declared
   oversized incomplete upload cannot hold the same keep-alive socket hostage
   for a later request. Partial-write error still returns retainedPartial path.
3. Native HTTP request/headers timeout30seconds, checking interval1second, and
   inactivity timeout30seconds. Busy is always released in the existing finally
   path after body abort/error. Browser GET remains available during pendingPOST;
   concurrent capture POST refuses, no fake readiness or timer rewind.
4. storage_receipt.json now uses exclusive fd+write+fsync+exact-byte readback,
   matching the individual artifact readback discipline. An error cannot return
   success based only on attempted receipt write.

## Exact actual-source delivery

The positive test uses root's ORIGINAL persisted files from
`outputs/landmark-canvas-capture-ZQyA1N`, prepared pins from
`outputs/landmark-canvas-harness-847KsC`, and the browser packager's actual
`buildTarBundle`. No pixels are redrawn, normalized or reconstructed differently.

- TAR61689344bytes, SHA
  89746082370fc7e7418239292db64b809ca1f334c001649730da22f393bda8a3.
- 43 original RGBA +43 original PNG + canonical capture receipt:87 files.
- All87 stored lengths/hashes exactly match observed originals.
- Corruption near archive end refuses before allocating any output directory.
- Injected second-image-open failure retains exact receipt+onePNG, no storage
  success receipt; a subsequent request demonstrates released busy state.
- Actual successful response and storage receipt keep ready:false/gpu:false/
  fontBackendAccepted:false/iblAccepted:false/productionInstalled:false.

Evidence directories (not a release):

- Good:
  `outputs/landmark-receiver-actual-proof-UlZXLV/landmark-canvas-capture-ylXoMC`.
- Injected partial:
  `outputs/landmark-receiver-actual-proof-UlZXLV/landmark-canvas-capture-2kabKq`.

## Focused connection and DOS boundary proof

Real HTTP keep-alive Agent with maxSockets1 first declares an oversized body but
sends only1byte. It receives403+Connection:close; next request uses another socket
and completes without the old stalled-body problem.

For the slow-body test ONLY, the returned testserver's native request/headers/
inactivity durations are reduced to120ms. The client sends a byte every20ms, so
regular progress defeats mere inactivity timeout; native overall request timeout
still closes/408s the stream within the1second checker cadence. Afterward busy
is released and outputRoot remains empty. Production defaults stay30000ms.
This is not a load/concurrency stress test or general localhost DOS immunity.

## Remaining honest boundaries

Browser packaging bound80MiB and receiver bound70MiB remain distinct. Observed
61,689,344-byte original archive fits both; this proof does not admit arbitrary
future larger captures or rescale images to conceal the limit.

Origin/Host/type/path checks and known SHA protect this local artifact delivery
protocol, not login or gameplay authority. A local process can fabricate HTTP
headers but cannot substitute pinned receipt/image bytes without a SHA collision.
Prepared manifest, source/output paths and their lifetime are trusted host-owned
configuration. Do not replace/reparent directories while receiver is active;
no filesystem-generation lease or hostile-global-Node-intrinsic sandbox is issued.

IO errors retain explicit partial directories; no destructive cleanup and no
crash-atomic directory commit is promised. Caller must require successful response
and independently verify files/receipt, never infer readiness from directory
existence. Original recipe capture still requires later platform-font, GPU/
sampler/environment and owner/importer admission. Actual portable publication
is still a separate HOLD workflow.

Frozen candidate SHA-256:

- receive.mjs:3A3AD2D506C4BC02D30E2B88F0DBFED5A543E2340A85BA1E8B95BFB7DDA7FB81
- test_receiver.mjs:421BD5DFC395B4F437F85FE5CF654EB312BA49D525E0769CFAA8E6B9C3AC21E1
- test_actual_capture.mjs:C9ED98A673CEF7BDB0772C335B96E42AB85009B11C6A8E64D65AB19AC5B9FA2C
- test_connection_cleanup.mjs:A0D0774104FC8BE129C4817A83086A592DD30DF22277223B3389A9F024EFB27B
- Root V1 unchanged:69F46D5B2E25A60EFAB3F77E2066DE57BA10858A5FCA22B5554A7E33073FBAAB

Root independent review/source admission is required before using V2 in the
actual capture workflow. This package is not graphics-quality acceptance.
