# Phase-local source identity cache for debris material snapshot

Date: 2026-09-27. Status: **FUNCTIONALLY VERIFIED CANDIDATE / PERFORMANCE
REJECTED FOR EVENT-FRAME ADOPTION**. This is additive transport-only evidence.
It is not connected to Root, damage authority, main, LIVE, or an export. The
frozen snapshot, refresh, and physical debris files were not changed.

## Frozen dependency chain

- physical debris `transport_vehicle_debris.gd` SHA-256
  `1cf791ea4890c844b8c1072cdccca647b3b8255cec718afa7e96f80b9c2bba8f`;
- geometry refresh candidate SHA-256
  `d2a4453901465e9310033156baefc751fc74f889bb51a3402da27bf6f34b2479`;
- rejected exact material snapshot SHA-256
  `0e000ba7c30c463fae5ff6390323f1bb36d87c138ebd4673bdd5465102627001`;
- exact damage assemblies SHA-256
  `8643b11808f5834445e34be6d1c2930a9cc2f5a930042dfb7edfcf4ce6d78279`;
- native visual manifest SHA-256
  `38598f43beb77c095879206ea5820c7fe922b227a64f77f793353f89321fee03`.

Exact candidate/test hashes and sizes are in the companion manifest.

## Change boundary

`transport_vehicle_debris_material_snapshot_cached.gd` extends the frozen
snapshot helper. It overrides only stage, commit validation, and the diagnostic
launch result:

- within one synchronous stage, an exact source `Material` instance ID is used
  to read its byte/type signature once and traverse its Resource graph once;
- within one synchronous commit validation, an exact source instance ID is
  used to read its signature once;
- every cache is a local variable and is discarded when that phase returns;
  nothing is reused across stage, callback, commit, launch, reset, or vehicle
  lifecycle boundaries;
- launch has no source-material read to cache. It continues to validate every
  independently owned private material through the frozen implementation.

The candidate does not group by color, name, exported ID, metadata, signature
value, or source descriptor. It allocates the same independent deep duplicate
for every copied surface, retains every private signature/graph watcher, and
performs the same atomic writes. Stage tokens, revisions, nested change signals,
source/private layout and hierarchy checks, reset/dispose, callback ordering,
and launch validation remain inherited from frozen `0e000ba7`.

Successful results add diagnostic counters:

```text
source_signature_reads
source_signature_cache_hits
source_graph_reads
source_graph_cache_hits
```

They count only exact source Resource identities in that call. They grant no
authority or cross-phase receipt.

## Correctness evidence

Safe Godot 4.7.2 headless results were sequential and clean:

- cache-specific suite: **author 46/46 PASS; parent fresh 46/46 PASS**;
- exact inherited frozen suite with only its preload changed to this candidate:
  **author 60/60 PASS; parent fresh 60/60 PASS**.

The cache-specific suite covers:

- actual compact sedan: ten assemblies, 72 copied mesh/surface rows, 72 distinct
  prepared and committed private material Resources;
- its actual 29 exact source identities: stage signature `29 reads + 43 hits`,
  stage Resource graph `29 + 43`, commit signature `29 + 43`;
- a 72-source-identity worst case: `72 reads + 0 hits`, proving there is no
  value-based equivalence;
- a four-surface exact alias: `1 read + 3 hits` while all four private material
  Resources remain independent;
- source replacement and same-identity mutation after stage, nested Resource
  change signal, private mutation after commit, foreign/stale token, abort and
  reset behavior.

The inherited 60-case suite additionally rechecks callback replacement,
source-reset independence, atomic rollback, source/private surface mutation,
ShaderMaterial rejection, nested Resource watchers, revision gates, geometry
refresh sealing, source/template/body reparenting, queued/free nodes, prewarm,
launch, reset/relaunch, and actual compact source-order binding.

## Sequential measurements

The comparison used eight actual compact-sedan pairs. Pair order alternated
between frozen and cached to reduce order bias. Configure and prewarm occur
outside the measured event interval; the event interval is stage plus commit.
With eight samples this report gives empirical min/median/max only and makes no
p95 claim.

| Actual compact event | min | median | max |
| --- | ---: | ---: | ---: |
| Frozen `0e000ba7` | 56.927 ms | 58.7385 ms | 62.782 ms |
| Cached candidate | 46.841 ms | 48.828 ms | 53.676 ms |

The cached median is 9.9105 ms lower in this isolated sequence, but **48.828 ms
is still unacceptable inside an explosion frame**. The candidate remains
performance rejected. The prior 57.517 ms measurement is historical evidence,
not the current comparator.

The no-alias 72-identity synthetic pair measured frozen 55.735 ms and cached
56.376 ms. This single pair shows no useful win and a measured +0.641 ms
difference; it is an empirical overhead receipt, not a stable regression
estimate. The inherited-suite single actual compact sample measured cached
stage 22.837 ms plus commit 24.728 ms.

The parent then ran both suites fresh and sequentially. Its separate eight-pair
series measured frozen min/median/max **57.359/57.7845/69.125 ms** and cached
**46.945/47.5305/54.540 ms**. Its no-alias single pair measured
58.324 ms frozen and 59.359 ms cached, a +1.035 ms difference. Its inherited
60-case sample measured cached stage 27.820 ms plus commit 23.941 ms. These
second measurements confirm the direction for the alias-heavy actual compact
case and the lack of a no-alias win; they do not change the rejection.

The emitted test field named `event_median_us` is the upper-middle order
statistic (`sorted[4]`) for eight samples. The medians in this handoff and the
manifest are the conventional averages of `sorted[3]` and `sorted[4]`; the raw
sample arrays remain the authoritative measurement receipt.

Independent sequential verification also passed **46/46 + 60/60**. Its actual
compact min/true-median/max was 58.729/59.566/64.616 ms frozen and
46.532/49.4945/55.327 ms cached. Its no-alias single pair was 63.203 ms frozen
and 61.912 ms cached, while the parent single pair showed a +1.035 ms cached
difference. The contradictory single-pair direction is measurement variance;
the parent-observed worst regression governs the rejection. The independent
inherited sample was 23.659 ms stage plus 23.732 ms commit.

These are isolated headless CPU timings. No renderer, shader warmup, GPU, FPS,
full scene, LIVE, or exported build was measured.

## Remaining cost and limits

The experiment removes repeated source signature/graph reads only. It still
performs 72 event-time material allocations/deep duplicates, every private
signature and Resource graph, 72 surface assignments, committed watchers and
launch-time private validation. It also retains the inherited linear refresh-row
lookups. The result demonstrates that source alias deduplication alone does not
meet the frame budget.

No callback is authenticated here. Root must still preserve source order:
char captured source identities, complete the synchronous callback, hide glass,
then snapshot/commit and launch. Replacement or mutation remains a real event
input and cannot be hidden by a stale cache. Batch canonical identity and later
callback-phase receipts remain separate dependencies.

Do not adopt this candidate as a latency fix. A later experiment may move the
72 private allocations and complete-property preparation outside the event only
under the exact identity/revision/callback contract in
`TRANSPORT_DEBRIS_MATERIAL_PREALLOCATION_AUDIT.md`.
