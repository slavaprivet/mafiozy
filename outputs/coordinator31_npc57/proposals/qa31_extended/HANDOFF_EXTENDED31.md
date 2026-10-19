# Extended release57 functional result

The native 1200-second run failed: resident2 remained OUTBOUND/opening for
865.507 seconds and resident8 remained PORTAL_WAIT_IN for810.235 seconds.
Exact1130 release57 pins, control and harness stayed unchanged; stderr is empty.
All ten residents moved at some time, but continuous liveness failed. The run
observed111 complete start/enter/pay/physical-exit shop cycles and475 walks.
It does not accept graphical performance while the user game is open.

Read EXTENDED_RESULT31.json and runs/release57_1200_01. The immutable raw files
include RUN.json, SOAK31.json, MASS30.json, SLOW_PLANNER31.json and HARNESS.zip.
CYCLES31.json matches receipts/exits to frames. VENUE_1511023256169_TRACE.json
preserves per-ID histories of the affected venue's participants.

TEMPORAL_AUDIT31.json explains the extra insufficient_soak_samples failure:
1196 one-second snapshots cover0.085..1199.821s, with accumulated render-frame
quantization. The per-render timeline covers exactly1200s and71999 physics ticks.
Native1200.711s finalization includes serialization. Raw failures are preserved;
motion10s and queue30s gates are unchanged. Future sampler cadence can be fixed
in a new harness, never retrospectively in these receipts.

Subsequent read-only log analysis found the actual last door event at frame23062:
SHOP-002 opening fraction0.692 was blocked by npc_resident_9. Resident9 continues
roaming in the leaf arc until terminal. New diagnostics/fix belong only to
../door_opening31. The existing release, F5, Git and evidence remain unchanged.
