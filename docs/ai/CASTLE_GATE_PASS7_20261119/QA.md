# Castle gate visual pass 7 — 2026-11-19

- Replaced full-height oak colour stripes with a deterministic 36/12 `wood` / `wood_alt` stagger on each 6×8 leaf. Every column now contains both tones.
- Corrected the reverse-face seam direction: the left inner face now mirrors the right instead of shifting its seams one plank toward the centre.
- Geometry, board order, 96 board colliders, two board MultiMeshes per leaf, 106 reverse-face fittings per leaf, materials, objects and draw calls are unchanged.
- PASS: pass7 board/bucket/collider/slot mapping and one-board replicated break; gate breach; network host/client gate destruction; architecture cascade; single-brick support; pass6 junction geometry.
- Network timing note: an intentionally shortened 14-second settle stopped before the second event reached the guest and failed. Rerun with a 26-second settle passed all checks: two explosions per side, identical `[36, 201]` brick counts and 8 gate boards on both peers.
- Graphical screenshots: close, inside, outside, whole castle and breach in `shots/`.
- Graphical FPS on GTX 980, three runs: courtyard 184.50 / 185.63 / 186.58; gate 155.01 / 156.40 / 156.80; whole castle 152.62 / 153.14 / 152.16. Gate view remained at 1,776 draw calls and 2,207 rendered objects.
- DeepSeek review found no pass-specific logic error after deterministic slot ownership and network replication were checked. It correctly warned that screenshots and this empty-castle benchmark do not establish 50×50 readiness.
- 50×50 status remains **not accepted**: there is still no real 100-combatant formation/contact/destruction benchmark. Budgets and required scenarios remain in `../CASTLE_JUNCTION_PASS6_20261119/BATTLE_50X50_BUDGET.md`.
