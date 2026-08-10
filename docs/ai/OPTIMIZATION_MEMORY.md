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
