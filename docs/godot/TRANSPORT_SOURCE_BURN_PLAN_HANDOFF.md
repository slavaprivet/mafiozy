# Transport source burn plan — frozen handoff

Date: 2026-09-27. Status: **frozen pure source-math component**.

This package reproduces only the exact linear RGB/roughness operation in pinned `vehicle_damage.mjs` line 276. It creates no Nodes or Resources, mutates no material, and owns no damage, HP, event, identity, callback, or vehicle-lifetime authority.

## Frozen files

- `tools/godot/export_transport_source_burn_oracle.mjs` — `b03fb1e4cca7f9c5f38794e3dcc5436ad74510e09c5c828b1ce9bfafccf5cc2a`
- `godot/mafiozi_walk/data/transport/source_burn_oracle.json` — `625040555e6a4dcab21491e1ec6d0267e25a1db65a852a82f2da3f7019a0df9c`
- `godot/mafiozi_walk/scripts/transport/transport_source_burn_plan.gd` — `2fd5d2f947d0bc24719292321a759ba2a6d9d808a53afd65238442f713881c70`
- `godot/mafiozi_walk/scripts/tests/test_transport_source_burn_plan.gd` — `6f0db4a5a4e0853fc6b37318e8f7441f2fb02b436dbf054a24501894d51898f1`

Source pin: `assets/maps/city_rebuild_v1/vehicle_damage.mjs` SHA-256 `e029cb4a03dcd23bbdd0fb2f73b7780db92f24f761cf83b030991acb3c403f92`, especially lines 55-64, 102-127 and 256-278. Source audit: `docs/godot/TRANSPORT_DEBRIS_BURN_PREPARATION_AUDIT.md` SHA-256 `aa714ae4247bea63188021e5b147b633ded3dcfc307f75fd3c93df5cbd58887d`.

The oracle exporter asserts the source SHA and Three revision 180, invokes the actual `createVehicleDamage` RPG destruction/update path, and reads colors from the actual material objects before and after the synchronous callback. It does not contain a rewritten burn formula. Two consecutive exports produced the same JSON SHA.

Root export must explicitly include `res://data/transport/source_burn_oracle.json` only if the test is shipped. The runtime planner does not load JSON.

## API

```gdscript
const BurnPlan = preload("res://scripts/transport/transport_source_burn_plan.gd")
var receipt := BurnPlan.plan(current_linear_rgb_f64, captured_opaque_eligible)
```

Input:

- `current_linear_rgb_f64`: exactly three finite values in `PackedFloat64Array`; HDR and negative linear values are retained without clamp or HSV conversion.
- `captured_opaque_eligible`: host-supplied Boolean. It is true only when the exact material identity was captured by `materialRest`, still exposes color, and has `transparent == false` at explosion. Source captures color-capable transparent materials too, then rechecks their current `transparent` flag during explosion. The Boolean is not an authority receipt.

Eligible output contains `apply_burn=true`, exact Float64 `linear_rgb`, `roughness=.99`, and `alpha_unchanged=true`. Ineligible output contains `apply_burn=false`, an unchanged copy of the input RGB, and `alpha_unchanged=true`.

The channel operation preserves source order:

```text
channel += (Three180LinearColor("#100f0e") - channel) * 0.94
```

The pinned Three target is stored from its exact little-endian Float64 bytes. The helper returns linear values. A future material host must separately convert linear RGB to Godot's sRGB-facing albedo property and preserve the source alpha; this helper intentionally does neither.

## Oracle coverage

The JSON contains seven exact Float64 numeric rows: black, white, ordinary linear color, the target itself, negative/HDR channels, tiny/large finite channels, and signed zero. Expected outputs are read from actual source materials at the callback and after explosion.

Eight actual-source semantic rows prove boundaries that the pure helper does not own:

- a captured scalar opaque material is charred before callback and cloned by detach afterward;
- replacing the mesh material after adapter construction chars the old captured identity while detach clones the current replacement unchanged;
- an array material is not independently registered by the scalar `materialRest` capture;
- a transparent material is neither charred nor detached;
- a captured opaque material toggled transparent before explosion is not charred or detached;
- a captured transparent material toggled opaque before explosion is charred, although its construction-time glass registration still hides it before detach;
- an arbitrary callback can mutate the current replacement and the later detach clone sees that mutation;
- a throwing callback observes the char but prevents glass hiding and detachment.

These receipts prevent the Boolean eligibility input from being mistaken for a generic source callback/material contract.

## Verification and cost

Commands:

```powershell
node tools/godot/export_transport_source_burn_oracle.mjs
tools/godot/run_transport_test.ps1 -Resource res://scripts/tests/test_transport_source_burn_plan.gd -TimeoutSeconds 60
```

Godot 4.7.2 verification: author **47/47 PASS**, parent **47/47 PASS**, independent reviewer **47/47 PASS**. The test compares exact `PackedFloat64Array.to_byte_array()` values, not a tolerance.

Fresh sequential parent headless measurement after the author run completed: 100,000 eligible plans in 375,289 us, or 3.75289 us/query. The exact Three target is decoded from immutable local little-endian bytes per query because GDScript decimal constants round these values one ULP differently. This is pure CPU micro-cost only. It does not measure resource cloning, shader compilation, explosion-frame latency, GPU/FPS, or the previously observed 57 ms material path, and it does not claim to solve that cost by itself.

## Required future host seams

- Establish exact current canonical material identity and captured opaque eligibility.
- Stamp/invalidate every cloned material property and identity; preserve current maps, emissive state, alpha, metalness, side and other source fields.
- Convert returned linear RGB to the native material property's expected color space while preserving alpha.
- Preserve source transaction order: attached char, synchronous callback, glass hide, detach/copy. Callback failure must still prevent detach.
- Rebuild across reset, material replacement, livery/traffic paint, or any relevant property mutation.
- Keep event authority, HP, source IDs, assembly ownership and lifecycle outside this helper.

The component is a finished exact-math seam. A private burned-material preparation/cache still requires a separately reviewed Resource owner and current-material stamp.
