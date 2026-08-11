# Mafiozi 3D optimization memory

The canonical file was missing from the working root on 2026-08-10. The latest
recovered historical baseline remains available at
`_github3d_impact_20260810/docs/ai/OPTIMIZATION_MEMORY.md` and must be read for
the full quality, pooling, streaming, warmup, shadow and input-transition rules.

## Non-negotiable interaction rule

- Proximity visuals must consume the existing throttled
  `nearbyActionState`; do not add another complete building/NPC scan to the
  render loop.
- Build door geometry once with the exterior and animate only pivot transforms.
  Do not allocate geometry, materials, vectors or timers while the player is
  approaching a door.
- One authoritative entrance must drive collision reachability, the marker,
  the `E` prompt, door animation and the actual transition. Hidden legacy DOM
  buttons must not be created or clicked as a bridge between those systems.

## Confirmed pattern: bank entrance (2026-08-10)

- All three bank entrances resolved to walkable anchors in local 3D QA.
- Reusing the 140 ms cached `nearbyActionState` opened only the matching bank's
  prebuilt double-door pivots; no extra proximity scan was introduced.
- The exterior `zoneBtn` stayed hidden, the common `E` prompt remained visible,
  and `E` entered the bank lobby directly without Three.js errors.

## NPC action prompt layering (2026-08-10)

- Use the existing cached nearest-NPC state and cached projection vector for the DOM `E` prompt; do not add another NPC scan or per-frame layout read.
- Project the prompt above the highest NPC name/role/HP label and use a fully opaque fill. Remove duplicate legacy top-HUD NPC buttons so `E` remains the single interaction path.

## Custody release and emergency arrivals (2026-08-10)

- Treat prison release as an input-cancellation and staged world-resume boundary: clear held combat/interaction state, reset frame timing and spread the first world updates across the existing resume frames.
- Interior crimes must store exterior world coordinates and remain queued until the player exits. A disconnected-road fallback vehicle must begin outside the 3D dynamic radius and become visible only while actually approaching, never teleport into the live view.

## Crisp projected DOM prompts (2026-08-10)

- Do not animate projected gameplay text with CSS `filter: blur(...)`: even after the animation, compositor rasterization can leave small bold glyphs visibly soft.
- Snap projected screen coordinates to whole pixels, use a 2D `translate(...)`, and avoid permanent `will-change: transform` on text overlays. This keeps the prompt crisp without adding layout reads to the frame loop.

## Police foot-route stall recovery (2026-08-10)

- Never extend the expiry of a failed cached foot route from its blocked branch. Doing so every frame keeps the same invalid first waypoint alive forever beside compact obstacles such as trees.
- Clear a route after a bounded no-progress interval and let the existing one-route-per-frame BFS budget recalculate it. Custody adds a shorter watchdog because an escorted player cannot be left waiting indefinitely.
- Deterministic 3D QA placed a tree at `(5.5, 5.5)` directly between the arresting officer and the police-van door. The officer changed from `escort` to `loading` through collision-safe replans with no Three.js errors and without another world scan.

## Prison intake static waiting corner (2026-08-10)

- Reposition intake furniture only inside the one-time authored prison constructor; do not add a frame update or a second collision representation for visual-only benches and screens.
- The television/information screen and both benches now share the south-west corner opposite the northern release gate. Local 3D QA kept the gate released, reported zero police/body overlap and no Three.js errors; the sampled render was 16.4 ms at the existing quality settings.

## Police retaliation and stationary firing gait (2026-08-10)

- Do not infer a police actor's movement from its cached patrol target in the 3D bridge. Combat AI can deliberately hold a firing lane while the old waypoint remains distant; using that target makes a stationary officer cycle the walk animation forever.
- Reset the explicit `walking` flag at the start of each police simulation tick and let the shared collision-aware foot mover assert it only after a successful displacement. Measured visual motion remains the renderer-side fallback.
- A player hit must enter a durable armed-retaliation state immediately, independently of delayed wanted synchronization. For investigation crews, promote the whole responding vehicle crew and its incident to armed contact so search/question phases cannot absorb incoming fire without answering.
- Local deterministic 3D QA confirmed return fire for patrol (`15` sampled shots, shooter `walking=false`), murder-response crews (`15` shots across two officers, both `walking=false`) and prison staff (`10` shots with the active prison alarm), with no Three.js startup errors.

