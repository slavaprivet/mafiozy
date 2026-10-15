# services_city56 — prepared services acceptance in batches of10

Status: **NATIVE BASELINE FOUND EXIT DEFECT; FIXED CITY RUN PENDING**.
actual10_01 completed hospital and restaurant, while bank exit stalled.
actual10_diag02 reproduced a sideways loop at one intermediate shop waypoint;
that exact owned diagnostic was stopped after evidence capture. Exit fix and
native component evidence: `exit_patch56/HANDOFF_EXIT56.md`. Latest user direction: batches10→20→30; default10,
full287 is rejected before launch. Python/evidence CPU checks: 30 PASS; independent
native evidence evaluator: 37 predicates. These CPU checks use marked synthetic report
data and are not service, visual, or performance acceptance.

## Run after root's perf and final source merge/import

From the workspace root:

```powershell
python -B outputs/coordinator30_npc54/proposals/services_city56/run_services56.py actual10_fixed03 --project outputs/coordinator30_npc54/game --residents 10 --seconds 420 --go
```

`--flags-json <array-or-ASSEMBLY.json>` accepts the final candidate launch flags.
Without that option it preserves frozen55's ordinary flags, including
`city-pose-far-cap=512`, matching root perf10. No sandbox RNG seed is added. The requested batch takes the first N original packet identities.
Physics dispatch, health, threats, staff, sites, and normal decisions remain on.
`--mode graphical` is available for a separately coordinated graphical run;
neither mode claims visual/performance acceptance. Without `--go`, the command
prints the exact prepared launch and hashes and starts no engine.

Only a read lease is taken for the selected `--project`. No import, project copy,
runtime patch, or shared/frozen file edit is performed. Engine and scheduler
hashes are verified. Project sources and harness are pinned before/after. The
registered exact child has a watchdog of 120s startup + selected service duration (180–420s) + 15s margin.
Only that child is terminated on script error or timeout. No automatic retry and no automatic increase of batch size. `--residents 287`
is rejected by both runner and native observer. Other accepted counts are multiples
of10 through280, only when explicitly selected for a later coordinated run.

## Four current original residents

The observer waits for the first requested N source IDs from `session_packet.json` (default10), all N
daily/health owners, and 12 real staff actors. Original IDs/counts and staff are
rechecked each second. It chooses four distinct living full-HP originals within that exact batch, nearest
real existing staffed venue outside points. It does not move NPCs, construct
venues, disable movement, replace routes, write HP, choose a pending purchase,
consume/change the owner's RNG, or call a settlement/arrival method.

1. Hospital: one QA **player-only** placement at physically supported clear ground
   6–10m from the selected resident. Actual viewport aim/fire, accepted TT shots,
   owned native projectile hits and two current-generation 24HP receipts must
   prove 60→36→12. The second shot waits for the real health stagger to end. Then
   the gun is stowed and the camera looks away/up. Hospital need, service, actual
   treatment receipt, HP60, outbound route, physical exit and released claims are
   observed through production owners.
2. Restaurant: choose a suitable resident whose next ordinary food RNG result
   is restaurant (prediction uses an independent cloned RNG state). Seed only
   initial energy19. The regular need branch creates the purchase and route.
   Require real cashier, 2s dwell, debit receipt, energy restoration and exit.
3. Bank: choose a resting/idle suitable resident; seed only wallet cash0, adjust
   the local conservation baseline, append `qa_initial_wallet56` setup receipt.
   The normal account need starts travel. Require real bank service, 2s dwell,
   authoritative receipt and physical exit.
4. Shop: same energy19 procedure as restaurant, selecting the normal shop food
   choice. Require actual cashier, purchase/debit, energy restoration and exit.

The two energy changes and one wallet change are explicitly journalled as QA
initial state, never service receipts. The player placement is recorded with
before/after, floor/capsule verification, count1 and NPC relocations0.

**Bank limitation:** current production simple-hospital policy is
`local_bank_grant28`, cash0→1000, `own_bank_debit=false`. This harness verifies
that real physical staff service and does not label it a withdrawal from the
resident's personal bank balance. Implementing different bank semantics is out
of this harness-only scope.

## Evidence and bounds

The 420s bound is justified by actual10_01: Shop10 physically travelled 424m
and was still about14m from its doorway at240s. It is not permission to ignore
an exit stall. Driver waypoints, door target, avoidance and replan reasons are
now recorded read-only once per second for selected unfinished cases.

`SERVICES56.json`: composition, exact selected source/generation/body IDs, nearest
venue addresses/coordinates, initial-state journal, actual shot/terminal/health
chain, native service ownership at counter distance≤.42m, staff/customer identity,
route phases/entry/outbound, conserved money receipt, HP/energy delta, physical
outside depth<−1.1m and distance≤.42m, on-floor exit and selected claims released.
Selected body continuity is checked each physics frame. First completed service
is frozen in the report while that resident continues ordinary production work.
Other residents' claims may legitimately remain active; global empty queues are
not required. Once per second the unchanged stalls56 classifier records all batch residents' real
phases/completions, physics dispatch, plus city movement. Four detailed cases are
the only per-frame reads; global scans and output are bounded. Measured observer
cost is reported, never folded into a performance claim.

`RUN.json`: independent 37-check evaluation, process exit/stderr/errors,
source/harness drift and exact command. `SOURCE*.json`, `HARNESS_PINS.json` and
`HARNESS_SOURCES.zip` preserve reproducibility without full project clones.

The nearest resident is not a promise of a navigable unobstructed route. Real
queues, threat interruption, unavailable route, failed shooting view, or service
timeout produce an honest failed/incomplete result with phase evidence. Native
syntax and behavior remain to be verified in the coordinated first run.

Provenance: injury30's authentic mouse/shot/terminal pipeline, final_qa30's real
staff/service evidence, and stalls56's unchanged phase classifier. Models, police
behavior, shared game and frozen releases were not changed.

The source/measurement cadence diagnosis is preserved in `CADENCE_REVIEW56.md`.
It explains the four-physics-steps-per-process-frame multiplier without claiming
that a catch-up cap alone restores real-time simulation. The full city287 is not
launched by this package.
