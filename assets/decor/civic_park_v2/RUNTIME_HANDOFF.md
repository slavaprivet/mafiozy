# Civic Park v2 runtime handoff

Status: EXECUTABLE_RUNTIME_TESTED / HOST_BRIDGE_PRESENT / LIVE_VISUAL_GATE_REQUIRED.

The approved 30 placements now have an executable optional installer in
`runtime.v1.js`, loaded from `three_preview.js` after `fullMaterialsReady`.
This is not a claim that the live game has accepted the placements.

The coordinator has now added the import map and gameplay bridge in world.html.
The user explicitly authorized integrating this approved civic kit into the
game and pushing verified work to main. The earlier inferred
`internal_project_staging_only` wording is a development activation policy;
it is not a newly discovered legal prohibition on that authorized game work.
The two transit shelters were moved after live QA found their initial sites
too close to a bank/business. Stable placement IDs are retained:
`DEC-SHELTER-DOWNTOWN` now uses r37,c8.9,yaw90 on the east edge of the old
neighbourhood park; `DEC-SHELTER-INDUSTRIAL` uses r35,c6.5,yaw0 on its north
edge. Both now belong to northside. The two approaches flank the kiosk at
r37,c7 and their full clearances remain disjoint from the kiosk and all other
28 objects. Generator, placement/focus JSON and registry hash references were
rebuilt together. All GLB files and source evidence are unchanged.

After the user's live feedback that the objects appeared too small, every
placement now declares `uniformScale`: district and park fountains 1.30,
central fountain 1.22, furniture 1.15, signs 1.0. The requested central 1.35
intersected both benches, the bicycle rack and a light clearance; even 1.25
intersected the scaled bicycle rack by 0.033 grid cells. 1.22 preserves every
accepted coordinate and gives a clean clearance gap. Meshes and actual
registered collision proxies use the same uniform transform.

Current pinned hashes:
- registry.v1.json (24361 bytes): `6d00520c407a61ae3174f6e4e54d393e1c5050f53df9ecc1bae55a6a9fe17c6d`
- placement.candidate.v1.json: `cb8bb5f19991dd5e2e6222aaf3218f39d5466c675ead387309ff0ceca6995639`

The preview server serves JS/JSON/GLB from `/assets/decor/civic_park_v2/` with
contained paths, correct MIME, no-store and nosniff. Restart the existing local
server to activate that route.

## Host requirements (world.html owner: coordinator)

- Before module scripts, import-map bare `three` to
  `https://cdn.jsdelivr.net/npm/three@0.180.0/build/three.module.js`.
  The host imports the unbundled matching GLTFLoader and injects it alongside
  the exact host THREE; a second Three copy is rejected.
- `bridge.getCityV3DecorHost()` returns `{mapRows:200,mapCols:180,
  worldUnitsPerGridCellM:4.1,classifySurface(r,c)}`. Surface checks run both before
  GLB fetching and immediately before activation. `unknown`, `road`, `water`,
  `building`, `rail`, `door`, `protected` reject the entire transaction. Classify
  against the actual current map, dynamic bodies and legacy prop clearances.
- `bridge.registerCityV3DecorCollisions(owner,bodies)` returns `{ok:true}` only
  when all 30 bodies are active. Each body is `{id,minR,maxR,minC,maxC}` extracted
  from actual GLB collision proxy geometry after socket/yaw/world transforms.
  Bodies must block foot/car routes and moving bodies as appropriate.
- `bridge.unregisterCityV3DecorCollisions(owner)` is idempotent and removes even
  a partially failed registration. Owner is `CITY_V3_CIVIC_PARK_V2_ROOT`.
- `bridge.previewApproachCityV3Decor({r,c,id})` safely approaches a requested
  placement and returns `{ok:true}`. Focus must not spawn inside the fountain.

No edits to world.html were made by the civic integration worker.

## Runtime behavior

All selected GLBs across LOD0/1/2 load with byte/hash validation and max three
concurrent loaders. Fetch and parse are cancellable; asset deadline is 20 s.
The city stays playable during loading. All 30 objects attach under one root
only after live preflight; collision-registration failure removes that root and
unregisters the owner. Page exit/renderer removal aborts loading and disposes it.

Distance LOD uses <22 m / <55 m / >=55 m, with 190 m object culling. The three
fountains animate their named water surfaces at deterministic 30 Hz, amplitude
0.018 m. Only three authored pedestrian-light objects exist; zero additional
GPU PointLights. The runtime never suppresses legacy objects or changes tiles.

Separately, the coordinator implements a user-authorized, preview-only map
preparation step: clear four bounded lots (r14,c34; r24,c64; r74,c14; r34,c4)
and four sign cells. That step is outside the atomic asset transaction. If GLB
loading fails, the prepared land remains a walkable park for that preview;
reloading without the decor flag regenerates the original map. Do not describe
asset rollback as restoration of those separately prepared map cells.

## Verification completed

- After the visual-size change: 23 Python tests PASS (13 static, 2 server,
  8 gameplay). Full scaled clearances remain disjoint across all 30 placements
  and off forbidden surfaces. The actual GLB transaction test additionally
  removes each item's scale temporarily, measures its true collision proxy,
  and verifies the registered body's width/depth grew by exactly uniformScale.

- After both shelter relocations:
  `python -m unittest -q test_city_v3_civic_park_decor_static.py test_city_v3_civic_park_decor_server.py test_city_v3_decor_gameplay.py`
  — 22 PASS (12 static, 2 server, 8 gameplay). Includes pairwise SAT of full
  clearances across all 30 placements and new exact-anchor shelter regression.
  The actual-GLB Node transaction suite also re-passed with 30 objects/30 bodies.

- `python -m unittest -v test_city_v3_decor_gameplay.py`: eight executable
  regressions run the actual extracted world functions with synthetic map,
  props and HQ data. The coordinator corrected the early bridge passability
  override in pedestrian/car/service collision entry points. The other checks
  cover atomic invalid-body rejection, occupied-player rejection, immutable
  registration copies, explicit gate, safe focus footprint and bootstrap TDZ.

- `python -m unittest -q test_city_v3_civic_park_decor_server.py test_city_v3_civic_park_decor_static.py`: 13 PASS (Python 3.14 has aiohttp; py -3.11 does not).
- `node --check three_preview.js`: PASS.
- Install Three r180 into a temporary dependency directory, then run
  `node assets/decor/civic_park_v2/test_runtime.mjs <temporary dependency directory>`.
  Verified with `%TEMP%/mafiozi-civic-decor-runtime-qa`: PASS using actual pinned
  GLBs and actual Three/GLTFLoader. 30 objects / 30 collision bodies. Tests cover
  socket/yaw/world transforms, LOD switching, water animation, culling,
  idempotent rollback, unknown surface rejection before GLB fetching,
  partial-registration exception rollback, cancellation and tampered GLB.

## One-tab live gates still required

Use current staging URL plus `cityv3decor=1` and
`cityv3decorfocus=DEC-FNT-CENTRAL-01`, then NORTH-01 and RICH-01 variants with
the full `DEC-FNT-` prefix. Verify all three fountains, day/night material style,
pedestrian approach, collision response, no legacy-tree/furniture overlaps,
station/door/driving clearance, and before/after FPS. Inspect
`cityV3DecorLoader`, `cityV3DecorActivation`, `cityV3DecorObjects`,
`cityV3DecorCollisions`, `cityV3DecorFocus`, `cityV3DecorNearbyObjects`,
`cityV3DecorLods` on document/canvas datasets.

No browser or server was opened by this worker. No commit/push performed.
