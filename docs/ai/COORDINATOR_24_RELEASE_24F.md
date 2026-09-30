# 24f — unified rear lights, native wall damage and corpse contacts

The previous ordinary 24e export lacked the rear-light module, although a separate owner preview already showed it. The combined 24f export includes that module alongside the existing front headlights, day/night, wall destruction, residents and corpse contacts. It uses one ordinary game process and no installer script.

F in the driver seat switches front headlights and dim red rear lamps. Braking or the handbrake makes the red lamps brighter. After the car stops and reverses, white inserts and a short shadowless rear beam illuminate the road. Exiting or losing focus clears reverse selection. The feature reads accepted vehicle controls and does not modify driving physics.

A scene-reload crash was reproduced in the combined native test: the modular building prefab could be outside the tree while still attached to a parent being destroyed. Immediate free attempted to remove a child during that parent's teardown. Parented prefabs now use deferred deletion; only an unattached failed load is immediately freed. The same native reload test then passed without errors.

The earlier 24e integration remains: the three-storey townhouse has native RPG wall cuts and physical fragments; the original three residents and eight buildings remain; dead residents block the player and can be nudged slightly. Full structural collapse and all-city NPC activity are still separate unfinished work. The townhouse's former glass/door visual nodes are retained hidden; replacement glazing and operative doors are not claimed.

## Verification before ordinary release

- Frozen candidate31: 272 source inputs; assembly SHA256 `3309bf75e46aab302793fab686373e4e8597ed714efb01f631117fdea0f93945`.
- Export PCK SHA256 `0bd000e02db726dd9e7eccff565982222ce8dc0ef5b950209edf0c0f600d945e`; 421 packaged resources include rear lights and both day/night scripts.
- Combined native02: 33 checks passed, including actual Godot E/F/W/S/Space inputs, exit, focus loss and scene reload. No transport-control fallback, source changes or engine errors.
- Original rear module owner GPU03: 35 checks passed with matching loaded-scene comparisons. The new combined31 rendered check is recorded separately; native tests are not FPS evidence.
- Combined compiled31 GPU01: 38 checks passed in 28.063 seconds, no engine errors, all 272 inputs and PCK unchanged. Six actual rendered images were inspected. The same full test quarter had p50/p95 6.956/9.875 ms without the new module and 7.059/9.798 ms with reverse illumination; the on-versus-off paired p95 difference was +0.013 ms. Static memory increased 53,344 bytes. Maximum first-activation frames were 9.145 ms for tail lamps, 10.671 ms for braking, and 9.966 ms for reverse. No material regression was observed in this quarter; this is not whole-city acceptance.
- Corpse28 retained evidence: original 16 collision shapes/15 joint identities and real TT death; positive test 61 checks, four accepted bounded contact impulses, maximum shift 1.987 cm. The player mask is 1025.
- Compiled30 passage followup: 565 checks passed after three finite-ammo native RPG shots and W plus one Space. The player entered 1.55 m into the building. This is headless functional evidence. Earlier GPU02 third-aim/passage failures remain recorded and unexplained; they were not changed to PASS.

The source-only Astra6 correction also ships for the separate legacy living-mark renderer. Current ordinary residents use the already-fixed common postmortem renderer for both living and dead impacts. The separate file is not advertised as a new active gameplay improvement.

Root applied the eight scoped changes over 24e and opened one ordinary 24f game at 21:08:31 MSK, PID43856. The launcher waits for exit and verifies the build. Readiness includes the original scene, rear lamps and day/night; the ordinary process responds and its error log is empty. The previous 24e game was stopped only for this sequential update.

## Evidence

Subsequent user inspection identified unresolved defects: walking catches on the lower edge of a damaged opening, fragments visibly separate roughly one second after the explosion, and very close downward AK fire can produce no visible marks on a corpse. These are active follow-up work; this checkpoint does not claim they are resolved.

`outputs/coordinator24_rear_lights31/DELIVERY31.json` and `native02/RUN.json` pin the combined build and behavior. `outputs/coordinator24_building30/passage_diagnosis/FOLLOWUP_REPORT.md` retains the exact passage result and its limits. `outputs/coordinator24_astra_control/ASTRA6_ACCEPTANCE31.json` records the renderer binding review. The guarded promotion records the precise runtime scope and preserves other owners' working files.
