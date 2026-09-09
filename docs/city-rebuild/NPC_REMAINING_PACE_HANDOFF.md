# Remaining humanoid source pace — 2026-09-10

Artist14 bounded follow-up to `ARTIST15_NPC_PACE_AUDIT.md`. Shared edits are limited to movement expressions in `world.html`; Artist15 models, portraits and menus are unchanged.

The native conversion remains 4.1 metres per source tile. Existing `_npcPacedSpeed` supplies maximum walking 4.6 m/s and running 7.8 m/s. Slower requested movement stays slower.

Applied to:

- Melee chase route and its local obstruction bypass, which share `chaseSpeed`. The old minimum 4.25 tiles/s produced 17.425 m/s; it now respects the run cap.
- Empire retreat and normalized tactical movement: run cap. Peaceful leader escort, routine/recruitment/arrival routes and ordinary activity destinations: walk cap. Escort of an actively fighting, panicking or enemy-engaged leader can use the run cap. Existing route keys, callbacks, admission, targets and AI decisions remain untouched.
- Interior major/business guards: combat and retreat use the run cap, patrol and ordinary walking use the walk cap. Ordinary steps also stop at their target instead of overshooting it.
- Bank panic: cap the combined escape and crowd separation velocity, so avoidance cannot add speed beyond the run maximum. Existing direction, collision checks and exit/report transition remain.

No global cap was added to `_npcAdvanceRoute`; non-human callers, cars, dogs, server combat and teleport/recovery mechanisms are unchanged.

## Validation

`node test_remaining_npc_pace.mjs` runs the actual source `_npcAdvanceRoute` for melee pursuit at 30/60/144 FPS, normal and extreme actor speeds; checks source escort/retreat/destination expressions; executes the actual bank panic velocity expression including strong separation. PASS. Running against the saved pre-change source fails with 17.425 m/s.

Also PASS:

- `test_npc_hero_pace.mjs`
- `test_service_npc_hero_pace.mjs`
- `test_npc_witness_reactions.mjs`
- `test_murder_witness_observation.mjs`
- `test_npc_life_system.py`
- `test_police_murder_custody_transport.py`
- `test_police_murder_custody_stress.py`
- `test_empire_route_generation_dom.js` — 12/12 route fingerprint, stale-generation isolation and arrival idempotency checks.

The phone regression's old exact adjacency assertion was updated: the new civilian-trip hook legitimately sits between cancellation and unique-NPC processing. The test now verifies the semantic order, cancellation before the dead early exit. No phone source change was needed.

Parent owns `/walk` gateway and live police/civilian scenarios. These tests establish source movement bounds and reaction contracts, not a claim that every map/interior scenario has been visually exercised.
