# One byte-exact Canvas capture bundle

Additive `bundle.browser.mjs` never imports Three, executes drawing, requests a
GPU/context, performs filesystem writes, changes capture pixels, or upgrades
graphics/font authority. Original `capture.browser.mjs` is unchanged.

API (browser and Node share the same implementation):

```js
const bundle = await buildTarBundle(window.landmarkCanvasCapture, closureBytes);
// {bytes: Uint8Array, filename, entries:87, ready:false,
//  receiptSha256: originalCaptureCanonicalHash, bundleSha256}
const parsed = parserTar(bundle.bytes); // Map<relativeName, read-only-by-contract byte view>
const admitted = await validateBundle(bundle.bytes, closureBytes);
// {receipt, entries, ready:false}; no disk writes or path interpretation.
```

`closureBytes` are the exact approved original closure.json bytes, not a parsed
and reserialized approximation. Its SHA is pinned by the module. All43 slot
identities/order, dimensions, cube face ordinals, source recipe keys/hashes and
original samplers must match the reviewed closure. Original capture receipt
canonical hash and all86 artifact bytecounts/SHA are verified before packaging.
PNG signature/IHDR dimensions are checked; native encoded PNG bytes are retained
without decode/re-encode. RGBA order/bytes are unchanged. Bundle carries the
original canonical receipt (including ready:false and all unresolved gates),
not a new ready receipt. Repeat/font provenance is not fabricated.

The archive is deterministic uncompressed USTAR: receipt.json first, then sorted
`images/texture-N-image-M.png` and `.rgba`, epoch/uid/gid0, regular mode0644,
no links/prefixes, canonical checksum, zero padding and exactly two zero endblocks.
Exactly87 entries are required. Whole bundle is bounded to80MiB; actual source
base RGBA is55,033,856 bytes, plus native PNG and receipt/header overhead. All
filenames are fixed ASCII relative artifact names: no caller filesystem paths.
parserTar returns views into caller archive bytes; callers must not mutate them
between validation and guarded copying. Root receiver owns symlink/path/race,
request-limit/loopback/origin admission and exclusive unique-directory writes.

## UI / preparation integration

Unfrozen index.html has two separate explicit-click buttons:

- «Сохранить PNG и RGBA локально»: builds/validates once, POSTs x-tar body to
  same-origin ./capture-bundle only on a loopback hostname, checks ok:true and
  ready:false receiver reply, displays the returned receipt/status.
- «Скачать одним TAR-архивом»: emits one original-landmark-canvas43.tar download.

No auto-upload, external service, server, browser, capture or game starts here.
Capture/build/save buttons are locked during work; new capture clears cached
bundle. Safe module is included in prepare.mjs's file/hash allowlist. Root alone
owns receiver and existing browser/server. To use new files, root prepares a NEW
verified harness stage; do not alter hash-admitted existing stage files in place.

## Node evidence / limits

`node tools/godot/map_editor_landmark_canvas_capture/test_bundle.mjs`
uses explicitly synthetic PNG/RGBA byte fixtures with the43 ORIGINAL source
dimensions and closure—not invented evidence of native rendering. Tests parse
all87 files, compare all86 artifact buffers/hashes, assert deterministic TAR,
unchanged originals/ready:false, and reject bad checksums/links/absolute paths,
duplicates/padding/truncation/unsafe slot order, source pin/recipe/sampler/dimension
changes, tampered canonical receipt, stale data and hash-consistent invalid PNG.
No Three/Canvas/browser/engine/server/GPU is executed. Native43+repeat evidence
and platform font backend remain root's separate live capture responsibility.

`node tools/godot/map_editor_landmark_canvas_capture/test_preparation.mjs`
checks original untouched capture formulas plus new module/UI syntax and prepared
allowlist without running capture. File-only preparation does not authorize GPU
or imply graphics, fonts, PMREM/IBL or game-owner acceptance.
