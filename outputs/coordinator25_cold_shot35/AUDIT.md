# Root35: first native TT shot — read-only audit

Status: **OPEN; no fix claimed.** This audit does not block the already checked quality25a lamp/dashboard release. No engine, test, production edit, cache clearing, process stop or candidate mutation was performed. Only this report was written.

The strongest source-level candidate is the first visible use of generic weapon/metal-impact material variants. The saved measurements do **not** prove shader compilation or identify the exact expensive function. Launch cosmetics and the first metal impact still share one uninstrumented phase.

## Frozen evidence

All paths below are relative to `C:/Users/Слава/Desktop/Мафиози`.

| Artifact | SHA256 |
|---|---|
| `outputs/coordinator25_street34/ASSEMBLY34.json` | `29153935662325aedeeab3c83ab58abeb7110a9aeead593f5e0981b466d36782` |
| actual quality25a `MafioziPreview.pck` | `bfd0a99e6f740ce6581ef8d02ca0464ed73a7c4e71b6324069613e6aa1871910` |
| `outputs/coordinator25_street34/runs/gpu01/RUN.json` | `b5c1625bd51b95262fca58de44dff9ba41b5fb3609ebfefffda06ed133a138aa` |
| `outputs/coordinator25_street34/runs/gpu01/RESULT.json` | `d9ade76ab8a1c23f2b56b8b0eecc85ab39e562bd5561ef4dd1206f4ee07ab377` |
| `outputs/coordinator25_street34/runs/gpu01/test_street34.gd` | `21d43c1948e4b6fb52ada715fae63f974e8e6fc830b47bc8b2a3a750c5b40ccc` |
| `outputs/coordinator25_street34/runs/gpu_dashboard01/RESULT.json` | `554aca78b9c227b7dde3cdfca80fb2aa61378e8329bb50e2ef1c2dfb693a2846` |

Actual packed GPU lamp run: 122 checks, no failures/errors; dashboard: 105 checks, no failures. RUN records no loose runtime resources, unchanged pack/source/QA and exclusive inventory endpoints. These functional passes do not close the first-shot issue.

| Phase | p50 ms | p95 ms | max ms |
|---|---:|---:|---:|
| First TT metal pole | 6.956 | 7.220 | **123.392** |
| Next metal lower pole | 6.945 | 7.180 | 7.519 |
| Next metal arm | 6.925 | 7.155 | 7.207 |
| Next metal hood | 6.936 | 7.142 | 7.229 |
| Glass after four metal shots | 6.944 | 7.114 | 7.269 |

In `report.frame_metrics.actual_TT_metal_pole.samples`, zero-based samples18/19 are123.392/22.806ms. From sample17 to18, static-memory monitor rises222328533→223124304bytes (+795771), draw calls788→792 and primitives197865→197839. Broken-lamp count remains0. These are correlated presentation/monitor observations, not isolated allocation or GPU-execution measurements.

Close-up steady paired lamp p95: off7.113/7.130ms; on7.169/7.132ms. Dashboard p95 reported by Root10.144→10.296ms. They do not measure first use. Owner's earlier first metal148.914ms remains open too;123.392ms is another occurrence, not a demonstrated25.522ms improvement.

The current fixture uses1280×720, `Engine.max_fps=0`, `vsync_mode=1`,60Hz physics. The earlier owner perf117 fixture used144fps cap/vsync disabled. Do not combine their absolute numbers as a controlled before/after optimization result.

## What the lamp path does on metal

Source prefix for these pointers: `outputs/coordinator25_street34/candidate34/godot/mafiozi_walk/`.

- `scripts/quick_controls/street_lamps.gd:96` registers only glass bodies in `_by_collider`. `_on_resolution:174–189` validates/deduplicates one terminal receipt, then returns for a metal body. It does not call `_break`, rebuild a collider, change lamp materials, start debris or play glass sound on that path.
- `_on_shot:158–172` performs bounded shot bookkeeping: one dictionary/seen array per accepted TT shot. This remains a measurable callback candidate, but the code does not contain an obvious100ms operation.
- `_collider:109–120` assigns `impactSurface="metal"` to pole/frame bodies. This selects the pre-existing **generic metal cosmetic branch**, even though the lamp break callback exits.
- `configure:64–101` builds lamp collision/visuals/audio/debris before ready. `street_glass_sound.gd:28–72` reads and decodes the three PCM files and creates four voices during configuration; `play_break:75` is reachable only after an actual glass break.
- The actual fixture asserts every metal shot preserves glass and sound (`test_street34.gd:334–347`). Its final snapshot has five native shots, one glass break, one sound, three streams,48 debris slots and no pending shots.

Therefore lamp break/debris/audio work is excluded from this first metal hit by source routing and accepted behavior. Lamp bookkeeping, generic effects selected by the new metal collider, rendering interaction and the exact first-use delay still need timing evidence.

## Generic first-use candidates, ordered by specificity

