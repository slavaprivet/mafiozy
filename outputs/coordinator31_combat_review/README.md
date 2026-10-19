# Medieval combat checkpoint — 18 October 2026

Production: `outputs/coordinator31_npc57/game`. Castle optimisation belongs to another agent; this checkpoint changes weapon scripts only.

Melee: palm sockets replace wrist anchors; both hands solve one handle; carried two-hand weapons retain the support hand. Blade safety uses corrected segment distances and rechecks the solved pose. Sword steering uses bounded acceleration, damping and a reachable target; sustained ground contact settles rather than repeatedly bouncing. Edge roll advances once per physics tick and cutting quality distinguishes edge/flat motion. Torso receives angular-load response. Static weapon meshes are combined by material with reduced primitive subdivisions; sword, mace, hammer, spear, axe and shield geometry corrected.

Castle deferred loading requires a weapon host on first equip. `preview_weapons.gd` now prepares that host before changing equipment state. Target-placement fallback rejects invalid ground positions during scene construction.

## Evidence and limits

`ACCEPTANCE.json`: merged19, 1504 independently measured rendered poses, no self-pose failures; minimum torso/head proxy clearances 0.223/0.233 m. Sustained ground pressure: angular speed settles to zero, no conservative overlap. One transient overlap of the conservative 3 cm world probe occurred elsewhere in the run; this is not a proof of perfect continuous world collision. Contacts/edge mathematical checks passed, stderr empty. Visual catalogue18 passed mesh-normal and retained-bow-string checks.

Input is scripted button state plus injected mouse motion. City residents disabled for the combat fixture. This is neither manual feel acceptance nor an isolated FPS benchmark. Body clearance uses skeleton capsules, not exact skinned-mesh collision. Bow draw/arrow/quiver work is a subsequent stage; initial bow changes here only batch static visuals and adjust materials.

## Reproduce

From repository root, using installed Python and the locked Godot executable:

```
python -X utf8 outputs/coordinator31_combat_review/run_review.py unique_run_name --production --display
```

Runner uses the project test scheduler. Choose an unused run name. `display_probe.gd` loads `qa31/pose_telemetry.gd` relative to itself. `contact_checks.gd` is a separate headless script. Raw failed runs are retained locally; do not classify them as passing.

Next user order: finish melee, then bow (RMB aim/trajectory, LMB fire, hands/nock, quiver/arrows, sounds and impacts, G/E and icons), then catapult visuals and physical pushing. FPS optimisation is assigned elsewhere.
