# Committed traversal/ladder pose — 27 September 2026

## Result

Both controllers now expose `committed_pose(rig: Dictionary = {}) -> Dictionary`.
This is a read-only presentation receipt, not a skeleton/body writer. It closes
the gap between the earlier probe prediction and the smaller prefix accepted by
the actual CharacterBody. It also follows any additional ladder terminal-support
truncation inside `commit_step`.

## Required host order

1. `step = controller.propose_step(...)`.
2. Physically test and execute each leading root, counting actual acceptance.
3. `state = controller.commit_step(step, actual_count, blocked_reason)`.
4. `pose = controller.committed_pose(rig_metrics)`.
5. Apply that pose through the existing sole player rig writer.

`step.pose` remains a prediction for inspection. It is insufficient for rendering
when the world changes after proposal, the CharacterBody accepts fewer samples,
or the ladder terminal-support guard rejects a later sample. Do not reuse it
after those cases. Restore the capsule height from the committed state when a
rejected sample temporarily changed it; this helper owns no collision shape.

The traversal snapshot retains reach preparation, source motion progress and
landing-settle stage. Zero accepted samples and aborts keep the last accepted
root. The ladder snapshot derives contacts and rotations from committed
travelled/mount/dismount state. Unbound/disposed states return `valid:false`.
Neither call mutates action state, input, pose authority, bone, weapon or body.

## Files and checks

Modified only `scripts/traversal/traversal_controller.gd` and
`scripts/traversal/ladder_controller.gd`; new own test
`scripts/tests/test_traversal_committed_pose.gd`.

Actual official Godot 4.7.2 headless:

- new actual CharacterBody late-blocker / zero-prefix / partial ladder / abort /
  disposal regression: 18/18 PASS;
- traversal controller: 122/122 PASS;
- ladder controller: 33/33 PASS;
- real-body ladder safety lifecycle: 17/17 PASS.

New snapshot-only warmed CPU, 256 samples: traversal p50/p95 48/65 us;
ladder 24/25 us. These are isolated CPU measurements, not loaded-scene FPS.
It replaces the predicted pose read in the host; do not render both snapshots.

Frozen file hashes are in
`outputs/traversal_committed_pose27/manifest.json`.
No main/player/project/export/Git/GPU/LIVE edits were made. Coordinator21 owns
host hookup, actual male/female rig acceptance and the single visible restart.
