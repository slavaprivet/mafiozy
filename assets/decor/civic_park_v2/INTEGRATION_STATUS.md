# Civic / Park Decor v2 — static integration gate

Status: **READY_STATIC_RUNTIME_WIRE_REQUIRED**.

This directory is a verified, fail-closed staging package. It is not wired to
`world.html` or `three_preview.js`, does not alter map tiles, and does not place
anything in the live game yet.

## What is shipped

- 54 immutable runtime GLBs: 18 asset types with separate LOD0/LOD1/LOD2.
- No catalog GLBs. The source catalog arrangement is preview-only and must
  never be interpreted as map placement.
- `registry.v1.json`: byte/SHA-pinned asset registry.
- `registry.v1.js`: loader and preflight helpers. `THREE` and `GLTFLoader` must
  be injected by the host; the module never imports a second Three.js copy.
- `placement.candidate.v1.json`: 30 exact, non-overlapping, sparse candidate
  anchors with focus coordinates and atomic rollback requirements.
- `SOURCE_AUDIT.v1.json`: independent results for all 57 source GLBs, including
  the three catalog-only files that were audited but intentionally not shipped.

## Intended visual pilot

The three fountain anchors are deliberately separated:

- Northside neighbourhood green: `r=17, c=37`, district fountain.
- Downtown civic garden: `r=27, c=67`, central fountain.
- Rich-quarter sculpture garden: `r=77, c=17`, park fountain.

All three clearances remain inside deterministic park cells. Furniture is kept
at park edges. Only three pedestrian-light placements exist across the whole
30-object candidate, so this slice cannot recreate the current lamp spam.

Useful future focus queries:

- `cityv3decorfocus=DEC-FNT-NORTH-01`
- `cityv3decorfocus=DEC-FNT-CENTRAL-01`
- `cityv3decorfocus=DEC-FNT-RICH-01`

The full list is in `focusCoordinates` inside the placement contract.

## Required runtime wire

The coordinator's later atomic runtime integration must:

1. Require local Stage A query gates `preview=1`, `previewcityv3=stage-a`, and
   `cityv3decor=1`.
2. Reuse the host `THREE` and its matching `GLTFLoader`.
3. Load and hash-validate every selected GLB before attaching one scene root.
4. Re-run the live road/water/building/rail/door/protected-zone preflight.
5. Attach only `CITY_V3_CIVIC_PARK_V2_ROOT`; register collisions afterward.
6. On any error, remove that one root, dispose only package-owned resources,
   unregister its collision handles, and leave map/gameplay/legacy decor intact.
7. Pass day/night walking and driving QA before any commit or `main` rollout.

No legacy object suppression is authorized by this candidate.

## Verification

Run:

```powershell
py -3.11 -m unittest -v test_city_v3_civic_park_decor_static.py
```

Expected: 11 tests pass. The suite re-hashes every shipped GLB, parses GLB 2.0
structure, checks required sockets/collisions, independently counts triangles,
verifies strict LOD descent, runs continuous map-mask sampling and SAT checks,
and verifies rollback and light-density limits.

