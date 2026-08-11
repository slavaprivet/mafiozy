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

## Boss identity during backend reconnects (2026-08-11)

- Authored empire leaders must carry a small static client identity (boss name
  and gang) in addition to their authoritative economy snapshot. If the backend
  is restarting, never downgrade them to the old specialist/service label.
- Keep the fallback bounded to the same nineteen roster entries. It may render
  boss labels and an offline dossier, but must not invent treasury, ownership,
  diplomacy mutations or assault results.
- Pass one boss flag and gang string through the existing 3D NPC snapshot. The
  pooled label canvas can then switch from the specialist card to the boss card
  without adding sprites, meshes or per-frame world scans.

## Shared wind shader programs (2026-08-11, v336)

- Foliage colour is a standard `MeshStandardMaterial.color` uniform and does
  not change the injected wind GLSL. Do not include that colour in
  `customProgramCacheKey`: eight leaf tints and four trunk tints otherwise
  compile identical source separately. Keep the two actual shader variants
  distinct by their authored leaf/trunk bend constants; colour, geometry,
  animation cadence, shadows and distance remain unchanged.
- On the latest main after the NPC-empire/blue-police updates, the same active
  prison-assault profile changed from 325 WebGL programs with 72 NPCs to 300
  programs with 71 NPCs. Current frame/render samples were effectively equal
  (`26.6/21.5 ms` versus `26.0/21.1 ms`), so this does not claim an FPS gain.
  The reliable result is 25 fewer resident programs in that scene.
- The first prison-combat shader expansion is still a major remaining spike:
  the two samples measured `1749.9/1746.1 ms` maximum frame/render before and
  `1498.8/1391.6 ms` after. Different arrest phases and populations make that
  timing comparison noisy; do not call the spike fixed. The reduced program
  count only makes the transition lighter without changing visible content.
  A fresh-main visual check preserved the separate green tree shades and
  real-time shadows at native quality; it reported 227 programs and no console
  errors.
- Final one-tab regression completed the four-unit escort as
  `jailed:escorted-to-booking` with `delivered:1`, kept compact NPC labels,
  `idleNpcLegMotionMax=0.0000`, chat local echo and real-time shadows, and had no
  JavaScript or Three.js errors. Clean release remained staged (`resumeFrames:3`)
  and a temporary focused probe outside the prison/causeway confirmed renewed
  fire (`accepted:true`, `blocked:false`) with continuing frames. The probe was
  removed, and every browser run used one tab which was closed together with
  the local server.

## Dirty boss-weapon instance colours (2026-08-11, v339)

- The four instanced signature parts of boss weapons (`rail`, `charm`, `stock`
  and `muzzle`) previously forced `instanceColor.needsUpdate` from
  `onBeforeRender`, uploading all four colour buffers on every rendered frame.
  Their matrices and charm animation must still update every frame, but their
  authored colour changes only when the NPC slot receives a different boss or
  colour.
- Precompute the nineteen weapon variant indices once and cache an
  `id:colour` signature per NPC slot. Write all four instance colours and dirty
  their buffers only when that signature changes. Clear the signature whenever
  the weapon is hidden or its slot becomes inactive so the first visible frame
  always restores the complete colour set and cannot show a stale/ghost colour.
- Do not claim an FPS gain from the available samples: the baseline and result
  had different NPC populations and the intervening main update added two new
  weapon parts. The reliable result is removal of four unconditional colour
  buffer uploads per rendered frame plus the per-NPC `Object.keys(...).indexOf`
  allocation/search. On fresh main, the one-tab boss preview kept four nearby
  bosses, real-time shadows, native `1.00` pixel ratio and the locked quality
  policy; a representative sample was 18 FPS, `27.2 ms` frame work, `18.4 ms`
  render and 225 programs, with no Three.js error.
- Regression QA kept chat local echo (`12:<timestamp>`), accepted a normal-city
  3D shot through the gameplay bridge (`confirmedShots:1`, route `firearm`),
  and kept the real server status as `Гражданский`. Prison QA rejected pistol,
  grenade and C4 without consuming ammunition/items and then completed a clean
  staged release (`resumeFrames:3`). The local static server still emits the
  known business/apartment JSON warnings because those API routes are absent;
  they are harness-only and not game/Three.js errors. The single browser tab
  was closed after the run.

## Inactive and settled instance matrices (2026-08-11, v340)

- `InstancedMesh.count` already excludes inactive remote-player slots from
  rendering. Do not zero-scale every unused slot or upload the three remote
  body/head/hat matrix buffers when `count === 0`. Iterate only the active
  prefix, clear inactive colour/speech signatures, and write every matrix on
  the first visible frame so slot reuse remains complete.
