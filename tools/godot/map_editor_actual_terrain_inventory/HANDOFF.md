# Read-only existing native terrain inventory

Frozen source candidate; no production changes or gameplay/editor admission.
Godot4.7.2 headless native test: **815 checks, zero failures**, explicit final JSON,
exit0 and no SCRIPT ERROR. Actual source revision `s01-20260927-melee21`,
main SHA `0916381441df9a9d111006aed2b34e4e1c2ec195ee24609757a552b388017571`.
Original imported source stage reused from Document agent:
`outputs/actual-main-pause-probe-qAWF1V`, snapshot SHA pinned in receipt.
Its source scripts/data/assets were not modified. Only two new inventory/test
scripts and generated result were added. No engine process remains alive.

## Actual crop evidence

- 31×31 cells, start `(76,0)`, cell4.1m, original origin `(395.65,0,45.1)`.
- Exact direct native `Surface_grass`291, `Surface_road`253,
  `Surface_sidewalk`114:658 dry visual instances. Each original MM, BoxMesh and
  original shared surface material identity is retained; no reconstruction.
-169 native dry-floor bodies match row/tile contiguous source runs, exact
  body/collider transforms, BoxShape sizes, enabled state and layer/mask1.
  Source strip positions and expected counts are reconstructed independently;
  native node/resource IDs and shape margin are captured, not replaced.
- Original water owner has its sole existing `SourceNativeWater` mesh303cells,
  1818 native vertices/indices, exact source Float32 position/depth bytes and
  original winding. Native normal-codec output hash is observed, not falsely
  asserted byte-identical to regenerated raw UP normals. Original water owner,
  factory, mesh and material identities are captured; no water/editor authority.
-24 direct convex source bodies are proven nonterrain by exact source ID/index,
  polygon Float32 points, identity transform/filter/lifetime; metadata alone is
  insufficient. Other original printshop nested bodies are outside the direct
  floor census. This is not a total scene collider admission.
- Original jump cells and12 offsets match source masks/anchors exactly.
  Their presence does not approve navigation, swimming or editing jump caches.

All three Dummy-renderer MM buffers are unavailable. Reports separately retain
`source_construction_sha` and `actual_buffer_available:false`; source expected
data is NOT presented as observed actual GPU-instance storage. A real renderer
or a genuine source owner CPU shadow is still required for transform proof.

## API and strict limits

`capture(originalMain) -> {ok, report, snapshot}` reads only. Version pinned,
main/source block/parent visibility validated. Surface layers1, overlaynull,
full visible_count−1, original identity pose/shadowOFF are mandatory.
Missing, extra, duplicate, unmatched and malformed direct bodies fail closed.

`verify_snapshot(originalMain, snapshot) -> {ok, report, error}` accepts only
the original issuer/main/parent WeakRef capsule and recaptures exact **enumerated
fields**. Queued/deleted/reparented scene lifetime fails. No owner repair,
rollback, replacement or resource writes are implemented. Material identity is
checked but material-content equivalence is NOT established; shader time/ripple
parameters naturally advance and are not immutable snapshot fields. Reports are
diagnostic serialization, not authority capsules or portable node identities.

Negative fixtures are labelled isolated: added unmatched/malformed bodies,
forged convex source metadata, foreign issuer, final scene reparent/queue/free.
Reparenting can invalidate actual gameplay-owner caches; the test performs no
further gameplay ticks or restoration claim afterwards. Production unchanged.

## Reproduction

`node tools/godot/map_editor_actual_terrain_inventory/stage.mjs --check`
verifies the334 captured source files and pinned new scripts, no writes.
The Document agent's independent `probe.gd` is intentionally excluded: it was
corrected after the snapshot, is not game source, and is not part of this test.
`--stage` instead copies them to a unique output project, no importer cache.
Root can import that isolated project sequentially then run:

```text
Godot --headless --path <stage> --quit-after 1200 --script res://test_actual_terrain_inventory.gd
```

For bounded independent rerun the already imported qAWF1V includes the exact
frozen scripts. Result is `terrain_inventory_result.json`; resource IDs differ
per process, so compare assertions/source hashes, not the whole generated SHA.
GPU/live quality, edited terrain collision/nav atomicity, full map adoption,
performance of the loaded game and editor acceptance remain HOLD.
