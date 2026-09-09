# Detailed water and contact splashes — 2026-09-10

Latest follow-up: [deep-water engine failure, fading steam, safe submerged exit and shoreline v6](VEHICLE_WATER_FAILURE_HANDOFF.md). This supersedes the historical shallow-only limitation below. Current isolated QA URL is `/walk?standalone=1&waterqa=1`.

User requested detailed attractive water and physical splashes when jumping into it or driving a heavy vehicle into it. Implemented in the shared walk renderer, including its world gateway. Preserve the existing artist swimming/wetness/pose and the original vehicle solver.

## Implementation

- `environment_surface_materials.mjs`: water-only shader revision 4. Six derivative-filtered wave scales, depth absorption, view-dependent sky tint/Fresnel, shallow caustic highlights, broken shoreline foam. Original ground/asphalt/paving/sand branches and geometry remain unchanged. No additional water-surface passes, lights or texture fetches. Sky tint is analytic and scene-lit, not a claim of true screen-space reflections.
- `water_interaction_fx.mjs`: read-only presentation simulation. Gravity 9.81 m/s², drag, velocity-aligned droplets, impact energy from mass/speed/depth, moving front-wheel spray, returning droplets and expanding shore-clipped arcs/foam. Swept contact catches crossing between frames. Standing, airborne overflight, first appearance, teleport and disabled actors do not fabricate entry impacts.
- Default limits: 240 droplets, 24 rings, 72 foam patches, 96 new droplets per frame, 100 m focus radius, three instanced batches. No raycast interception by visual particles. Pools and meshes disposed on map rebuild/pagehide. Surface receives the eight strongest live ripple events through `environmentVisuals.setWaterRipples`.
- `water_interaction_inputs.mjs`: actual posed hero foot origin; actual wheel pivots, transformed tyre support circles, front/rear metadata, vehicle profile mass and dimensions. Does not write movement/health/physics. Hero appearance changes, entry/exit and explicit inspection teleports reset sampling.
- Narrow `walk_preview.mjs` hooks: sample AFTER motion and artist swimming/pose, update FX before rendering, forward ripples, publish bounded counters in `document.body.dataset.waterInteractions`. Existing jumps, driving, damage, collision, swimming and rail hooks retained.

## Real vehicle access, not an unreachable visual hook

Existing landscape admission rejected every water point. A new bounded connector in `water_vehicle_access.mjs` joins the existing lakeside road to the west bank of Lake Azure across unchanged gentle terrain:

- Start (783.8088, 394.8000), shore (822, 406); 42.80 m total including 3 m beyond the shoreline point, 8 m wide.
- Slope at most 0.27, water depth at most 0.45 m; no global off-road/deep-water permission, no native-city water permission, no terrain flattening or collider removal.
- Added "Пологий берег Лазурного озера" to the existing walk place selector for finding the location. Steering, damage, ownership, model names/IDs and collision solver are unchanged.
- All 12 imported vehicle footprint profiles pass the continuous approach test. Actual slope-supported fire-engine GLB wheel bottoms reach 0.084/0.060 m below the surface; bus front tyres reach its contact tolerance. This is shallow entry, not underwater driving or a buoyancy/sinking system.

## Verification

CPU/actual-geometry PASS:

