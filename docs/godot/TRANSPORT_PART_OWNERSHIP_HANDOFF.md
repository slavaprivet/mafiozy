# Vehicle part ownership — frozen pure transport component

Runtime scripts/transport/transport_vehicle_part_ownership.gd SHAd6194d3ac9b2afb13483cbad30f4906b0603c57babd2ee4877b9aee06674a4c9.
Test scripts/tests/test_transport_vehicle_part_ownership.gd SHA1b74fac3514b294bc39ba4847521f887d25dff431c64f1262bf9f17919b7948e.

10038author+10038parent actualGodotPASS. Parent10000 reserve/rollback cycles232806us,average23.2806us; isolated logic cost, not loadedsceneFPS.

One-shot configure(vehicle_id,life_generation,actual_vehicle_root,bindings) requires actualroot metadata vehicle_id/life_generation, live tree and exact caller pair. Up to12distinct actual Node3D,64aliases; authored null remains MISSING. Pass the stamped actual vehicle body/root containing the visual, not an unstamped imported AuxScene.

reserve atomically validates bounded alias subset, deduplicates same physical node and returns lease_token plus canonical nodes in firstalias order. Caller alone detaches exactly those canonical nodes, then commit_detach_success; rollback_detach_failure releases on failed physical work. Same node cannot be copied by structural/trunk/blast paths twice. Missing authored parts do not create replacements.

Every boundary rechecks actual root metadata/incarnation/tree. Same-root newlife, removedmetadata, deletedroot/node, outsidevehicle nodes and old epoch leases fail. AVAILABLE/RESERVED nodes must remain descendants; COMMITTED may reside outside after actual detach. Claims persist until explicit sameincarnation reset/dispose; reset invalidates old leases. No automatic repair/lifecycle generation, visual/physics/HP/event/authority mutations.

Tests include successful atomic2node claim, partialconflict rollback prevention, aliases/twochannels, failure/success, sameRoot11->12, removedmetadata, removedtree, deletednodes, sourceboundary, exact12/13limit and10000cycles. Main integration remains Root21. This helper does not validate trusted event origin or grant damage authority.
