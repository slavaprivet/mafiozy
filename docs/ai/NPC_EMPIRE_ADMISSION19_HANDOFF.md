# Empire admission under civilian load

20 September 2026, Artist19. Short follow-up to checkpoint7370157.

The native pending-slice fix retained each boss's frontier, but the empire
pump still stopped after a denied shared admission. With19 bosses and many
residents, an empire owner was only touched once per round through the boss
queue. The shared scheduler expires owners absent for more than one epoch;
bosses therefore lost their places before their next turn. LIVE showed all19
bosses at zero speed with200–280seconds of pending requests.

`_processEmpireRoutePlanQueue` now visits at most the queue length captured at
entry, skips owners already touched this source frame, and continues after a
denied shared admission. It returns after one actual search slice, preserving
the shared4ms/eight-admission limits and existing generation/cancel checks.

Validation: `test_empire_pending_slices19.mjs` runs the actual pump and shared
scheduler with180 residents and19 bosses. The previous pump completes0/19
within900frames; the patch completes19/19 while every resident gets service.
Existing route cohort, generation12cases, admission observability and stall
recovery12cases pass. Controlled test costs do not constitute scene FPS.

Loaded into the existing18538 browser alongside road-egress, body-probe-cache,
peaceful-activity elapsed and picking-profiler fixes. First warmed DOM sample
shows10/19bosses walking with nonempty advancing routes, compared with0/19
before. Remaining coastal/blocked positions still require collision and
placement work; this is not complete boss or living-city acceptance.

Independent issue: Leila at rounded LIVE24.95,23.49 has a clear centre but
water under rear footprint corners in the actual fixture. Old coarse BFS can
publish an edge rejected during movement. Separate agent audit is in progress;
neither actor teleport nor disabling water/body collision is included here.

The later LIVE sample showed all bosses pending again after initial movement.
The expanded regression reproduced this with long searches: preserving only
the denied-pump continuation was insufficient. While another boss consumes
the one expensive slice, active queued owners still missed their two-epoch
lease. Expiry now retains an owner only while both its explicit empire queue
flag and pending request exist; dead/cancelled/stale work still clears through
the existing pump. Long-job regression:0/19 before,19/19 after, all180residents
also served. This second fix requires the next reload; initial walking was
not sustained acceptance.
