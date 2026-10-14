# Unified source ladder route admission — 27 September 2026

Traversal owner, additive component only. Base published78e67c826071f9c55d72a909d0c2ad4bd6488685.
Frozen manifest/receipts: outputs/ladder_source_route27/.
Helper scripts/traversal/ladder_source_route_probe.gd.

## Result

Combines source .51m own-entry collision corridor, preserved rail collisions,
exact authored ladder route and query-derived static roof grounding. Keeps
source descriptor/step-off unchanged; appends actual grounded endpoint only to
the derived Motion execution path/total. Source Motion and Pose files unchanged.

Actual-main source-index mapping is checked against EVERY accepted interior
convex point. TEST_ONLY standing CharacterBody completes ascent467 samples to
roofY6.47 and Ctrl slide385 samples back to source lower support. All source
filters restored; committed pose roots match actual accepted ascent roots.
Actual-main author2014 PASS; independent100 PASS three runs, parent rerun logged.
NOT real player, rig, E/Ctrl arbiter, main, export, GPU/LIVE or full migration.

## API / bounded work

- configure(real direct_space_state, mask, actor_rid); dispose clears authority.
- prepare(feet, source_descriptor, end, current_source_records) builds one
  pending lease. EVERY new attempt revokes previous proof, including failures.
- inspect_window(plan, exact cursor, max_samples=16) checks sequential current
  geometry/support/capsule windows, cap32. complete=true only after ALL samples
  and final five-ray support. No physical filters/motion admission before this.
- inspect(...) is synchronous certification convenience. Do not call it in the
  runtime update loop: full route certification is tens of milliseconds.
- inspect_samples(admitted_plan, motion.sweep_samples) returns current verified
  accepted prefix; rejects pending, stale, malformed and foreign proof.
- movement_filters(plan, actual_from, next_root) validates <=.04m physical
  segment and full-collision endpoint, returning during_move/after_move RID sets.
  Crossing OUT of corridor retains source filters for the short physical sweep,
  restoring them immediately after it. Rails/foreign bodies remain collidable.

Source record: body StaticBody3D, source_static_index unique nonnegative int,
building_entry_id matching descriptor ID, explicit String storey_part.
Empty String is CANONICAL for source base envelopes (Walk String(body.storeyPart
||'')); missing key/wrong type rejected. Root must supply trustworthy exact
source-index→current-body→part mapping. Helper does not authenticate a caller's
initial source role claim or recreate server authority. Actual body source_id,
space, transform, velocity, layer/mask and shape geometry are checked physically.

Private canonical lease snapshots descriptor/initial Motion state, grounding,
body/index/role/shape/RID/filter sets. Returned receipt can never reclassify a
rail or change index/route by coordinated dictionary edits. Lease revokes on
configure/dispose, failed admission/new attempt, source movement/removal, same
body shape replacement/data mutation, disabled shape, mask/sourceID change,
dynamic support or changed terminal roof. One route per probe instance.

## Root seam

1. Exact current adapter mapping remains root dependency. Preserve source IDs,
   index/roles/collider geometry. No guessed node-name matches or blanket RID set.
2. One E admits a pending route, automatically processes subsequent windows;
   don't require repeated E or prepare on every held-key frame. Central input
   owns pending/active ladder; Ctrl slide only after E admission, no cover clash.
3. After complete preflight, start plan.initial_state in existing Motion. Use
   propose -> inspect_samples -> per-root movement_filters -> actual native
   CharacterBody move -> restore after_move -> commit ACTUAL accepted prefix.
   Stop at the physical accepted root on rejection, never teleport to planned end.
4. Preserve unrelated/preexisting physical exceptions. Track only filters root
   itself adds. Restore on outside endpoint, finish/cancel/abort/dispose. Test
   fixture's _sync_filters assumes empty initial exceptions; do NOT copy that
   fixture reset indiscriminately into production.
5. Terminal grounded support and committed pose must be rechecked; keep input
   ownership through the additional grounding. Root owns the only body/rig writer.
6. Existing raw NativeLadderController still has its old admission. Root/traversal
   integration must deliberately adopt this new planner; receipt alone is not
   input/character integration. Existing legacy/controller modules not modified.

## Performance and limits

Actual loaded-main before windowing: single source admission24-30ms; with complete
private lease and16-sample windows total work41-59ms, distributed over20 bounded
windows. prepare1.3-1.5ms; per-window p50 2.07-2.86ms / p95 2.46-4.50ms in observed
runs. Integrity checks add work; windowing bounds a single update, not total CPU.
Root chooses per-frame budget and measures actual interactive responsiveness.

Ascent per-proposal inspection233 measurements p50~1.0-1.28ms/p95~1.27-1.94ms;
per-root filter/lease query467 measurements p50~.92-1.19ms/p95~1.23-1.82ms.
Independent small fixtures give cheaper numbers (not comparable): window
p50/p95269/341 to329/506us, filter166/341 to176/271us. Direct query/receipt cost
only, NOT complete frame/FPS or physical exception churn cost. Full-scene FPS,
crowd, actual rig, native LIVE application untested; root must measure before
production acceptance. No source/world content removed to reduce work.

Known remaining integration: actual adapter lease, central input, cancellation
and slide wrapper ownership, physical filter cleanup on every early exit,
complete rig pose mapping and GPU/LIVE. This package proves the native route,
not finished user-visible ladder gameplay.
