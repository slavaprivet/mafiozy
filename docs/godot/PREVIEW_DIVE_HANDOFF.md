# Max Payne directional dive — source sampler and required host contract

26 September 2026. **Pure unarmed sampler + source oracle + headless checks ready. Runtime input/movement integration is NOT done.** Main/player/locomotion/airborne, the running release and GPU windows were not modified. No Git operations.

## Latest source, not the superseded long dive

Read `docs/ai/NPC_UPRIGHT_WALK_DIVE23_HANDOFF.md` after `MAX_PAYNE_DISTANCE_20260919_HANDOFF.md`. The later23September change supersedes6m/s /4.8m:

- Source `hero_jump.mjs`: dive speed **4.2m/s**, maximum immediate travel **3.36m**, dive arc **0.42m**; normal speed3.5m/s, height1.05m, maximum travel2.8m. Metres are already native units; do not multiply by4.1.
- Flight0.8s, recovery0.45s, normal→dive cubic blend0.24s. Second discrete Space within **500ms inclusive**, before flight ends, with nonzero direction, upgrades the existing trajectory. It does not restart elapsed, change start time, or give a second upward impulse. Third press does nothing.
- `done`, `falling` or `ceilingHit` forbid upgrade. Missing new movement input falls back to the existing directional jump, then camera-forward for a stationary jump; that policy belongs to the keyboard host.
- Immediate dive can peak near0.42m. A late upgrade retains already gained normal height; never snap it downward to satisfy a fixed apex assertion.
- Source body tilt rises to1.53rad, holding side contact over progress0.64–0.72 (=0.10s) before standing over the last0.35s. Direction is relative to aim, while gaze follows aim independently.

Source receipts are also embedded in the oracle JSON:

| Source | SHA256 |
|---|---|
| hero_walk.mjs | 60ad2135010926f9fe1f18c62a89a877eb2547c708b723d7926f513043cc28c3 |
| hero_jump.mjs | 6315992afff118c63facd12c2957437ed46bd126642f49fc6619bd845df0d680 |
| hero_pose_transition.mjs | 674fcfce49b4cbe3048ff829e784595b680625f901d73b95a4976128e4a0b8e2 |
| walk_preview.mjs | e80ebf4be2d0404ad5b51d4bf28b756a9cba2b486c43c0797de748c37364dd47 |
| surface_motion.mjs | a9cacfd619e65da7f75cfe5ac756a97c003bd0f6d4bbe04d21d7ec6852cce8f6 |

## New files and pure API

`scripts/preview_dive.gd` is RefCounted and never writes a skeleton, visual node, physical position, velocity, scene or input. `scripts/tests/test_preview_dive.gd` exercises the real imported male rig and actual source oracle.

```gdscript
var dive = preload("res://scripts/preview_dive.gd").new()
dive.bind(hero_root, visual_motion) # At canonical rest, identity motion transform.
var pose = dive.sample(progress, dive_blend,
    actual_visual_root_yaw, aim_yaw, aim_pitch, travel_yaw,
    &"on_foot", authority_epoch)
# Host applies only if valid AND active, in its one final writer:
# local bone poses, visual_motion.quaternion, visual_motion.position.
```

Returned fields: `valid`, `active`, `poses`, `visual_rotation`, `visual_offset`, `progress`, `dive_blend`, `authority_epoch`. External owner or invalid epoch returns inactive and clears internal epoch; invalid input returns invalid and resets. There is no hidden elapsed/landing timer capable of surviving a lifetime change. Reset is read-only. The host owns whether there is an active trajectory and must discard old trajectory state on authority/lifetime changes.

This is the **unarmed** `jumpPose` branch. Rest rotations multiply the source XYZ deltas. Neck counter-rotation, final world-relative head aim, directional visual tilt and actual full-skin support are transferred. Aim pitch clamps to±1.28. Canonical translations/scales are preserved. Bind currently admits the canonical8338-vertex skinned male rig and identity rest motion; rebinding is required after rest/hierarchy/normalization changes.

Three static arithmetic helpers are also supplied:

