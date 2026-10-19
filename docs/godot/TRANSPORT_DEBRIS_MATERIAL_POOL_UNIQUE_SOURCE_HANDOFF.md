# Transport debris material pool: unique-source candidate

Status: **functionally verified load-only candidate; performance improved, but
not event/frame/streaming ready**.

This isolated candidate starts from frozen `transport_debris_material_pool.gd`
SHA-256 `c29037e98c71cc9bed733784adf107edd58417439d721680c0a43ca0ace329d0`.
It does not replace or edit that file.

## Change

`transport_debris_material_pool_unique_source.gd` keeps a cache only for the
duration of one synchronous source validation call. The cache key is the live
`StandardMaterial3D.get_instance_id()` and the cache row also retains the exact
Resource reference. The first occurrence is serialized with the frozen
`_signature`; later occurrences of that same Resource identity reuse those
bytes.

The ordered loop still compares the cached bytes with **each surface's own
admission signature**. All private material copies are serialized and compared
individually, so 72 surfaces still produce 72 independently owned private
materials. A cache is never retained across final validation, `receipt`, or
`take_prepared`; silent in-place metadata mutation therefore remains visible at
the next boundary. `Resource.changed` remains an early sticky invalidation only.

Admission remains uncached and records an independently computed signature for
every ordered surface. Materials with attached scripts are rejected before
signature capture: scripted property getters could mutate or re-enter during
serialization and would invalidate the equivalence of a single alias read.

For the actual compact profile the complete validation work changes
from 72 source signatures plus 72 private signatures to 29 unique source
signatures plus 72 private signatures.

## Unchanged contract

- Exact ordered source identity, generation, revision, opaque preparation token,
  one-shot ownership transfer, reset, dispose and signal cleanup are unchanged.
- Each `prewarm_step` creates at most one private material.
- Nested Resources and malformed/nonfinite/cyclic/oversized Variant graphs keep
  the frozen fail-closed behavior.
- Full final validation, `receipt`, and `take_prepared` remain separate atomic
  validations. No host mutation epoch exists, so validation is not sliced or
  cached across calls.
- No burn values, callback ordering, HP, authority, debris launch, event-frame,
  GPU, FPS, or full-scene behavior is implemented or claimed.

## Verification

`test_transport_debris_material_pool_unique_source.gd` retains the frozen pool
lifecycle and malformed-input suite, loads the real compact visual and damage
bindings, and checks 72 surfaces / 29 source identities / 72 private resources.
Additional cases cover nonadjacent aliases, comparison against every aliased
surface admission signature, silent mutation between calls, explicit
`Resource.changed` sticky invalidation, equal-valued distinct Resources, and
scripted-material rejection. Actual `StandardMaterial3D` setters do not reliably
emit `Resource.changed`: a silent mutation restored to byte-identical admitted
content before validation is observationally identical and accepted. A silent
mutation that remains different is caught by the fresh signature.

Godot `4.7.2.stable.official.ed1daf0bf`, safe hidden headless runner:

- correctness-only actual compact and adversarial suite: **200/200 PASS** in
  1.08 seconds; no comparison loop;
- full suite plus 20 alternating baseline/candidate pairs: **240/240 PASS** in
  9.17 seconds;
- both processes exited and joined. No GPU window was opened.

The 20-pair isolated load-only CPU results, in microseconds:

| Boundary | Frozen median / p95 / max | Candidate median / p95 / max |
|---|---:|---:|
| configure | 24,384 / 29,821 / 33,321 | 24,050.5 / 28,448 / 28,841 |
| final prewarm validation | 45,991 / 68,767 / 76,258 | 32,845.5 / 35,408 / 42,243 |
| receipt | 44,967 / 53,133 / 53,393 | 31,838.5 / 34,183 / 34,722 |
| take | 45,350.5 / 48,473 / 54,253 | 32,801.5 / 34,106 / 34,315 |

The candidate reduces median complete validation by about 28–29% and narrows
the p95/max tails in this isolated run. A 31–35 ms receipt or transfer is still
too expensive for event-frame or streaming use. Adoption, if any, is limited to
an explicitly scheduled load/prewarm phase. No full-scene FPS measurement exists.

For a short correctness-only rerun, set
`MAFIOZI_TRANSPORT_UNIQUE_SOURCE_CORRECTNESS_ONLY=1` only for the safe runner
process and invoke
`tools/godot/run_transport_test.ps1 -Resource res://scripts/tests/test_transport_debris_material_pool_unique_source.gd -TimeoutSeconds 3`.
That mode executes the actual compact 72/29/72 path and all adversarial/lifecycle
checks, but records the 20-pair comparison as skipped. The environment variable
must be removed after the runner returns. It has no production consumer.

An optional fused final-and-take API is intentionally excluded from this small
candidate. It requires a separate ownership/API review even though one
synchronous validation followed immediately by transfer can be atomic.
