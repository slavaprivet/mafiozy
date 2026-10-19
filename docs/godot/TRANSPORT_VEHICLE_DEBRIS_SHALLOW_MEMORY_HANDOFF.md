# Transport vehicle debris shallow-Mesh memory audit

Status: **FUNCTIONALLY VERIFIED / MEMORY BENEFIT REJECTED / DO NOT ADOPT**.

The frozen shallow-Mesh candidate changes `source.mesh.duplicate(true)` to
`duplicate(false)` while retaining the explicit deep duplicate of every active
surface material. Its earlier qualified configure comparison improved median by
about 6.4%, but still blocked for about 101 ms. This audit asks whether that
change materially reduces retained memory for multiple loaded debris providers.

## Separate-process memory method

The new test starts a clean Godot `4.7.2.stable.official.ed1daf0bf` headless
process for each `(frozen|shallow) × (1|3|10 providers)` case. It loads all
actual city-hatch visuals first, waits two process frames, records
`Performance.MEMORY_STATIC`, configures every provider, waits two more frames,
then records the retained delta. Thus GLB/catalogue/visual loading is outside
the measured provider delta. Each provider retains 10 assemblies, 76 hulls, 76
private Mesh resources and 76 private materials.

| Providers | Frozen retained delta | Shallow retained delta | Difference |
|---:|---:|---:|---:|
| 1 | 6,329,728 B | 6,329,808 B | +80 B |
| 3 | 18,263,904 B | 18,263,984 B | +80 B |
| 10 | 60,274,768 B | 60,274,848 B | +80 B |

The shallow path saves no retained static memory at any tested scale. The
constant 80-byte difference is measurement/bookkeeping noise in the unfavorable
direction. The likely reason is that the frozen path's redundant nested
material copies are temporary: every copied surface is immediately overwritten
by the required explicit private material duplicate, so both final graphs retain
the same 76 Mesh and 76 material resources per car. This is an inference from
the equal retained graph/counts and measurements, not a claim about allocator
internals.

Cold configure totals from these separate processes were not used as a speed
comparison because machine load and one-process ordering varied strongly. The
earlier alternating 20-pair qualification remains the usable configure result:
frozen p50/p95 107.5985/112.672 ms versus shallow 100.745/107.220 ms. That gain
was already rejected against the no-lag gate.

## Repeated correctness and physics

- shallow suite: **83/83 PASS**; 10/76/142,948, exact hull bytes/support,
  bidirectional source/private Mesh and material edit isolation;
- inherited physical suite: **264/264 PASS**; actual launch/fall/collision,
  natural sleep, retained debris and two-car/20-body stress;
- current physical rerun settled all ten bodies in 228 physics frames and the
  20-body stress case in 131 frames. Its timing was taken under variable host
  load and is correctness evidence only.

## Decision and limits

- Do not adopt the shallow candidate for memory or no-lag reasons.
- It remains functionally faithful, but its retained memory is identical within
  measurement resolution and configure still costs roughly 101 ms in the
  qualified comparison.
- Use the separate incremental preparation experiment for future load-time
  scheduling work; it also remains unadopted pending loaded-scene evaluation.
- These are isolated headless static-memory/physics results, not process RSS,
  GPU memory, loaded-scene FPS or LIVE acceptance.
- No frozen runtime, production integration, Root files, Git, GPU window or
  LIVE scene changed.

