# Missing one-way sign at Old Town — 19 September 2026

The final worker reported `no_safe_one_way_indication` at `one-way-narrow:L-OL-H-011:95:273`. The ordinary curb search only used the right verge, which is occupied by existing reservations. A bounded fallback now checks the continuous dry shoulder of the same mouth and may use its left verge after exhausting the right side. It cannot cross another carriageway/water or advance more than 2 m from this mouth. Existing `safeSign` checks still protect buildings, entrance corridors, parking access, crossing landings, rail clearance and other posts.

The one-way post is at native `(290.233859, 40.764682)`, faces the incoming stream, and sits 0.2 m beyond the first dry curb. It is installed through the normal `addPole` path, with the ordinary physical collider, before the final pedestrian field is rebuilt. The no-entry post retains its physical pose; 437 ordinary signs and all 60 signal heads retain their exact records.

Validation: 14 narrow/control-placement tests passed. `tools/road_dressing/audit_narrow_sign_fallback.mjs` rebuilt current dressing against the final parking/decor snapshot: no unresolved placements, both sign faces correct, 1,325 full-CAR positions through the narrow passage clear, and 2,661 pedestrian continuation segments clear of the final posts. The source snapshot was not modified. Report: `outputs/roads_logical_20260912/narrow_sign_fallback_audit.json`.

The fallback is construction-time only, with fewer than 700 surface probes on this 4.1 m passage. It adds one existing batched pictogram (8 instances), with no new light or material type. The fresh dressing build took 3.09 seconds including the existing whole-city work; this is not a before/after FPS result. **Performance of the shared game scene is unverified.** Final combined worker, parking pedestrian postpass and LIVE validation remain parent-owned.

## Final worker and independent audit

Root subsequently produced the final worker snapshot SHA256 `49a57b81992b763c5552f30302c30470e5c12d8ea482b4fac31aa1fc6e48386d`: 6,839 markings, 485 signs, 60 heads / 16 controllers, 77 crossings and zero unresolved placements. Six requested final audits now all pass; the first five were run once. Only the shared validator was rerun after its audit-only fix for the new bounded mouth placement mode.

The audit helper `tools/road_dressing/narrow_mouth_sign_audit.mjs` independently derives the correct mouth, approach and face from the passage, checks the actual projection within 2 m, exact topology boundary intervals to the first continuous dry shoulder, the complete 0.2 m post disk, building/access/rail/landing reservations, other poles and the physical collider. It does not invoke the placement generator or trust its mode flag. Measured dry-curb setback is 0.238694 m; the generator's 0.2 m value is its sampled estimate. Existing generic verge acceptance is unchanged. The shared script now returns failure exit status when it records errors.

Five regression tests passed, including falsified passage/direction/facing/pose metadata, a post whose centre is dry but radius clips the road, an intermediate water gap, and altered keepouts/landings/colliders. No production change was made for this audit update. Final six-audit summary: `outputs/roads_logical_20260912/final_six_audits_20260919.json`.
