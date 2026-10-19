# Native time-of-day bounded package — 27 September 2026

Status: **standalone CPU READY; host integration and LIVE/GPU NOT RUN**.

This package ports the exact presentation contract from
`assets/maps/city_rebuild_v1/walk_time_of_day.mjs` without changing the current
Godot scene, main host, player, project, export preset, UI or visible game.

## Files and ownership

- `scripts/environment/walk_time_of_day.gd` is the pure controller. It owns no
  game clock, save, network, weather, interior state, node or engine resource.
- `scripts/environment/preview_city_clock.gd` is a replaceable standalone
  source provider. It starts at noon unless a strict valid clock is supplied,
  advances one game minute per accepted one-second callback, and never replays
  a delayed backlog.
- `scripts/environment/walk_environment_adapter.gd` is the Godot resource seam.
  It applies a sampled frame to caller-owned `Environment`,
  `ProceduralSkyMaterial` and `DirectionalLight3D` resources. It returns without
  mutation while the caller says interior lighting is active.
- `scripts/tests/fixtures/walk_time_of_day_oracle.json` pins the source palette
  and exact 00:00, 05:00, 06:21, 12:00, 17:00, 18:39 and 22:00 samples.
- `scripts/tests/test_walk_time_of_day.gd` covers oracle parity, independent
  formulas, strict schema, controller/provider lifecycle, actual Godot resource
  application and bounded CPU cost.

## Clock and state contract

The controller accepts only numeric integral `hour` in `0..23` and `minute` in
`0..59`. Integral floats from decoded JSON are accepted. Strings, booleans,
null, fractions, infinities and out-of-range values are rejected. Invalid
startup retains noon; invalid later samples retain the last accepted time.

The provider is sampled once per 250 ms target interval. A late frame performs
one read and schedules the next read from that frame; there is no catch-up
burst. `update()` returns the same `Frame` object throughout the controller
lifetime. The target frame and one provider `ClockSample` are also retained.
Runtime update/application does not create Dictionaries or Arrays. Diagnostic
snapshots are caller-owned and written only on request.

The QA offset accepts only finite numeric hours and wraps modulo 24. It is
presentation-only. It must never be serialized or sent as source state.

The exact curve is:

```text
sunHeight = sin((hour - 6) / 24 * TAU)
daylight = smoothstep(sunHeight, -0.2, 0.4)
dawn = 1 - smoothstep(abs(hour - 6.35), 0.15, 1.85)
dusk = 1 - smoothstep(abs(hour - 18.65), 0.15, 2.05)
warmth = max(dawn * 0.72, dusk)
night = 1 - daylight
lampPower = hour < 7 or hour >= 17 ? max(0.48, night) : 0
```

Only daylight, dawn and dusk ease. The first frame snaps to its target; later
frames use `1-exp(-dt*2.4)` with `dt` capped at `0.1`. A zero-delta frame does
not advance the transition.

Fog is source exponential density:

```text
0.00305 + night*0.00062 + rain*0.00048 + snow*0.00025
```

Phase precedence is dawn (`dawn > .15`), day (`daylight > .62`), dusk
(`dusk > .15`), then night. The complete reusable frame also carries exact
background, ambient/ground, sun, exposure, environment intensity and sun-offset
values. Palettes and checkpoints are pinned in the oracle.

## Adapter boundary

The adapter maps the source frame to existing Godot resources only when the
caller explicitly configures them. It does not create or attach nodes.

- Source background becomes both procedural sky top and horizon.
- Source ambient ground becomes both procedural ground colors.
- Source environment intensity drives procedural-sky energy. This is the
  explicit Godot seam; final visual calibration remains a LIVE gate because
  Three and Godot do not have identical reflection-intensity APIs.
- Ambient color/energy, exponential fog color/density, tonemap exposure and
  directional sun color/energy are direct fields.
- Directional rotation is derived from source `sun_offset`; the light is not
  moved as if it were positional.
- Interior-active calls mutate none of these channels.

`lamp_power` is output only. This package adds no OmniLight3D, street-light
manager, facade/window emission, material mutation or scene-tree scan. That is
required because the current static render lease admits only shared sun/sky and
rejects local lights. A future lamp package must restore/revise that lease
before activating local lights.

The current browser clock is page-local and has no save or server assignment.
The current native NPC bootstrap packet's `game_minutes` is a frozen creation
receipt, not a live clock. Production integration must inject the chosen source
provider rather than reading that packet as runtime authority.

## Verification

Actual engine:

```text
Godot 4.7.2.stable.official.ed1daf0bf
```

Command:

```powershell
& 'C:/Users/Слава/AppData/Local/MafioziTools/Godot-4.7.2/Godot_v4.7.2-stable_win64_console.exe' `
  --headless --path godot/mafiozi_walk `
  --script res://scripts/tests/test_walk_time_of_day.gd
```

Result: **860 checks PASS, 0 failures, exit 0**. Maximum scalar difference from
the pinned JavaScript oracle was `3.75422424259142e-8`.

Headless CPU microbenchmark in that run:

| Work | Iterations | Total | Mean |
|---|---:|---:|---:|
| Reused pure sampling | 250,000 | 1,660,005 µs | 6.6400 µs |
| Reused controller/provider update | 100,000 | 785,668 µs | 7.8567 µs |

These figures prove bounded module CPU behavior and stable frame identity only.
They are not full-scene FPS, GPU, rendered fog/sky parity or LIVE acceptance.

## Root integration gate

After traversal acceptance, root may preload these scripts, retain the current
lighting resources, create one controller/provider/adapter, call update/apply
once per presentation frame, supply the authoritative interior flag, and
dispose on scene exit. Export inclusion, diagnostics cadence, lamp consumption,
same-camera p50/p95 and the one visible game restart remain root-owned work.

Do not add the feature to `preview_updates.json` until the single visible game
has passed day, dawn, dusk, night, interior freeze and frame-time checks.
