# NPC fully dry surface fast path — 2026-09-20

Status: READY on disk; live game/FPS verification pending with NPC lead. Small redundant-work removal, not a demonstrated solution to severe lag.

## Scope

- `artist14/wet_clothing.mjs`: return before world-matrix traversal only when waterLevel is null and no registered mesh has wetness. Existing uniform updates and sample-clock drain remain before the guard.
- `test_npc_wet_dry_cost.mjs`: CPU-only comparison of baseline (exact guard removed in memory) and candidate in isolated module graphs, actual male/female GLBs and complete actor.update calls.
- No surface host, wounds, NPC behavior, renderer or population limits changed. No game reload or additional GPU tab.

The production surface host already updates world matrices before wet.update. Water contact and active drying continue through the existing vertex path unchanged. This optimization relies on that host contract; it does not preserve the formerly redundant matrix-refresh side effect for arbitrary standalone callers.

## Validation

44 exact parity checkpoints PASS: wet arrays and versions, hasWet, shader uniforms, matrices, whole surface snapshots, particles and sample clocks. Covers moving dry actors, partial sample intervals, immersion, water-level changes, leaving water, drying to zero, restore/reset, fresh immersion and confirmed chest hit.

Per dry actor test: wet-specific matrix passes 24 -> 0; sample drains remain 24. Surface serialization regression PASS including restore, wounds, dry aging, no replay particles and invalid input cases.

Independent full actor CPU ABBA rerun, milliseconds p50 / p95:

| Actor | Baseline | Candidate |
| --- | --- | --- |
| Male | 0.1637 / 0.2272 | 0.1610 / 0.5556 |
| Female | 0.1278 / 0.1451 | 0.1216 / 0.1439 |

Short samples are noisy, particularly male p95. Only elimination of redundant traversal is established; no reliable whole-actor speedup or game FPS gain is claimed. This does not explain the reported ~8 ms surface cost by itself.

Commands from project root:

```text
node assets/maps/city_rebuild_v1/test_npc_wet_dry_cost.mjs
node --import ./assets/maps/city_rebuild_v1/test_npc_death_offline_setup.mjs assets/maps/city_rebuild_v1/test_npc_surface_state.mjs
```