- Corpse blood expands for its authored first 2.4 seconds and must keep its
  per-frame matrix updates during that interval. After the spread settles,
  cache source identity and projected position; live slots cache their hidden
  matrix. Clear signatures above the active NPC prefix so a reused slot cannot
  inherit a hidden or settled transform.
- The measured city/effect baseline had `r0`, no corpse pools and still reached
  the unconditional remote/corpse upload paths. Final effect QA reported
  `corpseBloodMatrixUpload=cached` with zero corpses and preserved four moving
  projectile profiles, eight bullet holes, six blood decals and two gore
  pieces. A separate ambulance fixture kept one visible settled corpse pool
  while also reporting `cached`, proving the visible settled matrix survived.
- Do not claim an FPS gain from the noisy samples: the effect baseline and
  result had different populations (`46` versus `41` NPCs) and measured
  `30.4/24.9 ms` versus `26.4/24.0 ms` frame/render work. The reliable result is
  removal of three empty remote matrix uploads plus the empty/settled corpse
  matrix upload; active remote motion and the blood-spread animation retain
  their full cadence.
- One-tab prison regression rejected pistol, grenade and C4 without consuming
  ammunition/items, completed `clean:local-timer:staged-world-resume-v311`
  with three resume frames, then accepted two consecutive exterior firearm
  shots (`magazine 10 -> 8`, updated shot timestamp, no prison block). The real
  server-backed status remained `Гражданский`, chat local echo advanced, native
  pixel ratio and real-time shadows remained on, and there were no JavaScript
  or Three.js console errors. The representative prison sample was `17 FPS`,
  `31.6 ms` frame work and `22.0 ms` render work, with maxima `91.9/65.4 ms`.

# Proximity-gated NPC identity labels (2026-08-11, v341)

- Reuse the existing throttled `nearbyNpcState` and brass foot ring as the only
  focus source; do not add a second distance scan.
- Civilian, police, gang and guard identity cards stay hidden until their exact
  pool index is within 3.05 tiles and owns the visible foot ring. This keeps at
  most one ordinary identity card visible at a time.
- Dialogue, bosses and unique interaction NPCs remain exempt so required
  conversations and authored characters do not lose their labels. Standalone
  guard and owner role badges still obey proximity focus.
- Healthy, unfocused NPC HP bars stay hidden; damaged actors keep their HP bar
  visible. Telemetry records visible, hidden and focused identities under the
  `nearby-ring-focus-only-priority-dialogue-v341` profile.

## Readable focused character labels (2026-08-11, v342)

- Once ordinary identity cards are proximity-gated to one ring-focused NPC,
  their world-space scale can increase by about 15% without returning to the
  former screen-wide overlap. Keep the existing 768x192 pooled canvas and only
  change sprite transforms; this adds no textures, draw calls or frame scans.
- Apply the same restrained increase to the local player name and the compact
  custody/response variants so nearby character labels remain visually
  consistent. Large dialogue, boss and unique-NPC cards already have adequate
  scale and should remain unchanged.

## Corpse marker and organic blood pool (2026-08-11, v343)

- Death overrides the proximity-gated identity rule: every active dead NPC
  reuses its existing pooled identity sprite for one compact `☠ МЁРТВ` card.
  The card texture is repainted only when the slot receives a different dead
  name, so the render loop adds no canvas work or new label objects per frame.
- Keep corpse blood in the existing instanced pool and its settled-matrix
  cache. One shared 192 px canvas texture supplies overlapping dark lobes,
  coagulated centre shading, an irregular transparent edge and bounded splash
  droplets. This improves the silhouette without particles, timers, extra
  per-corpse meshes or another draw call.
- A close local corpse fixture visually confirmed the readable two-line death
  card above the fallen body. Final one-tab ambulance QA reported exactly one
  dead label and one blood pool, `corpseBloodMatrixUpload=cached`, native pixel
  ratio, real-time shadows and no JavaScript or Three.js errors. Chat local
  echo advanced and the real server status remained `Гражданский`.
- The representative final sample had 58 NPCs, `17 FPS`, `36.0 ms` frame work,
  `24.3 ms` render work and a noisy `199.0 ms` render maximum during streaming.
  Do not claim an FPS gain from this visual package; its reliable performance
  property is reuse of the existing label/decal pools and settled matrix cache.

## Full-size decorative collision cars (2026-08-11, v344)

- MAP obstacle type `2` is a static parked car, not a live traffic vehicle. Its
  old two-box `3.5 x 1.75` silhouette was much smaller than the `5.8 x 2.75`
  traffic shell and had no wheels, which made every such obstacle look like a
  toy car beside the player.
