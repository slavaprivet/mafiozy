# Current actual host audit: melee21 → editor pause prerequisite

27 September 2026. Read-only source audit by editor document agent. No main/player/nav/production/frozen changes, engine runs, GPU/browser/game creation or external task messages. Parent reports LIVE PID43848; this audit does not attest that process or loaded resource versions. Source `main.gd` declares `s01-20260927-melee21`. Previous comparison: `MAP_EDITOR_HOST_CALLBACK_AUDIT.md` (physics18).

## Decision: one real next owner step

Implement **root-owned pause-only lease against the actual existing crop and its actual owners**, before any terrain replacement. Exercise K/editor-camera entry and exit without changing a single object or floor. This is a genuine main/transport/melee/navigation seam, not another isolated fixture. It does NOT admit editable terrain, water, full-map expansion or all-building movement.

Do not make main ALWAYS: descendants inherit it, potentially running player/transport while editor is open. Give only the editor-owned root ALWAYS; leave game subtree pausable. Lease must record previous `SceneTree.paused` and relevant input/camera states and restore only its own transition; external pause cannot be stolen. Non-mutating failed preflight must leave everything unchanged. After any actual entry mutation, a failed restoration must keep lease retained and gameplay blocked, not discard a token.

First admission should require actual `preview_ready`, no death/physics fault, stable owner-confirmed ON_FOOT grounded pose, no traversal/seat/door transition. Native vehicle bodies still exist while ON_FOOT: tree pause stops engine physics globally, whereas turning off transport process alone does not. No ad-hoc native-body restore, zero-controls or pose-authority change may replace its owner.

Melee policy must be explicit: the existing actual owner `preview_melee.cancel(reason)` can cancel held/active practice input and restore its camera offsets. Cancellation is a mechanic-visible policy, not exact preserve/resume. Obtain root/owner agreement and test its source cooldown/reset result. Alternative preserve-time policy needs a genuine pause-aware combat clock; none exists. Never silently shift all source timestamps.

Navigation admission cannot be implemented as `diagnostics().jobs == 0`: `_jobs` retains terminal records. Existing diagnostics expose total jobs, not a proof of all live continuations. Actual navigation owner needs an inspectable, generation-bound quiescence receipt: no pending bake/waiting snapshot/query/deferred completion or queue continuation. Do not call `dispose()` to manufacture quiescence: it destroys the map and source owner lifecycle. Start with refusing entry during BAKING/SYNCING and active work; owner must supply exact active-job inventory or reversible cancellation policy. A retained callback may still complete during pause, so the owner must reject/hold it under the same lease generation.

## What changed and what did not

SHA256 below is an exact read-only file snapshot, not compiled-script identity or LIVE attestation.

| Current file under scripts/ | SHA256 | Comparison to physics18 audit |
| --- | --- | --- |
| main.gd | 0916381441df9a9d111006aed2b34e4e1c2ec195ee24609757a552b388017571 | changed; installs melee practice, no editor owner lease |
| preview_player.gd | 92885321c2bf8d98e99967399b4284df6ef60894a67976b94a7d50f2293ed9ee | changed; melee/input/pose cancellation now relevant |
| preview_transport.gd | 4abd577e319e198ce2d6155e6a4fb4f968a3a7ca303497735d1a983f320ec15a | changed; no global pause checkpoint contract |
| preview_water_surface.gd | 7d89235d93f31dd565aadf37f549a05074bec5534acfb120543228f1dba2655c | identical |
| navigation/preview_navigation_host.gd | 0b6fd34bc1d77e1f27c2005b699477453f089f4f65bf7d21942e73adbad631d4 | identical |
| navigation/preview_engine_navigation.gd | aca4ff31b689a5b652ca85ddd0999d45696debb912bb8e1495f056d02db69aab | identical |
| preview_population.gd | 91815fd8851151fe8443a85b84b268a95a04c07ff39f0a136c60c631f58fe37c | identical |
| npc_visual/preview_resident_world_policy.gd | f4e35012690fd4c6cd2c43a6973a8bb9d92b7ad34d493eba5084715eb6ed17f8 | current exact floor/source policy remains relevant |
| combat/preview_melee.gd | 5098c2a1c98757446fa71bcb23117f3dfacc9b121d4c66d226ad572a6d64e5dc | newly relevant wall-clock owner |

Old water/terrain/navigation blockers therefore remain. Main still creates the original crop surface directly, not a GroundRenderer adoption capsule. Native full-map output tests do not prove this scene is full-map. No current main path mounts a final editor or adopts edited ground into navigation.

## Actual APIs and hazards

Paths relative to `godot/mafiozi_walk/scripts`; line references can move as owners work.

