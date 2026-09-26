# Cinematic dive — user tuning, 27 September 2026

Direct user request: «очень короткий прыг макса пейна. надо чтоб в полете был тут сразу падает. следите за фпс оптимизируйте качественно».

This runtime profile supersedes the dive distances/times in `S01_DIVE_MAIN_HOOK.md` and the old source runtime admission. It is an explicit new user design, not a claim of unchanged source trajectory. The pure `proposal` / `upgrade` APIs and their source oracle remain unchanged. Runtime chooses `cinematic_upgrade` and `cinematic_proposal`; ordinary jumps still use source `.8 s / 1.05 m apex / 2.8 m range`.

## Exact runtime profile

- Profile ID: `cinematic_user_20260927`.
- Flight target: 1.25 seconds from **first** Space, speed 4.2 m/s. Immediate range 5.25 m; upgrade at t has range `5.25 - .7*t` because its initial normal section travels at 3.5 m/s. At 500 ms the range is 4.90 m.
- Immediate apex .82 m. During ascent the retained target is `max(current_height, lerp(.82,1.05,smooth(t/.2)))`. A descending late upgrade keeps its actual height and continues descending.
- Admission still requires a released, discrete second Space within 500 ms, source permission radius .36, on-foot ownership, and an unblocked normal jump. Third presses, held repeats, ceiling/falling upgrades and text-entry input remain rejected.
- Recovery lasts .45 s from actual swept body floor contact. Flight elapsed never resets; normally the complete cycle ends around 1.70 s. An edge fall holds until actual support, even beyond this time. There is no invented water floor or completed swimming claim.

## Position/velocity continuation

Let t be upgrade elapsed, y0 the actual height above launch floor, v0 the instantaneous normal-curve derivative `5.25*(1-2*t/.8)`, and H the retained target height.

For rising upgrades the ascent duration is `A=3*(H-y0)/v0`. During ascent, u=(elapsed-t)/A:

`y=y0+v0*A*(u-u²+u³/3)`, `v=v0*(1-u)²`.

The descending segment uses cubic Hermite interpolation to ground at elapsed 1.25, with zero terminal vertical velocity. It begins at H with zero velocity after ascent. For already-descending upgrades it instead begins immediately at y0 with v0. For duration D and normalized u:

`y=yStart*(2u³-3u²+1)+vStart*D*(u³-2u²+u)`.

This is C1 (continuous position and velocity), including the apex; acceleration may change at segment boundaries. It does not reset the clock, teleport, or apply a second upward impulse. The existing CharacterBody frame-average velocity is not changed by admission; analytic v0 describes the instantaneous derivative of the previous normal curve rather than that preceding frame average.

Airborne pose progress is `min(.72,elapsed/1.25)` using the existing exact directional/full-body sampler. Progress .72 holds its maximum airborne tilt with zero recovery. At physical contact it advances from .72 to 1 over .45 s. The sole final pose writer still applies the full quaternion, every bone, and all-vertex grounding correction.

## Physics and bounded work

All motion remains swept `move_and_slide`; wall permission uses the .36 capsule and the body retains its actual .30 radius. Permission casts are raised 2 mm to clear the floor contact margin: Godot ignores initially overlapping geometry during a cast, which previously allowed a near-ground cast to miss the thin wall. This conservative query shift does not move the body; source ceiling clearance remains 4 cm.

Same-substep ceiling/edge gravity18 and actual floor recovery are preserved. The independent review found a continuing post-jump fall bug at dt=.2: the surface-motion contract caps dt at .1. The host now applies that cap and freezes continuing falls when hidden/minimized, without freezing visible focus loss. This matches the isolated surface-motion dt contract; the browser outer-frame cap may be smaller, so this is not a claim of complete browser scheduling equivalence.

Flight work remains at most 7 substeps, each ≤.04 s, consuming at most .25 s per frame. Hidden frames, nonfinite/negative time, and gaps >1 s create no time debt. The analytic profile adds constant work per substep and reuses the optimized packed skin support kernel; no per-frame scene traversal was added.