- Keep these collision visuals in static instanced obstacle pools. A full-size
  body, roof, hood and one shared four-wheel pool add two bounded static draw
  calls but no per-frame object creation or scans; transforms are written only
  when a streamed map obstacle is first registered.

## Dirty decal colour buffers (2026-08-11, v345)

- Bullet-hole and ground-blood matrices were already signature-cached, but
  both active pools still called `setColorAt` for every slot and marked the
  complete colour buffer dirty on every rendered frame. The local combat-FX
  baseline confirmed the hot path with eight bullet holes and six blood decals.
- Cache the exact rendered colour beside the existing matrix signature. A new
  bridge snapshot still updates every authored fade step at full cadence; only
  repeated render frames of the same snapshot skip identical colour writes and
  GPU uploads. Include geometry/source state in the signature so slot reuse and
  the first visible frame cannot inherit an incorrect colour.
- Telemetry exposes `bulletHoleColorUpload`, `bloodColorUpload` and the
  `bridge-snapshot-signature-v345` profile. This package must not claim an FPS
  gain from noisy scene samples; its reliable result is removal of redundant
  full colour-buffer uploads without changing resolution, effects or visible
  animation cadence.
- Final one-tab combat-FX QA kept four moving projectile profiles, eight bullet
  holes and six blood decals visible while both colour-upload telemetry values
  reported `cached`. Native pixel ratio, the locked quality policy and
  real-time shadows remained enabled; gameplay bridge was connected, chat
  local echo advanced and server-backed status remained `Гражданский`. The
  final merged sample reported 20 FPS, `38.3 ms` frame work, `27.5 ms` render
  work and 227 programs. It also preserved the incoming full-size parked-car
  package (`89` collision visuals, `10` active static obstacle draw calls).
  Do not use this noisy single-scene sample as an FPS comparison.

## Dirty shell matrix buffer (2026-08-11, v346)

- Shell physics remains authoritative in `world.html`: position, height and
  rotation advance on every simulation tick. The Three.js bridge samples that
  state every 45-70 ms, but the renderer previously rewrote every active shell
  matrix and uploaded the complete instance buffer on every rendered frame,
  including repeated frames of one unchanged bridge snapshot.
- Cache a slot signature containing source identity, position, height and exact
  rotation. Every changed physics sample still updates on its first visible
  frame at the existing cadence; only byte-for-byte equivalent repeated poses
  skip `setMatrixAt` and `instanceMatrix.needsUpdate`. Reused slots are safe
  because all render-affecting source fields participate in the signature.
- A temporary local-only fixture confirmed the hot path with 12 active shells;
  it was removed before the package. The baseline sample reported 21 FPS,
  `28.8 ms` frame work, `26.5 ms` render work and 227 programs at native
  quality with real-time shadows. Do not claim an FPS gain from that single
  sample; use `shellMatrixUpload` and `bridge-snapshot-signature-v346` to verify
  the structural result.
- Final one-tab effect QA kept all 12 shell instances visible and reported
  `shellMatrixUpload=cached`. The representative result sample was 20 FPS,
  `30.9 ms` frame work, `27.3 ms` render work, a `42.3 ms` render maximum and
  227 programs. Native pixel ratio, locked quality, real-time shadows and the
  gameplay bridge remained intact; chat local echo advanced, server-backed
  status stayed `Гражданский`, and no Three.js error was reported. The fixture,
  browser tab and local server were all removed or closed after verification.

## Raised labels and framed NPC health (2026-08-11, v347)

- Raise living-character label transforms and the nearby action-prompt anchor
  together. This preserves their vertical separation without adding another
  NPC scan or projection pass; corpse labels intentionally remain close to the
  ground.
- A richer health indicator can retain the existing two-sprite NPC pool. Share
  one frame texture and one fill texture across every slot, then resize and
  offset the fill sprite for a left-anchored value. Do not create a canvas or a
  texture per NPC or redraw the frame every animation tick.
- Hide the health indicator for dead NPCs. Healthy focused targets and damaged
  living targets keep the established visibility rule, while the fill colour
  continues to communicate healthy, warning and critical thresholds.
## Settled gore matrix buffers (2026-08-11, v348)

- Detached limbs and their two pooled chunks use an analytic ballistic flight.
  The renderer clamps flight time at `flightEnd`; after that point position,
  height, spin and both chunk offsets are mathematically constant, but both
  complete instance-matrix buffers were still uploaded on every rendered frame.
