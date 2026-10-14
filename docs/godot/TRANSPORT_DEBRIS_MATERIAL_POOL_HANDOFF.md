# Load-only private debris material pool

Date: 2026-09-27. Status: **FUNCTIONALLY VERIFIED LOAD/PREWARM
COMPONENT; NOT AN EVENT-PATH OR ADOPTION RECEIPT**. This additive transport
helper is not connected to Root, damage authority, the burn callback, physical
debris launch, main, LIVE, or an export. Existing frozen transport files were
not changed.

## Frozen files and purpose

- `transport_debris_material_pool.gd` owns a bounded, one-shot preparation
  lifecycle for an exact ordered array of `StandardMaterial3D` source
  Resources;
- `test_transport_debris_material_pool.gd` exercises the helper against the
  actual compact-sedan visual and adversarial lifecycle/content inputs;
- exact byte sizes and SHA-256 values are recorded in the companion manifest.

The actual compact input contains 72 opaque copied surfaces backed by 29 exact
source material identities. The helper still creates **72 distinct private
material Resources**. Source aliases never become shared private materials.

## Public API

```gdscript
configure(ordered_sources, generation, revision) -> Dictionary
prewarm_step(current_sources, expected_generation, expected_revision,
             max_count = 1) -> Dictionary
receipt(current_sources, expected_generation, expected_revision) -> Dictionary
take_prepared(current_sources, expected_generation, expected_revision,
              preparation_token) -> Dictionary
reset(ordered_sources, new_generation, new_revision) -> Dictionary
dispose() -> void
```

`configure` validates all sources before installing state and returns a new
opaque `PreparationToken`. Numeric generation and revision alone cannot revive
a receipt after reset or reconfiguration. `prewarm_step` permits a budget of
exactly one and duplicates at most one material per call. The final step also
performs a complete source/private validation before reporting ready.

`take_prepared` requires the current exact ordered source identities,
generation, revision, and token. It performs another complete validation, then
disconnects the pool's watchers, clears its borrowed references, and transfers
the ordered private Resources once. The pool becomes consumed. `dispose` does
not free Resources already transferred to the caller.

`reset` requires a strictly newer generation, validates replacement sources
before mutation, invalidates the old token, and starts empty. `dispose`
disconnects all source/private `Resource.changed` signals, including Resources
retained externally.

## Content and lifecycle fences

The helper records exact instance identity plus serialized type/value receipts
for stored properties and metadata. It rechecks them before ready and transfer.
It catches direct changes, silent in-place metadata container changes, private
changes, ordered replacement, and queued lifecycle changes expressed through
the API.

Metadata validation is bounded and fail closed: maximum depth 8, 32,768 total
charged items/UTF-8 bytes/packed elements, and 256 KiB per final signature.
Cycles and repeated mutable container identities are rejected, as are
unsupported Variant types, non-finite scalar/vector/color/packed values, and
oversized strings or packed arrays. Private Array/Dictionary metadata is
detached from the source.

Nested non-null `Resource` properties such as `next_pass` or textures are
rejected. This component therefore makes no false deep-clone or shared nested
Resource claim. The current tested compact materials contain no such nested
Resources. Only exact `StandardMaterial3D` inputs are admitted.

## Verification

The safe Godot 4.7.2 headless author run passed **187/187**. It covers:

- actual compact 72 surfaces / 29 exact source identities and 72 independent
  transferred Resources;
- one-copy budget, foreign generation/revision/token, consumed and stale token
  behavior;
- source replacement/property/container mutation and private mutation;
- reset, strictly monotonic generation, dispose signal cleanup, and retained
  transferred ownership;
- nested Resource, wrong material type, non-finite, cyclic, aliased,
  over-depth, over-count, over-byte, callable, and packed-array failures.

The parent and independent reviewer then ran the same frozen suite
sequentially. Both also passed **187/187**. No GPU window was opened.

## Sequential load-only cost

The author actual-compact run measured 72 preparation calls:

| Operation | Isolated headless CPU time |
| --- | ---: |
| preparation step min / true median | 0.736 / 0.8395 ms |
| final preparation + complete validation | 47.863 ms |
| separate ready receipt | 47.728 ms |
| one-shot validation + transfer | 47.638 ms |

The parent's fresh sequence measured min / true median **0.730 / 0.8015 ms**,
final validation **49.191 ms**, ready receipt **49.581 ms**, and transfer
**46.991 ms**.

The independent sequence measured true median **0.7785 ms**, final
validation/maximum **47.117 ms**, ready receipt **48.181 ms**, and transfer
**48.430 ms**. All three sequences therefore put the complete validation and
transfer work in the 47–50 ms range.

The maximum preparation sample is the final validation step, 47.863 ms. It is
not evidence that all calls have a one-copy CPU bound. The helper bounds
allocation to one new private material per step, while final validation,
`receipt`, and `take_prepared` scan the complete ordered set. For the actual
case that final guard serializes and compares all 72 source plus 72 private
signatures. `max_count = 1` bounds new Resource allocations only; it does not
bound the full CPU work to one signature.

These are isolated load-only headless timings. They do not measure an impact or
explosion frame, renderer, shader compilation, GPU, FPS, full scene, LIVE, or
exported build. All configure/prewarm/receipt/transfer work must remain in an
explicit load/preparation phase. This helper alone does not solve the rejected
~48–57 ms event-time material path.

## Integration boundary

The returned materials are only prepared storage. The helper does not prove
source callback identity or order, transparent eligibility at explosion time,
burn values, alpha/native color conversion, source replacement after callback,
surface binding, HP, RNG, authority, launch, or vehicle lifecycle ownership.
An eventual burn writer must authenticate those inputs and bind the transferred
Resources without accepting stale preparation as event authority.

No event fallback may silently duplicate materials again and claim this pool's
latency receipt. Root must explicitly schedule preparation outside gameplay
events and preserve the exact source rules before considering adoption.
