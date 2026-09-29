# Root22 braking and moving exit: single-window QA

Harness: `tools/godot/test_vehicle_braking_liveqa.gd`, frozen SHA-256
`c3a34c8c5dd34ce4e1e4d745d78f2c57d5a9dc5507cf0eb14e76c3f377efc491`.
Only Root may launch the visible run after closing its previous sole GPU game.
This author launched no GPU process and changed no main/body/player/project/Git.

## Actual scenario and bounds

Instantiates actual `res://scenes/main.tscn` with unchanged original spawn/camera.
Two episodes each warm up 1.2 physics seconds, physical E board, 0.5 seconds settle.
Episode 1 sends physical W for 1.5 seconds, then physical Space with W still held
for 3.2 seconds, releases Space and accelerates another 0.6 seconds. Driver must
remain attached. After mode requires planar speed below 0.35 m/s throughout the
last quarter second, and reacceleration of at least 0.6 m/s. Baseline records the
known defect without incorrectly failing the harness for that expected result.

Episode 2 reinstantiates the same main at its original spawn; W for 2 seconds,
actual physical E exit above 15 km/h, then physical input release. Requires actual
`exit_ragdoll`, `GETTING_UP`/`DONE`, `ON_FOOT`, released driver and grounded actor.
No direct velocity, transform, position, fake contact, force or phase injection.
Fresh main restored afterwards, preserving a playable native window and R support.

Body-entered signals and current chassis overlaps reject collisions during both
acceleration and braking; a wall/floor chassis stop cannot count as brake success.
Safety abort at 45 m displacement / 60 m path from episode spawn / fall of 5 m;
75-second timer watchdog; unowned keyboard/mouse/joypad input or focus loss after
first focus cancels. All owned E/W/Space and movement actions released on finish.
Observer is only the harness; production code remains untouched.

Typical scenario roughly 17–23 physics seconds plus scene loads/readbacks; bounded
timeouts can reach 35 seconds. Headless fixed-60-FPS simulation completes about
5–6 wall seconds, so its wall-frame metrics are not real game performance.

## Measurements and proof limits

Report includes each phase's frame-time p50/p95/max, draw calls and renderer
primitive counts. Primitives are not asserted to be exact triangles. Identical
inputs/camera/warmup are used before/after, but physics improvements produce
different entry speeds; the measured paths are not equal-initial-speed stop tests.
Windows process working set and engine allocation figures are sampled outside
timed intervals. Screenshots show seated, brake episode end, actual mid-fall after
10 ragdoll pose ticks, and recovered. Readback/write and next three render frames
are excluded. Headless saves no images and is never GPU/FPS/full-city acceptance.

Hashes before/after include harness and available source resources. Exported
compiled resources may be absent as text; immutable PCK hash is recorded instead.
Godot removes engine `--main-pack` from script-accessible command-line arguments;
the root external launch receipt MUST bind that actual engine argument to the
exact checked pack and its build receipt/source_inputs. The harness verifies the
supplied pack hash before and after, not a claim that its argument proves mounting.

## Headless results, final frozen harness

Baseline pack `exports/win64/s01-20260929-braking22-baseline/MafioziPreview.pck`:
SHA `9fcde74fb4860deb5ff4b20799399b201b46a4f604e10da3ba75636d2c0a867e`.
Body A382 baseline, actual main: harness PASS, no script/engine errors.
Brake entry 5.042062 m/s, after 3.2 s still 3.000995 m/s, path 11.480363 m;
`brake_stopped=false` explicitly. Exit entry 5.737719 m/s; ragdoll, recovery,
grounded and driver release PASS. Zero driving chassis collisions.

After pack `exports/win64/s01-20260929-braking22/MafioziPreview.pck`:
SHA `14a1e0de4fac67034e27670bdaa9860b7c075bb60d09c81a2d7bb03c5d8f4236`.
Body AE4D after, actual main: harness PASS, no script/engine errors.
Brake entry 8.999082 m/s, after 3.2 s 0.039334 m/s, tail max 0.056234 m/s,
path 11.848621 m; release+0.6 s 3.565281 m/s. Exit entry 12.043511 m/s;
ragdoll/recovery/grounded/driver release PASS; zero driving chassis collisions.

Reports: `outputs/coordinator22_braking_liveqa/baseline-headless/report.json`
and `outputs/coordinator22_braking_liveqa/after-pack-headless/report.json`.
Both selftests restored main before exiting. Native cancellation, screenshot
content and city performance remain for Root's sole GPU acceptance.

## Exact Root commands

From repository root, set `$qaMode` to `baseline` then `after` in two sequential
single-game windows. Never launch these concurrently. Save actual command and
build receipt/source_inputs in the external root launch receipt.

```powershell
$qaMode = 'after'
$qaDir = if ($qaMode -eq 'baseline') { 's01-20260929-braking22-baseline' } else { 's01-20260929-braking22' }
$qaPack = (Resolve-Path "godot/mafiozi_walk/exports/win64/$qaDir/MafioziPreview.pck").Path
$qaSha = if ($qaMode -eq 'baseline') { '9fcde74fb4860deb5ff4b20799399b201b46a4f604e10da3ba75636d2c0a867e' } else { '14a1e0de4fac67034e27670bdaa9860b7c075bb60d09c81a2d7bb03c5d8f4236' }
if ((Get-FileHash -LiteralPath $qaPack -Algorithm SHA256).Hash.ToLowerInvariant() -ne $qaSha) { throw 'Pack hash mismatch' }
$qaScript = (Resolve-Path 'tools/godot/test_vehicle_braking_liveqa.gd').Path
$qaOut = Join-Path (Get-Location) "outputs/coordinator22_braking_liveqa/$qaMode-native"
& 'C:/Users/Слава/AppData/Local/MafioziTools/Godot-4.7.2/Godot_v4.7.2-stable_win64_console.exe' --main-pack $qaPack --script $qaScript -- "--braking-mode=$qaMode" "--braking-output=$qaOut" "--braking-pack=$qaPack" "--braking-pack-sha=$qaSha"
```

For headless validation add engine arguments `--headless --fixed-fps 60` before
`--` and user argument `--selftest` after it, using a distinct output directory.
Native runs MUST NOT use `--fixed-fps`, which would distort wall timing.
