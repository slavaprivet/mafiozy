# S01 camera input — independent headless checks, 26 September 2026

Root implements the user-requested camera controls in `preview_player.gd`.
This task added only `scripts/tests/test_preview_camera_input.gd` and this
receipt, and corrected the release-launch limitation in
`S01_PERF_LIVE_PROTOCOL.md`. No production/main/export edits or GPU launch.
The current visible process was left untouched.

## Actual result

Godot `4.7.2.stable.official.ed1daf0bf`:

```powershell
& 'C:/Users/Слава/AppData/Local/MafioziTools/Godot-4.7.2/Godot_v4.7.2-stable_win64_console.exe' --headless --path 'C:/Users/Слава/Desktop/Мафиози/godot/mafiozi_walk' --script res://scripts/tests/test_preview_camera_input.gd
```

**50 checks PASS, zero errors, exit 0.** Actual imported player, physical floor,
input events, two real text controls and spring-arm obstacle queries are used.

Verified:

- Free mouse look starts enabled. Motion rotates camera yaw/pitch without RMB;
  actual yaw pivot follows, pitch clamps at −1.05 / +0.45 radians.
- Wheel zoom is `distance * exp(direction * factor * 0.12)`, including fractional
  factors, zero-factor fallback, opposite steps and ignored release events.
  Distance clamps at 3 / 16 m and reaches the actual spring-arm target length.
- Escape releases free look; released pointer motion/wheel do not alter camera.
  Echo Tab is ignored. Tab enables then disables the semantic free-look state.
  Left-button press regains look, left-button release does not.
- Real `LineEdit` and `TextEdit` focus each suppress orbit, wheel zoom, Tab,
  left-click recapture, movement and jump. Camera events are also delivered
  directly to the real unhandled-input handler in these cases to ensure the
  controller guards work even if an event reaches it. Click works after text
  focus ends.
- Focus-out clears free look and RMB compatibility latch. Subsequent motion
  cannot orbit. Focus-in alone does not recapture; click restores look.
- A 90-degree rotation delivered as mouse motion changes actual movement.
  W/A/S/D physical key events go through `Input.parse_input_event` and their
  real InputMap mappings; all four move in the expected camera-relative
  directions on the actual physical floor.
- A real wall shortens the spring arm without changing the desired 16 m zoom;
  removing it restores the unobstructed distance.
- The production source hash is unchanged from test start to finish. Inputs
  are released at completion and finalization.

## Headless limitation and resolved finding

The first run exposed that headless `DisplayServer` does not retain
`Input.MOUSE_MODE_CAPTURED`: reading `Input.mouse_mode` remains visible. The
original Tab toggle therefore could not be exercised reliably in headless.
Root changed the toggle to the controller's own `_free_mouse_look` semantic
state. The final run verifies both Tab transitions without faking system mouse
state or modifying production from the test.

Physical OS pointer capture/release remains **native-unverified**, explicitly
returned in the test's `native_unverified` array. Default capture in the actual
Windows game, physical mouse feel, window focus transitions and the new main
HUD/update panel require coordinator observation. This test uses synthetic
events/notifications, not physical keyboard or desktop mouse automation.
No LIVE, GPU, FPS or release-executable acceptance is claimed.

## Receipts

| File | SHA-256 |
| --- | --- |
| Tested `godot/mafiozi_walk/scripts/preview_player.gd` | `54d33276063fb8f31389104b1c624a404f10b7042114e5b21f70af35e95b19eb` |
| `godot/mafiozi_walk/scripts/tests/test_preview_camera_input.gd` | `a340dfdc37bbaef818607593c436979bf5648e028acae1ce22b6b458f90286cb` |

## Exported-content testing boundary

Root observed that review05 Windows release ignores external `--script` and
starts the default main scene. Do not launch this test or the perf harness via
that release EXE. Console engine `--main-pack <exported.pck> --script <absolute
test path>` actually executes external harnesses, but that is a **debug engine
with exported content**, not release execution/performance verification.
