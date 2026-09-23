# Bruiser surface cache recreation — production fix, 23 September 2026

**IMPLEMENTED / CPU PASS / short root LIVE PASS, longer observation pending.**
Срочный blocker от Координатора20.
Художник21 менял только shape/save/restore участок `npc_actor.mjs`; fire/update,
vehicle pose, population scheduling и authority не менялись. Root явно разрешил
этот участок; fire child frozen. No commit, push or extra GPU tab.

## Reproduced cause

`createBruiserShape` changes private `position` vertices when a hired bruiser's
source state is presented. Surface snapshots correctly sign that active geometry.
After eviction, `npc_population.make` creates a base actor and restores the saved
surface **before** its initial `actor.update`, which would activate the bruiser
shape. The shaped signature therefore fails against the base geometry.

Actual population + actual male GLB RED reproduced the exact LIVE stack:
`npc_surface_state.validateSurfaceMesh` → `wet_clothing.validateSnapshot` →
`hero_artist14_surface.restore` → `npc_actor.restoreSurfaceState` → population make.
Identity/sex/appearance descriptor caching already worked; this is a missing
private body-shape state, not proof of a sex/garment identity swap.

## Change

Saved actor envelope now includes `bodyShape:{version:1,bruiser:boolean}`.
`restoreShapedSurface23` validates that field, prepares the recorded private shape,
then invokes the complete existing surface validator/restorer. On rejection it
restores the previous shape and rethrows the original error. It does NOT swallow
an exception, discard wounds, skip signatures, change actor identity or replay hits.

Surface payload validation still precedes surface mutation. Existing identity,
sex/height, reaction, source death and downed-state validations remain in place.
Only actual restore or shape transitions do shape work; no new per-frame scan.
An already matching shape retains the existing update early-out. Shape creation
was already required at initial `update`; recreation now performs it before restore.

Legacy V1 envelopes without `bodyShape` retain base-shape compatibility. A legacy
shaped snapshot lacking shape metadata remains rejected rather than guessed or
healed. These states are in-memory only: a full page reload recreates the cache.

## Verification

New `assets/maps/city_rebuild_v1/test_npc_bruiser_surface_reentry23.mjs`:

- Actual male/female × base/bruiser: four population eviction/recreation cycles.
- Wet clothes, a raycast clothing bullet wound, head bruise and receipt dedup
  survive recreation and actor position change; no replayed blood particles.
- Contradictory returning gender/outfit packet cannot replace saved appearance.
- 28 malformed shape/identity/sex/garment/anchor cases rejected without changing
  existing geometry or effects; valid live shape switching/restoration checked.
- Base legacy state compatibility and rejection of ambiguous shaped legacy state.
- **48 actual rendered wet-attribute/snapshot comparisons** plus attribute object
  identity across both shape toggles: PASS. Root's proposed second clone problem
  did not reproduce. The wet geometry is already in `owned` after surface creation;
  shape preparation keeps the attached wet attribute. No wet-clothing patch needed.

Existing tests PASS:

- `test_npc_surface_state.mjs` — local anchors, dry aging, death, receipts,
  7 atomic-invalid cases, independent resources.
- `test_npc_population.mjs` — 23 checks, including cache eviction, source clocks,
  actor resource limits, interpolation and explicit death/respawn.
- `test_npc_actor.mjs` — actual assets, appearance/resources, lifecycle and isolation.
- `test_mercenary_bruiser_visual.mjs` — two actual models, canonical bones and kicks.
- `test_npc_actor_appearance_resources.mjs` — template and per-actor ownership.
- Node syntax and scoped `git diff --check` PASS.

Root's independent actual-GLB review also PASS: male/female privateClone and
appearance-owned paths, wet attribute identity and 10-second drying, wounds,
receipt/no-particle replay, invalid rollback and plain/shaped legacy cases.
Review script reported by root:
`.git/ai-pipeline-local/live23/bruiser_surface_independent_review23.mjs`.
Applied runtime-only review diff is
`outputs/npc_bruiser_surface_reentry23_applied.patch` (27 lines; do not reapply).

CPU recreation samples for the complete actor including clothing/wounds were
16–29 ms in the last regression run; these are not a before/after patch benchmark.
Broken baseline aborts recreation, so its early throw cannot be used as a speed
comparison. **Производительность общей сцены не проверена.** Root owns LIVE/FPS.

## Root follow-up

Root reported a second LIVE load: centre → Kingswell, all five crew members
caught up; the previous signature exception did not recur, hero and NPC updates
continued and car entry was progressing. This confirms the fix is loaded in that
short scenario, not whole-city/FPS or complete vehicle acceptance.

Reload the combined package, repeat centre → Kingswell travel and camera/roster
cache churn, including hired bruisers. Confirm no surface-signature exception,
advancing NPC source/presentation clock, correct wet clothing and retained wounds.
Do not claim vehicle/source clock bugs independently fixed solely by this patch;
the reproduced exception can abort their enclosing Walk update.

Guard wait/detour work is paused by root's urgent instruction. Isolated files
`npc_guard_wait_detour23_candidate.mjs`, its test and captured crowded fixture
are unfinished, NOT READY and must not enter this production fix.
