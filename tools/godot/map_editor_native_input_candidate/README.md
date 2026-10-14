# Native input conformance — actual source objects, headless only

27 September 2026. This source-only fixture does not modify the frozen source assembly,
production project, main/player, GPU state or Git. Stage validated current
source through the existing stager (196 original GLBs / 30,212,460 bytes,
procedural+transport source buffers; 1373 files; cacheCopied:false). The test
runs externally against the resulting fresh project; no import/UID cache is
copied. Baseline negative runner remains in outputs/map_editor_native_input_conformance.

```powershell
node tools/godot/stage_map_editor_assembly.mjs --stage --procedural --transport
# Use destination returned by the stager below. Observed validated stage:
& 'C:/Users/Слава/AppData/Local/MafioziTools/Godot-4.7.2/Godot_v4.7.2-stable_win64_console.exe' --headless --editor --path outputs/map_editor_source_assembly_xzhZTw --import
& 'C:/Users/Слава/AppData/Local/MafioziTools/Godot-4.7.2/Godot_v4.7.2-stable_win64_console.exe' --headless --path outputs/map_editor_source_assembly_xzhZTw --quit-after 1200 --script 'C:/Users/Слава/Desktop/Мафиози/tools/godot/map_editor_native_input_candidate/test_native_input.gd'
```

## Scope

Real existing Controller/Camera3D/panel and registry `pick`, no pick overrides.
Explicit viewport 1280x720. Native camera ray projects screen (640,360) through
actual current source bounds. Registries and native factories admit source SHA.
Owner callbacks are geometry-only fixture admissions; they do not prove live
game pause, nav/traffic/support/colliders authority or script lifecycle safety.

Tested originals:

- Authored GLB `buildings:REBUILD-VISUAL-old_town_narrow_townhouse_v1-001`:
  1 baseline record; 7 native mesh/collider snapshot entries.
- Tree V3 `explore-pine-707`: admitted full 9394 procedural baseline to respect
  registry contract, input assertions only on this original's 13 source parts.
- Parking V1 `parking-lots:parking:REBUILD-VISUAL-hospital-001`: 265 admitted
  transport baseline records, assertions on this original's 6 source parts.

Short RMB selects and deletes the ray-picked original, not a predefined ID
substituted for pick. Undo restores exact opaque source record/native bounds
and native shape snapshots: mesh/material resource identity, transforms,
visibility/shadow flags, collider filters, MM count + full source batch CPU
transforms and selected slot transform/color. These are CPU/native resource
checks, NOT rendered pixels or GPU shadow acceptance. Headless rendering
readback alone is not a visual proof.

RMB look drag (>4 pixels) does not delete. Real panel pointer and LineEdit focus
guards reject map deletion; press-map/release-over-panel cancels stale click.
No full-map rotation/save-load acceptance or whole-scene FPS claim here.

## Actual results and reproduced regression

Initial basic coverage: 61 checks PASS, exit0. Adding the following adversarial
sequence produces 67 checks / 3 failures, exit1, one per real source family:

1. RMB press on picked map original.
2. Focus actual search LineEdit.
3. RMB release while text focused.
4. Release text focus.
5. A second RMB release at same map position before 500ms expires.

The text-focus early-return clears camera motion but not Controller's
`_right_pressed`. Step5 therefore deletes the original despite no new press.
The runner undoes each reproduced deletion before testing remaining guards.
Suggested narrow root-owned fix: clear `_right_pressed` in the text-focused
branch as already done in the pointer-over-panel branch. No controller/source
assembly mutation has been made by this fixture author.

Additional scoped observation: checking overhead center rays for every
parking-bay candidate found no candidate whose returned original ID equalled
that bay ID; lot/control merged bounds won in this fixture. Hence the accepted
parking sample is explicitly a lot, not a claim that bay-specific ray selection
has been proven. This does not prove bays unreachable from every possible ray;
nearest merged-bound versus exact per-part selection remains separate review.

Root-owned source Controller now clears `_right_pressed` both in the general
text-focus guard and in early focused-K return. Fresh source stage xzhZTw +
fresh headless import completed exit0. Extended runner: **73 checks PASS,
exit0**, including actual LMB ray selection and focused-K interruption. The
negative pre-fix 67/3FAIL evidence remains unchanged in the output directory.

Accepted Controller SHA-256:
D1812CB127B6526A14E12CBF047EF2A0365ABA036D031060844DFC369B5E40C4.
Test SHA-256:
F79BB97BFADCD4A4A0D43B5376F146656C445CB6A8D70D6A0805C9D35EA99FEE.
No LIVE gate or production completion claim. Original h7YmkU assembly was not
patched; its Controller still reproduces the negative scenario.
