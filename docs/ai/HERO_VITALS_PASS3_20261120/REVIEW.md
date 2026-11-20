# Hero vitals and death, 20 November 2026

## Changes

- Body diagram keeps critical injury visible even when the limb's controls are disabled. Only reset on a new life restores healthy colours.
- Severing the head forces HP to zero and enters the shared death path. Death clears an active burn timer.
- Armor on the diagram follows actual equipment change events. Light, medium and heavy layers are distinct; severed pieces remain visible and are never covered by armor graphics.
- The current weapon's existing thumbnail appears before its name. The healthy status line is hidden.
- Combat and fatal falls use one death presentation. Controls stop, the articulated hero falls, the camera pulls up to a side view, and the message names the cause. The death entry point is idempotent.
- The local articulated physics driver is prepared once before armor meshes are added to the rig. It sleeps until death. This fixes the `pose_binding` failure observed with equipped armor; no injury status polling was added.

## Checks

- `test_hero_vitals_integration.gd`: PASS in headless Godot, including injury persistence, armor equip/remove, weapon icon and head sever.
- `test_hero_death_presentation.gd`: PASS in the castle scene, including death while armored, body motion, camera, combat/fall cause and duplicate death events.
- `test_hero_vitals_visual_capture.gd`: PASS in graphical Godot with mixed armor; physical start and impulse true, head lower relative to pelvis after falling. Screenshots in local `exports/win64/hero-pass3-qa`.
- DeepSeek review: `deepseek_prompt.txt` and `deepseek_response.txt`. Recommendations were checked against code and the live runs; the review itself is not acceptance evidence.

## Limits

No matched 50-vs-50 FPS measurement was made in this pass. The graphical capture FPS includes capture and scene startup and is not a performance benchmark. Physical torso bisection is outside this change.
