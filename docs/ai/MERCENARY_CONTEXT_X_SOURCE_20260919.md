# Context X — source integration, 19 September 2026

Owned scope: `mercenary_world.js`, `mercenary_core.mjs`, new `test_mercenary_rally_actions.mjs`. Root owns input, target picking, action choice and UI. No browser operations or commit.

- A valid rally destination cancels uncompleted approach/work before an effect: bomb planting, cutting, power shutdown, lock work, medic rescue. Invalid destinations leave current work intact.
- Armed charges and pending effect receipts receive queued rally destinations. Their current safety/receipt action remains authoritative, then ordinary movement resumes. No repeated effect submission. Receipt includes `cancelled`, `deferred`, `blocked` counts/IDs.
- A medic under explicit rally does not immediately undo the user's cancellation through automatic rescue scan. Explicit object revive still works. Follow restores ordinary automatic scanning.
- Action availability rejects self-target, hospital target, duplicate assigned action/target, dead/unavailable member and wrong profession. Ordinary unrelated NPCs are not revivable by the squad adapter. The implemented medic action revives a downed ally; this is not a new full-health healing action.

## Local QA helpers

All require ready + local loopback + `mercenaryqa=1` (or existing demo gate), validate source body/native collision, floor and nearby occupant clearance.

- `qaPrepareProfessions({positions})`: `positions` maps all five profession IDs to `{x,y,z}`. Places existing unhired candidates for 30 seconds; hired members stay unchanged. Returns `placed`, `skipped`, `rejected`. No grant/recruitment.
- `qaAssembleProfessions({positions,patientPosition})`: explicit user-authorized stand assembly. Existing hired IDs move to validated points. Missing roles use actual existing source residents and ordinary recruit ownership/guards; a private synchronous QA flag bypasses only hire distance. No currency or equipment grant. Current ordinary source recruit has **no hire fee**, so result truthfully reports `charged:0`; no invented tariff. Returns `assembled`, `rejected`, `patient`, `charged`.
- `qaPlacePatient({position})`: existing hired bruiser becomes nonfatal downed patient. Ordinary live members hold current rally positions so medic waits for explicit X. Armed/awaiting members untouched. QA patient's rescue window lasts at most 600 seconds; then ordinary hospital lifecycle applies. Successful revive clears QA extension; subsequent wounds use normal 20-second grace. The deadline is saved and restored only in local QA mode, without extending the original window on reload. An explicit QA preparation can reset this bruiser's hospital state to downed, preserving identity, equipment and cash; other hospitalized members stay untouched.

## Checks

Initial new rally suite: 7 failures before source changes; 8 passes after. Expanded 15 new cases cover cancellation, deferred safety/receipt, eligibility, invalid destinations, gated QA assembly, ID preservation, once-only recruitment, ten-minute expiry and restoration of ordinary grace. Latest selected run with lifecycle restore and record tests: **26/26 PASS**. Earlier world/core/record suite: **62/62 PASS** before QA assembly extension. Full scene FPS and stand LIVE are root-owned and unverified by this subtask.

Final world/core/new-rally run after QA assembly and rescue extension: **63/63 PASS**.

## Live stand follow-up

- QA assembly now distinguishes missing/occupied citizen, native obstruction, source solid and wrong floor through `rejected[].code` plus readable reason. Nominal slot failure tries at most 48 neighbouring points within 4.8 m; body/native/occupancy checks remain mandatory. Occupant spacing is 1.4 m (small floating tolerance), not 2 m.
- If the original specialist is owned by an indoor visit or civilian trip, QA leaves that NPC untouched and may adopt another existing free eligible resident using the normal profession rules. It never spawns or extracts an occupied actor. No available resident yields an explicit refusal.
- Core reads authored `target.workRange` at command and each live update, bounded from 0.2 m to profession/balance range; approach stop distance remains 85% of this range. Tests confirm actual source movement reaches 30–40 cm for `workRange:.4`, then holds without drift while working. Invalid/oversized values cannot extend interaction range. Source squad revive descriptors still need authored contact metadata from coordinator; this follow-up did not change default revive distance.
- Expanded source QA/rally suite: **19/19 PASS**; world+rally before the last contact test **65/65 PASS**; core/action/rally contact-range run **27/27 PASS** before the last world-contact case. LIVE remains coordinator-owned.

## Patient reload follow-up

- Actual fresh-adapter reload after 30 seconds preserves the original ten-minute QA rescue deadline. Expiry and non-QA reload still use normal hospitalization. Explicit preparation resets only the hired bruiser after valid placement; no general hospital or currency bypass.
- The NPC named by `npc-combat-session.dataset.npcId` is excluded from adoption/recruitment. An already hired placeholder named `Проверка урона` receives a stable personal name during explicit QA assembly, retaining its ID and equipment.
- Selected source, lifecycle, focus and rally tests: **85/85 PASS**. Additional actual-source tight fence test passes with `workRange:.2`, approach 0.48 m outside the mesh and 0.42 m body clearance, without crossing the mesh. This proves the source tolerance in that bounded scenario; the reported LIVE circling requires the actual native path/geometry diagnosis by the coordinator. General scene performance remains unmeasured here.
- A second regression reproduced a genuine arrival mismatch: with range 0.2 m and ground 0.12 m above the authored approach, the source stopped horizontally at 0.17 m while 3D distance remained 0.208 m, leaving work permanently in approach. Core now subtracts the vertical distance component before choosing horizontal stop distance. The 3D action radius and all collision checks remain unchanged. Regression failed before the fix and passed after; latest selected five-file run **95/95 PASS**. Added arithmetic is one square root per approaching member update, no search/allocation; full-scene timing still belongs to coordinator LIVE acceptance.
