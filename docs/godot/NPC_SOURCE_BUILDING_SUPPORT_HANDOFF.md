# Verified original building support and fast source cache

The component reproduces the original ordered support query for all 78 source entries (75 buildings and 3 detention entries). It preserves ramps, stairs, platforms, storeys, hospital and detention floors, exact scalar Float64 transforms, and original four-cell candidate ordering. It neither creates actors nor grants physical admission.

## Integration

Prefer `godot/mafiozi_walk/scripts/npc_visual/npc_source_building_support_cache.gd` (SHA `5e2c1df165c97e9824bcbf4ee2aa3ce93e2d7873f27eec794cd18f2c653e227e`). Instantiate it once and call `configure_cached(bytes)` with `outputs/astra21_npc_registered_building_native/BUILDING_SUPPORT.native.bin` (SHA `b024890f87a7713246aaaace5ba5a903dfb3bff2626fc525e776d354cf9885f3`). Check `ok` before publishing the provider. Cache deserialization disables Object construction and binds the exact source helper, source data, phase and Godot version `4.7.2-stable (official)`.

The inherited base helper is `godot/mafiozi_walk/scripts/npc_visual/npc_source_building_support.gd`, SHA `25fbaa80e9465f907e0768c68efe792867cbc72e48f1cb40dae5a7a2958f11c5`. Its raw `configure(data_bytes, value_bytes)` is retained for source verification. Raw source data SHA is `dd304db781ee18da12cb3111a3f8126b89658a2562dee38ccd9c2567c9a3ca15`; Float64 binary SHA is `1a05e2bd1d05ffb48634991c1047fc4c1e7fff873f4a0c1fa08d3cb4792a6b88`. Both complete files, original modules and pristine exporter evidence reside in `outputs/astra21_npc_registered_building_support`.

`floor_at(x,z,reference_y=0)` returns a tri-state dictionary with `known`, nullable scalar `value`, and the winning `entry_id` when present. `entry_floor(index,x,z,reference_y)` scopes the original query to one entry. `collision_collections()` returns private copied bodies for all 78 entries in source order (17,086 bodies). `invalidate(reason)` permanently faults future queries; the integration owner must invoke it when the actual session or door state no longer matches. Query coordinates and support heights are metres. Do not replace scalar transforms with engine vector transforms or collapse source divisions at spatial bucket boundaries.

## Actual verification

- Raw author: 213,140 checks PASS, including 106,564 original per-entry Float64/null cases and all colliders. Failed initial metadata assumptions remain preserved in historical logs.
- Independent raw review: 340,937 checks PASS, 113,639 original composite queries with exact values and winning source indices, including all 326 actors' five sample positions. Review `outputs/astra21_npc_registered_building_composite/HANDOFF.md`, SHA `542f1239d54b8a10d1dfe79e178463b1aba6bfddd39f5fd51e9d1af8b3c590bb`.
- Cache builder: 358,406 exact type/Float64 roundtrip checks PASS. Cache author: 220,222 source-query checks PASS.
- Independent cache review: 447,512 checks PASS, all per-entry and composite source cases, exact private entries/index/colliders, invalid bytes, copied snapshots and invalidation. Review `outputs/astra21_npc_registered_building_cache_review/HANDOFF.md`, SHA `4b0bebb044126e8c5222a895de28e7de82de7a81dfc2f041545862e3ff2804a5`. Final runs exit 0 with empty stderr. Source-helper-change rejection was inspected, not destructively exercised.

Paired same-process preparation benchmark (2 warmups, 7 samples, identical preloaded inputs): raw p50/p95 753,893/768,027 us; cache 82,239/87,928 us. Evidence `outputs/astra21_npc_registered_building_native/PAIRED_CACHE_CPU.json`. Native deserialization and source dependency hashing remain. Independent cache measurement including disk reads: p50/p95 86.365/94.021 ms (2 warmups, 10 samples). These are startup CPU measurements; they do not establish scene FPS or per-frame update cost.

## Limits and pending integration

The approved source phase is `OFFLINE_NEW_SESSION_SOURCE_REFRESH_INITIAL_DOORS_UPDATE_ZERO_BEFORE_NATIVE_REGISTRATION`. This is actual original initial-door source data, not a current LIVE door lease. Building support is only one part of original combined ground. Rail support is currently HOLD: independent boundary tests found 55 source null/number discrepancies in helper `0e69b4aa`; its correction and peer review must precede combined-ground acceptance. Complete registered collision/frame state still needs source mercenary gate/persistence and ordered physical/logical vehicle/current-train data. Missing data must remain UNKNOWN. NPC runtime remains OFF until the actual complete registered provider and all-326 placement are accepted by Root21. CPU/headless checks do not replace LIVE/fullsceneFPS.

Root21 owns main/host/player/export/current door and dynamic state integration. These helpers and cache do not change HP, progress, IDs, server authority, NPC births, GPU scene or Git. Existing source-ready delivery `9216e6a5` is historical and is not this new component packet.
