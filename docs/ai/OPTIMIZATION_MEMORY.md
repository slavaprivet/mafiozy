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

## Major-building assault anchors (2026-08-11)

- A moved 3D landmark must update the authoritative assault coordinates in
  `world.html`, `mafiozi_bot.py` and `_preview_ws_server.py` together. The
  server validates the player's exterior position before opening the combat
  interior; stale coordinates therefore look like a dead UI action but are
  actually a `too_far` rejection.
- The residence moved from `(66,36)` to `(136,16)`. A static cross-file check
  protects all five major-object anchors against another 2D/3D drift.

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

## Humanoid walking arm swing and combat priority (2026-08-11)

- Preserve the locomotion arm pitch before resetting the unarmed player's limb quaternions. Resetting the quaternion and then restoring only limb position silently erases the walking swing.
- Apply a restrained opposing arm swing to the shared instanced NPC pose so civilians, gangs, police, guards and interior actors inherit it without per-role loops or allocations. Custom humanoid actors such as the Brigadir should use the same amplitude range.
- Firing must remain the final arm-pose override, with reload, throwable, custody, injury and death layers retaining their existing higher priority. Telemetry distinguishes walking-arm NPCs from firing NPCs so QA can detect accidental pose mixing.
- Local browser QA forced an unarmed walk and measured changing arm pitches (`0.011/-0.008` at the sampled frame), while 38 nearby humanoid NPCs used the shared walking pose. A retaliation run captured one firing police actor alongside 35 walking-arm actors; the firing actor stayed excluded from the walking-arm count and no Three.js error occurred.

## 3D interior NPC picking and robbery HUD (2026-08-11)

- `activeAimSurface` switches from the world `ground` to `interiorFloor` inside authored rooms. NPC picking must accept both surfaces and copy `camera.layers.mask`; forcing layer 0 makes visible interior actors unpickable.
- A screen-space aim projected onto the floor is not accurate enough for a raised NPC, especially an owner behind a counter. After an instanced NPC pick, route the stable interior NPC id through the bridge and calculate the gameplay ray from the NPC's authoritative `r/c` coordinates.
- Canvas-only mission HUD is hidden by the production Three.js canvas. Critical progress such as remaining guards and owner pressure needs a small bounded DOM HUD updated only when its state key changes; do not rebuild HTML every frame.

## 3D business-owner identity (2026-08-11)

- Business owners should be authored in the gameplay source and bridged through the existing bounded interior NPC snapshot with a stable `visualRole`, wardrobe palette and hairstyle index. Do not infer ownership from a display name in the renderer.
- Premium owner details remain instanced: lapels, pocket square and three reusable hairstyle accents add bounded draw calls without allocating a mesh per owner or per frame.
- The normal pooled NPC label carries `ВЛАДЕЛЕЦ ЗАВЕДЕНИЯ` plus the owner's name. A shared fallback role texture is shown only while speech temporarily replaces that label, preserving identity without dynamic per-frame canvas painting.

## Vehicle hold-E prompt (2026-08-11)

- Reuse the existing 140 ms `nearbyVehicleState` sample for both the ground ring and the projected DOM prompt. Do not add a vehicle scan or a layout read to the render loop.
- While driving, bridge the current car as the same cached interaction with `kind: exit`; this keeps entry, hijack and exit on one hold-E state machine and one roof-anchored prompt.
- Project one persistent DOM node from the cached ring position, snap its coordinates to whole pixels, and only animate the inner progress width. A 650 ms hold prevents accidental entry/exit while staying responsive.

## Human-readable gang identity labels (2026-08-11)

- Normalize legacy `yellow`/`purple` faction codes once in the world bridge to `Моретти`/`Беллини`; renderer labels must never expose transport/debug identifiers.
- Carry the authoritative `mafia_family` beside the existing faction in aggro snapshots. Keep the legacy mapping as a compatibility fallback for already-running servers and old cached snapshots.
- Reuse the existing NPC label texture update signature. Family-name changes rebuild only the affected pooled label texture and add no scan or per-frame allocation.

## Desktop held-button mouse chords (2026-08-11)

