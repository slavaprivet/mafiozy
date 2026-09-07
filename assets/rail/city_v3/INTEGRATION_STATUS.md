# City V3 rail Stage A status

This directory is an opt-in, local-preview-only runtime slice. It is disabled
unless all of `preview=1`, `previewcityv3=stage-a`, and `cityv3rail=1` are
present on localhost. A failed byte, SHA-256, node, geometry, or world receipt
check leaves the rail layer inactive; a later startup failure rolls the world
and scene back together.

Pinned source package:

`C:\Users\Слава\Documents\Codex\2026-09-02\mafiozy-artist15\outputs\regional_train_and_track_tiles_v1_runtime_slice_v1`

Implemented and evidence-backed:

- one smooth-clay three-car GLB consist on the current MAIN-native closed
  south-coast route;
- eight candidate stops from the pinned binding, each with a runtime-owned
  64 m clear platform and visible -27.6 m / +27.6 m alignment marks;
- exact 0.4 s open + 3.2 s hold + 0.4 s close dwell;
- boarding and safe exit only through exported platform-side door pivots;
- exported three-body train collision, door-obstruction hold/reopen, route
  authority, and two road-gate interlocks;
- police/jail and the premium red suspension bridge remain untouched.

Still blocked, and deliberately not simulated:

- the eight stops are coastal MAIN-native development candidates, not approved
  one-per-district placements;
- no approved central-interchange transform exists;
- no connected authoritative depot edge/socket exists;
- `rail_station_tile_kit_v1` is not installed as a finished station set: its
  individual boarding lengths are 24/32/36/40/48 m, shorter than the 55.2 m
  consist, and it has no authoritative world/nav/collision binding.
