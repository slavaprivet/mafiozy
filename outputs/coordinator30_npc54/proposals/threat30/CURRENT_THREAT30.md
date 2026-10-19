# Current threat delivery

Apply order, preserving the frozen initial package:

1. `MANIFEST30.json` / `apply30.py`: initial 15 hunks and three helpers.
2. `FIX_DISPOSE30.json`: dispose after weapon child exit without reading a null tree.
3. `FIX_META30.json`: no missing-metadata error when the threat flag is off.
4. `FIX_FAIR_PERCEPTION30.json`: dequeue only as many candidates as the LOS budget can examine.
5. `FIX_RAW_SHOTS30.json`: retain a native shot across spatial budget exhaustion.
6. `FIX_LOS_PENDING30.json`: retain far witnesses awaiting their actual LOS quota;
   share one ray result between visual/hearing decisions and tolerate float error
   at the 100ms sense boundary.

Root owns all production writes. The initial patch files and manifest remain frozen;
the small follow-up JSONs carry exact before/after contexts. Revision2 world after
raw-queue changes is SHA256 `e70ad35aa04edb57f99217dd181c8509d9e04c2fa864ce9202717d646a6f81ab`.
Revision3 including pending LOS is SHA256
`22ed08e2680343562dd0cc91c8441868e7acd7f06d876fe12cdfed55a4bc4fe3`.

Native evidence:

- `runs/component04`: 17 assertions, real A-star/capsule wall detour, 1.10 speed,
  15-second quiet recovery, replay rejection and medical priority. Controlled life
  and observation ports; genuine physical movement.
- `runs/component05`: same checks with weapons removed from tree before disposal;
  clean exit without tree errors.
- `runs/city02`: coherent production city, real viewport gun/aim/miss shot,
  7.72199m flee at max 1.980009m/s, 237 committed phone-pose frames, honest pending
  report, 15-second quiet recovery and completed production normal activity.
  Then real TT hit 60->36 with matching accepted shot, native terminal and HP
  receipt, classified `actual_hit`. All 11 assertions passed; scheduler exit0,
  stderr0, full source/harness drift0. Clear phone image remains to be captured;
  city02's player obscures the screenshot. `CITY_ACCEPTANCE30.json` pins evidence.
- `runs/raw01` and `runs/raw02`: 64 and 224 current ordinary witnesses receive one
  shot through the production spatial grid on real capsules, including after the
  first 0.45s exhausts the actual query budget. Both 11 assertions passed, clean
  native exit. Duplicate signal, role filters, stale captured generation, query
  bounds, TTL and cleanup verified. Signal and life/health wrappers are controlled
  fixture ports: this is not full-city FPS or 224 complete resident behaviors.
- `runs/raw_far02`: all 64 ordinary native capsules at 25m heard the same single
  fixture shot through genuine LOS rays after initial spatial-budget exhaustion.
  Maximum two LOS rays per sense tick, current generation/role guards, TTL and
  cleanup passed. `raw_far01` preserved the earlier float-boundary failure; the
  corrected fixed-rate boundary passed without increasing the ray cap.

The raw queue contains at most 8 incident jobs. Each preserves at most 512 owner
dedupe entries, expires four seconds after its last actual shot, queries at most
16 results/128 scan units per tick and uses the existing delivery/LOS caps. An
opaque empty query is retained until TTL, not treated as a completed scan. Repeated
automatic shots update the existing incident job. No new all-roster scan or NPC
movement authority was added.

Budget limitation: two LOS rays per 100ms and a four-second TTL can inspect roughly
80 distant witnesses per isolated shot, while nearby unoccluded-hearing witnesses
do not require a ray. The 224-actor hearing fixture uses close witnesses. This does
not claim all 224 distant witnesses in a dense ring can be examined within four
seconds. Raising that global cap requires an explicit performance measurement.

Still required after revision2 integration: repeat the actual city gun/phone cycle
against final pins. Service interruption during a real shop/restaurant visit has
not received a dedicated native run; the implementation uses the existing guarded
physical exit owners. Full population performance and final low-HP hospital cycle
belong to root/other owners. Police response was deferred by the user: no responder,
accepted case or arrival is claimed.

## User priority change — delivery first

Root relayed the user's explicit instruction to add the current work to their scene
now and investigate bugs/load later, then save main/GitHub. New city03/service/perf
runs are therefore deferred. This agent has no running engine, and will not launch
one against the user's newly opened scene. The prepared `run_city30.py city03
--graphical` uses the general lifecycle flag and a temporary observation camera for
one clear phone screenshot; it has not been executed. City02 remains the latest
full native gun/phone/recovery/actual-hit result, against its recorded earlier pins.
Raw revision2 and LOS revision3 have their separate native component proofs. They
must not be described as a full final-scene or full-population performance pass.
