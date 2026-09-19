# NPC perception and civilian reports — 2026-09-12

Owner: Artist16 perception subagent, source world sections only. Root owns live acceptance and native LOS geometry. Existing source NPC objects/IDs, roles, routes, server combat, boss individuality and police custody remain in place.

## Behavior

- `_npcCanSeePoint` uses a 140-degree field of view, configured distance, and LOS before recognizing a crime, victim, suspect, corpse, crash or remembered hostile player. Very close physical contact still requires LOS. Indoor/local-coordinate and seated civilian snapshots cannot masquerade as outdoor eyewitnesses.
- The helper calls `registerWalkNpcPerceptionResolver` callback (`fromR/C`, `toR/C`, `eyeHeight:1.45`, `targetHeight:1.1`). A `{blocked:boolean}` result is authoritative for native visual geometry; otherwise existing world tile LOS is used. Root supplies and measures the geometry adapter.
- Shot/fire hearing is radial; walls reduce range to 45%. A hearing-only caller reports `heard_gunfire`, never claims to recognize the shooter. Existing automatic fire event throttle remains. Visual observers remain separate from hearing panic.
- An armed player is observed for 1.6 seconds, then a civilian retreats through the existing collision-safe panic route and calls. Lost sight resets exposure. One actor has a 60-second weapon report cooldown; completed reports have a 30-second general cooldown; at most two calls active. Armed guards/police/boss/gang roles are excluded from this civilian branch.
- New witnesses move at least 0.65 source tiles and reach 2.5 tiles from the remembered threat before starting the actual phone timer. A blocked escape falls back to an in-place call after 3.5 seconds, without snapping position. Existing finite call timer, interruption and offline retry logic remains. Panic/social/helper/recovery are the original source state machine.
- A free nearby city patrol receives an observation target only. `_npcUpdateSuspicionCop` uses the existing collision-aware police mover, walks to the remembered location, observes for 5.5 seconds and returns to patrol (60-second overall timeout). Custody, prison, murder crew, pursuit and actual crime preempt suspicion. No invented murder, damage, wanted or omniscient player tracking.

## Typed report / authority

`civilian_report` is a new authenticated WS request handled just before `open_fire` in `mafiozi_bot.py`. `civilian_suspicion.py` validates the connection's own server player context, finite positions, bounded ranges, report type, resident-ID syntax, nonce, cooldown, current weapon and recent server shot for hearing. No target UID, damage or wanted is accepted. Only that connection receives the exact nonce `civilian_report_reply`.

**Current server has no civilian registry.** ID syntax is validated on server, while exact live object identity is checked in source. The ACK explicitly returns `witness_verified:false`; this is a low-trust request for observation, never evidence granting wanted/damage. A holstered weapon at report time or no recent server shot can cause rejection rather than inventing past authoritative facts. A full observation-time server registry is a separate extension.

Client source only completes the typed call after matching its exact pending nonce and live capable caller. Stale/interrupted ACK does not complete a call. It uses the original submitted coordinates, not arbitrary response coordinates. Disconnected non-preview stays pending. Static local preview dispatches observation locally with `npcWitnessReport=local-preview:observation-only`; it does not pretend to send or receive a server packet.

Legacy actual-crime `open_fire` witness contracts are unchanged. Murder response still dispatches independently of completed phone calls. This change does not remove the preexisting server police radius-based observation checks; police owner must review those separately.

## Checks

PASS:
- `node test_npc_perception.mjs`: front/back/FOV/distance/wall/native adapter, hearing attenuation, role exclusion, weapon exposure/lost sight, retreat/blocked timeout, finite/blocked reports, no false `open_fire`, cooldown and two-caller limit.
- `node test_npc_suspicion_dispatch.mjs`: typed ACK, exact object/nonce, local preview, patrol eligibility, existing collision mover, observation/recovery, actual-crime preemption.
- `python test_civilian_suspicion.py`: self context, invalid/NaN/infinite/out-of-range input, nonce/cooldown, no arbitrary targets, dead/jail/unarmed, no wanted/HP mutation.
- `node test_npc_witness_reactions.mjs`, `node test_murder_witness_observation.mjs` (fixtures now face their event, include retreat before phone).
- `python test_npc_life_system.py`, `python test_police_foot_navigation.py` (12 arrivals, 0 overlap), `python test_police_murder_custody_transport.py`.
- `python -m py_compile civilian_suspicion.py mafiozi_bot.py`.

