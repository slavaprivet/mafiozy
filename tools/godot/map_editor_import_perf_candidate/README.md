# Import provenance CPU candidate — isolated, no production change

Measured actual native authored242/procedural9394/transport265 map, 9901→9904
objects. Original196 GLBs headless imported once, same source bytes and settings,
three legitimate copies, actual core Controller, MapStore save/fresh factory.
Frozen V3/V1, factories, source metadata, materials, geometry, LOD, colliders,
owner, lifetime and rollback logic remain unchanged.

## Measurement first, changes second

Profiling wrappers isolated the hotspot: procedural provenance56,381 checks
took6.320827s; geometry-owner prepare20 calls only373us. Controller prepared
document1.684499s, composite partition2calls2.149122s. These are inclusive
times: they overlap and must not be added. Baseline profiling overhead is not
an FPS result or the final A/B timing.

Streaming exact immutable-key admission removes multiple deep copies whose
only purpose was to erase transform and construct a raw-source variant.
Document.validate_record is retained first, including complete safe JSON/depth/
finite/record validation and deep detached output. Key count/name/type, source
canonical OR admitted raw source, model, template, transform extras and frame
constraints remain exact. Nothing serializes/normalizes the caller; nothing
skips dry-run or real owner approvals. No cache or dirty-version shortcut.

Optional exact comparator avoids allocating8-byte arrays for equal NONZERO
float64 scalars. Equal nonzero doubles have identical representation; zero
sign and NaN payloads fall back to original byte comparator. Mixed int/float
keeps original int64 range/int conversion rules. Deterministic30351 cases match
the original reference, including +0/-0, NaN payloads, infinities, subnormals,
int64/int53 limits and10k seeded arbitrary double patterns/adjacent ULPs.
No epsilon or float32 truncation is used for opaque metadata.

## Actual results

Three sequential uninstrumented A/B pairs, each30718 checks PASS:
baseline install14.976113/15.593799/15.430803s;
candidate14.333421/13.231541/13.792279s.
Median15.430803→13.792279s, saving1.638524s (**10.6%**).
Verification median578750→577930us, effectively unchanged. Only3 pairs;
background desktop/other CPU work can vary timing. No GPU/FPS claim.

Standalone original procedural mutation/owner/rollback/precision/checkpoint/
five-clone-save-freshload suite9458 PASS. Original transport equivalent852 PASS.
All six uninstrumented actual combined Controller/save/native-fresh tests PASS.
Controller, composite and factory behavior is inherited unchanged; only the
two narrowly scoped child registry `_check` methods are overridden.
The parent's later MapDocument header optimization is NOT in this comparison.
It can be combined separately and must be measured again on identical inputs.

benchmark.json records raw timings, count and exact scope. Shadow/source
resource parity and true gameplay/GPU gates remain from previous handoffs.

## Constructor/API compatibility and integration boundary

`res://procedural_registry_perf.gd` extends frozen
`res://scripts/procedural_registry.gd`; instantiate.new()/configure(factory,
trusted_owner) exactly as V3. `res://transport_registry_perf.gd` extends frozen
`res://transport_registry.gd`; same V1 constructor/configure and public APIs.
Both preload `res://provenance.gd`, which preloads `res://exact_equal.gd`.
Exact helper references original `res://scripts/map_editor/trusted_json.gd`
for special IEEE cases. Do not replace the shared core helper with an
unreviewed global variant. This is a four-file optional subclass candidate,
not a mutation of original registry source or authority policy.

Root may explicitly opt into these four files in a new source assembly and
select new constructors. Full Controller/precision/mutation/rollback tests
remain required. Authored registry, Controller and MapDocument not patched.
No main/player/res/GPU/Git changes are authorized by this isolated candidate.

## Reproduce from source

node tools/godot/map_editor_import_perf_candidate/stage.mjs --check
node tools/godot/map_editor_import_perf_candidate/stage.mjs --stage
The stager checks frozen base registry hashes, source-verified original full
assembly closure, no cache/UID copy. It creates only a new outputs subdirectory.
Use approved Godot console --headless --editor --path THATPATH --import once,
then sequential --headless scripts:
- res://test_full_registry.gd — unchanged baseline30718
- res://test_perf_full.gd — candidate30718
- res://test_exact_equal.gd —30351 reference comparisons
- res://test_perf_procedural_regression.gd —9458
- res://test_perf_transport_regression.gd —852
Profile separately with test_profile_full.gd; wrapper timing adds overhead.
Only the semantic count is deterministic; hardware timings are measurements.
Stager records current core source hashes: parent core changes may intentionally
change absolute timings; always compare both variants from the same closure.
