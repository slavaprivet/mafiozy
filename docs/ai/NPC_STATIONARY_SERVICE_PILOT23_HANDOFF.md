# Stationary service pilot23 — READY FOR REVIEW (CPU), NOT ACTIVATED

Root approved narrow source/adapter scope after published main8f39187.
Only pilot `REBUILD-VISUAL-print_shop-001`; no other buildings, world.html,
Walk, generic layout generator or GLB edits. Commit/push remains root-owned.

## Source / adapter ready for review

- `assets/maps/city_rebuild_v1/npc_resident_commerce_source.js`:
  `_residentCommerceRegisterService(buildingId,provider)` opt-in registry,
  identity-safe unregister, per-arrival/browse/commit employee eligibility and
  generation stamp. Unregistered buildings retain existing checkout. Empty
  registry has a shared constant fast path without per-tick object allocation.
  Orders store registration tokens, not provider closures/scene references.
  Death/replacement/unregister before payment cancels without debit. Actual
  source remains sole wallet/inventory writer; accepted purchase callback runs
  synchronously before a new needs choice. Invalid nonfinite/fractional/overflow
  existing wallet is refused rather than reset or spent.
- `npc_stationary_service_adapter.mjs`: explicit session-only source adapter.
  Requires current service access (building/revision/station/seller+buyer
  generations/visit). Checks actual source order/receipt objects and finite
  before/after balances. Injected needs binding consumes one actual purchase
  receipt into its mirror; no second wallet debit. A mismatch returns
  account-sync-required; the already completed purchase is not repeated/refunded.
  Existing customers without needs binding retain valid service checkout.
- `test_npc_stationary_service_adapter.mjs`:33 actual-function checks PASS:
  one debit/mirror, old inventory preserved, death before/during, seller
  replacement, lost customer position, unregister, other building isolation,
  failed mirror, duplicate registry, online refusal, invalid money.
  Existing resident commerce test PASS; needs-commerce11 PASS. Source access
  callback is controlled in these adapter tests; actual NPC is not instantiated.

Frozen source SHA256 during root LIVE6/perf window:
`21e1013983040cbda65284cbb3b7f2b883b6b909a9cd77ac6d7dcdf927699c76`.
No world registry activation has been added.

## Geometry module / actual collision test — PASS

`native_print_shop_service_station.mjs` adds only this instance's existing
ground-floor stockroom technical door and a small public counter, register and
newspaper stack. It reads existing authored room descriptors, requires a
host-certified layout, exports world staff/customer/spawn/door anchors and
counter/leaf/handle colliders. It preserves instance identity and existing room
contents. WeakMap prevents duplicate station construction; dispose owns only
its added resources. Shared interior mesh pool reuses existing resources.

Opening is an exact state request, not a toggle. The leaf opens outward so the
employee at the inside anchor is outside its sweep. Closing is automatic after
egress; supplied nearby bodies are checked over the swept arc before request
AND on every moving update. No movement/HP/source actor mutations occur here.
The host must supply the complete bounded nearby body set (≤64), register the
returned colliders and integrate needsUpdate with its existing entry cadence/
shadow invalidation. The module is not imported by world/Walk yet.

`test_native_print_shop_service_station.mjs` uses the actual GLB/static-city
fixture. Written checks cover source .738m capsules at all anchors, closed/open
door with handles, staff and customer paths, solid counter, a body entering the
door sweep after a close request, duplicate construction, cached idle colliders,
draw/triangle budget and disposal. PASS after root closed GPU measurement window.
Uses tracked test_fixtures/native_static_collision19.json.gz, not an untracked
outputs snapshot. Counter and moving leaf/handle envelopes checked against
original static geometry.21 parts/4 draws/924 triangles.