- A second physical mouse button is not guaranteed to produce another `pointerdown` while RMB remains held. Keep the accepted RMB aim state authoritative and support `mousedown` plus a deduplicated primary `click` fallback inside the 3D canvas.
- The fallback must reject interactive DOM controls and use the last handled timestamp so the usual `pointerdown`/`mousedown` path and the late `click` cannot produce two shots from one press.

## Batched outlines in transformed groups (2026-08-11)

- Before baking a child mesh into a world-space outline batch, call `updateWorldMatrix(true, false)`. Calling only `updateMatrixWorld(true)` can leave a dirty parent group's translation unapplied, causing remote structures such as prison walls to appear as black wireframes near the city origin.

## Stable projected prompts and roof occlusion (2026-08-11)

- A world-anchored DOM prompt must be projected after the camera update on every rendered frame. Throttling only the interaction scan is safe; throttling the already-cached projection makes the label visibly step behind a smoothly moving camera.
- Snap projected coordinates to whole pixels and move the prompt with one 2D `translate(...)`. Keep its appearance animation opacity-only: blur or animated scale/translation competes with the world projection and looks like shaking.
- Keep building raycasts throttled, but retain occlusion state between samples. A short release hysteresis plus exponential opacity easing absorbs triangle-edge changes and prevents roof materials from flashing between opaque and transparent states.
- Do not fade a building's facade to the same low opacity as its roof. At night a 22% wall becomes visually indistinguishable from an empty lot; use per-material floors (about 52% for walls and 28% for roofs), and immediately restore the selected building's materials while its entrance prompt is active.

## Authoritative business-property markers (2026-08-11)

- Ownership visuals must consume `myBusinesses` through the existing two-second landmark refresh. A successful purchase may update the local cache immediately, but later server synchronization remains authoritative and can remove the marker after ownership loss.
- Reuse the cached roof-sign texture for the roof-mounted `СОБСТВЕННОСТЬ` plaque and one bounded instanced roof-contour batch for all purchasable businesses. On dynamic updates, compare a compact ownership signature and touch visibility/matrices only when that signature changes.
- Carry `owned` in the cached nearby-building interaction so the existing `E` prompt can say that the player is entering their property. Do not add another proximity scan.

## Authoritative gang world and business control (2026-08-11)

- Keep lair, roaming gangs, business operations and garrisons in the existing bounded `aggro`/city-gang snapshot. Never synthesize combat-capable fallback actors in the 3D bridge: disconnected mannequins look alive but cannot move, receive authoritative damage or return fire.
- NPC business ownership is display-only on the client and must be applied once at snapshot start. It may draw rings, flags and operation phases, but must never overwrite the server-authoritative player/family business status.
- Reuse the existing two-second landmark refresh for 3D business flags. The refresh signature contains only business ID, faction, guard ID/state and defense level, so unchanged snapshots allocate no new meshes and add no per-frame NPC scan.
- Deterministic regression QA covered two three-member factions, one bounded reinforcement, police response, street control, business march/capture/garrison/takeover, Lair warning/alarm/grenade dodge/boss fall and reconnect payload. The focused suite completed in `3.3 s`; the authoritative hire check debited SQLite from `$1000` to `$500` and returned the same balance to the client.

## NPC police custody (2026-08-11)

- Mark the exact NPC shooter at the kill event (`gang_id` plus stable `bot_id`); never infer an offender later from the nearest living gang member.
- Keep the offender in its owning gang object but exclude `_custody_id` actors from patrol, combat, reinforcement strength and ordinary aggro snapshots. This prevents one NPC appearing in a fight, police car and jail at once.
- Advance cuffing, escort, loading, routed transport, unloading, prison escort, the server-timed 60-second sentence and release in the existing bounded world tick. Snapshots carry only active custody records; the client reuses its NPC and police-vehicle render paths.
- Gang-response cops have no `target_uid`. The common cop cleanup must preserve cops with a valid `target_gang_id`, including Lair and nest lookups, or the response disappears before reaching the offender.
- Release at the visible police-station exit. The original gang actor can rejoin its formation or use a short independent roaming waypoint window before normal AI resumes.
- Fresh-main regression: all six embedded scripts pass `check_world.py`; `test_gang_world_ai.py`, `test_npc_life_system.py` and `test_npc_police_custody.py` pass. The snapshot-driven client path adds no new per-frame global NPC scan.

