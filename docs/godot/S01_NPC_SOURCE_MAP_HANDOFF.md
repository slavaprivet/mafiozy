# Actual source MAP handoff — 27 September 2026

**The full deterministic source `buildMap()` output is now available: 200 rows × 180 columns, 36,000 integer cells.** Two pristine executions of the actual source produce identical MAP and supporting state. This resolves the missing full grid for the explicitly selected **POST_BUILDMAP / BEFORE_NATIVE_RESOLVER** phase. It does not resolve NPC placement or authenticate an existing session.

Artifacts are in `outputs/coordinator21_npc_source_map/`:

- `MAP.post_buildMap.json`: plain `[row][column]` array, canonical compact JSON plus LF, SHA256 **`be566fd54e9afdd24e2150dd1b53498c1d00d0063b5b5f19a8ceba9fdbee59f4`**.
- `manifest.json`: source receipt, dimensions, tile counts, source slice hashes and explicit limits.
- `source_slices.json`: all 47 exact source statements/declarations/functions, original locations and SHA256. The 15 actual functions include the complete buildMap, race spline/tile generator, traffic portals, beach and district decor dependency chain.
- `source_supporting_state.json`: generated traffic portals, bank/gas tiles, park/HQ blocks, race tiles, beach decor and POI records; no NPC roster.
- `export_actual_build_map.mjs`: reproducer. Run `node outputs/coordinator21_npc_source_map/export_actual_build_map.mjs` from the repository root.

Source: `world.html`, SHA256 **`9f5cc5a1a80db37dbf3136ecab66c4cdba2bd679dbea03aa10800ac16d8a95b5`**. The reproducer refuses a different source SHA and also checks source bytes after execution. It extracts unchanged source code, compiles it and evaluates declarations in their original order. There are no fabricated map constants, gameplay stubs, passability callbacks, RNG or clock values. The only host adapter is a write-only DOM diagnostic sink for `document.documentElement.dataset.trafficEdgePortals`; an attempted read throws. No browser, GPU, game process or production file was changed.

## Source phase and admission

The first actual `buildMap()` call is at world.html:8046. Its dependencies are all source literals or deterministic math; no seed is required for MAP. Population initialization is scheduled later by `setTimeout(...,0)` at lines 25921–25927. The ordinary source `initNpcs` native branch marks rows `_npcInitialPlacementPending` when no native resolver is registered (line 12249). That supports a pending source stage; it does not authorize visible NPC placement.

This receipt deliberately precedes async editor overlays and native surface/collision registration. The studio loader chooses `/__studio_map` on localhost and `map_overrides.json` elsewhere, then applies `data.mapEdits` at lines 75877–75907. The tracked `map_overrides.json` has 11 tile edits and 107 decor rows; SHA256 `41490ae3a69668e14b10e52b67a0b144ca1b0fc28db7027e095152a046689532`. Its bytes alone do not prove what `/__studio_map` returned to a particular running session, nor the timing of overlay hydration. No override was silently applied or omitted from a claimed hydrated-world result: the chosen phase is explicitly before the overlay.

`topology_for_placement.json` is not a substitute for this source MAP. It is marked `pendingHostSnapshot:true` and differs from the actual post-buildMap result in **22,900 of 36,000 cells**. Its replacement-city placement role remains separate.

## Checks

Both independent VM contexts return identical complete grids, supporting arrays and diagnostic writes. Dimensions and every cell's integer type are checked. Source landmarks are checked directly: police building `[76][76] = 1`, dry jail compound within canal `[76][81] = 9`, canal `[20][90] = 16`, bridge `[50][90] = 19`. The actual race and beach implementations execute; they are not replaced with broad rectangles or always-false helpers.

| Tile | Count |
|---|---:|
| 0 | 12500 |
| 1 | 3189 |
| 2 | 280 |
| 3 | 67 |
| 4 | 39 |
| 6 | 31 |
| 7 | 353 |
| 8 | 428 |
| 9 | 5873 |
| 14 | 4350 |
| 15 | 80 |
| 16 | 7336 |
| 17 | 280 |
| 18 | 1014 |
| 19 | 180 |

## Remaining owner inputs

Artist21/root still own actual `npcPassable` answers, full native collision/surface providers, runtime prison/civic/building/decor/rail/vehicle states and the explicit new-session RNG algorithm/seed, source clock and session identity used by the NPC factory. This grid does not create those answers. Keep any before-resolver rows hidden/pending until the real placement owner admits them. Crop selection must follow complete source generation, without rerolls or moving actors merely to fill the preview quarter.

No residents, visible births, identities, server roster, appearance values or gameplay authority were fabricated here. CPU execution is an offline correctness check; no loaded-scene performance or LIVE acceptance is claimed.
