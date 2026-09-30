# 23c playable checkpoint — 30 September 2026

This checkpoint preserves the exact source inputs of the version the user
explicitly requested to play at 04:26–04:39. It is not completion of the Walk
migration, full combat, visual acceptance, or final optimization.

Release: `s01-20260930-quality23c-play`.
PCK SHA-256: `4a2392c044eff5163e5fa4c4a95dbdcd5da8467c9fce3d3b1b7c825168bbe1bf`.
Source provenance: the release `build_receipt.json` and frozen
`outputs/coordinator23_quality/candidate03`; mutable owner work was not staged.

Included: original 14-weapon arsenal and thumbnails, Q menu/current-weapon card,
cargo model selection and named interaction cards, ground drop/pickup preserving
UID and ammunition, source projectile/impact/RPG presentation, movement-facing
separate from combat aiming, source crouch/crawl and shoulder/sniper camera.
The original NPC host and its accepted floor-seam fix remain included. NPC
damage still supports only the earlier subset; pellets, penetration, blood and
RPG damage are not delivered by this checkpoint.

Validation: 42 actual shots across 14 weapons × 3 stances, 2030 checks; actual
posture 1533 checks/54 displayed poses, original JS world-bone error ≤4.36 µm;
standalone compiled PCK visual/behavior run: 17 captures, 155 checks, no errors.
The final release changes only the five-item notes JSON after that run.

Comparable loaded compiled-PCK measurements retained all 3 NPCs, 8 buildings,
377 colliders, and 14 cargo items. A common rendered camera fixture equalized
framing while actual camera calculations continued; this is not whole-city FPS.

| Scenario | Baseline wall p95 | 23c wall p95 | Baseline GPU p95 | 23c GPU p95 |
|---|---:|---:|---:|---:|
| Idle | 3.905 ms | 4.055 ms | 2.328 ms | 2.342 ms |
| AK fire | 5.068 ms | 6.049 ms | 2.828 ms | 2.930 ms |
| Full cargo | 5.862 ms | 6.976 ms | 3.073 ms | 3.104 ms |

Static memory increased by 57.8–64.6 MiB. Resource allocation and hot-path
optimization remain open; the measured increase must not be described as fixed.

Packaging fixes: load the imported scope texture through ResourceLoader;
retain the existing NPC source-receipt export addon in frozen stages; record
its three build inputs and reject PCKs lacking the raw receipt scripts.
Headless `--path` tests can read local files absent from an export and therefore
do not prove standalone package closure. Runtime NPC hash checks remain intact.

User feedback after delivery: weapon cards are overbright, bullet holes look
weak/unrealistic, and RMB aiming needs the Walk zoom behavior. These are active
follow-up defects, not accepted visuals. The user clarified that the wall issue
means the marks themselves, not weapons showing through walls.
