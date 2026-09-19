# Door specialist actions — 19 September 2026

Owner `/root/crew_follow_routes18`. Core/source READY; no browser or reload. Production scope: `mercenary_core.mjs`, `mercenary_world.js`. New tests `test_mercenary_door_actions18.mjs`.

- `breach_door`: bruiser, melee skill, base 2.5 s, base maximum range 1.5 m (authored smaller workRange remains authoritative), cooldown 3 s. Offered only for an unopened, intact, locked door with **breachable === true**. Russian label `Выбить дверь`.
- Existing `plant_bomb` also accepts unopened, intact, locked doors with **bombable === true**. Vehicles preserve previous rules. Existing four-second planting, six-second fuse, >=8 m retreat from target.center and waiting-for-safety behavior are shared unchanged. A module must publish the actual door centre separately from its approach point.
- Unlock/kick/plant on the same door are mutually exclusive across professions, preventing simultaneous effects by different operators. Another command becomes eligible after cancellation. Existing vehicle command concurrency was not changed.
- Both reuse ordinary contact refresh, bounded routing, timer publication, hit/death interruption before completion, acknowledged async receipt, cooldown and single XP award. Core never opens geometry or applies damage itself.
- Effect payload supplies `noiseRadius:12` for breach and `40` for plant_bomb. These are world metres and may be overridden by balance. **This metadata alone does not create audible sound or police/NPC noise reactions**; renderer/source callback owner must connect any such behavior. No generic noise bridge was invented here.

## Integration contract

The door module owner `safe_operator_clearance18` confirmed `mercenary_breach_door.mjs` with real `breakOpen(effect)` and `blast(effect)`, physical collider updates, contact y~.8, workRange .08, source .738 m footprint clearance. Root target binding must derive breachable/bombable from supported real callbacks; no inferred profession affordance for arbitrary locked decoration. Root additionally owns action priority, timer label, pose animation and showcase UI.

`performEffect` receives `kind`, `memberId`, `targetId`, authoritative current target/member, skill stats, unique actionId/requestId and noiseRadius. Success is true or `{ok:true}`; a Promise is accepted and held exactly once. Rejection yields no XP/completion. Existing effect source gate requires a real armed core action for detonation.

## Verification and limits

New suite **10/10 PASS**: explicit capability rejection, exact 2.5-second work duration, hit/death/cancel/externally-opened interruption, cross-profession exclusion, six-second fuse with safety hold, pending receipts accepted/rejected once, source label/contact/physical approach and one callback at **5/10/30 FPS** for both kick and explosion.

Combined core/new-door/rally/world/elapsed run **97/97 PASS**. Existing car physical route and retreat still pass at 5/10/30/60 FPS. Core 5-member fixture p50/p95 .0005/.0022 ms (source/GPU excluded); no new per-frame scans beyond the existing <=5 action/roster checks. **Performance of the shared scene and actual rendered door animations are not checked LIVE.** No claim of complete integration before root's callback/pose/module wiring and common reload.