- Keep all airborne `setMatrixAt` writes and uploads at full frame cadence. Once
  a slot reaches `flightEnd`, cache the exact final limb/chunk pose signature;
  the landing frame is written before subsequent identical frames become
  cached. Identity, final position, spin and limb scale participate in the
  signature so a reused slot cannot inherit a wrong settled transform.
- The existing `previewgore` baseline confirmed two active limbs (and four
  chunks) at native quality with real-time shadows. Its representative sample
  was 18 FPS, `34.5 ms` frame work, `26.3 ms` render work, a `44.1 ms` render
  maximum and 227 programs. Do not claim an FPS gain from this noisy scene;
  verify the structural result through `settledGoreInstances`,
  `goreMatrixUpload` and `full-flight-settled-signature-v348`.
- Final one-tab QA on the merged raised-label/framed-health build sampled a
  complete preview cycle: eight samples stayed `dirty` while at least one limb
  was airborne (`settled=0/1`), then 24 samples became `cached` only after both
  limbs landed (`settled=2`). The final noisy sample reported 22 FPS, `27.2 ms`
  frame work, `25.2 ms` render work, a streaming-affected `138.6 ms` render
  maximum and 227 programs, so it is not an FPS comparison. Native pixel ratio,
  locked quality, real-time shadows, the new shared framed HP profile, gameplay
  bridge, chat local echo and server-backed `Гражданский` status remained intact
  with no Three.js error.

## Raised framed NPC health anchor (2026-08-11, v349)

- Keep the shared frame and fill sprites unchanged and raise only their pooled
  group anchor. This places health between the character head and the already
  raised identity card without adding textures, draw calls, scans or per-frame
  allocations.
- Apply the same one-unit lift to standing and crawling poses so injury
  animation cannot push the framed indicator back onto the character model.
## Projectile matrix snapshot signatures (2026-08-11, v350)

- The four instanced projectile layers (body, trail, glow and core) previously
  rewrote every active matrix and uploaded all four buffers on every rendered
  frame. Projectile physics remains authoritative in `world.html`; the 3D
  renderer receives discrete bridge snapshots every 45-70 ms, so render frames
  between snapshots can contain byte-for-byte identical poses.
- Cache a per-slot signature containing identity, position, elevation,
  direction, body scale, trail length, glow scale and core scale. Every new
  bridge position is still written immediately to all four layers; only a
  repeated unchanged snapshot skips `setMatrixAt` and buffer uploads. This does
  not interpolate, quantize or reduce the visible projectile cadence.
- Full QA must cover all thirteen projectile weapon profiles (`pistol`,
  `nagan`, `revolver`, `pistol_heavy`, `pistol_gold`, `shotgun`, `smg`,
  `tommy_gun`, `golden_tommy`, `rifle`, `sniper`, `taser`, `rpg`) plus the
  non-projectile `grenade`, `molotov`, `c4` and unarmed visual states. Verify
  `projectileMatrixUpload` and
  `bridge-snapshot-signature-all-firearms-v350`; do not infer an FPS gain from
  unmatched scene samples.
- A bounded localhost-only QA fixture now renders all thirteen projectile
  profiles together with moving and held bridge phases; the existing model
  audit covers seventeen primary states and sixteen aliases. Final one-tab QA
  reported `17:16:0` (no model faults), kept all 13 projectile profiles visible
  and observed both `dirty` and `cached` matrix-upload states. The final merged
  run sampled 12 moving/dirty and eight unchanged/cached frames. Grenade,
  Molotov, C4 and unarmed remained explicit non-projectile profiles. The
  representative final sample was 22 FPS, `26.2 ms` frame work, `23.6 ms`
  render work, a `34.5 ms` render maximum and 227 programs. Native pixel ratio,
  locked quality, real-time shadows, the incoming raised framed-HP profile,
  gameplay bridge, chat local echo and server-backed `Гражданский` status
  remained intact with no Three.js error.
## Health-fading identity cards (2026-08-11, v351)

- Use the existing player-name canvas and pooled NPC-label canvases as the
  health indicator. At full health their black backing is complete; on damage
  the dark background recedes from right to left through a soft transparent
  edge while bright text and the role-coloured frame remain readable.
- Remove the separate player and NPC health sprites entirely. NPC canvases are
  repainted only when their existing signature or integer health percentage
  changes, and the player canvas follows the same bounded health signature, so
  the effect adds no per-frame texture creation, draw calls or population scan.

## Expired combat-effect source cleanup (2026-08-11, v352)

- Shells, muzzle flashes, blood splats, impact particles, explosions,
  throwables and Molotov fire already expire in the simulation and all combat
  pools have hard caps. Bullet holes are intentionally persistent but remain
  bounded to 32. The confirmed retention was `bodyPartFx`: detached limbs
  stopped reaching the 3D bridge after their authored eight-second life, but
  their source objects stayed in the 12-slot array until later sever events.
