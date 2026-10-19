# Root receiver focused review — delivery only, HOLD preserved

27 September2026. NEW test-only directory. Root receive.mjs/harness/source images,
browser module, production/main/GPU/Git were not changed. No new browser/native
capture was started. All own local servers stopped on test completion.

Reviewed receiver SHA:
69f46d5b2e25a60efab3f77e2066de57ba10858a5fca22b5554a7e33073fbaab.
Root added mandatory host-observed canonical capture receipt pin during this
review; all final tests include it:
614c65a7a209946125dbc5fcd0632bb575df66cdf080cf6d083d300b914f4a32.

```powershell
node tools/godot/map_editor_landmark_receiver_review/test_receiver.mjs
node tools/godot/map_editor_landmark_receiver_review/test_actual_capture.mjs
```

Run only outside Coordinator21's explicit GPU/performance measurement windows.
Own tests finished before the latest window and have no live process handles.

## Negative TAR/HTTP tests

43 assertions **PROBES_CONFIRMED**, ~0.43seconds. Tiny canonical87 file headers
are accepted by both parsers; synthetic payloads intentionally DO NOT represent
valid pixel captures and are refused by validateBundle. Negative coverage:

- traversal/absolute/script paths, symlink/PAX/prefix metadata, duplicate/unsorted
  filenames, missing/extra termination, bad checksum/padding/null suffix/UTF8;
- required host capture pin, wrong method/path/Host/Origin/content-type, absent
  origin, zero and oversized declared content-length;
- permitted same-origin request holding a partial body blocks concurrent POST;
  abort releases busy and a later invalid request is handled normally;
- all rejected HTTP attempts leave outputRoot empty, no receiver output folders.

HTTP clients use independent connections/Connection:close so intentionally bad
content-length probes cannot poison the test client's keep-alive request queue.

## Actual original capture delivery

100 assertions **PASS**, exit0, ~2.98seconds. Uses ONLY original files supplied
by root in `outputs/landmark-canvas-capture-ZQyA1N`; source preparation from
`outputs/landmark-canvas-harness-847KsC`. Rebuilds TAR via agent's actual
`buildTarBundle({receipt,artifact},closureBytes)`, without executing source
factories or redrawing textures. Existing artifacts remain unchanged.

- Archive:61689344 bytes (fits receiver70MiB).
- Archive SHA:89746082370fc7e7418239292db64b809ca1f334c001649730da22f393bda8a3.
- 43 original RGBA +43 original PNG + canonical receipt =87 files.
- Wrong host-observed receipt pin refuses independently of self-consistent data.
- Late corrupted archive rejects with retainedPartial:null; no folder allocated
  before ALL original receipt/image hashes are checked.
- Actual POST succeeds; all87 stored lengths/SHA match original validated bytes.
- Storage receipt stays ready:false/gpu:false/fontBackendAccepted:false/
  iblAccepted:false/productionInstalled:false.
- Injected second-image-open failure retains exact receipt+one original PNG,
  returns403 with explicit retainedPartial, creates no storage success receipt.
  Busy releases and later invalid request is handled normally.

Observed test evidence retained:

- Healthy package:
  `outputs/landmark-receiver-actual-proof-xReJt5/landmark-canvas-capture-Xg2KxC`.
- Injected partial:
  `outputs/landmark-receiver-actual-proof-xReJt5/landmark-canvas-capture-U4VAjt`.

The caller's known canonical receipt pin binds image SHA, dimensions, recipe,
sampler and font metadata. Arbitrary new self-consistent client receipts do NOT
pass. This resolves the earlier unpinned self-reported-pixel concern. It does
NOT grant font backend, environment/IBL, GPU sampler or game-owner admission.

## Remaining scoped observations

### P3 — receiver/browser canonical USTAR header divergence

Receiver parseTar accepts nonzero USTAR uname metadata when checksum is updated;
the browser parser requires its exact canonical generated header and rejects it.
Reproduced with canonical87-header tiny fixture; no valid capture or approval
was fabricated. Header bytes change archiveSHA while image/receipt bytes stay
identical, so this is deterministic packaging/contract mismatch, not a path
traversal or host-pin bypass. Align header policy if one shared canonical USTAR
format is intended. Browser budget80MiB versus receiver70MiB is also an explicit
interface difference; actual observed61,689,344-byte archive fits both.

### P3 — rejected incomplete keep-alive body not drained/closed explicitly

Early403 does not explicitly drain the request or set Connection:close. A raw
Node client declaring an oversized incomplete body, then reusing its same
keep-alive socket, stalls its next request behind the old unfinished body. Our
initial probe hit its3-second client timeout; corrected independent-connection
probes succeed. No game/browser-wide stall or unbounded memory claim follows.
Consider closing rejected upload connections explicitly and retaining a bounded
request/headers timeout; requestTimeout currently30seconds. Full DOS/slowloris
load testing was not performed during shared game measurement windows.

### Host filesystem/lifetime boundaries

Prepared source/output paths are host-owned, not accepted from HTTP userdata.
POST validates cached pinned source bytes, fixed file paths and known capture
pin; GET serves only configured whitelist and checks current file hash/link.
Package_manifest itself is host-generated configuration, not a cryptographic
authentication mechanism for arbitrary client paths. Do not replace/reparent
host source/output directories while a receiver is live; startup path checks do
not issue filesystem-generation leases against external concurrent changes.
Origin/Host checks restrict browser access; a local raw process can manufacture
HTTP headers, but still needs the root-observed image/receipt hashes to store a
capture. This is a local artifact sink, not a login/authority server.

Storage_receipt.json is exclusive but not itself fsync/readback-verified. There
is no crash-atomic package publication guarantee; callers must require successful
response, verify package/receipt and maintain HOLD. Retained partial directories
must not be admitted by existence alone. No missing original image/font/equipment
is substituted by these tests, and actual portable publication remains separately
blocked by owner/importer/font/GPU gates.
