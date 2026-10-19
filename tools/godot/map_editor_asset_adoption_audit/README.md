# Catalog GLB adoption audit (source-only, 30 September 2026)

No files were copied or imported. This is a read-only SHA-256/byte-size comparison of [catalog.json](../../../godot/mafiozi_walk/data/map_editor/catalog.json) against the current `godot/mafiozi_walk/assets` tree. [manifest.json](manifest.json) is the deterministic complete inventory: all 196 SHA IDs, expected byte sizes, 201 source paths, 188 exact missing IDs, production matches and 13 source-dependency receipts. [audit.mjs](audit.mjs) can regenerate it read-only; re-audit after any asset change.

- Source: **196/196 GLBs** match expected SHA and size; GLB inspection found **0 external buffer/image URIs**. All **13/13** catalog source dependencies match expected SHA and size.
- Production asset tree: **8/196** catalog byte-identical GLBs are present anywhere; **188** are absent (25,601,564 raw bytes). All **8 declared catalog `resPath` values** currently point to those byte-identical files. The prospective SHA-addressed `res://assets/map_editor/<SHA>.glb` path is a separate migration policy: only **3** are present there and **193** are absent.
- Placed authored content: **242 objects / 33 distinct GLB types**; byte-identical assets exist for **6 types**, missing for **27**. All **6 present placed types** are at their declared catalog `resPath`; only **1** also uses the prospective SHA-addressed path. The five other present types use legacy building/decor paths, which a factory loading the current catalog `resPath` can locate by path. This does not prove Godot import or full-world gameplay compatibility.
- The catalog's `imported-verified` status for eight resources is historical; the byte audit finds all eight at their declared catalog `resPath`, but only three at the prospective SHA-addressed path. `.glb.import`/Godot cache existence, scene behavior, collisions, interiors, navigation, draw calls and FPS were **not** tested.

## The 33 placed types