- Prune expired detached-limb sources on the existing 250 ms effect telemetry
  cadence. Do not shorten their visible life or landing animation. Track the
  four delayed wall/RPG impact paths through one `try/finally` scheduler so QA
  can prove every pending callback releases its counter after firing.
- The localhost lifecycle fixture reached `g12:q24` (twelve expired source
  records and 24 pending callbacks) and then settled to `g0:q0`. A static
  listener audit found no effect-spawn or update-loop path that registers new
  listeners; the active map editor revision installs its handlers once, while
  legacy revisions are not initialized.
- Final one-tab QA on the reconciled health-card/NPC-empire main kept the v351
  health-fading identity cards, chat local echo, the server-backed
  `Гражданский` status, native `1.00` pixel ratio, locked quality and real-time
  shadows. The representative noisy sample was 19 FPS, `39.7 ms` frame work,
  `28.1 ms` render work, `54.4 ms` render maximum and 225 programs. This is not
  an FPS comparison. No JavaScript or Three.js error occurred; only the known
  missing business/apartment API warnings from the static server were present.
## Nineteen signature gang weapons (2026-08-11, v345)

- A single generic gun box with a firing pitch near `-1.16` rotated the barrel
  through the NPC head. Author weapons along local `+Z`, keep the ranged root at
  chest height (`y ~= 2.25`) with a near-horizontal pitch (`-0.055`), and move
  both pooled arms onto the grip and fore-end. Melee weapons use a separate
  bounded swing pose instead of reusing firearm recoil.
- Do not build nineteen standalone Three.js groups. Ten shared instanced weapon
  part pools (body, rail, stock, muzzle, grip, drum, blade, charm, two limbs and
  four spikes per slot) produce the 19 silhouettes through fixed transforms and
  per-instance colors. This adds six bounded instanced layers over the previous
  four-part signature system, with no per-frame mesh/material allocation.
- Arrow, harpoon and dart flight reuses three bounded projectile instance pools
  (shaft, head and fletching, cap 48). Their transforms are written inside the
  existing projectile pass, and all three pools are included in shader warmup;
  do not create a mesh or compile a material when a crossbow first fires.
- Combat parameters originate in `npc_empire.py` and travel in state/assault
  snapshots. The JS table is only an offline/local-preview mirror. Guards and
  bosses share their family's weapon id/profile, avoiding preview colors or a
  stale base-gun profile replacing live server state.
- Local QA at `previewzoom=2.6` showed ranged weapons held across the chest in
  both idle and forced firing/recoil poses without crossing the head. The same
  scene exercised three simultaneous signature projectiles with the bounded
  budget `n72:r0:p3:s0:b0:g0`, native shadows and no browser/Three.js console
  warnings or errors. This is a correctness/capacity result; no FPS gain is
  claimed because the weapon preview intentionally changed actors/projectiles.

## Long boss routes and visible crews (2026-08-11, v348)

- A boss carrying out a server `activity` must not reuse the local civilian
  wander target. Build the complete route only when the activity key changes
  or a confirmed blockage requires a retry.
- The boss walknet uses street tiles `0/8/9/18/19`; ordinary unique NPCs remain
  restricted to pavements `8/9`. The long search is capped at 42,000 visited
  cells and retries after 1.2-4 seconds, never on every rendered frame.
- Do not visualize all server members for all nineteen families. The client
  shows at most four nearest crews, one to three escorts each, with an absolute
  cap of 12 NPCs and a 1,800 ms membership refresh cadence.
- Empire escorts are excluded from civilian population and respawn accounting.
  Otherwise hired fighters silently displace residents and alter city density.

## Stable prison-light shader family (2026-08-11, v353)

- Material colors are uniforms and were not the cause of the high program
  count. A localhost-only compiled-source audit found 225 cached programs but
  only 167 unique vertex/fragment GLSL pairs: 58 pairs were byte-identical.
  Each duplicate cache key differed only by the outdoor PointLight count
  (`1` versus `3`).
- The startup warmup itself created the redundant family by rendering the
  complete city once with both quiet prison-beacon roots visible and once with
  those roots hidden. Gameplay already keeps the roots visible and switches
  the two authored lights off with zero intensity, including normal, custody
  and alarm transitions. Remove only the hidden-root warmup render; do not
  detach, recolor or reduce the beacon lights.
