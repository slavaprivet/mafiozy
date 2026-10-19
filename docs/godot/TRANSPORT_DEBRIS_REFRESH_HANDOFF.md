# Exact dirty debris refresh candidate — PERFORMANCE REJECTED

Candidate scripts/transport/candidates/transport_vehicle_debris_refresh.gd SHAd2a4453901465e9310033156baefc751fc74f889bb51a3402da27bf6f34b2479.
Test scripts/tests/test_transport_vehicle_debris_refresh.gd SHAbafbea90e1ff9c9017e655401b61df77949322edab668281a0739af04413e79e.

145author+145parent actualGodotPASS; frozen base1cf791ea unchanged and264author-repeatPASS. API configure with initial_revision, refresh_geometry(assembly, explicit_dirty_meshes, expected_revision, exactly_next_revision), geometry_receipt. Reuses body/shape/private materials; stages exact new private ArrayMeshes and bulk-transformed hull points, atomically recaches source state/bindings. Actual hierarchy/pose/scale/finite/layout/bounds/source/prepared objects checked; 2M cap retained; lifecycle sealed after first successful launch even across reset. Caller must explicitly report every in-place edit; provider grants no damage/event authority.

Actual hatch falls/collides/naturally sleeps301frames. In-place door, replacement lid and exact source wheel subdivision/private hash parity pass. Parent light p95 door933us/lid925us/wheel362us; sum2220us. These cheap cases alone do NOT qualify the actual damage workload.

Actual compact_sedan source solver+exact deformation selects68meshes; two configured detachable assemblies receive14dirty meshes/26hulls/67239vertices. Refresh21.65–21.67ms author /22.880ms parent; deformation itself31–36ms; prep3.6–3.7s load-only. Total same-frame exceeds16.7ms. NOT INTEGRATION READY; no event delay or rest hull substitutes adopted.

Native cleaning experiment rejected:
- Measurement-only candidates/transport_vehicle_debris_clean_hull.gd SHA f9f161936c83e0a0579c3c27e1a87a56d4ea0e7d3b8333e23562dc679dee7033.
- test_transport_vehicle_debris_clean_hull.gd SHA10906a30eb18a748e43e8e06a99cd0a1da1ab7a8b237f2f2549a38f1f694bd15.
-246measurement checks PASS, verdictREJECT; direct p9526.408ms vsnativeclean44.503ms, nativeclean alone28.509ms across8repeats. Native Mesh.create_convex_shape(clean=true,simplify=false) removes raw67239points to4043 but all14 hulls fail10um support parity; max0.1172mm. Both variants collide/sleep89frames, which does not excuse changedsupport. Engine cooks hull again on assignment; extra cleaning duplicates work. No unsupported point-cloud API used, no simplification/content deletion accepted.

Root owns native acceleration/build/adoption and sole LIVE. Loaded-scene FPS still unmeasured. This candidate solves geometry lifecycle/correctness but does not solve the full same-frame performance requirement.