## Bounded police visual escalation (2026-08-11)

- An interactive quest car can be a police patrol even when it uses a civilian model. Preserve `police_patrol` as an authoritative render flag and override civilian paint before the 3D snapshot reaches the vehicle pool.
- Build patrol door panels, badges, push bars, tactical steps and heavy armor once inside the existing bounded vehicle slots. Wave changes only toggle nested groups; never allocate a new livery when a response car enters the radius.
- Keep every response tier in a recognizable blue family. Escalation should be communicated by silhouette (sedan, tactical unit, armored van, roof gun), equipment and scale instead of recoloring late waves almost black or red.
- Officer belts, radios, badges, shoulder patches and vests belong in the existing instanced NPC parts. This adds bounded draw calls and avoids one mesh hierarchy per officer.

## NPC custody route stress (2026-08-11)

- A passability check on one straight pursuit step is not pathfinding. In the first 120-position stress sweep, `29/120` NPC-murder responses stopped at building corners because officers never selected an alternate direction.
- Reuse the bounded pedestrian A* for the final offender approach. Cache route/index per officer, replan only after the offender changes cells or after a 2.2-second no-progress watchdog, and expose remaining nodes/replans/stalls through the existing cop snapshot. The identical sweep then completed `120/120`, with `0` stuck and a maximum `5.8 s` to cuffs.
- Never use the visible prison gate wall tile as a routing destination. The former `(80.5, 69.55)` target returned no route, causing a direct fallback through buildings in all `48/48` convoy samples. Route the vehicle to the passable road stop `(78.5, 69.5)` and use authored prison-gate/intake waypoints only after unloading.
- Validate the vehicle staging point before custody begins: it must be passable, reachable from the offender and have a route to prison. Keep it fixed while the officer escorts the NPC; recalculating it behind the moving officer makes the car drift.
- Post-fix end-to-end simulation completed all eight phases for `48/48` arrests with zero invalid outdoor escort/transport samples. Total simulated arrest-to-release time ranged from `86.9 s` to `116.0 s`, including the exact 60-second sentence.
- A separate moving-offender sweep completed `40/40` pursuits with `0` stuck; the slowest moving target was cuffed after `7.2 s`. Cell-change replans remained bounded (maximum `14` total across the two responding officers during one chase).

## Prison emergency lightbars (2026-08-11)

- Keep emergency lightbar housings fixed. Animate lens emissive intensity, inner emitters and bounded additive glow with a double-flash red/blue cadence instead of rotating the entire fixture.
- Preserve a constant scene-light count: only the two gate fixtures own zero-intensity `PointLight` slots, while tower fixtures use emissive meshes. Reusing shared housing geometry/materials keeps the six authored beacons inexpensive.

## Roof-mounted exterior signs (2026-08-11)

- A semantic building name must have exactly one exterior source. When a landmark already owns an authored sign, the generic POI/business loop must not add a second floating label; this removes the hospital, pizzeria, club, market and factory duplicates.
- Use world-space sign geometry attached to the roof: opaque board, shallow frame, two supports and a depth-tested texture face. Camera-facing sprites with `depthTest:false` behave like HUD and visibly slide over the roof while the player walks.
- Cache `CanvasTexture` instances by normalized label and accent color. The number of building names is bounded, so this avoids redrawing identical ownership/status textures without introducing a per-frame update.
- Treat ownership as a secondary strip joined to the main roof sign, not another hovering title. Continue toggling it from the authoritative two-second ownership refresh and keep the instanced roof contour as the long-distance ownership cue.

## Jail interaction boundary (2026-08-11)

- Check active jail state before cached NPC selections and other early-return interaction branches. A late jail guard cannot hide a stale action when an earlier remembered target already returned from the function.
- On entering or remaining in jail, clear the selected gang-bot id and expiry together with the visible action and target id. Do not merely hide the button: a delayed click or the next frame can otherwise revive the stale action.
- Mirror the client gate in both production and preview WebSocket hire handlers. An active sentence or custody marker must return `reason: jailed` before distance, faction or payment logic can mutate the fighter.

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

## Prison emergency lightbars (2026-08-11)

