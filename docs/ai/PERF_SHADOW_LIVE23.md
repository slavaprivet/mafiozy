# LIVE7: building shadow comparison, 23 September 2026

One existing game tab at localhost:18538, `renderer=walk`, explicit
`buildingshadowcull=1`. The shared runtime contains the reviewed 16-file chain
through 0d8546a; entry/building shadow culling remain OFF by default in source.
The default-ON commit 78d3666 was excluded. Vehicle shadow culling remained ON.

All three readings used the same frozen 3D scene and 120 warmed samples.
This measures rendering, not gameplay FPS: source world continues behind the
fixed presentation. GTX 980, ANGLE D3D11, GPU timer valid, multiDraw available,
1049x920 at pixel ratio 1. Camera [616.95,3.54,54.45], quaternion
[-0.0348366182,0.9646593017,0.1681301558,0.1998776935].
Snapshot: 72 NPC seen, 43 visible, none pending; 18 traffic actors, none loading.
All three snapshots matched; freeze remained active for each recorded sample.

| Metric | OFF A | ON | OFF B |
|---|---:|---:|---:|
| GPU mean ms | 99.00 | 92.47 | 96.81 |
| GPU p50 ms | 96.97 | 91.40 | 96.64 |
| GPU p95 ms | 112.31 | 102.81 | 102.00 |
| Render p50 ms | 118.20 | 112.00 | 116.90 |
| Render p95 ms | 137.50 | 130.60 | 122.40 |
| Interval p50 ms | 141.80 | 136.20 | 140.20 |
| Interval p95 ms | 165.90 | 157.60 | 150.50 |
| Main draw calls | 4761 | 4761 | 4761 |
| Shadow draw calls | 2554 | 1477 | 2554 |
| Total draw calls | 7315 | 6238 | 7315 |
| Total triangles | 5058291 | 4749380 | 5058291 |

Three screenshots were visually inspected inline. No obvious change in the
visible character, car, building or ground shadows at this view; the restored
OFF count exactly matches baseline. Shadow submissions fall 42.2%, total
submissions 14.7%, GPU median about 5.5%. GPU/render p95 is noisy and does not
show a stable improvement against BOTH controls. The scene remains too slow.
This limited daytime viewpoint does not certify every camera, night lighting,
shader transitions or gameplay FPS. Default-ON remains pending broader checks.

After recording, the first freeze expired at its 120-second safety timeout;
a following toggle started a new freeze. Escape explicitly ended that freeze,
verified `active:false`, `scope:gameplay`, `stopReason:Escape`.

Root validation before LIVE: six perf suites, four NPC/input smoke suites,
four static/vehicle/wheel batch regressions PASS. Independent review included
76,320 geometry cases and actual Three.js bounds invalidation/copy guards.
CPU checks are separate from the LIVE results above.
