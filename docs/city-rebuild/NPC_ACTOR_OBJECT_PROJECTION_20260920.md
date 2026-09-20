# NPC object-only projection: small allocation reduction

Approved scope by Artist19: add one-pass getActorObjects and replace only
the mercenary getPickRoots/getRoots NPC object projections. No world source
snapshot changes, no reusable writable shared arrays, no behavior/death edits.

## Actual-source reproduction

npc_population.getActors constructs filter array + fresh row objects + mapped
array. The two walk mercenary root callbacks immediately map these rows to
row.object, producing a third array and discarding the wrappers.

The test extracts the actual old getter and actual new method, comparing
object reference identity/order across eight cases: empty, reordered,
duplicate rows, missing/pending actor, hidden actor, cached-not-in-snapshot,
replaced actor and caller-owned output mutation/retention. It also asserts
only the two scoped projections use the new method and getNpcs retains the
old full-data getter. Both runtime files pass syntax checks.

71 admitted actors in a72-row fixture: old71 row objects +3 arrays per call;
new0 wrappers +1 fresh array. Main CPU p50 0.00394→0.00149 ms. These are
structural allocation counts, not heap bytes or a measured GC reduction.
This is a small hygiene improvement, NOT an explanation/fix for severe lag.

## READY manifest

- npc_population.mjs: getActorObjects plus returned API member; getActors
  remains untouched, membership still latest+actors.has(id), visibility is
  NOT used for filtering.
- walk_preview.mjs: only the two object projections inside mercenary creation.
- test_npc_actor_object_projection_prototype.mjs: now extracts both actual
  runtime getters (filename retains its experimental origin).
- This handoff.

Fresh output array belongs to the caller. No snapshot/row reuse, AI state,
world.html, deathRecord, blood, actor geometry, density or collision changes.
Skin memo remains defaultOFF pending Artist19 LIVE A/B; no new GPU tab or
commit/push performed. This getter change is CPU-tested, not LIVE-accepted.