## Verification and freeze

Godot 4.7.2 headless, actual CharacterBody physics and canonical male rig:

- `test_preview_dive_integration.gd`: **6480 assertions PASS**. Includes 51 upgrade times at 10 ms intervals, numerical C1 derivatives, monotonic late descent, no change to body position/velocity at 500 ms admission, all eight directions, actual released Space events, thin walls, ceiling cancellation/contact, edge/lower support, ownership epochs, hidden/focus behavior, actual main containment and water-without-floor.
- Simulated input rates 3/5/10/30/60: cinematic distance 5.250361–5.250364 m; sampled apex .816114–.820000 m; normal distance 2.800343–2.800347 m, apex 1.05 m at sufficiently frequent samples. The 3 FPS input run is bounded simulation, not a measured game FPS claim.
- Recovery starts at actual contact around 1.25 s; progress remains .72 while still airborne at 1.10 s. Full upright rotation returns at completion.
- `test_preview_dive.gd`: **10396 assertions PASS**, unchanged 168 source pose oracle cases and 3 trajectory traces. Source maximum visual offset error .000025665 m and quaternion-dot error 5.96e-8.
- Mixed controller + pose CPU p50/p95: **.570/.784 ms**. Pure warmed sampler **.532/.796 ms**, support kernel **.518/.811 ms**; one-time binding 33.325 ms. These runs were independent of graphics, not a comparable loaded-scene FPS acceptance. Previous short-profile host measurement .579/.785 ms is reference only, not a controlled paired benchmark.

Production freeze SHA256:

`scripts/preview_player.gd` final contact and pose fix: `13e3d83baa7648be5040bde64d1b899404bc2d7984aed22afe8b02b0c9b4db57`

`scripts/preview_dive.gd`: `32be580dbbfdc9169225e822acafb7c73c68c6e33a139c0b0970585808927ceb`

Independent reviewer completed **101 assertions PASS** against final player `13e3d83b` and unchanged dive sampler. The repeat found a real one-frame early standing pose in the preceding contact fix: ordinary progress overwrote cinematic progress before actual floor contact. The final guard preserves cinematic pose until contact; all eight premature-recovery traces are empty, with assertions unchanged. Eight directions retain 100 ms upgrade range 5.180340–5.180342 m / apex .934981 m; late 490 ms descending curve error 3.77e-8 m without renewed ascent; post-fall .2 s capped integration error 1.526e-7 m; ceiling-clearance error .0007376 m; full skin (8338 vertices, 56 samples) grounding error .00002450 m. See S01_DIVE_INDEPENDENT_REVIEW.md.

The runtime package is not yet a LIVE/FPS acceptance. Root owns export08, the one visible game, and loaded-scene frame-time validation. Swimming, stepping/slopes, crouched/armed variants and full gameplay migration remain outside this package.


## Actual-main contact correction before export08

Root's actual main motion self-test exposed a real blocker at the public-approach spawn: launch floor y=.017727 m, landing floor y=0. The old source 2 cm tolerance left the cinematic body hovering at launch height after its arc, so actual floor contact and recovery never started. The second jump consequently could not begin. This was not visible in the original single-height floor fixture.

Cinematic motion now continues swept gravity after nominal flight whenever actual `is_on_floor()` is false, including sub-2 cm floor differences. Ordinary source motion retains its existing tolerance. No teleport, forced grounded flag or removed collider was introduced.

Additional physical ledge regressions at 5, 18 and 19.9 mm check actual contact, completed recovery and admission of the next jump. Updated own suite: **6489 assertions PASS**, mixed controller/pose CPU p50/p95 .571/.737 ms. Root's actual main harness reproduced the previous failure and passes after the fix: both episodes have actual grounded=true and empty jump state; distances 5.226859 and 5.086938 m, end feet y=0 and .005281 m. Evidence: `outputs/coordinator21_perf_acceptance/motion_contact_before/report.json` and `motion_contact_after/report.json`. This is headless motion acceptance, not graphics FPS. Independent reviewer is rerunning its suite against the final player hash above.
