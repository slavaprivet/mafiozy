# Civic / Park Decor Kit v2

Status: **standalone asset-local kit; MAIN is untouched; no placement is authorized.**

## Contents

The kit contains 18 types: three distinct fountains, a 4 m plaza tile, straight
and corner curb modules, round and rectangular planters, a civic bench, bin,
five-place bike rack, kiosk, transit shelter, three road/wayfinding signs, and
two low pedestrian lights. Every type has separate LOD0, LOD1 and LOD2 GLBs.
Three catalog GLBs exist for preview and validation only.

## Placement contract

All transforms are asset-local. Instantiate individual assets only at explicit
planner-authored civic, park, plaza, transit or roadside anchors. Never interpret
the catalog layout as map placement and never scatter these assets automatically.

Every asset exports `PLACEMENT_SOCKET_*` and `CLEARANCE_*`. Physical furniture,
curbs, fountains, signs, shelters and lights also export tagged `COLLISION_*`
proxy nodes. Fountain files additionally provide `WATER_SOCKET_*`,
`ANIMATED_SURFACE_*`, and bounded `WATER_JET_SOCKET_*` nodes.

## Runtime and QA

- LOD0: close/hero use, recommended to 22 m.
- LOD1: street gameplay, recommended 22–55 m.
- LOD2: district silhouette, recommended beyond 55 m.
- Runtime owns LOD selection and collision visibility.
- Materials are texture-free, matte, palette-locked smooth clay.
- Water animation uses the deterministic 30 Hz contract recorded in the asset JSON.

Use `civic_park_decor_kit_v2.asset.json` as the placement/LOD source of truth,
`civic_park_decor_kit_v2.validation.json` for reverse-import evidence, and
`civic_park_decor_kit_v2.sha256.json` for exact bytes and hashes.