- In the same ordinary preview scene the cache settled at `114/114` unique
  programs with no duplicate compiled sources, down from `225/167`. Forced
  prison beacon animation plus all thirteen projectile profiles remained at
  `114/114`; a confirmed pistol/laser-firearm shot settled at `113/113` with
  no duplicate or late shader family. Real-time shadows, the gameplay bridge,
  server-backed `Гражданский` status and all 17 weapon states/16 aliases
  (`17:16:0`) remained intact. Do not claim an FPS gain from these unmatched
  scene samples; the confirmed result is lower shader-cache/program pressure.

## Creator anatomy and city body-profile parity (2026-08-11, v342)

- Keep free creator rotation transform-only: pointer dragging updates the existing character group's Y angle and label, never rebuilds the rig or option-card snapshots. Rebuild geometry only when a saved look field actually changes.
- The detailed creator may use a richer local rig (separate shoulders, upper/lower arms, elbows, hands, thighs, knees, calves and shoes) because it owns exactly one animated WebGL context. Option cards continue to reuse the single static off-screen renderer.
- City body composition must remain a bounded local-player concern. Apply the saved body profile by scaling the existing torso/arm/leg meshes and toggling at most one belly/chest accent; do not add another actor loop, skeleton system or per-frame allocation.
- Preserve the saved `body/face/hair` integers across the world bridge. The city renderer exposes compact QA signatures (`data-player-body-profile`, `data-player-face-details`, `data-player-hair-profile`) only when the visual signature changes.

## Collision-safe character accessories (2026-08-11, v343)

- Classify creator choices before changing hair visibility. Only fitted head coverings (`1,2,3,4,7,8`) tuck the crown hair; glasses, the eye patch and the chain remain independent accessories and must never create a generic hat.
- A fitted hat can hide the high-volume hairstyle mesh while retaining two small temple locks (and a tucked rear lock for long hair). This avoids z-fighting without adding collision tests or per-frame geometry allocation.
- Anchor the chain in front of the greatest body/armor depth when applying the body profile. The full body needs a dedicated forward offset because its belly is parented to a torso whose depth scale also affects the belly mesh.

## Gender-readable creator silhouettes (2026-08-11, v344)

- A single uniform width multiplier does not make creator gender readable. Keep shoulder, waist, hip, limb and depth multipliers separate so the same four body profiles remain recognisable while male/female silhouettes differ.
- Reuse one female face-detail group and one body silhouette group in the city rig. Toggle and rescale those existing meshes only when the authoritative look signature changes; do not build geometry in the animation loop.
- Creator and city must apply the same semantic shape: narrower shoulders and waist, wider hips, a tailored chest, slimmer limbs, lashes, lips and earrings.

## Shared creator-grade city character rig (2026-08-11, v354)

- Keep the saved creator look authoritative and map the same `gender`, `body`,
  `face`, `hair` and `hat` meanings onto both the playable city avatar and every
  NPC. In particular, creator ids `5`, `6` and `9` are glasses, eye patch and
  chain; they must not be treated as generic fitted hats.
- Rounded body/limb capsules, hands, layered shirt, face parts, gender details
  and all ten hair/accessory meanings remain bounded shared `InstancedMesh`
  pools for the 72-NPC render cap. Reuse the existing owner hair pools for long
  hair, quiffs and fringes; separate shoulder, elbow, lapel and duplicate-hand
  pools pushed the clean close-view sample down to 14 FPS and were removed.
  Do not build a standalone Three.js object tree per resident and do not allocate
  geometry or materials in the animation loop.
- A localhost visual pass checked both a full female/chain/curls look and a
  heavy male/glasses/long-hair look beside the unique Said NPC. The city exposed
  70 stable appearance variants in the measured population. After consolidating
  the redundant pools, the steady close-NPC view reported 22 FPS, `19.7 ms`
  current frame work, `15.2 ms` current render work and 710 view-dependent draw
  calls, with no browser console errors. Earlier samples of the same optimized
  rig varied to 669 calls / `15.7 ms` render as the streamed and shadowed scene
  changed, so compare structural pool count rather than promising a fixed draw
  count for every camera position.
- Local `previewcity=1` may bypass the character menu only on localhost and only
  when the URL already supplies `character` plus `has_look=1`. Production keeps
  the server-backed character gate unchanged.

## NPC anatomy and micro-expression pass (2026-08-11, v355)

- Improve population silhouettes by replacing the shared capsule torso with one
  lathed neck/shoulder/chest/waist profile. Body diversity still comes from the
  existing per-instance X/Z profiles, so this changes geometry once rather than
  introducing a skeleton or object hierarchy per NPC.
- A tapered shirt panel, one two-wing collar geometry, a shared jaw and an
  optional beard pool add clothing and face depth. Rounded shoes reuse the same
  paired pool. Keep these details instanced and hide them through the common
  death/slot lifecycle to prevent detached parts after an NPC dies or despawns.
