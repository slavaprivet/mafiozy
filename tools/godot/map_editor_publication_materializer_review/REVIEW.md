# Frozen materializer adversarial review — two reproduced boundaries

27 September2026. Frozen source hash remained
33F2E0E45A3BE19EC720A0B271A81B55088FE9C0AB502C70FBC04BC59C194633.
No frozen module, production, main, Godot import/native, GPU or Git changes.
Separate Node-only probe, ~0.39seconds, **8 assertions PROBES_CONFIRMED**.
This is NOT a claim that the reviewed module passed the negative expectations.

```powershell
node tools/godot/map_editor_publication_materializer_review/probe_review.mjs
```

Prerequisite: synthetic materializer test receipt/artifacts from its completed
65-check conformance run. Probe reads only that synthetic data, not actual
ready resources. All writable test output is a new unique
`outputs/publication-review-*` directory, retained for evidence.

## 1. Mutable host-receipt comparison executes a late getter — P2

Location: materialize.mjs `sameMap` canonical comparison, and admission condition
ordering in `publish` immediately after exact MapBundle approval check.

Sequence using valid synthetic-schema receipts:

1. Host textureCaptures has `{width:1}` under an unused probe key. Configure-time
   receipt snapshot is plain data and passes `dataCopy`.
2. During actual synchronous validator callback, replace current receipt with
   `{get width(){ runtimeGates.delete('ground-owner'); return1; }}`.
3. Postflight checks sourceManifests and runtimeGates successfully.
4. Later `sameMap(textureCaptures,admitted.textureCaptures)` canonicalizes the
   current replacement and invokes its getter. It returns equal JSON while
   removing a runtime gate which was already checked.
5. Publication returns `ok:true,wrote:true` with `ground-owner` absent.

Probe observed getter count1 and successful output. This requires a mutable
trusted-host receipt/callback, NOT arbitrary map JSON; it does not bypass the
actual53 HOLD by itself. Nevertheless it disproves the stronger guarantee that
all changed host admissions during callbacks are safely rejected before writing.
An unused receipt demonstrates the comparison side effect independently of
real image capture completeness. It is not fabricated actual texture admission.

Recommended narrow successor (do not patch frozen source blindly): capture the
entire CURRENT host admission packet as strict non-executable plain data before
comparing anything; reject accessors/proxies/custom collection overrides. Then
compare the two callback-free copies with native Map/Set operations. Validation
and current-packet capture must not invoke arbitrary property getters/toJSON or
overridden Map/Set.has/iteration. Merely repeating runtimeGates at the end leaves
new getter ordering attacks and is not a complete fix.

## 2. Proxy request executes traps and is accepted — P2 boundary

Location: materialize.mjs `dataCopy` prototype/descriptors inspection.
Direct property accessors are correctly rejected before invocation, but an
otherwise valid closure wrapped in a Proxy is not rejected. Prototype, own-key
and descriptor inspection executes **7 traps**; the publisher then succeeds.

Actual request payloads must be plain parsed JSON. A JSON wire input cannot
contain these executable traps. If that restriction is an explicit host-only
contract, record it; otherwise the API/documentation's broad executable-data
refusal is not enforced. A hard Node native `util.types.isProxy` refusal before
reflection, applied recursively to request and current host receipt data, is a
practical successor prerequisite. Strict native collection identities are also
needed if collection custom methods are outside the trusted callback contract.
No generic JavaScript reflection is a secure sandbox against hostile Proxy code.

## Confirmed boundaries

- Current per-instance `busy` prevents direct reader/validator reentry (original
  conformance result). It is not a process-global lock across separately created
  publishers; host serialization remains required where relevant.
- Detached original Buffer snapshots/hash validation protect against ordinary
  reader-owned byte mutation and path substitution. Resource bytes are exact,
  not serialized from the decoded validator objects.
- Injected second-blob open failure writes one real original blob, returns
  `ok:false,wrote:true,partial_retained:true`, retains destination and creates no
  manifest. A subsequent publication succeeds in a different unique directory.
- Frozen source remains byte-identical after all probes.
- No crash-atomic directory commit is promised. Failures after manifest creation
  or crashes can leave a manifest-bearing partial directory; callers must use
  successful return/admission and never publish by directory existence alone.
- Actual inventory remains blocked by its53 holds; no actual MapBundle/source
  approval, missing raster, gameplay owner or production release was fabricated.

Root should decide a hardened successor/admission contract before integrating
this materializer with dynamic host receipts. No GPU/FPS or native integration
claim follows from these small file-only synthetic probes.
