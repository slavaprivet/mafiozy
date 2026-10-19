# NPC blast parts — isolated evidence 20, 2026-09-20

**Latest:** the prototype now uses incremental baking, absolute event TTL and immutable-geometry WeakMap caching, with [preparation and latency reduction](NPC_BLAST_PARTS20_PREPARE.md) and [optional shared-budget ground integration](NPC_BLAST_PARTS20_GROUND_INTEGRATION.md). See also the [incremental lifecycle contract](NPC_BLAST_PARTS20_INCREMENTAL.md). The synchronous prototype description and measurements below are historical baseline evidence; `npc_blast_parts_sync_reference20.mjs` is retained only for exact regression comparison.

Scope assigned by Coordinator20/NPClead19: reuse actual NPC geometry for confirmed fatal blast presentation. No production import, source HP/dead/root changes, browser or GPU run. Blood/drips belong to 19; recovery/actor animation belongs to agent2; source damage/death binding belongs to Coordinator20.

## Existing paths and the missing binding

- `world.html:25087–25145`: `bodyPartFx` already exists, cap **12 records**, lifetime **8000 ms**. `_maybeSeverLimb` randomly chooses one of four limbs from weapon chance, damage/remaining HP, and excludes `_invulnerable`/`_keyNpc`. It changes `_severMask` and sometimes `_forcedCrawl`; this is not a universal confirmed blast death receipt.
- `world.html:55300–55309`: source prunes expired detached parts using their authored lifetime. Preserve this source-owned expiration.
- `world.html:71104–71115`: bridge exposes bounded `goreFx` with id, r/c, velocity/spin, part, age/life, role/faction/skin. It has **no targetId, death key, damage event ID or confirmed semantic cause**. Position/role/appearance cannot safely identify an actual dead actor.
- Root `three_preview.js:3225`: existing parts are an instanced **BoxGeometry** and two Icosahedron chunks, cap **12/24**. `:5271–5276` admits `dynamic.goreFx`; `:5682–5705` animates flight, settles on a fixed ground plane and caches settled matrices. This is reusable lifecycle evidence, not authored male/female limb geometry.
- `assets/maps/city_rebuild_v1/npc_population.mjs:91,113,175`: actor surface state persists across release and snapshot interruption. New effects must survive actor disposal independently and deduplicate the same source death after re-entry.
- `assets/maps/city_rebuild_v1/blast_response.mjs:9,23–29`: bounded explosion queue (16, process 4/update), world/glass/hero/vehicle visuals. It deliberately avoids unrelated NPC scene traversal. Do not infer NPC death from spatial proximity to this visual effect.

The current actual GLBs have material-separated skinned meshes, not independent severed limbs. Male/female share a 28-bone humanoid layout. Existing Artist14 hit/fall/dead surface does not split those meshes. `goreFx` is not currently consumed for actual GLB fragments in Walk.

## New isolated prototype and regression

`assets/maps/city_rebuild_v1/npc_blast_parts_prototype20.mjs` bakes the current visible pose, assigns every source triangle to the strongest of six bone regions (torso/head/two arms/two legs), retains UV/material appearance and creates static fragments. Existing rigid appearance accessories follow their attachment bone. Mounted weapon and wound meshes are excluded. No new bitmap or per-frame skeleton is introduced. Texture handles are cloned while image data are shared, so source disposal does not destroy effect handles.

Admission requires a host-supplied receipt with exact actor ID, event ID, death key, `confirmed: true`, `deathConfirmed: true`, `cause: 'blast'`, finite origin and impulse. These booleans are a prototype input contract, **not authentication**. The integration host must derive them from accepted damage. Replay of an event or the same death via another event is denied. Receipt-capacity exhaustion fails closed; old evidence is not evicted to permit replay.