- Blinks and tiny pupil saccades are deterministic functions of time and stable
  pool index. They allocate no vectors, timers or tweens and remain inside the
  existing bounded NPC pose loop. A 3-second QA window observed one or two
  simultaneous blinks throughout all 30 samples.
- Count every paired (`hand`, `brow`, `ear`, shoes and equipment) and quad hair
  pool from the active NPC instance count. Previously several paired pools kept
  their full 72-NPC capacity active even when the visible population was smaller.
- Local close-view QA held 22 FPS with no console errors. Samples reported
  `16.4-17.5 ms` frame work, `12.9-14.4 ms` render work and `661-683`
  view-dependent draw calls. Geometry detail increased the sampled scene to
  about `1.82M` triangles, but submission and frame timings remained below the
  v354 comparison sample; retain the shared-pool design if adding more detail.

## Articulated NPCs and semantic weapon details (2026-08-11, v356)

- Split the shared NPC arm into an upper-arm pool plus one paired forearm pool.
  Derive elbow, forearm centre and hand endpoint from reused quaternion/vector
  scratch objects inside the existing pose loop. This gives walking, firing,
  phone, medical and cowering poses visible elbow bends without per-NPC bones,
  allocations or object trees.
- Role clothing uses one shared tapered lower-garment pool for police, medics,
  guards, owners, bosses and deterministic civilian/female variants. Its colour
  is updated through the existing appearance signature, and it participates in
  the common despawn/death hiding path.
- Detail the held arsenal with a fixed semantic mesh set reused across weapon
  families: trigger guard, front/rear sights, ejection port, top rail, barrel
  shroud, stock pad, bipod, sling ring, safety pin and special wire. Configure
  transforms only when the equipped weapon changes; never create a hidden full
  hierarchy for every inventory item.
- The localhost arsenal audit covers 16 armed profiles plus `none` and all 16
  aliases. It requires at least two semantic details for every armed profile and
  zero for `none`. The v356 run returned `17:16:0` (profiles:aliases:faults):
  pistols 4-5 details, shotgun 6, SMG/Tommy 6-7, rifle 8, sniper 10, taser 7,
  RPG 4, grenade/Molotov 2 each and C4 3.
- A close populated preview held 22 FPS with no console errors at 678 draw
  calls, `21.4 ms` frame work and `14.0 ms` render work. A wider streamed city
  view naturally rose to 2,043 calls / `26.1 ms` render while retaining 22 FPS;
  compare like-for-like camera views and remember that only the selected weapon
  exposes its detail subset.

## Player wars with autonomous bosses (2026-08-11)

- Keep durable war pressure on the server tick/state path. A declared war stores
  one `next_attack_at` row per boss/player pair; a due strike blocks one owned
  business and immediately advances the deadline in the same transaction. This
  prevents duplicate bombing rewards/effects when several clients poll together.
- Do not add a new proximity timer for hostile bosses. Mark the boss and its
  already bounded escort pool from the 30-second empire snapshot, then activate
  fire inside the existing NPC update pass. The crew synchronizer remains capped
  at 12 visible members and runs at its existing 1.8-second cadence.
- A relation score and a war pact are different state. Negative sentiment alone
  must not silently start a war; the explicit declaration is allowed only below
  zero. This distinction is also important for UI labels and for cleaning stale
  scheduled attacks after compensation, truce, alliance or an empire collapse.
- Regression measurement: the server integrity scenario (schema, declaration
  guard, one due business strike, deduplication state and truce cleanup) completes
  in the same test batch in about 1.5 seconds. Inline `world.html` syntax checks
  pass across all 6 script blocks; the change adds no render objects or draw calls.
- A boss needs a concrete world destination, not just an economic event label.
  Derive one deterministic `activity` per 75-second server slot and include its
  target in the existing 30-second state snapshot. Do not create a movement
  timer per boss. A live browser sample showed the selected boss move 5.11 tiles
  in 6 seconds and finish a 14-node route while the existing escort pool stayed
  capped at 12 and the world simulation held its configured 30 FPS.
- UI portraits must not silently remain on the 2D fallback in a 3D preview.
  Every relative module referenced by `/preview/world.html` needs a matching
  `/preview/...` route. The dossier renderer reuses one offscreen WebGL snapshot
  scene for all static canvases, rebuilding only the selected character between
  draws; do not allocate 19 simultaneous renderers. Browser QA confirmed the
  first six empire cards and the opened dossier all reported `portraitMode=3d`.

## Empire ownership colours, headquarters and work loops (2026-08-11, v357)