Actual precise executor staff/customer cycles at60/15/7/5/3Hz:10 PASS. Every
step uses actual _residentNativeSegmentPassable, floor checks and per-frame
navigation cache reset. Arrival within .08m; max7 substeps/.35s, no catch-up
teleport. Customer first passes public jamb through customerVia.33 adapter
checks include owner/death/obstruction and early-arrival floor/occupancy checks
when target XZ already matches. Independent floor-arrival regression PASS
(adapter cc989b95). No renderer/skeleton instantiated in these tests.

CPU probe `outputs/npc_service_counter23_probe.json` selected the free counter
envelope before geometry addition. It is not a substitute for the final test.
Hidden spawn still needs camera/occlusion-aware source permission: a closed
door alone does not prove invisibility through windows/ceiling reveal.

## Lifecycle independent fixes

`npc_service_employee23_candidate.mjs` now43 own checks PASS, reviewer4/4 actual
checks PASS. Semantic duplicate birth receipts compare stable fields and verify
authority, independent of JSON key order. A verified birth followed by a verified
later death can advance generation and start that generation's own60s timer,
without reviving a corpse. Old-generation death remains rejected. This isolated
candidate is not imported into production, and not part of the source registry
activation yet. Detailed contract in NPC_SERVICE_EMPLOYEE23_HANDOFF.md.

## Activation still required

Root supplies scoped world getNPCprovider/registration ranges after perf.
Instantiate an ordinary damageable seller actor via existing source lifecycle,
resolve its real service/customer slots, connect the technical door/collision
executor and session needs binding. Existing fear/police/death takes priority.
Only then activate this ONE building's provider. Renderer/visual merchant
acceptance and comparable whole-scene frame time are pending; no online bank
or source healing implementation is claimed.

## CPU cost and exact package

Comparable384 browsing NPCs,50 warm/350 interleaved rounds (baseline8f39187):
source baseline p50/p95 .2007/.2202ms; empty registry .2310/.2509ms;
one registered adapter .2298/.2506ms. CPU checkout cost only.
Geometry cached idle update/colliders p50/p95 .0002/.0002ms in final run.
**Производительность общей сцены не проверена.** No GPU window used here.
Explicit proposed stage files/SHA256: NPC_STATIONARY_SERVICE_PILOT23_MANIFEST.json.
No files staged/committed by Artist21. Adapter test imports root
npc_resident_needs23_candidate.mjs: this untracked test-only dependency MUST
travel with package alongside tests. Lifecycle foundation is not runtime imported.

IMPORTANT activation constraint: current commerce Arrive/Tick tests
visit.door.inside with .04/.08 source-cell tolerances. Routing only to new
counter customer anchor would fail old door test. Keep entrance identity and
exit route; provide separate certified service arrival target under registered
provider and use consistently in visit movement and checkout. Do not globally
overwrite building door.inside or bypass arrival for other buildings.

## Combined physical lifecycle regression

New test_npc_service_physical_lifecycle23.mjs:5 full cycles60/15/7/5/3Hz PASS.
Actual printshop geometry + real moving door + swept actor executor + lifecycle:
verified death ->60s -> unavailable while camera host denies hidden spawn ->
one fixture birth in backroom -> blocked movement holds -> inside/open/exit/
close/work -> eligible customer, then death invalidates eligibility.
Physical return after birth takes5.88/6.00/6.71/7.60/9.33s respectively; lower
cadence door dt intentionally capped .1s, no teleport/catch-up through bodies.
Authority receipts, camera visibility, customer slot and persistent source actor
are fixture inputs here: no actual world spawn or visual acceptance claimed.

## Reviewed arrival delta applied

Coordinator20 explicitly released applying patch f2b902ec after independent ACCEPT.
Applied only npc_resident_commerce_source.js (registered target getter and
per-visit registration/coordinates/stamp binding). No provider activated.
After apply: commerce baseline PASS, adapter33 PASS, actual geometry+checkout26
PASS, needs-commerce11 PASS. Old21e101 freeze superseded only for this delta.
New source SHA is in refreshed manifest. Source employee activation remains
isolated proposal only; world/Walk untouched.