CPU microbenchmark (72 actors, 2000 visual scans, same VM with stub LOS; **not loaded-game FPS**): previous radius/LOS p50 0.0142 ms, p95 0.0238 ms, 72 LOS/event; FOV/native-adapter gate p50 0.0426 ms, p95 0.0667 ms, 31 LOS/event. Cheap gates add ~0.03 ms/event while avoiding 57% of expensive geometry LOS candidates. Armed sensing is inside existing rotating 18-actor/250 ms life tick, not all actor pairs each frame. New server validation p50 0.0037 ms, p95 0.0039 ms per report (2000 iterations).

**Производительность общей сцены не проверена.** No GPU/browser instance launched by subagent. Root live acceptance: observe front-facing civilian on dry accessible sidewalk; draw weapon for >1.6 seconds, watch retreat → phone → patrol observation → recovery; repeat behind wall/behind actor; fire behind wall in close/far audible radii; interrupt caller, verify no false completion; verify police existing arrest/murder behavior still owns its actors. Shared authenticated backend must restart to load the new handler; static monitor18538 is not this backend.

## Follow-up: police discovery and server observer proof

Root requested a bounded police review after the civilian work. `test_police_perception_discovery.mjs` first failed against the actual `_alertNearbyCops` function: an officer behind a wall sent a witness report. The fixed source now requires FOV/native LOS for a new identification. Hearing-only gunfire assigns a remembered inspection location without identifying the shooter. `_copInRadius` uses actual x/y, no longer tx/ty waypoints. Visible bank-bag discovery shares the same visual gate.

Generic patrol pursuit obtains `_policePursuitTarget`: visible contact renews seven-second location memory; lost sight pursues that saved location instead of tracking the invisible player's current coordinates. Existing direct attack/owned pursuit is adopted, while arrest/custody/prison/murder response retain their branches. Shooting/arrest requires the target to remain visible. A patrol also observes an exposed weapon for 1.2 seconds (check every 400 ms), then inspects without granting wanted or firing.

Native eye/target heights now use source stance: prone/downed .35, crouch .8; a swimming/escaping observer uses sampled water depth plus .18 above ground; standing observer1.45 and standing target1.1. Root geometry callback receives these explicit heights.

Physical navigation: police main mover already used full-body segment validation and bounded cardinal routes. The small .01 fallback previously checked only the destination and omitted walking state; it now validates the swept segment and marks actual movement. Existing foot-navigation harness still passes 12 arrivals, zero overlaps; custody harness still passes. This does not claim all server cop movement is migrated to native collision geometry.

Server follow-up requested by root: `test_server_police_perception.py` first failed the actual extracted `open_fire` cop_sees assignment against a test wall. New `_world_observer_sees` reads accepted server x/y/ang, distance, 140-degree FOV and existing `_world_los`, rejecting dead/jailed/cuffed/interior observers. `cop_sees` and `player_sees` no longer mean simple proximity and do not read client witness flags. No pursuit, direct attack, HP or wanted transition was removed.

**Authority limit remains explicit:** `_world_los` uses the legacy server tile formula. Native GLB/terrain/vertical occlusion is unavailable on server. The separate historical `witness_npc`, `civilian`, near-station branches in `has_witness` were intentionally preserved; a complete authoritative civilian registry would be required to replace their trust boundary without deleting existing phone/report mechanics. Thus verified server FOV/legacy LOS is not a claim of full native authenticated visibility.

Server CPU, 72 observer checks/event, 1000 samples: radius-only p50 .0201 ms / p95 .0263 ms; FOV + actual legacy LOS helper with test wall p50 .159 ms / p95 .1907 ms. Event-driven cost increase ~.14 ms; no per-frame server scan added. This is CPU microbenchmark only. No backend restart or additional GPU scene was performed.

Further PASS: `test_police_perception_discovery.mjs`, `test_server_police_perception.py`, `test_npc_suspicion_dispatch.mjs` (now also stale previous-call ACK on same actor), repeated existing perception/witness/murder/nav/custody suites, server syntax compilation. Root still owns loaded-scene and authenticated backend acceptance.
