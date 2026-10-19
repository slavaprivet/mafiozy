# Customer visit + lease23 — isolated actual-world proposal, NOT APPLIED

Apply only AFTER accepted employee world proposal. This addon changes proposed
world/bridge hooks, no shared runtime edits. Four hashes in adjacent JSON.
Import createServiceVisitLease23/createServiceExitMovement23 on Walk side only
after root supplies current camera/geometry/body guards; no activation call here.

Source native entry/entryAlignment/returnPoint remain authoritative. Upon REAL
inside arrival, registered service visitor waits at most3s for a single service
lease. No browsing/order is created at entrance. Lease binds source object,
unique customer ID/generation, visit object+ID, station/site revision and clock.
Current NPC presence, HP, control and site are checked; TTL20s renewed by active
approach. Missing actor, stale identity/visit/site/clock or existing holder deny.
Normal existing building capacity remains separate and is released by original
native exit/abort pipeline. A second customer may wait and leave without paying.

Certified points are actual lane-adjusted entrance -> lane-adjusted customerVia
-> counter. Source input coordinates are preserved: no global door.inside changes.
Full GLB cycle exposed open public leaf corner not present in closed-door isolated
checks. Preserve entry lane offset until clear of leaf and use .01m corner arrival
for customer route; capsule remains .18sourcecell/.738m. Reverse follows counter
-> Via -> actual inside -> lane-aligned outside -> original returnPoint.

At counter source Arrive/Tick are the sole debit/stock writer. Cancellation and
unpaid provider loss cause physical reverse; paid orders never replay. Independent
source exit ownership survives termination of the service lease: it checks current
source actor/visit/generation, current geometry/site, exact certified route points,
floor and sweep. It cannot authorize purchases or continue approach. This avoids
stranding a customer at counter when provider unregisters. Source geometry host
must remain until outstanding exits finish; teardown before exit uses existing
safe recovery instead of allowing stale geometry. Source installation exposes
advanceServiceExit capability separately from merchant provider registration.

Pre-loop employee tick(now,0) refreshes service lifecycle BEFORE customer checkout;
existing post-loop tick(dt) performs movement after NPC priority logic. This fixes
fresh-source clock mismatch (after-loop alone always showed previous tick at sale).
World helper validates route certificate and registration every approach tick.
Public-door outside alignment is preserved on reverse and on waiter timeout.

Actual test_npc_service_customer_world23_candidate.mjs PASS:
- real spawnNpc bodies, actual native enter/visit/reservation/checkout/source hooks;
- actual printshop GLB, public and service door, floor and full source capsules;
- normal sale+reverse and mid-approach cancel+reverse at15/3Hz (4 cycles);
- two concurrent real source visits7Hz: one checkout, other waits/exits unpaid;
- provider removed BEFORE payment7Hz: reverse under source exit ownership, no debit,
  original returnPoint reached and capacity/service lease released;
- no root teleport; original shared door metadata and returnPoint unchanged.

Camera spawn invisibility remains injected, not observed. Fixture uses current
A7 vehicle surface helpers, one scene/static city; full moving city/player/body
collision host and renderer/FPS remain root's acceptance. Source employee source
binding independent ACCEPT is separate. Remote employee post-panic entrance return
is still pending; do not call whole pilot ready or active.

Host contract: validateLayout/isCurrentSite/entranceInside/validateRoute, now,
identity/currentVisit/isPresent, employeeReady, canControl, canSweep/isStationFloor.
Exit host shares source identity/control and CURRENT geometry independently of
service lease. disposeServiceVisits invalidates lease on provider teardown, while
source exit callback remains until visits have physically left. No online bank,
hospital executor or service handoff gestures are implemented by this addon.

Review corrections: acquired visitId is immutable and checked on every authority query. Current canControl also gates valid/touch/ownsServiceSlot, including checkout already at counter. Immutable route certificate is privately bound by WeakMap to the original source actor/visit/acquired ID; separate exit can return that original visit after revocation without transferring payment rights to a replacement ID. Eight actual-world scenarios PASS, including same-object ID mutation and loss of control at counter (80 cash unchanged, no receipts, physical reverse after authority resumes).