- Keep emergency lightbar housings fixed. Animate lens emissive intensity, inner emitters and bounded additive glow with a double-flash red/blue cadence instead of rotating the entire fixture.
- Preserve a constant scene-light count: only the two gate fixtures own zero-intensity `PointLight` slots, while tower fixtures use emissive meshes. Reusing shared housing geometry/materials keeps the six authored beacons inexpensive.

## Street actor density and foot NPC custody (2026-08-11)

- A persistent business garrison must count against the global city-gang quota. Excluding `guard` groups looked bounded in isolation but produced `4 patrols + N garrisons`, concentrating 18+ gang actors around adjacent businesses.
- Police dispatch is a desired per-gang quota, not an amount to append. Repeated witness/murder calls now spawn only the deficit; 12 repeated calls requesting two officers remain exactly two live assigned officers.
- Missing damage attribution is not player attribution. A corpse discovered by the delayed emergency scan with `source == null` can come from NPC crossfire or the environment and must not emit player `open_fire`/wanted.
- NPC offenders use a server-authoritative walking custody route: wounded → officer approach → cuffs → cached city A* to the prison road gate → authored prison intake path → 60 s cell → station exit. Player custody remains the existing vehicle pipeline.
- Reserve the custody record at the 30% wounded roll so the gang AI immediately excludes that NPC from combat. The arresting officer remains a visible leader about 0.72 tiles ahead; no client custody vehicle is created when `mode == foot`.
- Fixed-seed verification: 24/24 varied street starts reached the cell, with at most one route replan; deterministic lethal-hit branches verified 70% death / 30% custody; 3D preview loaded with no console warnings/errors.

## Dynamic effect buffers and police route reuse (2026-08-11)

- `InstancedMesh.count` is the authoritative visibility boundary for packed projectile, shell, bullet-hole, blood and gore pools. Do not rewrite hidden matrices above the active count. A slot entering the active prefix must still receive its complete matrix on that first visible frame; static decal matrix signatures therefore include source identity, position, rotation and scale.
- Cache the four projectile colour layers by the resulting colour/weapon class, not merely by actor id. Upload `instanceColor` only when one of those actual results changes. Gore limb/chunk colours follow the same slot-dirty rule. Bullet-hole and blood fading remains at full render cadence because its colour genuinely changes; only their unchanged matrices are cached.
- Player gait, weapon pose/recoil, reload state, blood count and wreck-fire DOM fields are diagnostics. Publish them through the existing 250 ms telemetry cadence; their underlying animation and effect transforms remain per-frame.
- A successful police foot route may live for 2.6 seconds while the target stays within the existing two-tile invalidation threshold. Direct collision checks still run every movement tick, and the existing 520 ms no-progress watchdog still forces an earlier replan. In the same ordinary-city preview scenario, measured BFS frequency fell from `10.85` to `7.23` plans/s (about 33%) while target-shift and stall recovery semantics stayed unchanged.
- Representative native-quality city samples changed from `26.5 ms` frame work / `22.8 ms` render to `23.2 ms` / `20.6 ms`. These are single-run scenario comparisons, not device-independent promises; scene population was 43 versus 40 NPCs respectively.
- Final local regression kept one browser tab and closed it afterwards. Pooled projectile/bullet-hole/blood/gore effects, compact NPC labels, chat local echo, real-time shadows and the server-backed `Гражданский` status remained intact. Prison assault reached `4:0` reinforcement state and `shadowed:3`; escort later progressed to `server-rejected` rather than sticking. Prison release reported `clean:local-timer:staged-world-resume-v311`, and repeated post-release fire produced a bullet hole without a runtime or Three.js console error.
- Remaining risk: the prison-return view still compiled two `mfz-wind-v3` programs (`227 -> 229`) during live rendering. The observed render maximum was `220.5 ms` after this package versus `384.8 ms` in the baseline run, but this is not considered fixed. The program growth happened with no active projectile effect, so future work should audit deferred-root wind shader warmup rather than degrade foliage, shadows or resolution.

## Shared police foot-route results (2026-08-11)

- Police officers can request the same cardinal BFS from the same map cell to
  the same half-tile target during one response. Cache that immutable path for
  2.6 seconds under the exact start/target key; each officer still owns its
  route index, expiry and retry time. Keep the cache bounded to 64 entries.