| Asset type | Objects | SHA-256 | Production bytes |
| --- | ---: | --- | --- |
| woodland_crosswing_house_v1 | 2 | `060efe1399086eba29b8ba0871787792aa4bfd8187a54203837e5f7ddf44814b` | canonical |
| pine_ridge_cottage_v1 | 2 | `0ee0526b4389a356006396310d796c69080ddcd976ecac24d7dd7c424e2a0da3` | missing |
| pawnshop | 4 | `1a95f97569d94d162d2d0c4217e1435a2b9e5860a49a2d140d90e4d899d6232f` | other path |
| planter_round | 5 | `24870a5bb4c9ca667c2bba3e8955216229f6a4a95a4e5800398bb2551e8dc12e` | missing |
| hillstep_chalet_v1 | 3 | `26f0868537c6e95136cdf69f9d3a7a554b61b29e974fc1949cdd94f8819c8714` | missing |
| fountain_park | 3 | `28487ee1d66bc48013f8a4166bf218427f56f8e961a078bc71c6396a751ef36e` | missing |
| bin_civic | 5 | `29806183182dfab201800c69a1a0d29ee671e8b20030ce5ae83182f148c957f0` | missing |
| lamp_civic_double_v1 | 48 | `47ae1fe13f50413fde7ee6a2dc35126765b34ff10ab725bf5983fbaa789a9a89` | missing |
| hospital | 1 | `542b901c3bd0abebf4ac8a3590cbf30047eb748abb7ab3216fa18ec6ecd780a8` | missing |
| eastside_stepped_apartment_v1 | 4 | `5af57644b8896f3062b69a26c10aa393b2a6364899b5ef71ab28aac6156ebbba` | missing |
| nightclub | 1 | `624967d9ad8e11bd105e314794af8371c67e8d0bd3a2d00855243b56371a9415` | missing |
| eastside_garden_walkup_v1 | 4 | `627e644d51f0488d67bc476498a0ae5404e522fa0c7a240c1ecd9f4b0d287f10` | missing |
| civic_hall | 1 | `81a289dc228032ae4bd0a7f610a06527f9eac36ca3ee8efdc1be312053e4ad3c` | missing |
| lamp_bellini_v1 | 32 | `81c8b123ded3e5b9f2230cf46f91b59ad13b65583b9b9617b9d4e861c63226f5` | other path |
| bench_civic | 18 | `83de855700a952d824f24e617cd3f2f967b3a88c2399727f7b956d37c724e941` | missing |
| bank_large_shell_v1 | 1 | `8902684ddc01ff119cb18221ae3853cc78301ae65256c5e69e383549709c1789` | missing |
| veranda_bungalow_v1 | 1 | `8adf5797cf739c73bf5b3a7d0586406dade6f1a3b566c18cda2c0a510ba5aa5b` | missing |
| bank_medium_shell_v1 | 1 | `97d92c7b3aee62d353e74566d262dce887d44f0c692c7b8efd696087df5965fc` | missing |
| strip_club | 4 | `a29f4603767b74b71baae3d42c4cbd44e7831b90634bc1bfa7dbfe23e3f4272c` | missing |
| coastal_orchard_house_v1 | 2 | `ac9b33396f0773823d74a517ec8764438bd8b2bd253110a0cf3806310f5b9f20` | missing |
| print_shop | 4 | `ad7b8ef7e7e4143f0e989b7a585c03bb9bd1c13d5efb8689cf67ebcb92ac4d97` | other path |
| bank_small_shell_v1 | 1 | `ba3580e4549cf1cce5ceea826aad62158118271a2dbacf23723da7bc33664aab` | missing |
| garden_lane_house_v1 | 3 | `c15b6c3f8360a504a76f35e4b96510c18fb30a321db75651a8260bd965540c37` | missing |
| compact_podium_glass_tower_v1 | 2 | `caa4b79ab28993e3a8c84054f5366de2df94a4d70ff76f7073d01dd73caea531` | missing |
| bookmaker | 4 | `cf7da54c2037182ca975bf5d08c291a8c7a41e7a1107c7f223b5522468ce8d70` | missing |
| fountain_central | 1 | `d1aef72399f74966ad6e69a523d9f94fc851cd320f6e543e8ba796aac7ac8681` | missing |
| gun_shop | 4 | `e97d6fac4097af61eaf45ad79d84caf5eadf5f167d3ff3acebfae72ff42d9755` | other path |
| fountain_district | 4 | `ec544301e7d9af769eaf7978d630f88dd882331851fae9165dc3c3d54f00cbcf` | missing |
| glass_pavilion_small_v1 | 4 | `ecae5f97bd53e9466bea3a520ec95a58ecacd7a232fbde902de0a1a7d4672873` | missing |
| lamp_foundry_v1 | 32 | `efed19a8fe04819321de8304e71f9c4e4ed892662e2844cb4bdbdcdb29492bb6` | missing |
| old_town_narrow_townhouse_v1 | 22 | `fd0178400e608c44f4c7c8841d9a308e0ae2ec4db4df36033f04401f9b135067` | other path |
| lamp_pine_v1 | 16 | `fe092a7d5833b2008fa90a54ae0580f03ee19d90f03dd26297ad54f0647b54c1` | missing |
| police_station | 3 | `fff0639b3800df3f212c548c9fc45d755b5627c0d3098f10cbc55e9567232d4f` | missing |

The five byte-identical resources outside the prospective SHA-addressed path (but at their current catalog `resPath`) are:

- `1a95f97569d94d162d2d0c4217e1435a2b9e5860a49a2d140d90e4d899d6232f` — `godot/mafiozi_walk/assets/buildings/pawnshop.1a95f97569d9.glb`
- `81c8b123ded3e5b9f2230cf46f91b59ad13b65583b9b9617b9d4e861c63226f5` — `godot/mafiozi_walk/assets/decor/lamp_bellini_v1.81c8b123ded3.glb`
- `ad7b8ef7e7e4143f0e989b7a585c03bb9bd1c13d5efb8689cf67ebcb92ac4d97` — `godot/mafiozi_walk/assets/buildings/print_shop.ad7b8ef7e7e4.glb`
- `e97d6fac4097af61eaf45ad79d84caf5eadf5f167d3ff3acebfae72ff42d9755` — `godot/mafiozi_walk/assets/buildings/gun_shop.e97d6fac4097.glb`
- `fd0178400e608c44f4c7c8841d9a308e0ae2ec4db4df36033f04401f9b135067` — `godot/mafiozi_walk/assets/buildings/old_town_narrow_townhouse_v1.fd0178400e60.glb`

The manifest's `missingIds` field is the exact 188-ID missing set; `resources` records each source path, byte size, placement count, declared catalog `resPath` and prospective SHA-path presence separately. The v2 manifest was regenerated by a fresh source/production SHA audit after the CPU window, and its 17 structural checks pass. This audit is an asset-adoption prerequisite, **not** permission to copy files or claim full-world editor/visual admission.