- `upgrade(state, Vector2(dx,dz), now_ms)` returns a copied state, upgraded only under source guards. Input state carries `elapsed`, `startedAt`, `mode`, plus optional `done/falling/ceilingHit`. It preserves age and sets normalized `direction`, `diveStartElapsed`, `diveBlend`. It does not move the actor.
- `proposal(state, step_dt)` returns `travel`, `arc_y`, `elapsed`, `progress`, `diveBlend`, `done`. These are desired source trajectory values, **not permission to set position**. Done freezes; invalid state/delta is rejected.
- `frame_steps(raw_delta, visible)` follows the current source clock: hidden/invalid/nonpositive/>1s gaps yield no steps; a visible accepted frame consumes at most0.25s in at most7steps≤0.04s, with excess discarded and no debt. Traversal has a separate older cap and must not use this helper accidentally.

## Required host changes before enabling dive

1. **One owner and a full visual transform.** Current `preview_player` applies only poses plus motion position. It must also apply/reset the returned quaternion in that same writer. Leaving a rotated motion node behind after death/vehicle/traversal/water or after recovery is forbidden. Aim/body yaw use actual+Z imported model convention; camera movement is currently expressed through Godot−Z, so derive travel with `atan2(world_dx, world_dz)`, not guessed left/right signs. Eight source directions are oracle-tested.
2. **One normal/dive trajectory clock from the first Space.** Current ordinary Godot jump uses5.2m/s upward velocity and9.8 gravity with velocity-mapped airborne pose; that is an explicit earlier adaptation, not the source0.8s/1.05m trajectory. Simply starting a new0.8s dive on the second Space would reset flight and violate source continuity/range. A source-faithful host must migrate normal and upgraded dive to the same source clock, or explicitly resolve the normal-trajectory adaptation before integration. Do not derive source elapsed from the existing ordinary pose's progress and pretend it is the same clock.
3. **Physical sweeps for every proposed substep.** Determine desired XZ travel from locked direction and proposal, desired Y from base support plus arc, and move through `CharacterBody3D.move_and_collide`/equivalent real shape sweep. Project remaining movement along wall normals where source sliding is allowed; use actual collision output to commit position. Never `position = proposal_position`. Current capsule is radius0.30/height1.9; source movement permission radius is0.36. The host must preserve the source0.36 permission footprint separately or explicitly resolve this existing migration difference; changing the player collider silently is outside this package.
4. **Support/ceiling/water per substep.** Port the actual `resolveJumpSurface` semantics: ceiling clearance includes body height+.04, ceiling hit cancels future upgrades and enters fall; lower support after flight enters gravity18 fall with actual velocity and actual support contact. Query floor/ceiling along the actual moved path, including thin forbidden water boundaries. Water/climb/traversal/vehicle/death/custody owners preempt this mode before input and before final pose. A timer is not proof of landing. Full-skin visual support here is a local ballistic plane, not a replacement for world slope/wall/water collision.
5. **Recovery and queued posture.** Keep source0.10s side contact +0.35s rise inside total0.45s recovery. Source queued C/Z is applied only after flight and actual contact, via the0.28s `hero_pose_transition` blend, including combined pelvis/root orientation. That transition, posture system, combat weapon IK/grips and shooting are not implemented by this unarmed sampler. Do not replace them with a generic stand snap.
6. **Cancellation/lifetime.** Source admission denies artist action/busy/menu/seat/transition/blast/vertical navigation and unsupported new jumps. Source focus loss clears held controls and queued posture; hidden updates freeze without a catch-up impulse. On actual external authority, reset the sampler and cancel the host trajectory; on return use a new epoch. Teleport/reload/respawn also starts a new lifetime. Epoch only in the sampler cannot cancel a stale host state passed in again.

This contract is why the package is intentionally not imported by current player. Parent owns the integration decision and the single visible game.

## Actual source/Godot checks

Reproducible generator: `tools/godot/build_dive_oracle.mjs`; fixture `godot/mafiozi_walk/scripts/tests/fixtures/preview_dive_oracle.json`,416557bytes. The generator resolves the repository from its own location and imports actual current `createHeroWalker`, `launchJump`, `tryDiveJump`, `stepJump` and actual player GLB using Three180 from the established vendor path (override `MAFIOZI_THREE_VENDOR` if needed). It does not reimplement the expected formulas. Fixture includes exact source bytes/SHA256 and GLB652732bytes/SHA256; tests reject stale source receipts.