- Cache lookup happens before the one-BFS-per-frame reservation. Direct body
  collision checks still run on every movement tick, target movement still
  invalidates the officer route, and the existing 520 ms no-progress watchdog
  clears a path that cannot be followed. The change therefore does not bypass
  collision or turn shared state into a shared actor position.
- In a 20.066-second warmed city sample with 34 live NPCs, the cache served 29
  identical requests (`1.45/s`) while 108 real BFS builds remained (`5.38/s`):
  about 21% of otherwise required builds were avoided. The scene remained
  render-bound at 22 FPS and roughly 1,877 draw calls, so this is a CPU-spike
  reduction rather than a claimed average-FPS increase. One noisy run still
  recorded a `64.8 ms` route maximum during a `140.2 ms` render spike; do not
  present the maximum as solved without a controlled trace.
- The one-tab prison regression kept the clean staged release, server-backed
  `Гражданский` status, weapon confiscation, four-unit alarm response,
  `shadowed:3`, compact labels and real-time shadows. Input remained responsive
  after release; the preview spawn was still on the prison island, so attempted
  fire remained correctly rejected as `inside-prison`. No JavaScript or Three.js
  errors occurred; only expected missing-API warnings from the local static
  server were present.

## Static detail geometry batching (2026-08-11)

- The next measured city bottleneck was render submission, not the JavaScript simulation: a production sample spent `26.3 ms` of `29.2 ms` frame work in `renderer.render`, at `1843` draw calls and about `1.18M` triangles.
- The existing spatial static-detail merge was unnecessarily restricted to `BoxGeometry`, although it already copies the exact transformed vertex, normal and UV buffers. It now accepts ordinary opaque static buffer geometry with that same standard attribute layout. Instanced/skinned geometry, morph targets, vertex colours, custom render/depth callbacks, transparent material and custom attributes stay unmerged so shader behaviour cannot change.
- On the same loaded city content this increased merged static sources from `610 -> 778` and spatial batches from `69 -> 88`: 168 more authored details became 19 batches, removing 149 potential submissions without changing their vertices, materials, resolution, shadows or culling chunks. A diagnostic city sample then reported `1689` draw calls, `21.2 ms` render and `23.6 ms` total frame work at `1,175,416` triangles and 35 NPCs. A later production sample varied to `1846` calls / `29.1 ms` render as the streamed view and shadow set changed, so treat the 149 structurally removed submissions as the reliable result rather than promising a fixed FPS gain for every camera/time state.
- Fresh-main prison regression kept weapon confiscation intact (`shot`, grenade and C4 all rejected with unchanged ammo), completed release as `clean:local-timer:staged-world-resume-v311`, stayed responsive through repeated movement/fire input, and reactivated the prison assault with four units. Alarm shadow batching reached `shadowed:3`; the run had no JavaScript or Three.js error and preserved compact NPC labels, real-time shadows and the server-backed `Гражданский` status. The prison run measured `57.2 ms` maximum render work and `118.2 ms` maximum frame work while the escort was active.

## Shared cadence for high-volume 3D diagnostics (2026-08-11)

- Vehicle, medical, NPC gait/heading, wreck, custody, prison-gate, reload and arrest fields in `renderer.domElement.dataset` are QA telemetry, not gameplay state. Publish them through the existing 250 ms `telemetryDue` cadence while keeping movement, pose, damage, fire, siren, door and shadow calculations at full frame cadence.
- This removed roughly 58 redundant DOM attribute assignments per rendered frame and moved 14 diagnostic `filter`/`map` passes over cars and medical effects from every frame to about 4 Hz. The city comparison was render-bound and had different populations (`36 NPC / 1714 calls` before versus `39 NPC / 1814 calls` after), so its `23.8 -> 27.8 ms` frame samples do not establish an FPS gain. The reliable result is the bounded diagnostic work; do not present the noisy scene comparison as a speedup.
- Fresh-main browser regression kept one tab, native quality and real-time shadows. The prison weapon QA rejected shot/grenade/C4 without changing ammo, local-timer release completed cleanly, a new assault spawned four units, and the escort remained responsive with `shadowed:3`. At 67 visible NPCs the sampled frame was `26.6 ms` (`22.3 ms` render), with `96.7 ms` maximum frame work and `41.6 ms` maximum render work. Compact labels, corrected prison outlines and the server-backed `Гражданский` status remained visible; there were no JavaScript or Three.js errors.