1. **Metal impact material state / first visible draw.** `scripts/weapons/weapon_surface_impacts.gd:104–119` first shows the impact pool, then sets five chip materials to additive blend and emission for metal (`:117–118`). Initial pool creation at`:24–46` does not exercise a real metal hit. Marks first become visible at`:89–101`. These changes can introduce render/material work; saved frame timings cannot prove shader/pipeline compilation specifically.
2. **Launch cosmetics.** `scripts/weapons/weapon_projectiles.gd:72–99` allocates meshes, materials and bounded projectile/casing/flash pools during configure. `_take:137–146` first shows a pool entry; `_color:151–156` enables emission at shot time (`_spawn:219` applies it to core/nose). `_flash:185` first shows the muzzle; `_eject:224` first shows the casing, called by the next advance at`:237–239` even for TT casingDelay0. First-use work may therefore remain despite CPU-side preallocation. Include all these events in the trace.
3. **Synchronous accepted-shot and impact routing.** `scripts/weapons/preview_weapons.gd:320–357` performs `effects.shoot` before emitting `shot_emitted`; timing that signal alone misses preceding launch work. `_surface_impact:304–312` routes non-character contacts to the generic surface effect. `weapon_projectiles.gd:258` emits the cosmetic impact synchronously; terminal receipts drain later at`:285` through`:31–36`. Observing the terminal signal alone does not measure all preceding ray/cosmetic work.

Weapon model loading is a weaker candidate for this specific measured phase: `scripts/weapon_visual/weapon_visual_catalog.gd:34` loads at first equip, while the fixture equips TT at`:317`, then waits45 frames, runs paired feature phases and waits90 steady frames before the first shot. No new surface mesh/material/node creation occurs inside `_mark/_impact`; their resource allocation is already in configure. Material state changes and first visible draws remain distinct from resource preallocation.

All26 `scripts/weapons/` source pins in candidate34 exactly match accepted candidate31. The cold path is not a changed generic weapon implementation in25a; new metal targets can still expose an existing first-use path. No generic TT gunshot/audio allocation path was found in these weapon scripts; glass audio is separate and did not play on metal.

Critical source pins:

| File | SHA256 |
|---|---|
| `scripts/weapons/preview_weapons.gd` | `48998eb4207d40ff3bf6c91ba19aa026f145c7bc083bd13a743b071044b1e97c` |
| `scripts/weapons/weapon_projectiles.gd` | `e1a1433b1f5df9c8aea116580e1a8443279401f2e65b832756eee18923552d27` |
| `scripts/weapons/weapon_surface_impacts.gd` | `bc116ecee2aad8f6b394efc824706ffaf8259467655ea44ba183750aafe3b552` |
| `scripts/quick_controls/street_lamps.gd` | `d31561e1d2d7eeed00b4afaf7586b2a91a51b5e7688ec9ca6a9edcf331da6e67` |

## Smallest useful isolated next probe

Use a separate immutable candidate under this root35 folder, based on exact25a279pins. Do not patch shared production or owner packages. Root schedules each real-renderer process sequentially; preserve the one visible user game until the approved measurement window. Keep camera/settings,8 buildings/8 lamps/3 active residents, colliders, geometry, materials and genuine accepted native TT/ammo path.

First add a bounded in-memory trace, flushed only after the shot window: frame number and microsecond timestamp for input press, `after_pose_applied` entry/exit, `effects.shoot`, projectile advance/ray, cosmetic signal, surface `hit/_mark/_impact`, terminal drain, lamp `_on_shot/_on_resolution`, casing activation and `frame_post_draw`. Record before/after effect counts and material flags. Do not print per event or deep-copy whole scenes inside timings. A signal timestamp alone is insufficient for the synchronous calls identified above.

Run these diagnostic orders in separate fresh processes; no hidden warmup shots:

| Case | Native shot order / one controlled change | Resolves |
|---|---|---|
| A | Metal pole first, then identical metal again | Reproduce and align cold/warm cost with named spans |
| B | Clear miss first, then same metal | First launch versus first metal impact; assert first terminal is not a hit |
| C | Same first metal, disconnect only lamp shot/resolution callbacks | Exclude new lamp bookkeeping while retaining the exact metal collider, generic impact, visuals and lights |

C is diagnostic only: reconnect before any functional glass acceptance, or retire that process. Do not use it as an optimized gameplay build. B intentionally warms launch effects and cannot be cited as a cold-metal fix. Retain process/cache provenance; do not delete user shader caches. A bounded initial set is three runs; repeat only the discriminating comparison if results are ambiguous.

If the large interval lands inside a script span, isolate that call next. If script spans stay short and the stall follows material/visibility changes at the next draw, investigate renderer/material first-use work; a short script span alone does not prove driver shader compilation. Only then try prepared immutable metal material variants or explicitly staged render preparation in a **separate** candidate, preserving exact visual/material/debris/collision behavior. Merely moving work into loading, warming with a hidden shot, suppressing effects or reducing content is not a demonstrated end-to-end fix.

Acceptance for a later fix must retain an un-warmed first real metal shot, report total initialization plus first-use costs and repeats, then re-run genuine glass, persistent marks, lamp/debris/audio and packed native/GPU behavior. This report makes no performance-completion claim.