- Keep family identity on the existing 72-slot NPC instancing path. Bosses and
  their bounded escorts carry the same server-authored primary/accent pair;
  reuse the existing gang aura and clothing instance colours instead of adding
  a mesh or material per fighter.
- Headquarters are a fixed pool of 19 marker groups. The dynamic bridge sends
  only active, nearby, server-owned HQs; losing `hq_key` or entering `ruined`
  removes the ring, rooftop flag and gang-name label on the next snapshot.
  Label canvases repaint only when ownership, name, colour or coordinates change.
- Reaching an activity target must not leave a boss idle until the next
  75-second server slot. After a short visible inspection dwell, reuse the
  collision-safe route planner for deterministic nearby work waypoints. Do not
  add timers or a second NPC scan. Browser QA observed Sofia move 10.74 tiles in
  nine seconds while her route shrank from 45 to 13 nodes; the bounded scene
  exposed 11 escorts and 12 active nearby HQ markers.

## Physical NPC empire wars (2026-08-12, v358)

- NPC-vs-NPC diplomacy with `pact='war'` now overrides the 75-second visible
  activity with one deterministic `gang_war` order. The server publishes the
  same enemy, stance and force to every client and remains authoritative for
  holdings and economy.
- Do not create a second global combat loop. Field combat runs in the existing
  NPC update, reuses `spawnBullet`, `spawnMuzzle`, `_npcMuzzleWorldPoint`, hit
  reactions and 3D shot timestamps, and becomes physical only within 52 tiles
  of the local player.
- Target selection is throttled to 260-365 ms per fighter. The visual budget
  remains four nearby leaders and at most twelve escorts; the existing caps of
  50 bullets and 16 impacts remain active during family firefights.
- Boss/escort AI compares local force and combat HP to choose advance, strafe,
  focus fire or a timed retreat to the authoritative HQ. Unique bosses retain
  story invulnerability outside this separate field-combat HP pool, avoiding
  accidental civilian death, witness and ambulance flows.
- The 3D bridge exposes field HP plus `_shotAt`, `_shotSeq` and `_shotWeapon`;
  omitting any of these makes real combat look static in 3D.
- Local preview seeds exactly one NPC-family war for immediate QA. Production
  never uses this fixture: its orders come from SQLite diplomacy and the
  five-minute empire tick.

## Confidence-driven empire firefights and dossier UI (2026-08-12, v359)

- Do not equate weapon ideal range with an automatic backward step. Compute a
  bounded confidence value from local ally/enemy count, both families' server
  strength and current combat HP. A confident squad presses or holds its firing
  line; retreat is reserved for critical HP or a real power ratio below 0.68.
- A confident shooter locks its current target for 3.2 seconds and enters a
  short pressure window. This prevents target thrashing and the visible
  shoot-one-round/backpedal cadence without adding searches: force counts are
  cached during the already throttled 260-365 ms target scan.
- Weapon cadence may tighten while pressing, but still uses the shared bullet,
  muzzle and impact caps. Never emulate sustained fire with a new interval or
  per-weapon timer.
- The empire dossier is CSS/DOM UI, not a WebGL scene. Reuse its single portrait
  canvas and style the surrounding command strip, bevels and action panels;
  reset the card scroll position when switching from the dashboard so the
  sticky header cannot cover the portrait and identity block.

## Family-colored empire fighter labels (2026-08-12, v360)

- Empire crew identity cards must consume the same authoritative `bossColor`
  and `bossAccent` already used by their clothes and ground aura. Include both
  colors in the cached canvas signature so a changed family style repaints once
  instead of becoming stale.
- Reuse the fixed NPC label sprite pool and the existing proximity-ring
  materials. Updating their colors does not justify new sprites, meshes or a
  second per-frame label pass.
- A family card may create its gradient only inside the signature-gated repaint
  branch. Never allocate gradients during unchanged animation frames.

## City-wide empire roaming (2026-08-12, v361)

- Peace-time boss orders must not orbit the headquarters. Choose one
  deterministic destination per existing 75-second activity slot from a
  bounded city-wide pool covering both city halves, the bridge, coast and
  port. This changes only the server snapshot; never add a roaming timer or a
  render-loop target search.
- The empire walknet may use every connected public land tile
  (`0/7/8/9/14/15/17/18/19`) while still respecting the shared pedestrian
  collision probe and the authored prison, arena and lair exclusions. This is
  what lets a family cross the bridge and reach the beach, pier and port
  without walking through water, buildings or container stacks.
- Preserve the 42,000-node route cap and the existing retry cadence. The full
  180x200 map has fewer cells than that cap, so coast/port reachability does
  not require a second pathfinder or per-frame work.