## Matte wreck shader warmup (2026-08-11)

- The first vehicle explosion after a prison release changes the live car paint from clear-coated to matte (`clearcoat: 0`). That is a distinct physical shader variant for both the screen and shadow/linear passes. Before this fix the first post-release shot grew the program cache from `231` to `233` and produced a measured `78.5 ms` render peak; a deterministic vehicle-explosion rerun reached `95.2 ms` with the same two missing physical programs.
- Warm the matte paint with a single retained material proxy alongside the two already-required prison light warmup frames. Do not mutate the live car and do not add extra full-city renders. Removing the proxy is safe, but disposing its one material immediately releases the only GPU-program reference and makes the first explosion compile the variants again.
- Deterministic `previewprisonreleaseqa + previewcarexplosion` verification kept three visible point lights, reported the clean staged release, retained all explosion/fire layers and showed no explosion-time program growth. The sampled render maximum was `32.2 ms` (`22 FPS`, current frame work `20.5 ms`). A final rerun after rebasing onto the WebView RMB/LMB changes also had no explosion-time growth and measured a `36.6 ms` render maximum at `20 FPS`.
- The ordinary-city regression moved the player `0.193` tiles with a held `W`, rendered `37` live NPCs with `compact-readable-v264` labels and real-time shadows on, and sampled `27.1 ms` frame work / `23.5 ms` render. Server-backed status remained `Гражданский`; local chat submission advanced `chatLocalEcho`. Browser console had no runtime errors (only expected local static-server warnings for unavailable JSON API endpoints). One tab was used at a time and all tabs and the preview server were closed afterward.

## Business-assault reconnect and stall recovery (2026-08-11)

- Keep guard deaths, owner pressure, hit sequence and the one-time post-raid
  token in the existing server assault session. On reconnect, return this small
  bounded state instead of rebuilding progress from client visuals.
- Cache a terminal decision reply by `(uid, token)` for a short bounded window.
  A retry after a lost WebSocket response must replay the exact result without
  charging C4, transferring ownership or applying a payout twice.
- The client may make one timed retry only after the server cache exists. A
  second timeout restores the decision UI and waits for reconnect recovery.
- Stall recovery stays inside the already-bounded interior NPC list. Track
  per-guard progress, invalidate the shared route cache first, then perform a
  collision-checked local nudge; use an authored post only as the last fallback.
  Do not add a city-wide scan or allocate recovery work every render frame.
# City traffic and street-light readability (2026-08-11, v330)

- A city-wide lighting pass must not create one `PointLight` per fixture. Keep the nearest-player point-light pool bounded (four in this scene) and render the full network with instanced emissive bulbs, instanced additive head halos, and instanced ground glows.
- Traffic-signal state was already correct (`55` active fixtures and a changing `ew:ns` phase), but tiny flat-color lenses were visually unreadable from the isometric camera. A small radial-gradient halo texture plus a slightly larger lens preserves one draw call per color while making the active lens legible in daylight.
- Street lamps now use the explicit authored schedule: on from `17:00` through `06:59`, off from `07:00` through `16:59`. Do not infer fixture power only from the continuous sky daylight curve; twilight grading and the gameplay schedule are different concerns.
- QA telemetry: `data-traffic-signal-light-profile`, `data-street-lamp-schedule`, `data-street-lamp-power`, and `data-street-lamp-count`. Local time QA remains available through `preview=1&previewtimeoffset=<hours>`.

## Special NPC actions and delegated business collection (2026-08-11)

- Route a unique NPC from the authoritative bridge flag/role before the generic
  civilian classifier. Reuse the existing cached NPC pick and action overlay;
  do not add another renderer-side proximity scan or a duplicate 3D prompt.
- A delegated business action may aggregate the already-synchronized bounded
  `myBusinesses` map to label the interaction, but the server must revalidate
  assistant employment/salary, ownership and collectible income atomically.
- A recurring-cost NPC hire needs one explicit confirmation surface shared by
  every entry point. Show the immediate charge, daily cadence and projected
  balance, while keeping the server authoritative: the `$500` conditional debit
  and assistant insert remain in one `BEGIN IMMEDIATE` transaction.
