# Debris material pool exact-comparator experiment

Date: 2026-09-30. Status: **FUNCTIONALLY VERIFIED / PERFORMANCE REJECTED / DO NOT ADOPT**.

This additive candidate tested whether the frozen load-only material pool's 47–50 ms full-validation spikes could be reduced without weakening its mutation, lifetime, token, or one-shot ownership rules. It is not connected to damage, explosions, Root, main, physics, rendering, LIVE, export, or Git. The frozen pool `transport_debris_material_pool.gd` remains byte-identical at `c29037e98c71cc9bed733784adf107edd58417439d721680c0a43ca0ace329d0`.

## Candidate files

- `godot/mafiozi_walk/scripts/transport/candidates/transport_debris_material_pool_exact_compare.gd`
  - 20,081 bytes
  - SHA-256 `6d76e4b40b4fc7a2e7e48f039eebbc4f56f24ac0ccfadecfb41ce52323ef1fc3`
- `godot/mafiozi_walk/scripts/tests/test_transport_debris_material_pool_exact_compare.gd`
  - 17,443 bytes
  - SHA-256 `178bbce693ea13b529bd24a4e3c84b33bcc6acf01df3df4668355d3a8dea871c`

Exact sizes and hashes are repeated in the companion manifest.

## Experiment boundary

The candidate keeps the frozen public API and lifecycle:

```gdscript
configure(ordered_sources, generation, revision)
prewarm_step(current_sources, expected_generation, expected_revision, max_count=1)
receipt(current_sources, expected_generation, expected_revision)
take_prepared(current_sources, expected_generation, expected_revision, preparation_token)
reset(ordered_sources, new_generation, new_revision)
dispose()
```

It still creates one independent private `StandardMaterial3D` for every surface. The actual compact-sedan case remains 72 ordered surfaces, 29 exact source identities, and 72 private Resources. Allocation remains limited to one material per prewarm call.

At admission the candidate records detached typed property/metadata snapshots and performs the frozen 256 KiB serialized-size guard once. Later full validation compares supported Variant graphs directly, including raw signed-zero distinction, rather than serializing the complete material receipt again. Final prewarm, `receipt`, and `take_prepared` remain full atomic scans. No multi-call validation result grants transfer authority.

This atomic boundary is intentional. Incrementally validating content over several calls is unsound for the actual materials: Array/Dictionary metadata can mutate in place without emitting `Resource.changed` after an earlier slice and before transfer. No authoritative host mutation epoch currently closes that window.

The candidate preserves finite-value, depth, item, byte, Resource, callable, cycle, repeated-container identity, ordered identity, source/private mutation, generation/revision, opaque token, reset, dispose, consumed, and transfer guards. Typed Array/Dictionary metadata is rejected fail closed because the direct comparator does not claim typed-container descriptor parity. This is an intentional tightening in the rejected candidate, not a production behavior change.

## Correctness

Godot 4.7.2 safe runner result: **232/232 PASS**, exit 0.

Coverage includes the frozen lifecycle/adversarial cases plus:

- actual 72-surface/29-source compact visual and 72 independent transfers;
- exact signed `+0.0` versus `-0.0`, constructed from raw IEEE bytes;
- silent in-place source and private metadata mutation;
- typed Array and typed Dictionary fail-closed admission;
- NaN, Resource, cyclic, aliased, oversized and unsupported Variant rejection;
- 20 alternating frozen/candidate measurements using the same actual sources.

## Final 20-pair sequential timings

All values are isolated headless CPU microseconds. p95 is nearest-rank sample 19 of 20 after sorting.

| Operation | Frozen median / p95 / max | Candidate median / p95 / max |
|---|---:|---:|
| Configure | 25,840.5 / 26,919 / 28,115 | 41,550 / 43,085 / 43,962 |
| Final prewarm + full validation | 48,676.5 / 52,301 / 53,077 | 197,641.5 / 209,427 / 226,033 |
| Ready receipt | 48,054.5 / 53,940 / 57,876 | 191,448 / 204,077 / 204,371 |
| One-shot take | 48,273 / 53,168 / 59,980 | 193,636.5 / 201,312 / 204,667 |

The candidate is roughly four times slower for every full validation boundary. GDScript recursive Variant traversal costs far more than the engine's native `var_to_bytes` implementation. It does not optimize the frozen spike and must not be adopted.

The single author candidate sequence reported final validation 190,626 µs, receipt 195,083 µs, and take 190,995 µs. Ordinary one-material candidate prewarm calls had median 2,897 µs; the final call remained the complete scan.

## Limits and decision

- **PERFORMANCE REJECTED / DO NOT ADOPT.** The frozen pool remains authoritative.
- The experiment does not provide a sound incremental authorization API; it demonstrates why such a receipt needs a sealed host mutation epoch or immutable source graph.
- CPU timings are load-only component measurements. They are not explosion-frame acceptance, renderer/GPU cost, full-scene FPS, LIVE, or export evidence.
- No content, physics, collision, visual, material count, source callback rule, or event order was removed or weakened to improve cost.
- No production file was modified.

