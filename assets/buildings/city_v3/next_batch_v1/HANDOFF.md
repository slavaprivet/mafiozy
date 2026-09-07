# City V3 next building slice — fail-closed handoff

Recommended next atomic visible slice: `gun_shop@1 + bookmaker@1 + strip_club@1`.
The three exact frozen accepted GLBs, source sidecars, local manifests, corrected
bindings and tests are bundled here. Runtime activation and legacy suppression
remain `false`; this package does not modify `world.html` or `three_preview.js`.

## Exact placement table

| Key | District | Center `r,c` | Footprint `minR..maxR / minC..maxC` | Exact legacy shell / door | Public anchor -> road | Authored service anchor -> road |
|---|---|---:|---|---|---|---|
| `gun_shop@1` | `southside` | `87.375, 17.750` | `86.425122..88.324878 / 16.344390..19.155610` | `legacy:procedural:80:10:85:15:89:19` / `door_85_15_0` | `88.121756,17.273171` -> `runtime:road-tile:90:17` | `87.138244,18.986439` -> `runtime:road-tile:87:20` |
| `bookmaker@1` | `industrial` | `47.750, 47.375`, yaw `90` | `46.364756..49.135244 / 46.344268..48.405732` | `legacy:procedural:40:40:45:45:49:49` / `door_45_45_0` | `48.330902,48.039244` -> `runtime:road-tile:48:50` | `46.465049,46.949585` -> `runtime:road-tile:43:46` |
| `strip_club@1` | `docklands` | `97.750, 150.750` | `96.744512..98.755488 / 149.595244..151.904756` | `legacy:procedural:90:150:95:150:99:153` / `door_95_150_0` | `98.535732,150.689878` -> `runtime:road-tile:100:150` | `97.084512,151.711537` -> east sidewalk `c153.5` -> `runtime:road-tile:100:153` |

These are procedural shell replacements, not fixed existing gameplay POIs:
`legacy.gameplay_poi` is intentionally `null`. Do not silently bind them to a
`BUSINESS_POIS` entry. Exact tile IDs, legacy door positions/facing, pad
rectangles, route segments and road probes are in `bindings.candidate.v1.json`.

## One-tab focus probes after integration

- Gun shop: `http://127.0.0.1:8081/preview/world.html?preview=1&direct=1&previewcityv3=stage-a&cityv3buildings=1&cityv3focus=gun_shop%401&force3d=1&render=3d`
- Bookmaker: `http://127.0.0.1:8081/preview/world.html?preview=1&direct=1&previewcityv3=stage-a&cityv3buildings=1&cityv3focus=bookmaker%401&force3d=1&render=3d`
- Strip club: `http://127.0.0.1:8081/preview/world.html?preview=1&direct=1&previewcityv3=stage-a&cityv3buildings=1&cityv3focus=strip_club%401&force3d=1&render=3d`

Use one existing browser tab and replace the URL between probes.

## All-10 disposition

| Addendum key | Disposition | Reason |
|---|---|---|
| `civic_hall` | `BLOCKED_ADDENDUM_MOVE` | Asset and reverse import pass, but current repository stages the same asset at a different location and its style gate is still `review_pending_candidate`; no silent move. |
| `public_school` | `BLOCKED` | Source sidecar says `art_review_pending` and `integration:not_authorized`. |
| `chop_shop` | `ART_WRAPPER_PASS_RUNTIME_BLOCKED` | Fresh wrapper is project-authored and hashed, but its copied socket/collision metadata assumes origin placement rather than the active recentering loader and has a synthetic rear-center service socket. |
| `print_shop` | `ALREADY_IN_EXPLICIT_PREVIEW_SLICE` | Current MAIN-native binding is authoritative; the all-10 row is a different duplicate proposal. |
| `hq` | `BLOCKED` | Accepted GLB exists, but no exact-hash source sidecar/generator plus exact public/service access contract was found for this addendum row. |
| `bookmaker` | `READY_STATIC` | Exact accepted art, rights provenance, corrected anchors/routes and static SAT pass. |
| `gun_shop` | `READY_STATIC` | Exact accepted art, rights provenance, corrected anchors/routes and static SAT pass. |
| `strip_club` | `READY_STATIC` | Exact accepted art, rights provenance, corrected anchors/routes including the safe L-shaped service path and static SAT pass. |
| `pawnshop` | `ALREADY_IN_EXPLICIT_PREVIEW_SLICE` | Current MAIN-native binding is authoritative; the all-10 row is a different duplicate proposal. |
| `poker_club` | `ART_WRAPPER_PASS_RUNTIME_BLOCKED` | Fresh wrapper is project-authored and hashed, but its copied socket/collision metadata assumes origin placement rather than the active recentering loader and its exact visible service-door route is not independently bound. |

The fresh five-wrapper package is preserved as a negative control, not copied
into this slice. Its own manifest records `snapshot_match_at_audit=false`.
`SOCKET_PUBLIC_DOOR.extras.anchor_rc` repeats the superseded origin-based
addendum values, and `SOCKET_SERVICE` is a generated rear-center socket rather
than the accepted art's visible service entrance.

| Wrapper | Public recenter error (cells) | Synthetic service -> visible service-door error (cells) |
|---|---:|---:|
| `gun_shop` | `0.162535` | `1.390942` |
| `bookmaker` | `0.225797` | `1.387257` |
| `strip_club` | `0.170580` | `0.995954` |
| `poker_club` | `0.065218` | `0.949564` |
| `chop_shop` | `0.096829` | `0.426637` |

The active loader tolerance is `0.015` cells and currently hard-accepts only
`pawnshop@1` and `print_shop@1`, so all five wrappers fail closed even though
their isolated art-package audit says PASS.

## Validation and apply rule

Run:

```powershell
python -B test_city_v3_next_building_batch.py -v
```

Prepared result: `11/11 PASS`. The suite verifies immutable hashes, accepted
release membership, project-authored/no-third-party provenance, exact GLB
service nodes, recentered anchors, every legacy tile and door, roads, water,
rail, streetlights, unaddressed buildings, gameplay anchors, police, the red
bridge, pairwise separation and non-overlap with the current pawn/print slice.

After the rail handoff settles, capture a fresh runtime snapshot and repeat the
SAT plus all three one-tab focus probes. Load all three visible meshes first.
Only after all three pass may the exact listed legacy structures, tiles and
doors be suppressed in one transaction. Any failure keeps all three legacy
shells and doors.