| Actual entry point | Current semantics / consequence |
| --- | --- |
| main `_ready` 88; awaits physics frames 177–178; `preview_ready` | Do not pause during bootstrap and claim a ready scene. Capture/save coroutine at 829 awaits `RenderingServer.frame_post_draw`, separate from physics lease. Headless must not call GPU frame capture. |
| main `_physics_process` 522 | Advances printshop doors and population. Scene pause stops pausable callbacks, but public owner functions remain callable. |
| main `_process` 799–815 | Water receives absolute `Time.get_ticks_usec()/1e6`; frame sample uses wall-clock delta. Resume creates a water phase jump and a bogus giant frame sample unless root defines its intended clock/sampling policy. Water visual-time freeze is not already implemented. |
| main `_build_surface` 599 | Direct-child Surface MultiMeshes and dry floor strips, water tile16 excluded when detailed water succeeds. Floors are split by exact tile key, not only solid state. Even dry grass→asphalt may alter strip grouping/node identity; do not infer topology/owner parity just from equal height. |
| main `_cache_jump_surface_contains` 349; `preview_jump_surface_allowed` 383 | Original surface-derived traversal cache; edited crop needs owner-approved new capsule, not mutation of pinned `_block`. |
| `preview_water_surface.build` 80 / `advance` 139 / `dispose` 146 | `advance` updates shader time/ripples. `dispose` frees original instance/material factory. There is no prepare/swap/rollback/re-admit callback for edited water cells. |
| `preview_population.setup` 21 / `step` 59 | Source-admits actual navigation and floor policy; `step` pumps navigation and resident state. RefCounted owner has no automatic process-mode protection if called externally. |
| navigation host `attach_existing` 112 / `_publish` 222 | Initial exact source floor/collider capture into cached `_static`; direct main floors and sibling printshop interior. No edited GroundRenderer root adoption. Repeating attach is not a transactional scene replacement. |
| backend `publish_source` 64 | Invalidates jobs and frees old map before replacement; not reversible rollback. Staged map/policy swap requires a new owner seam, not passing this method as editor nav success. |
| backend `_baked_callback` 108 / `_finish_bake` 113; `_query_callback` 228 / `_finish_query` 231 | Async completion invokes RefCounted `call_deferred`; native RID/map/job state may mutate even when game nodes stop processing. Epoch guards protect stale source, but no editor pause generation exists. |
| backend `diagnostics` 306 / `dispose` 311 | `bakes_inflight`, `queued_snapshots`, total jobs/map iteration useful for diagnostics. No complete public active-continuation barrier. Dispose increments epoch and frees map, not reversible pause. |
| `path_job_queue._now` 63 / `finish` 171 / `cancel` 193 | Absolute wall clock and 4000µs slice; cancellation deliberately retains current/served until finish/frame change. Do not claim cancellation empties every continuation. Quiescent finish/frame-boundary receipt needed before pausing; no raw timestamp rewriting. |
| melee `_allowed` 46 / `clock_ms` 50 / `cancel` 89 / `advance` 113 | Permission checks grounded on-foot/control/focus but not tree pause/editor lease. Absolute elapsed time can expire contact windows on resume. Manual callback invocation is not prevented by process modes. |
| player `_physics_process` 266 / `_unhandled_input` 603 / focus `_notification` 657 | Input polling plus monotonic jump request time; focus callbacks may alter cursor while editor owns it. Source-approved camera accessor and mouse-capture API exist, but editor needs precedence for focus recovery. |
| update panel NotesPoll timer 75 | The only explicit ALWAYS process mode found in actual scripts/scenes scan. Polls notes JSON and updates UI; this benign callback remains active during pause. Do not treat it as gameplay stopped proof. |

## Godot pause boundary (official docs)

Tree pause stops normal pausable node processing and 2D/3D physics; ALWAYS editor processing does not automatically restart physics. Signals can still invoke connected methods regardless of processing mode. Therefore tree pause alone cannot attest async owner/resource immutability. See [Godot pausing games](https://docs.godotengine.org/en/stable/tutorials/scripting/pausing_games.html).

`SceneTree.create_timer` defaults to `process_always=true`; any future owner timeout must declare its pause policy explicitly. See [SceneTree reference](https://docs.godotengine.org/en/stable/classes/class_scenetree.html). Tick clocks measure elapsed engine time, not gameplay pause duration; use an agreed gameplay clock where mechanics require frozen elapsed time, not fabricated source timestamps. See [Time reference](https://docs.godotengine.org/en/stable/classes/class_time.html).

## Headless acceptance scenarios for the actual owner implementation

These are required scenarios, NOT runs or PASS claims from this audit. Instantiate actual main scene/data in the single headless process; no substitute geometry, fake callbacks or GPU capture. Source may be staged read-only outside production with exact hash closure. LIVE remains owner21 permission-gated.

1. Actual baseline ready: source crop, surface/floor identities, body transform/velocity, printshop door states, nav map/iteration/jobs, player camera/input/pose, melee snapshot. Enter/exit pause-only lease; no object/ground edits. Verify exact identities/resources, ownership and no extra surface/floors/actors.
2. During lease run several process frames with explicit editor ALWAYS sibling/root: editor camera/UI works; player/transport/doors/population callbacks do not advance; actual vehicle body physics does not drift. Observe connected signals separately rather than assert all callbacks stopped.
3. Residents-enabled actual main: attempt entry while BAKING, SYNCING and path query pending. Fail before mutation or complete genuine owner drain. Deliver retained deferred completion while paused and ensure no new admitted gameplay map/job receipt can escape lease generation. Test real source owner, not direct helper mock success.
4. Melee charge/block/attack held at K entry, focus loss and mouse release while paused, then resume: root-approved cancel policy leaves no held attack or camera kick, no accidental input action. Record cooldown policy. Traversal/seat/door transitions must refuse or use their actual owner checkpoint contract.
5. External pre-existing tree pause, stale/double receipt, owner freed/replaced, root scene reload deferred during lease, failure after camera/input mutation, rollback failure: never unpause external owner or drop unknown partial lease. Retain actionable failure until recovery.
6. Wall-clock pause: water phase and first frame sampling have explicit policy; no bogus FPS report. Path slice not left active over pause. Resume gates on owner revalidation before first physics update, not after actors start moving.

After pause-only real-host acceptance, next separate step is **adopt existing crop terrain inventory without rebuilding**: capture exact direct-child surface batches/floor strips/materials, source origin/palette, water instance and jump cache; original-node rollback; no duplication. Only then prepare edited floor/nav/world-policy/water swaps. Protected water, source auth and building locks remain HOLD until their actual owners approve transactional replacements.
