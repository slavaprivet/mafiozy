# Castle junction pass 6 — 2026-11-19

- Closed the real 1.25 m gap between eight existing corner-walk spans and four circular tower floors; resulting overlap is 0.10 m.
- Added 4.86 cm overlap between existing wall-walk deck spans and removed random visual tilt from walk/parapet/bypass groups.
- No new cells, instances, materials, buckets or draw calls.
- Counts: 61,886 bricks, 343 chunks, 1,776 draw calls, 2,207 objects.
- PASS: junction geometry/alignment, architecture support, pass2 support, single-brick destruction, gate breach, close screenshots.
- Graphical FPS, GTX 980, three runs: courtyard 182.91 / 187.08 / 187.20; gate 157.41 / 157.50 / 157.35; whole 153.14 / 152.22 / 152.34.
- 50x50 status: not accepted. Existing castle/battlefield fixtures do not instantiate 100 active combatants. A dedicated formation/contact/destruction benchmark is required before claiming mass-battle performance.
- The existing battlefield-only run on 2026-11-19 had high absolute field FPS but failed its relative-loss threshold and one gate baseline was contaminated by multi-second stalls; it is diagnostic only.