Bounds: 2 simultaneous victims, 36 meshes/victim, 20,000 source triangles/victim, 32 cached topology layouts, 256 receipt keys, 8-second lifetime. Topology classification is shared by matching skin/index/bone-region arrays, including cloned appearance geometries. Material handles are reference-counted; fragments are disposed on expiry/reset. Prototype time is seconds; source age/life is milliseconds.

Run: `node assets/maps/city_rebuild_v1/test_npc_blast_parts_prototype20.mjs` — **PASS** on the actual GLB assets and production appearance function:

| Appearance | Parts | Meshes | Triangles | Last CPU admission ms |
|---|---:|---:|---:|---:|
| Male civilian | 6 | 28 | 12,384 | 30.639 |
| Female civilian | 6 | 23 | 11,368 | 18.835 |
| Leila | 6 | 22 | 11,248 | 11.582 |
| Marat | 6 | 28 | 12,384 | 15.271 |
| Male police | 6 | 32 | 13,056 | 10.399 |
| Female police | 6 | 28 | 12,208 | 9.521 |

Negative cases: unconfirmed/nonfatal/bullet/wrong actor/NaN impulse, event replay, same death with different event, third concurrent victim. Asserted source surface/root/yaw/bone positions/quaternions/scales and mounted weapon unchanged; all admitted triangles retained once; no extra skinned meshes; actor disposal followed by a 30-second update gap leaves zero active effects/material leases. The mounted test weapon has actual mesh geometry and its material is absent from fragments.

Two plain male victims in the update microbenchmark: 12 moving groups, 34 meshes; 60 updates p50 **0.0057 ms**, p95 **0.0345 ms**. Appearance cases would require up to 64 extra meshes at the tested cap of two. Material reuse does not batch draw calls. Admission **9.5–30.6 ms** can hitch, and exact JSON topology keys still allocate on admission. These are CPU microbenchmarks, not FPS or GPU measurements. **Производительность общей сцены не проверена.**

## Minimal integration contract for the owners

1. At the accepted damage/death transition, source emits one stable receipt `{targetId, deathKey, damageEventId, cause: 'blast', confirmedDeath, origin, impulse, ageMs, lifeMs}`. Boss/police/civilian appearance is irrelevant to eligibility after confirmed death; this must not bypass authoritative invulnerability/HP rules. Do not reconstruct blast cause from weapon, random chance, nearby explosion or HP alone. Existing nonfatal sever records remain semantically distinct.
2. Add actor/death/event binding to the existing `bodyPartFx → goreFx` path or replace it with an explicitly versioned record in the same lifecycle. Keep source TTL/caps and transport current age. A consumer reconstructs presentation time from age and rejects expired records; it must not restart an 8-second effect on delayed receipt, reconnect or reload.
3. Exactly one active renderer owns a receipt. After successful GLB admission, the same frame swaps the original corpse **visual** for fragments and suppresses the corresponding legacy proxy record. Source physical root/dead/HP remain untouched. If admission fails (budget, unavailable actor, unsupported geometry), retain the normal corpse. Never hide it before success. Renderer switch/re-entry needs the same death-key ledger; disposal or slot churn cannot resurrect a consumed effect. Missing actor/event binding means no safe matching/suppression, so current unbound records must not spawn parallel GLB effects.
4. Body replacement and expiry semantics need an owner decision: avoid restoring an intact corpse after fragments expire. Do not implement this by changing authoritative death state. Blood/ground drips stay with 19 and share accepted damage identity instead of a second random trigger.
5. Before production: precompute topology during actor/model preparation; batch fragments by compatible material or merge appearance pieces; distribute baking work under an explicit frame budget while retaining the corpse until ready. Match source age even when work is deferred. A two-victim visual cap is a prototype bound, not fulfilment of unlimited simultaneous blast deaths.

Remaining art/physics work: closed cut surfaces/caps, correct normals at separation, floor collision/settling, part proportions and visual QA. The prototype does not hide the corpse, preserve incoming source age, settle on geometry, or integrate any renderer. It proves model reuse and bounded lifetime/resource disposal only. No production asset/module was changed.
