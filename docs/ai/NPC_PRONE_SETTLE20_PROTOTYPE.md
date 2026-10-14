# Prone death settle20 — in-memory proof, not integrated

**Historical prototype. Superseded by production `NPC_PRONE_SETTLE20_HANDOFF.md`; the test with the historical prototype filename is now the combined-origin production regression.**

2026-09-20. Production vehicle entry and actor remain unchanged/released. `test_npc_prone_settle_prototype20.mjs` substitutes actor/helper text only in memory. `test_npc_prone_death_entry_audit20.mjs` records the still-unfixed production case.

## Why a different target is needed

Source-shaped medical downed/forcedCrawl → confirmed deathFromDowned has raw age0 correctly, but canonical back-fall presentation flips a belly-down body: current actual first step1.642–1.748m and visual pivot change1.574rad. Simply blending for0.28s to that target removes the first snap but still raises/rolls the body during the following frames.

The candidate holds the displayed belly-down orientation and current crawl phase, then applies small local head/neck/arm relaxation over0.45s. It keeps the resulting prone corpse pose permanently for that death epoch. Root/yaw do not change. Six fatal causes select small relaxation strengths; the blast renderer remains separate and may replace the intact body. This is a continuity proposal, not a claim of finished visual animation quality.

## Actual proof

28 cases: male/female × stationary/crawling × six causes+unknown. First step<5.6e-8m, visual pivot change0rad, largest subsequent60Hzstep0.001255m, head rise<0.010m, actual skinned floor error<2e-10m. State changes to dead immediately and raw age remains0. JSON recreation and5s cull retain the settled pose without resuming crawl gait.

Additional male/female checks pass: external lifecycle sync/save before first update; observation gaps1/5s reject stale inheritance; confirmed fatal receipt over custody/phone; nonfatal stun/knockdown unchanged; normal standing death unchanged; explicit alive/new epoch clears inherited prone pose. Settled candidate retains ground memo hits.

CPU steady corpse age0.8,20 warmups+30 samples: male p50/p950.726/0.840ms →0.727/0.821ms; female0.690/0.883ms →0.653/0.685ms. No scene FPS, GPU, or LIVE visual acceptance.

## Proposed integration, requires separate approval

- Extend entry metadata with explicit origin `vehicle` / `prone`; absent origin must mean legacy vehicle. Existing vehicle renderer, strict vehicle translation validation and0.28s expiry remain unchanged.
- Capture prone only when a living unblocked actor actually displays full authored prone posture (medical downed flag and posture value>=1.99999). No source age manipulation, HP inference or artificial moving flag.
- Keep one reused pose buffer; accepted death locks its origin. Vehicle origin blends to current renderer; prone origin renders the inherited belly-down pose plus relaxation and persists until epoch reset. Source deathProfile selection and settled ground memo remain authoritative.
- Add origin-specific translation validation, without loosening vehicle constraints. Actual source `hero_walk.mjs:posturePose` changes only pelvis translation at full prone: x=rest.x, y=.86-rest.z, z=rest.y-1.46. All other bone translations equal rest; scales remain positive and equal actual rest within1e-5. Both GLBs measure pelvis offset[0,+0.66,-1.26]. Candidate already validates this exact formula; it does not accept arbitrary wide P bounds.
- Preserve optional serialization, atomic validation, old saves, stale observation rejection and raw source clock contracts. Transitioning/partial prone is not covered by this narrow full-prone proposal.

The current test deliberately replaces the vehicle eligibility/renderer in its isolated module to test prone independently. It is NOT an integration diff to copy wholesale: production needs the explicit origin discriminator so vehicle behavior remains intact. Before integration, add combined vehicle/prone save-origin rejection coverage and a visual review of the small relaxation angles.
