# Threat30 integration handoff

Scope is the three new native helpers plus 15 exact hunks. `apply30.apply_to(project)`
expects the caller's scheduler write lease. CLI obtains its own. It preserves peer
population/lifecycle/healFX hunks; it never copies complete daily/population files.
Population30 query and wake API must be applied first. Enable `--city-threat30=1`
and `--city-physical-dispatch30=1`; local avoidance uses its existing flag.

Perception distinguishes visible gun, aimed-at, nearby shot and confirmed accepted
health hit. It retains the existing ordinary/unarmed role scope and yields to
medical, incapacity and active retaliation. The daily controller preserves physical
service exits, then follows genuine bounded A-star/capsule routes. Fear speed is
ordinary speed times exactly 1.10, without changing the baseline. Current simple
daily routes use 1.8 m/s, hence 1.98 m/s. Legacy uses the individual's record speed.
Fresh observations extend a 15-second quiet deadline; replay cannot extend it.
Normal decisions resume on timeout.

The world senses at 10 Hz, uses at most one aim ray and two extra LOS rays per tick,
population30 bounded spatial queries, and at most 16 queued shot observations per
tick. The queue is capped at 128 with 4-second expiry and coalesces each witness's
same incident burst. Issued observations are indexed per current owner and kind,
bounded at 2048; other ledgers are capped at 256. Death/dispose clears routes and
owned phone props. There is no all-roster fallback.

Phone uses the existing sole skeleton writer with a dedicated ear pose. Completion
requires actual retreat >=2m and >=8 committed visible pose frames. At most two
calls globally can run, with one call per incident. The optional scene metadata
`npc_police_report30` is a Callable receiving `native_police_report30/v1`. With no
port, the report is retained as `dispatch_unavailable`; police arrival stays false.
The user deferred police behavior. No police dispatch is delivered by this package.

Report fields: report_id, incident_id, kind, witness_source_id,
witness_generation, witness_session_id, witness_body_id, observed_scene_instance_id,
accepted_time_ms (world active clock), source_identified, weapon_id,
crime_position (Vector3 only if identified, otherwise null), retreat_m,
committed_phone_frames, call_completed. Only an external port's accepted response
with a nonempty case_id can become accepted. Hearing does not invent a criminal
position or player identity.

Native component01 passed real wall LOS/FOV, A-star/capsule detour, observed speed
1.8000126 versus 1.9800170 m/s (ratio 1.1000017), repeated threat extending recovery
to 22.0167s, stale replay rejection, ordinary following route and zero retained jobs.
Its source snapshot is archived under its run folder. This test uses controlled
observation/life ports: it is not proof of real city weapon/health/phone/agenda.
Final component04 PASS 17/17, exit0, stderr0. It rechecks final bounded changes plus low-HP admission and burst ledger.
See its scheduler and assertion receipts; a run is only accepted when both pass.

Remaining coherent55 city acceptance: visible gun / actual aimed-at / genuine
inventory shot and hit; actual phone pose + report; physical service exit; low-HP
hospital override; fear -> 15 quiet -> completed normal activity. Also validate
200+ source roster with the population owner's measurements. No full-city/perf
acceptance is claimed by this proposal.

Historical failed component02/parse02/component03 are preserved. A duplicate local declaration
introduced during editing was corrected before component03; a typed Array fixture assignment was corrected before component04. No production/shared
file or existing accepted release was modified.
