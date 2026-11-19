# 50 vs 50 performance gate

Target is 60 FPS on the GTX 980 reference machine.

- Full-frame p95 <= 16.7 ms; p99 <= 25 ms.
- AI decisions for all 100 actors: average <= 2.5 ms, p95 <= 3.5 ms.
- Physics, weapons and admitted contacts: p95 <= 3.0 ms.
- Navigation scheduling budget: 1.0–1.5 ms per frame, not the current general 4 ms ceiling.
- Prefer <= 2,400 draw calls and <= 3,500 rendered objects in the contact view.
- Full-rate logic only for the nearest 12–20 fighters; medium distance 15–20 Hz; far distance 5–10 Hz.
- Contact admission must use spatial neighborhoods and active pairs, never all-to-all checks.
- Test four states for 30 seconds each, three runs at 720p and 1080p: empty castle+field, 50+50 formations, 50+50 melee contact, and melee during gate/wall destruction.
- Record frame p50/p95/p99/max, process/physics time, draw calls, objects, primitives, active bodies, navigation/contact/support work.
