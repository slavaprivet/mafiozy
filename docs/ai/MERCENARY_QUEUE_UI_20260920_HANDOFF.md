# Specialist queue UI — 20 September 2026

Owner `/root/safe_operator_clearance18`. Code and focused tests READY; root owns the single LIVE game tab. Source queue contract: [MERCENARY_QUEUE_20260920_HANDOFF.md](MERCENARY_QUEUE_20260920_HANDOFF.md).

## Integrated behavior

- X over an additional eligible target offers “В очередь” while the specialist is busy. Both X and command-panel submissions keep the current action and report the new object number.
- Current work is marked green with number 1; waiting targets are restrained amber with subsequent numbers. These markers persist after aim moves away. Ordinary aim remains red. Completed targets have no marker. Numbers are per member, with member names in label titles.
- Smooth rounded object arcs are retained. NPCs retain lower rings. Cars get only a small overhead X/number, never a hull outline or fill.
- Presentation is capped at 10 targets including aim. Current tasks receive priority; an aimed queued target is included even when it was outside the cap. V/X-ground clearing is source-owned and removes presentation on the next ordinary sync.
- The command panel shows each member's waiting list and queue count. Waiting-list ordinals count waiting tasks; scene numbers also include the current task.
- Actual fleet vehicle `damage.state` is now consulted. `wrecked`, `destroying`, HP <= 0, or destroyed object metadata invalidate the target. A visible wreck no longer offers X—Подорвать or accepts a new plant command.

## Files

New `mercenary_task_markers.mjs`; integration in `mercenary_walk.mjs`, queued palette in `mercenary_selection_view.mjs`, panel presentation in `mercenary_command_ui.mjs`, actual wreck state in `mercenary_targets.mjs`. All under `assets/maps/city_rebuild_v1/`. No core/world edits in this scope.

Markers use a fixed pool of at most ten presentation views and DOM nodes. Geometry is cached for a retained target; progress, queue promotion, camera changes and color changes do not rebuild it. Materials belong to the pooled views; source materials and geometry are never mutated. DOM overlay intentionally has no `data-walk-hud` attribute to avoid the earlier fullscreen badge-mask issue.

## Verification and limits

Combined queue/UI/selection/walk tests: **38/38 PASS**. A final cap adjustment preserving the aimed queued target was followed by affected marker and walk suites: **6/6 PASS**. Coverage includes actual source X queueing, stable current action ID, persistent 1/2 markers, FIFO promotion, V cancellation, cap/deduplication, vehicle marker without hull, completed removal, behind-camera hiding, panel labels, and actual fleet wreck rejection by prompt and source.

CPU fixture of ten task marker updates: p50 **0.0058 ms**, p95 **0.0122 ms**. Worst fixture objects add ten draws / 7,680 triangles; geometry builds stay at ten after repeated updates. This is a CPU fixture, not a matched whole-scene FPS measurement. Source queue's own validation is documented separately.

**LIVE and performance of the shared game scene are not checked here.** Root should load source+UI together and verify panel then fence queue, green current/amber next, promotion, V cancellation and a wreck without prompt. DOM number labels hide behind camera, outside clip, detached/invisible or over 100 m; they do not yet raycast against walls. The 3D arcs retain depth testing. Current action includes its approach phase and is green before physical work starts.