## Police pursuit speech bridge (2026-08-10)

- Reuse the bounded `_copChats` map for patrol warnings; do not create a second speech collection or scan the NPC population from the renderer.
- City police are cloned into the 3D combat snapshot with a prefixed render ID. Resolve chat through the clone's `_actionRef.id`, then copy only the active text into the existing `speech` field consumed by pooled NPC labels.
- Use both a per-officer cooldown and a short global police cooldown so nearby patrols take turns instead of covering the screen with simultaneous bubbles.
- Deterministic 3D QA confirmed that a wanted-player pursuit emitted `Полиция! Остановись!` at `7.93` tiles, propagated the same text through the 3D NPC speech snapshot, and continued the physical approach without Three.js errors.

## Simultaneous RMB aim and LMB action (2026-08-10)

- Do not rely only on `pointerdown` for a two-button mouse chord. Pointer Events emits `pointerdown` when the mouse changes from no buttons to at least one; pressing LMB while RMB remains held can emit only `mousedown`.
- Keep the normal pointer route, and add a narrowly gated `mousedown` fallback only when RMB is reported in `buttons`, laser/throw aim is already held, and the canvas is the event target. A short timestamp guard prevents double actions in browsers that emit both event types.
- Deterministic local 3D QA held RMB for `280 ms`, then pressed LMB. It confirmed one pistol shot with the laser still held, a grenade throw at `3.25` tiles, a Molotov throw at `3.23` tiles, and accepted C4 placement. Every case used the fallback exactly once and reported no Three.js errors.

## Embedded WebView RMB/LMB bitmask fallback (2026-08-11)

- Once RMB aiming has been accepted, the local held-aim state is the reliable source for the following LMB chord. Some embedded Chromium/WebView builds emit the LMB `mousedown` with `buttons === 1`, omitting the still-held RMB bit, so requiring `buttons & 2` drops the shot even though the reticle remains visible.
- Keep the canvas-target gate and the short pointer/mouse duplicate guard. Removing only the unreliable bitmask requirement preserves UI click isolation and prevents duplicate shots.
- The deterministic chord QA must use the degraded `buttons === 1` event so this WebView-specific failure remains covered.
- Browser QA against the current workspace build used `buttons === 1` and confirmed exactly one pistol shot, one grenade throw at `3.32` tiles, one Molotov throw at `3.45` tiles and one accepted C4 placement. Every action used one fallback event, kept RMB aim active through the LMB action and produced no Three.js startup error.

## Witness phone-call animation (2026-08-11)

- Carry witness state through the existing bounded NPC snapshot as one boolean (`phoneCalling`); do not add a renderer-side NPC search or a new actor collection.
- Render the phone as one pooled instanced part in `npcParts`. The call pose and phone visibility are derived from the same authoritative flag, so ending the report hides the prop without allocations or cleanup timers in the frame loop.
- Police dispatch remains server-authoritative: a delayed report updates wanted state first, then the existing patrol and response-vehicle systems consume it. The visual animation never decides whether police respond.

## Authoritative gang world and business control (2026-08-11)

- Keep lair, roaming gangs, business operations and garrisons in the existing bounded `aggro`/city-gang snapshot. Never synthesize combat-capable fallback actors in the 3D bridge: disconnected mannequins look alive but cannot move, receive authoritative damage or return fire.
- NPC business ownership is display-only on the client and must be applied once at snapshot start. It may draw rings, flags and operation phases, but must never overwrite the server-authoritative player/family business status.
- Reuse the existing two-second landmark refresh for 3D business flags. The refresh signature contains only business ID, faction, guard ID/state and defense level, so unchanged snapshots allocate no new meshes and add no per-frame NPC scan.
- Deterministic regression QA covered two three-member factions, one bounded reinforcement, police response, street control, business march/capture/garrison/takeover, Lair warning/alarm/grenade dodge/boss fall and reconnect payload. The focused suite completed in `3.3 s`; the authoritative hire check debited SQLite from `$1000` to `$500` and returned the same balance to the client.

