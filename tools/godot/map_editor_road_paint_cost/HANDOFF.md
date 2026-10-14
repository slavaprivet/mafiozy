# Actual road paint cost diagnostic — no integration recommended

Frozen original V3 runtime SHA256 `280880c927809d0d773c3175cdf43fc7534a772af286d77fbf0b50a85fe53628`; exact source manifest `82e6ef82a824e002d0f315972ffd3d967102b7c36256371699992bcfb76220dd`. Both unchanged. Separate candidate/stager/tests only; latest unique staged project `outputs/map-editor-road-paint-cost-7pwbET`. Godot4.7.2 headless **23,044 PASS, exit0**; no GPU or production game.

## Source workload

59 merged-original-paint batches, 6449 stable marking IDs, 38,694 vertices. Actual paints have original position+normal attributes, no UV and no source index; native sequential indices have only the existing CCW→CW reversal. Each marking owns six vertices.

| Selected actual batch | Markings / vertices | Current position array | Complete native input payload |
|---|---:|---:|---:|
|RoadPaint:5,2:warm|1 / 6|72B|168B|
|RoadPaint:2,3:white|59 / 354|4248B|9912B|
|RoadPaint:3,1:white|339 / 2034|24,408B|56,952B|

Payload is the exact sum of submitted position/normal/generated-index bytes, **not measured allocator/GPU memory**. Move creates one replacement ArrayMesh. Undo/redo creates zero: original runtime already retains and swaps exact old/new mesh references.

## Bounded candidate and alias finding

Original deep-copies the whole Mesh array then immediately replaces its copied old vertex channel. Candidate skips only that discarded channel, explicitly duplicates **every nonvertex packed channel**, and copies current positions exactly as original. It keeps mesh prototype/normal/index/source descriptor/groups/drawRange/material/IDs and identical owner prepare/commit/rollback/history operations.

An earlier naive shallow Array duplicate was **rejected**: mutating a packed normal channel in the shallow copy altered the source Array's channel. Do not rely on generic Packed COW semantics when it is stored inside copied Variant arrays. The final candidate has an explicit detached-channel mutation test; no source alias remains in supported actual paint inputs.

## Comparable CPU result

Same headless process, exact same original buffers/batches and owner fixture, five warm move/undo cycles,60 samples per selected batch, baseline/candidate move order alternates. Full parity checks occur outside timed calls. Explicit real gameplay/nav callbacks are not wired; fixture only exercises the original callback transaction interface.

| Move | Original p50 / p95 µs | Candidate p50 / p95 µs |
|---|---:|---:|
|Small|32 / 57|34 / 62|
|Median|61 / 94|61 / 94|
|Largest|161 / 198|162 / 205|

Original undo p50 16/19/19µs, redo13/15/14µs; candidate undo14/16/15µs, redo13/15/13µs. Candidate does not change inherited history code; small differences are scheduling noise, not an undo optimization. Previous comparable run largest142/270→144/298µs also showed no median win; another144/212→147/228µs corroborated this.

**Conclusion: meaningful acceleration not demonstrated. Keep frozen original.** Maximum skipped old vertex channel is only24.4KiB; script loop overhead and unchanged ArrayMesh creation erase any observed gain. No altered LOD/resolution/shadows/geometry/materials or batching are proposed.

`OS.get_static_memory_usage()` returned0 in this release headless engine. Reported process live deltas therefore also0 and **unavailable as allocator evidence**, not proof of zero allocation. Private native mesh allocation/driver buffers cannot be measured by this run. Exact input bytes and one mesh per move/zero per undo-redo are the usable bounded allocation-work facts.

## Validation and possible higher-priority issue

All59 source vertex/normal submissions match frozen raw Float32 bytes; every generated triangle winding and all6449 marking→six-vertex IDs verified. Baseline/candidate submitted arrays and native readback compared during edits, exact original prototype identity restored by undo, redo replacement preserved, delete/failed owner transactions/history/material/source metadata preserved. Native readback here is mutual parity, not original GPU shader/depth-offset/visual acceptance.

The inherited procedural `_history` is an unbounded Array retaining both meshBefore/meshAfter and vertex snapshots. One sparse edit is inexpensive, but a host committing every pointer event for a long drag could retain many full batch meshes. No such live host frequency is proved here. Profile actual drag commit count/history lifetime before next work. A separate user-visible stroke transaction/coalescing or agreed bounded history could address that retention; it changes undo granularity and needs actual host/owner contract, not this micro-optimization. Do not mutate cached prototypes or discard history resources still referenced by undo/checkpoints.

Run `node tools/godot/map_editor_road_paint_cost/stage.mjs`, then Godot console `--headless --path <printed unique stage> --script test_paint_cost.gd`. Stager copies only source/buffers/code/project, no imports/cache; original runtime/source hash locked. This is a CPU diagnostic candidate, not a production-ready source owner/safety package. Full common-scene frame time, draw calls, GPU and game collision/nav behavior remain unmeasured.
