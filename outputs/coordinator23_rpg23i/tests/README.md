# RPG23i actual-main acceptance preparation

NOT EXECUTED. Syntax checked only against candidate16; requires root frozen candidate17 gate/recipient integration. No shared/owner edits, no GPU.

`python outputs/coordinator23_rpg23i/tests/run_case.py --project ABS_CANDIDATE17_PROJECT --case floor --out ABS_FRESH_DIR`

Run cases sequentially: floor, wall, spread, range_end, cancel, context_dispose. Fresh actual main per case,25s internal/30s external bound. Exact critical staged input hashes before/after must match. Full3moving original NPC and8buildings,377original physics collision bodies retained. Original objects cannot be replaced with synthetic recipients. No HP, ammo or target-ticket injection.

Actual equip/input LMB makes accepted Fire shot, authoritative inventory spend, fresh presentation muzzle, actual native Flight and real closest-contact physics query. Harness wraps actual Flight impact callback only to record original receipt and current owners/context, then forwards unchanged ONCE. No positive callback is manually manufactured. Source yaw/pitch offsets are independently recomputed from emitted actual shot, camera target and muzzle; running case uses real movement InputMap. Genuine retired receipt replay/copy and unissued target capability must not change HP/life/physical/explosion state. Actual R reload must spend finite reserve.

Fixture uses original same camera reparented to scene and player placement at a traversable floor around actual NPC centroid. Existing floor and existing closest wall only; no new colliders or hidden actors. All3walking/physics stay scheduled. NPC radius and independent two-stage integer damage oracle use current native positions captured at true impact. Physical checks keep same16body15joint IDs and source medical/final-eyes policy. Range-end fires61.5m upward near original NPC and proves source horizontal blast semantics at highY.

Cancel retires real accepted token (trusted pool-eviction lifecycle test, not an invented UI cancel action). Context-disposal wraps existing current-damage-context provider, returning its exact value after disposal; this tests real gate callback reentrancy while actual Flight is retiring. These negative cases must leave HP/life unchanged. No claim that source blast physical severing/blood/self/player/vehicle/building/server features are implemented.

Needed current API: weapons.npc_rpg_gate (live); population.hit_owners exact3; gate.last_result/native_impact/_target_current/take_target; effects._flight._impact_port/slots; owner._row/_serial, physical owned bodies/joints/eyes. Root should announce stagefreeze before first run. Scope is behavior, not GPU appearance, FPS or ordinary-camera usability.