Godot4.7.2 headless: **168 source poses** =8directions×7progress×3blend values; all local quaternions, visual quaternion and source full-skin contact match. Max quaternion dot error5.96e−8; maximum support offset error**0.000025665m** (0.026mm). Actual rig/root remain untouched. Three current-source free-flight traces compare immediate,200ms and500ms upgrades field-by-field; compact travel, timing, upgrade guards, third press, invalid/hidden/slow-frame clocks and authority/epoch reset pass.

Additional isolated real Godot capsule probes demonstrate the required host primitives:3.36m requested sweep cannot cross a2cm wall, upward sweep detects ceiling before reaching arc target, and downward sweep reaches actual support within1cm physics margin. These are contract probes, **not a finished Godot dive controller or water/landing integration**.

Final **10396 assertions PASS, exit0**; assertion count includes repeated per-bone/source cases and is not10396 unique gameplay scenarios. Log `outputs/coordinator21_perf_acceptance/dive_test.log`.

```powershell
node tools/godot/build_dive_oracle.mjs
& 'C:/Users/Слава/AppData/Local/MafioziTools/Godot-4.7.2/Godot_v4.7.2-stable_win64_console.exe' --headless --path godot/mafiozi_walk --script res://scripts/tests/test_preview_dive.gd
```

Actual JS `test_hero_jump.mjs` and `test_jump_keyboard.mjs` also PASS:8directions, compact range/arc, normal/dive continuity, input guards,3/5/10/30/60FPS,40normal/dive source collision cases, per-step water/wall/ceiling/floor and no hidden-gap impulse. Source thin-water-strip footprint remains a sampled permission limitation; do not claim an exact swept disk from those JS checks.

## Performance and remaining cost

First correct full scan: CPU p50/p95 **18.342/20.206ms**. Rigid hulls alone7.692/8.801ms. Removing the redundant pre-gaze solve and prepacking support reduced final varied-source-pose CPU p50/p95 to **0.530/0.708ms**, same168pose workload with equality checked after every optimization.

Prepared once at bind:1101 rigid convex support points;2079 weighted source vertices reduce to1682 unique weighted support vertices/5770 packed influences. Identical weighted groups preserve the same affine projection; final hot loop uses packed bone-local preweighted points and cached per-bone Y rows, with no mesh extraction, per-vertex Dictionaries, scene reads or timing calls. Full-body support includes head/arms/cloth while tilted, not only boots. No authored geometry is removed.

Independent128sample warmed same-pose profile: total p50/p95 **0.534/0.739ms**; support kernel **0.499/0.709ms** in separate timing windows. Different windows and scheduler noise must not be subtracted as a rigorous decomposition. Support scanning remains the dominant cost. Bind took **33.506ms once** in this run and belongs to loading, never a per-frame operation; preparation DTOs are released after the packed support is built. This is one-actor CPU only; loaded-scene p95 still requires measurement. Do not call sample multiple times per frame for the same final pose.

**Производительность общей сцены не проверена.** Runtime input/motion, visible dive direction/gaze/contact, weapon handling, actual water/slopes/obstacles, full-city frame times and release export remain OPEN.

## Exact delivered working-copy hashes

- preview_dive.gd: `9a90722492bbf6e1c0303251d78dccd599093cb8a30804548011bb44be3bc86c`
- tests/test_preview_dive.gd: `c44138bd0775f6bdccb969c4a5860ef95514a6141fad2941aa46a3c0f461e708`
- tests/fixtures/preview_dive_oracle.json: `a1a05026179c726ccb46b2a41815e9cfcec2b3fc1202da94c74de6a0b8639187`
- tools/godot/build_dive_oracle.mjs: `e5e73669d161cc939abf3cb1c4179f73aef9d2d05e744673d348d796f613a080`

These are raw tested bytes; script newline conversion may change raw hashes. The minified fixture has no platform newline dependency. No runtime file imports the new sampler yet.
