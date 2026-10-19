# Hardened portable materializer V2 — source-only candidate

27 September2026. Separate successor; frozen V1/verifier unchanged. No production,
main/player, Godot/native/import/GPU/Git changes or actual publication release.

```powershell
node tools/godot/map_editor_publication_materializer_v2/test_materialize.mjs
```

**91 checks PASS**, exit0, about2.76seconds. Includes previous65 conformance
assertions, both reproduced adversarial attacks, callback reentry/host override
guards and real partial-write failure injection. Original V1 SHA remains
33F2E0E45A3BE19EC720A0B271A81B55088FE9C0AB502C70FBC04BC59C194633.

Actual inventory: integrity=true, ready=false, **53 HOLD**, output writes0.
Directory entries unchanged after actual refusal. No actual user approval,
texture/raster capture, installed authority or ready MapBundle was manufactured.

## Exact successor differences

- Native `util.types.isProxy` refusal BEFORE any prototype/descriptor reflection:
  closure root/nested values, configuration, trusted packet, validator function,
  collection/source whitelist. Proxy traps observed0.
- Descriptor-only plain host packet reads. All host fields/getters are inspected
  without invocation; inherited/custom-prototype/accessor packet bindings refuse.
- Exact Map/Set native prototypes, no own properties/overrides and no subclasses.
  Collections copied using captured native entries/values and iterator-next
  functions, not caller `.get/.has/iterator` implementations. Overrides invoked0.
- Deep, bounded, descriptor-safe capture receipt snapshots. Entire CURRENT host
  packet is captured before ANY admission equality comparison. Comparing the
  detached copies cannot call a late capture getter/toJSON. Attack getter calls0.
- Host configuration identity checks bind reader/trusted packet/approved SHA and
  output root. Callback replacement or current packet accessors refuse prewrite.
- Both reader and validator recursive publish calls refuse under the same
  per-instance busy gate; outer valid synthetic operation may safely finish.
- Capture snapshots share one bounded data budget; closure data remains bounded
  at depth64,500000 values,4096-character strings. This is not a general parser.

Late getter regression: validator replaces a receipt with getter that removes
`ground-owner`. V1 publishes with missing gate; V2 rejects before getter executes,
before output directory creation. Proxy regression: V1 executes7 traps and accepts
request; V2 rejects with0 traps. Previous ordinary corruption/path/ready flag,
SHA/approval/validator/source-gate rejection and exact/deduplicated blob IO remain.

## Host API and boundaries

`createMaterializer(configuration)` returns synchronous `publish(closure)`.
Configuration is a plain, non-Proxy, descriptor-only host packet containing:

- `readBlob`: explicit non-Proxy source-whitelist reader returning original bytes;
- `trusted`: plain packet with strict native `sourceManifests:Set`,
  `familyManifests:Map`, `runtimeGates:Set`, `textureCaptures:Map` and genuine
  installed `validateMapBundle` function (undefined can only produce refusal);
- `userApprovedMapBundleSHA`: exact user-approved, installed-validator-admitted
  map snapshot SHA, not a flag derived from request data;
- `outputRoot`: absolute existing nonredirected host directory, not user-data path.

The host still owns actual source/importer/runtime/user-approval freshness for
the whole synchronous call. This is **not an arbitrary-JavaScript sandbox**:
trusted Node realm/intrinsics must not be globally monkey-patched by owner code;
callbacks must not perform external writes or independently publish through a
different handle. Captured native collection operations reject supplied-instance
overrides, not hostile replacement of all global filesystem/language intrinsics.
No generic trust bool, script-source equality or Set constructed from map JSON
can issue actual game authority. Per-instance reentry is not a process-global lock.

Optional `sourceWhitelistReader(Map)` additionally rejects Proxy/custom collections
and source receipt data, then checks admitted absolute regular file identity path,
length/SHA on every read. It never discovers filesystem files from map userdata.

## IO ordering and retained failures

Unchanged frozen `verifyClosure(...,{requireReady:true})` must succeed before ANY
publisher directory/file creation; exact approved MapBundle, safe current host
receipt equality and original buffered SHA checks follow, also prewrite. Only
then create a unique validated host-root directory, exclusively write declared
`blobs/<sha>.<json|glb|bin|rgba>` original bytes, fsync/hash readback, canonical
manifest.json and readback. No scripts/.godot/UID/arbitrary userdata paths.

Injected second-blob open failure: one original blob retained, no manifest,
`ok:false,wrote:true,partial_retained:true`. A following successful publication
uses another unique directory. No automatic destructive cleanup. No crash-atomic
rename/durable recovery guarantee: caller must require successful return and
importer admission, never infer publication readiness from directory existence.

Positive cases remain clearly synthetic:9901 fabricated fixture keys,196 references
to one tiny GLB, one shared4-byte buffer, eight synthetic family manifests, one
synthetic approved map; eleven unique blobs. These are schema/dedup/IO proofs,
not actual242+9394+265 gameplay approval, visual parity or portable release.

Frozen successor hashes:

- materialize.mjs:0771551D796A24D3A7A7012E9868197F010F221B891E33C558AF01A280449205
- test_materialize.mjs:296A6855B4E1F8A1DCF672003DC7110D8090E5BB19305531B07F82AEEE8ACC9A

Root independent review/admission remains required. Actual export must preserve
all53 HOLD until genuine approved map and remaining owner/texture/GPU/importer
contracts are admitted by their respective owners.
