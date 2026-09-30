# Compiled30 passage followup — PASS, headless only

The unchanged compiled candidate30 is physically passable after three actual RPG rounds and one native jump. The exact original third-shot guard passed; no target, collider, damage, capsule, mask, source geometry, or acceptance threshold was changed.

- PCK: `65cc360a59e53896c9404f44ac4fcd81227ee3876de555362e130d91c6263043`.
- Assembly: `18670dcf97af806bad0d36e1f5b94bb47503affdfcc1d89c9ee19ed9e3abc7a2`; all 271 pinned source files unchanged.
- `run02/RUN.json`: exit 0, 23.1578 seconds, 565 checks PASS, no native errors. Own PID43100 exited; ordinary user game PID41296 was preserved.
- Three finite-ammo RPG shots, three native impact terminals, three completed destruction events. Targets remained `(15.8, 1.105/.555/2.1, 2.3085)`.
- After the third upper-wall impact the actual native overhead ray at the passage hit y2.60, compared with y1.95 after the first two shots. The roof was not targeted.
- W plus exactly one Space produced 56 observed native jump frames, then landed on the native floor. Final position `(15.86144, .104897, .757849)` is 1.55065 m behind the front wall. All original capsule/mask and three NPC identity checks passed. The 105 mm floor lip remains physical and is crossed by the ordinary jump.

## Actual reload and aim trace

The 17 retained snapshots show `_aiming=true`, `_held=false`, `_pressed=false`; native R loaded the real magazine. Before LMB the state was magazine1/reserve1/reload0/cooldown0/sequence2. LMB then committed shot3.

While transitioning from the low target to the upper target, the first sampled sight intersects the floor and the next intersects the rear wall. At `reload_1` the camera and muzzle already hit the front face at y1.991734; at `reload_30` they converge to y2.099996. All sampled post-reload settle frames remain on that front face. At the original guard, camera and muzzle z are 2.3085003 and 2.3084998. Owner contact resolution identifies component7, current surface4/triangle19, as the intended front strip.

This headless run does **not** reproduce or explain the earlier `compiled_gpu02` third-sight failure. Its early transient rays are observed facts, not proof of that failure's cause. The minimal next rendered check should retain the same aim snapshots immediately before the existing third guard, including a failure snapshot, rather than change damage or geometry.

## Evidence and limits

`FOLLOWUP_SUMMARY.json` SHA256 `1ce8414159c456bd45648c003d316609343f65b8ebbdb8069a8f41cc3dca878a` links exact evidence hashes. Full retained evidence: `run02/RESULT.json`, `run02/AIM_TRACE.json`, `run02/DIAGNOSIS.json`, `run02/RUN.json` and the three executed QA sources. The first two-shot module/triangle diagnosis remains immutable in `run01` and `REPORT.md`.

This is a compiled functional result, not GPU, FPS, OS focus, whole-city performance, full house collapse, W-only traversal, or NPC breach-entry acceptance. It retains the original headless fixture: one explicit clear-floor player placement, attached camera, `_free_mouse_look=true`, and native synthetic mouse/button/key events. There were no NPC teleports or runtime/source edits. No further engine runs are scheduled by this agent.
