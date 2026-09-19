# Route admission cap audit — candidate only

**No production changes. Result: unused capacity is real, but simply changing cap 2 -> 8 gives a variable improvement. Do not claim a proved whole-city/FPS improvement. Root decides whether a controlled LIVE trial is justified.**

`node test_npc_route_admission_cap_audit18.mjs` extracts the actual current queue and planner. Candidate changes only `_npcRouteWorkCount>=2` to `>=8` inside a test VM. The actual shared four-millisecond accounting, FIFO, expiry, iteration order, retained progress and all collision rules remain unchanged.

## Deterministic queue test

288 actors, 233 older queued requests, fixed actor iteration each frame. Work is composed of .05 ms atomic quanta. Cases include .25 ms jobs, a mixture of .25/1/6 ms jobs, and all 6 ms jobs. Longer jobs retain remaining work across admissions. All actors finish; both caps respect four milliseconds plus at most one atomic quantum.

| Workload | Complete batch, cap 2 -> 8 | Unused budget caused by cap, 2 -> 8 | Unused budget caused by iteration/FIFO, 2 -> 8 |
|---|---:|---:|---:|
| Short, 72 ms total | 7.25 -> 1.85 s | 500.5 -> 70 ms | 3.75 -> 3.75 ms |
| Mixed, 954 ms total / 144 retained actors | 14.45 -> 11.95 s | 201.25 -> 0 ms | 2.05 -> 6.55 ms |
| Heavy, 1,728 ms total / 288 retained actors | 21.65 -> 21.50 s | 8.6 -> 0 ms | 2.05 -> 4 ms |

The cap matters primarily when admitted requests finish cheaply. With heavy searches consuming almost a full slice, increasing the admission count provides almost no improvement. A FIFO head whose turn has already passed still waits until the next frame; increasing the cap cannot remove that ordering limit.

## Actual city geometry, moving actors

288 actors, each run 30 simulated seconds at 20 Hz / 1.8 m/s, repeated outings after physical completion, actual body/sweep collision on every movement step. Current production wander includes the applied fine-grid exit helper. AB then BA order guards warm-up ordering. All four runs have zero blocked movement steps.

| Metric | AB: cap 2 -> 8 | BA: cap 2 -> 8 |
|---|---:|---:|
| Routes issued | 479 -> 519 | 507 -> 517 |
| Outings completed | 220 -> 267 | 244 -> 255 |
| Moving sample share | 59.62% -> 65.49% | 63.06% -> 66.26% |
| Pending sample share | 37.65% -> 31.23% | 34.12% -> 30.25% |
| Request latency p95 | 16.5 -> 13.5 s | 15 -> 13.3 s |
| Planner CPU total | 1,924 -> 1,950 ms | 1,825 -> 1,971 ms |
| Planner CPU per route | 4.02 -> 3.76 ms | 3.60 -> 3.81 ms |
| Accounted work p95 | 4.210 -> 4.193 ms | 4.182 -> 4.203 ms |
| Route update p95 | 4.792 -> 4.652 ms | 4.631 -> 4.646 ms |
| Unused cap budget | 285.5 -> 0 ms | 340.2 -> 0 ms |
| Unused ordering budget | 186.2 -> 226.6 ms | 217.2 -> 281.3 ms |

In these runs cap 2 leaves about .48–.57 ms per frame unused solely because it has admitted two jobs. Another .31–.36 ms per frame is left over with fewer admissions and still-pending actors, attributed to fixed-order/FIFO availability. Cap 8 actually peaks at six admissions. Its unused cap budget vanishes, while ordering-related unused budget remains .38–.47 ms/frame.

An earlier cold AB was nearly flat/slightly worse: 475 -> 479 routes, moving 58.05% -> 57.83%, planner 2,102 -> 2,210 ms, latency p95 16.70 -> 16.85 s. This negative run is why cap 8 is not marked an unconditional performance win. Admission overhead, real-time slices and resulting route-goal reservation order affect the outcome.

The four-millisecond stop condition is unchanged, but individual atomic work and host scheduling can exceed it in either version. Latest maximum accounted slices ranged 5.26–7.48 ms; the earlier cold pair had larger outliers on both sides. No candidate-specific increase of the budget or atomic edge work was introduced. More successful movement also increases movement CPU, so no FPS claim follows from planner numbers.

Full report: `outputs/npc_route_admission_cap_audit18.json`. The actual fixture has native geometry and one real car/building; it excludes whole-world AI, live streamed actors/railway and GPU. No game tab was created or reloaded by this audit.
