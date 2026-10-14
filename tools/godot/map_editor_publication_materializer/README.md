# Portable materializer — source-only, actual publication remains HOLD

27 September 2026. NEW package; frozen publication_closure verifier/audit/schema
unchanged. Node file-only tests, no Godot/native/import/GPU/main/Git activity.

```powershell
node tools/godot/map_editor_publication_materializer/test_materialize.mjs
```

Result: **65 checks PASS**, exit0, about2.45 seconds. Actual admitted inventory:
integrity=true, ready=false, **53 HOLD**, materializer output writes=0. Directory
entry snapshot unchanged after actual refusal; no actual publication folder,
approved map or missing raster capture was manufactured.

## Host API and admission boundary

`createMaterializer({readBlob,trusted,userApprovedMapBundleSHA,outputRoot})`
returns one synchronous `publish(closure)` method. These arguments are explicit
configure-time trusted host resources/callbacks, never fields from user map JSON.

- `readBlob(portable)` is a source-owned whitelist reader returning original
  Buffer bytes. The materializer only passes declared canonical paths, never
  sourcePaths, arbitrary file names or paths chosen by map userdata.
- `trusted` is the ORIGINAL frozen verifier admission contract: exact source
  manifest Set, family manifest Map, installed runtime/importer gate Set,
  original texture captures and actual `validateMapBundle` callback.
- `userApprovedMapBundleSHA` binds the exact map snapshot actually approved by
  the user and admitted by the installed importer/baseline/ground validator.
  No default map, approval flag, dummy validator or substitute state is issued.
- `outputRoot` is an absolute, existing, nonredirected host directory. The
  publication request supplies NO output path or directory name.

The caller must own freshness/lifetime of installed owner and importer receipts
throughout this synchronous call. This module cannot prove native script-load,
GPU, gameplay, traffic/nav or authority state by itself. Set membership is the
existing closure contract, not a new authority capability fabricated here.
Changed receipt sets/maps/validator identity during reader/validator callbacks
refuse before writes. Reentrant publish also refuses. No owner callback is made
between the successful admission postflight and the final synchronous file IO.

`sourceWhitelistReader(Map)` optionally builds a reader from explicit trusted
receipts `{source:absoluteRegularFile,kind,sha256,bytes}` keyed by portable path.
It rejects unlisted paths, redirected/nonregular files and changed source bytes.
The Map is source-owner configuration, NOT reconstructed from publication JSON.

## Write ordering and bytes

1. Reject executable/accessor/custom-prototype/oversized request data and detach
   the closure from caller mutation.
2. Capture original bytes through the explicit source whitelist; call unchanged
   `verifyClosure(...,{requireReady:true})` including actual MapBundle validation.
3. Require exact approved MapBundle SHA, unchanged host admission receipts and
   still-exact buffered hashes. Any refusal so far: **no mkdir/files**.
4. Resolve and validate host root; create a unique `map-publication-*` directory.
5. Exclusively create exact declared `blobs/<sha>.<json|glb|bin|rgba>` files,
   fsync and hash-readback original bytes. Shared blobs are written once because
   the frozen verifier rejects duplicate identities and permits shared references.
6. Exclusively write canonical `manifest.json`, fsync/readback; return success.

No scripts, .godot, UID cache, importer-generated scenes or arbitrary user path
can be written. Manifest canonicalizes inventory key ordering only; resource
JSON/GLB/buffer/raster blobs remain their exact source bytes, not re-encoded data.

Failure AFTER creating a unique output folder returns `ok:false`, `wrote:true`,
`partial_retained:true`, destination/error. It deliberately retains the exact
partial package for diagnosis and does not claim publication success or delete
material. There is no crash-atomic directory rename/recovery contract or external
publishing/network call. Only a returned successful package may be offered to
the next trusted importer; the module never mutates the installed game.

## Conformance coverage

Actual inventory negative proof retains all53 HOLD and original missing captions/
rasters/PMREM/installed owner gates/absent approved MapBundle. Unsafe path aliases,
ready flags, corrupt bytes, missing validator/source admissions, mismatched user
approval, changed runtime/source receipts, getter userdata, oversized data and
reader reentry all refuse without new output entries.

Positive test uses ONLY tiny synthetic-schema admissions:9901 synthetic keys and
196 references to ONE tiny generated GLB, shared4-byte buffer, eight synthetic
manifests and one synthetic approved map. Eleven unique blobs written twice to
two unique directories prove deduplication, exact bytes, canonical manifest,
exclusive creation and hash readback. This is NOT the real242+9394+265 map, NOT
actual runtime approval, NOT fabricated actual raster completeness and NOT a
production portable release. Synthetic test artifacts remain under the explicit
`outputs/publication-materializer-conformance-*` directories; receipt names the
last run's directory.

## Frozen source hashes

- materialize.mjs:33F2E0E45A3BE19EC720A0B271A81B55088FE9C0AB502C70FBC04BC59C194633
- test_materialize.mjs:7D596BA0569FB90A8D915A5EE9582573AA8A0F83C1FF31F94F0334CAFD8FD391
- unchanged closure.mjs:B5B9A630FF4BB0738B0715EBC7B1E17F2B72E14A42C106F28D9521794E65ED5B

Remaining integration: real user-approved joint MapBundle, all actual texture/
sampler/environment and installed importer/owner admissions, source lifecycle
freshness receipt, trusted output host hookup. Current actual export must remain
HOLD until those gates are satisfied by their real owners.