- Static regression executed the real action-classifier/button functions for
  both hired states and checked both business-entry paths plus the server-backed
  collect-all dispatch. All six embedded `world.html` scripts passed syntax
  compilation; no new per-frame renderer work was introduced.
- Disposable SQLite verification confirmed `$1200 -> $700`; a `$400` balance
  stayed unchanged and could not create the hire. The confirmation is created
  only on demand and adds no render-loop work.

## Unique specialist roster (2026-08-11)

- Keep authored specialists in one fixed blueprint roster and reuse the normal
  four-connected pedestrian route planner. A unique passability predicate may
  narrow destinations to city pavement, but it must not create a second AI or
  movement loop.
- Persistent specialists are additive to the ambient population budget. Exclude
  them when counting ordinary resident slots, otherwise adding twenty story
  actors silently removes twenty citizens from the city.
- Bridge identity, title, salary and authored look through the existing bounded
  NPC snapshot. The renderer reuses its instanced body parts and pooled label;
  unique actors do not receive standalone meshes, materials or per-frame canvas
  painting.
- Until a specialist has an implemented server-authoritative service, show the
  quoted daily price but keep hiring disabled and perform no debit. This avoids
  charging for placeholder behavior or creating client-only employment state.
- Static QA confirmed 19 blueprints, 19 unique ids, names, looks and start
  points, complete required fields, and salaries from `$300` to `$1200`. Seven
  embedded `world.html` scripts and `three_preview.js` passed Node syntax checks.

## Autonomous NPC empires and headquarters assaults (2026-08-11)

- Simulate faction economy and territorial decisions in bounded five-minute
  server ticks, never in the render loop. Catch-up is capped at 72 ticks so a
  long-offline player cannot trigger unbounded work on first load.
- Keep one authoritative ownership row for businesses. NPC factions use stable
  negative owner ids, which preserves the existing property UI/API without
  inventing a second ownership source or colliding with Telegram ids.
- Headquarters combat is tokenized and server-authoritative. Guard HP, the
  guard-before-boss gate, hit-rate limit, boss HP and final resolution all live
  in SQLite transactions; the client only predicts animation and reconciles the
  returned values.
- A terminal assault choice is single-use. Annexation, looting or vassalization
  transfers cash/ownership and marks the token resolved in the same
  `BEGIN IMMEDIATE` transaction, preventing double rewards after retries.
- Reuse the existing bounded interior NPC/guard AI and the existing instanced
  3D humanoid pool. Unique boss guns add two instanced detail parts with a
  19-color signature table; do not allocate a standalone model per boss or per
  frame.
- Static and disposable-SQLite QA confirmed 19 unique empires/HQs, all 171
  ordered boss-to-boss diplomacy pairs, exact `$500` diplomacy debit, unchanged
  balance on insufficient funds, guard gating, and single application of the
  headquarters reward/business transfer.

## Endless NPC-empire sandbox lifecycle (2026-08-11)

- Never permanently delete an authored boss after an HQ defeat. Collapse the
  faction into a bounded ruined state, remove its holdings/economy/army, reset
  all player and NPC diplomacy to neutral, and store one server comeback time.
- Comebacks are processed inside the existing five-minute empire tick. A due
  leader receives one free unoccupied HQ, two fighters, low strength and a
  small trait-based bankroll; no timers or simulation work are added to the
  client render loop.
- District control is a cached aggregation of the already-bounded holdings
  table. Headquarters, buildings and businesses carry fixed weights; eight
  district rows plus cached leader totals are recomputed once per server tick.
- A decisive NPC war may collapse a rival only after its final non-HQ holding
  falls. The victim is excluded from the remainder of the same tick to prevent
  stale-row resurrection or post-defeat actions.
- The client receives the leaderboard, district standings and recent chronicle
  with the normal empire snapshot. Its sandbox dashboard is event-driven and
  creates no new world scans or per-frame allocations.
- Disposable-SQLite QA verifies ruined to rebuilding, neutral reputation reset,
  a new HQ, exactly two comeback fighters, a single comeback event, nineteen
  ranked leaders and all eight district standings.
