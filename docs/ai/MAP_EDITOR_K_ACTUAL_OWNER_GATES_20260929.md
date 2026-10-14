# Godot K editor: actual S01 owner gates, 29 September 2026

Read-only audit of `godot/mafiozi_walk/scripts/main.gd` SHA-256
`653837bb2365c92f9e290e1f8c5126bf6fbb5357da8db3570cdb6f1bec9f6d50`
(Git commit `d8ae1d1c7d03`). Production has no K pause/editor hookup.
`preview_ready` alone is insufficient: optional transport, melee and residents
are installed before it, but optional setup can fail without preventing READY.
This document defines admission needs; it does not grant readiness. The
tools-only derived probe belongs in `tools/godot/map_editor_main_pause_candidate`.

| Owner | Source evidence | Required enter/verify/resume contract |
| --- | --- | --- |
| Player/traversal | `preview_player.gd:268-310,333-353,640-690`; `_pose_authority`, `_pose_epoch`, `_jump`, `_source_falling`, direct `Input` polling | Exact actor/life/pose receipt, stable grounded or explicitly supported pose, no active dive/jump/fall transition, preserve transform/velocity/capsule/camera; absolute-time dive needs virtual-clock or refusal. |
| Transport/body | `preview_transport.gd:189-216,236-386`; native body independent integration/contact | Exact session/vehicle/seat/life/phase/control receipt, stable ON_FOOT or separately admitted SEATED, refuse APPROACH/HOLD/BOARDING/EXIT_HOLD/EXITING/RETURNING_TO_SEAT without owner hold. Preserve body transform/linear+angular velocity, control and collision ownership. |
| Melee | `preview_melee.gd:48-50,87-135`; source cooldown and held mouse | Preserve original absolute time before first K; pause only with exact action/timer/held-input receipt and virtual active time. `tools/godot/map_editor_native_clock_candidate` proves narrow native clock semantics, not full gameplay admission. |
| Printshop/doors | `main.gd:482-503,522-529`, `preview_printshop_interior.gd:158-189` | Door fraction/target/collision/occupant/nav-version receipt. Refuse a partial transition until owner can hold and restore it. |
| Residents/navigation | `preview_population.gd:40-66`, `preview_engine_navigation.gd:102-123,223-229` | Main physics stops the pump, but asynchronous bake/query callbacks defer finish work. Need generation/job/transition quiesce and callback barrier, or refuse K when active. Physics-stop alone is not proof. |
| Water | `main.gd:804-809`, `preview_water_surface.gd:139-145` | Main passes absolute `Time.get_ticks_usec` to water. Offset/hold simulation and ripple age or refuse detailed water; default is enabled. No visual phase jump on resume. |
| Impacts | `main.gd:509-518`, `player_impact_host.gd:189-212` | Explicitly inventory installed optional host; refuse an active impact until physical receipt/rearm exists. |

Input is a cross-owner barrier, not merely a handled event. Player polls
`Input.get_vector`/run/jump, transport polls physical E and driving keys, and
melee stores held mouse booleans. Key-up can occur while gameplay callbacks
are stopped. K entry must consume gameplay input, reconcile stale held flags
without inventing presses, and require release/rearm before gameplay resumes.
On failed exit, physics and gameplay input remain blocked. `NOTIFICATION`
focus-out paths do not substitute for this barrier because K is not focus loss.

The editor-only K listener must keep processing under `SceneTree.paused`
without moving the gameplay parent to `PROCESS_MODE_ALWAYS`; otherwise the
same K cannot close the editor. A successful candidate must show native input
K enter/exit, no player/vehicle physics ticks while paused, unchanged body and
source cooldown state, preserved water phase, no async navigation mutation,
same-key exit and refusal in unstable states. Measure cold load, idle frame
cost and p50/p95 on comparable loaded scenes before LIVE. A default S01
residents-disabled pass cannot be advertised as full population/nav acceptance.