## Humanoid walking arm swing and combat priority (2026-08-11)

- Preserve the locomotion arm pitch before resetting the unarmed player's limb quaternions. Resetting the quaternion and then restoring only limb position silently erases the walking swing.
- Apply a restrained opposing arm swing to the shared instanced NPC pose so civilians, gangs, police, guards and interior actors inherit it without per-role loops or allocations. Custom humanoid actors such as the Brigadir should use the same amplitude range.
- Firing must remain the final arm-pose override, with reload, throwable, custody, injury and death layers retaining their existing higher priority. Telemetry distinguishes walking-arm NPCs from firing NPCs so QA can detect accidental pose mixing.
- Local browser QA forced an unarmed walk and measured changing arm pitches (`0.011/-0.008` at the sampled frame), while 38 nearby humanoid NPCs used the shared walking pose. A retaliation run captured one firing police actor alongside 35 walking-arm actors; the firing actor stayed excluded from the walking-arm count and no Three.js error occurred.

## NPC police custody (2026-08-11)

- Mark the exact NPC shooter at the kill event (`gang_id` plus stable `bot_id`); never infer an offender later from the nearest living gang member.
- Keep the offender in its owning gang object but exclude `_custody_id` actors from patrol, combat, reinforcement strength and ordinary aggro snapshots. This prevents one NPC appearing in a fight, police car and jail at once.
- Advance cuffing, escort, loading, routed transport, unloading, prison escort, the server-timed 60-second sentence and release in the existing bounded world tick. Snapshots carry only active custody records; the client reuses its NPC and police-vehicle render paths.
- Gang-response cops have no `target_uid`. The common cop cleanup must preserve cops with a valid `target_gang_id`, including Lair and nest lookups, or the response disappears before reaching the offender.
- Release at the visible police-station exit. The original gang actor can rejoin its formation or use a short independent roaming waypoint window before normal AI resumes.
- Fresh-main regression: all six embedded scripts pass `check_world.py`; `test_gang_world_ai.py`, `test_npc_life_system.py` and `test_npc_police_custody.py` pass. The snapshot-driven client path adds no new per-frame global NPC scan.

## Desktop held-button mouse chords (2026-08-11)

- A second physical mouse button is not guaranteed to produce another `pointerdown` while RMB remains held. Keep the accepted RMB aim state authoritative and support `mousedown` plus a deduplicated primary `click` fallback inside the 3D canvas.
- The fallback must reject interactive DOM controls and use the last handled timestamp so the usual `pointerdown`/`mousedown` path and the late `click` cannot produce two shots from one press.

## NPC custody route stress (2026-08-11)

- A passability check on one straight pursuit step is not pathfinding. In the first 120-position stress sweep, `29/120` NPC-murder responses stopped at building corners because officers never selected an alternate direction.
- Reuse the bounded pedestrian A* for the final offender approach. Cache route/index per officer, replan only after the offender changes cells or after a 2.2-second no-progress watchdog, and expose remaining nodes/replans/stalls through the existing cop snapshot. The identical sweep then completed `120/120`, with `0` stuck and a maximum `5.8 s` to cuffs.
- Never use the visible prison gate wall tile as a routing destination. The former `(80.5, 69.55)` target returned no route, causing a direct fallback through buildings in all `48/48` convoy samples. Route the vehicle to the passable road stop `(78.5, 69.5)` and use authored prison-gate/intake waypoints only after unloading.
- Validate the vehicle staging point before custody begins: it must be passable, reachable from the offender and have a route to prison. Keep it fixed while the officer escorts the NPC; recalculating it behind the moving officer makes the car drift.
- Post-fix end-to-end simulation completed all eight phases for `48/48` arrests with zero invalid outdoor escort/transport samples. Total simulated arrest-to-release time ranged from `86.9 s` to `116.0 s`, including the exact 60-second sentence.
- A separate moving-offender sweep completed `40/40` pursuits with `0` stuck; the slowest moving target was cuffed after `7.2 s`. Cell-change replans remained bounded (maximum `14` total across the two responding officers during one chase).

