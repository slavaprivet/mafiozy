# Exact damaged assembly refresh — prerequisite measurement

Test scripts/tests/test_transport_vehicle_debris_refresh_cost.gd SHA8fb1eeec7c77d701f67c5ae99a3b895b00cd85145b4550403d818aea9cf4f6b5.85PASS,24 warmed repetitions on each real hatch assembly; no frozen production edits.

Actual modified source mesh is cloned privately; transformed ConvexPolygonShape3D points extrema match changed source vertices. Reused native frozen layer0 shapes update/prewarm without a separately observed activation spike.

Perassembly p50/p95/max microseconds:
| Assembly | Hulls / source vertices | Fresh mesh+convex | Existing points only | Fresh private visual+reused points |
| --- | --- | --- | --- | --- |
| Door |13 /18036|9374 /10339 /10861|5425 /5956 /6398|9219 /10712 /10853|
| Hood lid |2 /2664|1388 /1481 /1500|772 /899 /1359|1360 /1502 /1577|
| Wheel |5 /15271|4872 /5694 /5719|2879 /3328 /3400|4725 /5187 /6749|

Physics frame waits compare baseline pacing p95/max20706/20715us; door15446/15447,lid19936/19937,wheel17906/20723. These waits are not update CPU or loadedsceneFPS. Eight microseconds over baseline max does not establish a regression.

Reject full113ms configure inside damage. Exact perdirty assembly refresh with retained private resources/reused shapes is a justified next implementation, not already integrated. Multiple doors detaching in one impact may add linearly; sameframe budget remains unresolved. No source1.55s preparation lead assumed: RPG/structural failure can be immediate. Never silently use undamaged rest hulls or delay source events.

Next isolated optimization experiment: use native Transform3D*PackedVector3Array bulk transformation for hull points while retaining exact positions, avoiding repeated GDScript vertex transform calls. New SHA/results supersede this baseline only after actual parity tests. Root soleLIVE loaded scene remains acceptance requirement.

Builtin bulk follow-up: test6ba59134dcca3b6e0657e8b87ae30f960f57faad8e909547e51ba558c26d7aa5,88PASS. Transform-only scalar->bulk p95 door1285->775us,lid165->90us,wheel1088->560us (40-49 percent). Full exact refresh p50/p95/max door8627/9591/9649,lid1294/1658/1672,wheel4450/4876/5228us. Reused hull-points p95door5528,lid850,wheel3246us. Geometrytransform errors<1e-6; nativeconvexcooking/resourceextraction dominate remainingcost. Additive candidate refreshadapter nowbeingimplemented; old1cf791ea frozenunchanged. No loaded-scene acceptance.