- `test_water_interaction_fx.mjs` — 14 groups, including swept impacts, heavy-vs-light energy, gravity/recontact, yaw, depth, no stationary/teleport spam, bounded pools, real THREE r180 instancing/shader hooks/disposal and shore-clipped ring vertices.
- `test_water_interaction_inputs.mjs` — real vehicle profiles, posed tyre contact, detached wheels, no solver writes, hero/seat/teleport handling.
- `test_water_vehicle_access.mjs` — unchanged actual terrain, exploration decor colliders, 12 footprints, protected/deep/off-corridor rejection, actual fire-engine/bus GLBs.
- `test_water_inspection.mjs`, `test_walk_water_hooks.mjs` — actual shore geometry and actual walk hook extraction/dispatch, lifecycle, shader feedback, opt-in QA denied in network world.
- `test_walk_water_integration.mjs` — actual `stepCar` + 10,500 kg fire-engine GLB, slope support, sampler, simulator and extracted walk hook. First spray at 3.30 s / 16.54 m approach / 9.95 m/s; 60 droplet recontacts. Final root run included 357 native + 2314 decor + 508 road colliders (agent's earlier shared-tree run had 513 road colliders); both passed. Actual `launchJump`/`stepJump`/`resolveJumpSurface` yields entry impact at 0.783 s and 22 recontacts. Real shader uniform feedback asserted. No geometry/topology changes.
- `test_environment_surface_materials.mjs` — 14 material variants, 9768 actual lake vertices unchanged, maximum sampled depth 6.84 m; exact THREE shader chunk contracts.
- `test_environment_visuals.mjs` — original 239 placements and grid preserved, actual ripple passthrough, material lifecycle.
- Existing `test_hero_jump.mjs`, `test_jump_keyboard.mjs`, `test_exploration_vehicle_support.mjs`, `test_walk_rail_hooks.mjs` and walk syntax check pass.

## Historical limitation — first implementation turn (resolved below)

Browser automation failed three discovery attempts, including a session reset, with `Unable to load browser request-header policy`. No browser safety policy was bypassed, no alternate browser automation was used, and no user game tab was closed/reloaded during this water turn. GPU compilation, final visual appearance, interaction timing and full-scene FPS are **not yet LIVE verified**. CPU shader-string tests do not establish a successful GPU render.

An explicit local inspection UI is available at `/walk?waterqa=1`: "К берегу", "Прыгнуть в воду", "Тяжёлая машина", "Заезд в воду". Setup positions the real local actors; jump and throttle then use the existing solvers. The UI does not mount if `window.Mafiozi3DBridge` exists, and is absent from the normal URL. No server restart/deployment/account transaction or real multiplayer membership/inventory mutation was performed.

Artist14 continues to own swimming/wet-clothing/combat/hero poses. Other terrain, NPC, vehicle-model, traversal and HUD changes in the shared dirty tree were preserved; do not restore an older whole walk file over them.

## Follow-up LIVE verification and water v5 — 2026-09-10

The user explicitly requested in-game verification and further water improvements. Browser access recovered. Actual standalone `/walk?waterqa=1` was loaded in this task's browser1/tab3; the coordinator's separate game tab was not touched. No server restart/deployment or multiplayer state change.

- Before revision: screenshots at the Azure shore showed pale/milky water, continuous regular caustic grid lines and parallel broad wave stripes.
- Water-only revision5 replaces that grid with sparse, low-contrast shallow highlights, curves the six wave domains with analytic Jacobian-correct shading, removes diffuse stripe modulation, and deepens turquoise/absorption. No geometry displacement, new surface passes, textures or lights. Other terrain branches remain unchanged.
- Reloaded actual full game: `startupCompile.phase="rendered"`, `error:null`, console error list empty, including after both particle shaders became visible. Day and evening surface screenshots inspected. The regular caustic grid is absent and the shore/depth gradient is clearer. This is visual QA, not a full performance benchmark or multiplayer acceptance claim.
- Real hero jump from the dry shore: one impact; capture showed 18 active ballistic droplets, one ring and one foam patch. Real 10,500kg fire-engine drive: two tyre impacts, 60 active droplets, two rings and two foam patches. Visible outward near-wheel spray, no artificial particle spawning used. Counts are runtime observations, not fixed deterministic requirements.
- Continued simulation after captures: all 78 droplets returned to water, active droplets/rings/foam fell to zero, draw calls fell to zero, stationary vehicle created no extra bursts. GPU error log remained empty.
- Added two local-only inspection buttons: `Стоп-кадр всплеска` arms capture of the next real impact after 0.14 simulated seconds; `Продолжить` resumes. Capture releases controls, never fabricates an impact, resets on fixture/map reset, and is unavailable in bridged world/normal URL. Main frame is stopped only when explicitly armed local capture fires. This makes short-lived real splashes inspectable despite automation latency.
- Final tab is unpaused, daytime, hero on the shore, settings closed, personal-file HUD collapsed. Marked deliverable/open requested; do not close it. The panel remains usable for repeating the two tests.

Follow-up tests PASS: 18 FX groups (including shared shader/mesh ringfront and mirrored/reverse wheel fans), water shader14 variants + numerical warp Jacobian, actual vehicle/jump integration (357 native +2314 decor +530 road colliders in this shared-tree run), environment visuals, local capture unit/hook tests, and walk syntax. Main source changes are narrow water inspection hooks; coordinator15 grass/roads/parking and artist traversal hooks preserved.

## Follow-up: synchronized ripple fronts and wheel fans — 10 September

Independent FX audit found a real mismatch: geometric rings previously used different
starting radii and strength-dependent speeds while `environmentRippleAt` used
`radius = 0.08 + age * 1.35`. Small recontact rings could trail their shader waves
by nearly three metres. All FX rings now use the shader contract: initial radius
0.08 m, speed 1.35 m/s, lifetime 4.5 s; strength changes amplitude/opacity only.
The exported `waterRippleRadius(age)` and named constants document this contract.
Rendered arc geometry spans 0.97–1.03 times that radius, so its centre, not an
edge, follows the shader front. Both rims are checked against shore water/height.

Wheel spray previously had no left/right contact-side information and could aim
both fans into the same side of the chassis. Real contact coordinates now derive
local side and, when omitted, front/rear from the vehicle transform rather than
array order. Outward mirrored fan momentum is added to inherited vehicle motion.
The leading axle generates the bow wake: physical front axle forward, rear axle
in reverse. Impact emission still supports all actual contacts. No gameplay
velocity, terrain, car model, sampler or world/walk/material source was modified.

`test_water_interaction_fx.mjs`: 18 groups PASS, including radius extracted from
the actual shader source, primary/recontact wave agreement, real THREE r180 ring
centre geometry, mirrored fan momentum for four yaws in both directions, and
unordered wheel metadata. Existing bounded pools, three batches, raycast opt-out,
shore clipping and disposal checks still pass. `test_walk_water_integration.mjs`
also passes with the current 357 native + 2314 decor + 530 road colliders: actual
fire-engine entry at 3.30 s, 60 droplet recontacts; actual hero jump entry at
0.783 s, 22 recontacts. Collider-count changes belong to the concurrent road work.
This subsection reports CPU/geometry verification; root owns current LIVE/GPU QA.