## Batched outlines in transformed groups (2026-08-11)

- Before baking a child mesh into a world-space outline batch, call `updateWorldMatrix(true, false)`. Calling only `updateMatrixWorld(true)` can leave a dirty parent group's translation unapplied, causing remote structures such as prison walls to appear as black wireframes near the city origin.

## Network gang gunfire bridge (2026-08-11)

- A server combat event must update both transient FX and the shooter's durable client actor state. Creating only a bullet and muzzle flash leaves the pooled 3D NPC in its idle arm pose; stamp `_shotAt`, `_shotWeapon` and `_shotSeq` on the already-cached gang bot at event time.
- Reuse the prepared per-weapon audio buffers for remote NPC shots and attenuate gain from the cached player/shooter coordinates. Do not synthesize a new sound graph or scan actors in the render loop.
- Inter-gang packets must carry the attacker's id, weapon and authoritative bullet speed. The server regression emitted pistol, shotgun and rifle shots at 14, 11 and 20 tiles/second, applied their damage only after flight, and confirmed that a player rifle hit reduced the targeted gang NPC's server HP.

## Major-interior guard navigation (2026-08-11)

- A shared combat loop must not reuse one landmark's authored patrol points or
  obstacle list for every interior. Generate and cache walkable posts per room,
  and build the flow field from the current interior's authoritative collision
  function.
- Use the same collision source for movement, route cells and line of fire.
  Otherwise an NPC can see and shoot through furniture that its feet cannot
  cross, then appear stuck while continuously selecting the impossible target.
- Keep the existing bounded flow-field cache (one field shared by the assault
  group) and reset it only after a guard's bounded no-progress watchdog fires.
  The regression fixture produced 92 valid posts in a representative room and
  confirmed a collision-safe route step plus blocked/open firing lanes.

## 3D security identity and combat bridge (2026-08-11)

- Interior combat NPCs must bridge weapon, last-shot time, alert state and active
  speech together with position/HP. A visible projectile alone is insufficient:
  without the timestamp the Three.js actor remains in its idle pose while firing.
- Give security a role-specific cached palette and instanced vest/badge instead
  of allocating unique meshes per guard. Major venues can select palette by the
  existing interior id while all guards still share the same bounded NPC pools.
- A persistent common role marker should use one shared canvas texture and a
  fixed sprite pool. This keeps `ОХРАНА` visible even when the main identity label
  temporarily becomes a speech bubble, without per-frame canvas work.

## 3D interior NPC picking and robbery HUD (2026-08-11)

- `activeAimSurface` switches from the world `ground` to `interiorFloor` inside authored rooms. NPC picking must accept both surfaces and copy `camera.layers.mask`; forcing layer 0 makes visible interior actors unpickable.
- A screen-space aim projected onto the floor is not accurate enough for a raised NPC, especially an owner behind a counter. After an instanced NPC pick, route the stable interior NPC id through the bridge and calculate the gameplay ray from the NPC's authoritative `r/c` coordinates.
- Canvas-only mission HUD is hidden by the production Three.js canvas. Critical progress such as remaining guards and owner pressure needs a small bounded DOM HUD updated only when its state key changes; do not rebuild HTML every frame.

## 3D business-owner identity (2026-08-11)

- Business owners should be authored in the gameplay source and bridged through the existing bounded interior NPC snapshot with a stable `visualRole`, wardrobe palette and hairstyle index. Do not infer ownership from a display name in the renderer.
- Premium owner details remain instanced: lapels, pocket square and three reusable hairstyle accents add bounded draw calls without allocating a mesh per owner or per frame.
- The normal pooled NPC label carries `ВЛАДЕЛЕЦ ЗАВЕДЕНИЯ` plus the owner's name. A shared fallback role texture is shown only while speech temporarily replaces that label, preserving identity without dynamic per-frame canvas painting.
