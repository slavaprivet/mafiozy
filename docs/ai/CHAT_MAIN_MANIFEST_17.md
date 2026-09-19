# CHAT MAIN MANIFEST 17

MAIN_SHA: 3442bf0d84dd66e787005aa2bbb456caf298b9ca
MANIFEST_AT: 2026-09-19T16:39:18.2774112Z
Источник: фактический working tree. Freshness: каждый файл hash до/после чтения; все четыре отправленных пакета проверены после сборки. Это не заявление о неизменности после отправки.

## Astra 1: grass-cell-index-parity-20260919

SOURCE_SNAPSHOT_ID: 4a3e599dd600002edf3d7a9434d7a78acbfec9b9c0aa2be159622475bcb18612

| Owner source | SHA256 полных байтов | Переданный текст | Dirty |
|---|---|---|---|
| assets/maps/city_rebuild_v1/environment_grass.mjs | 0d03f361d1b08506889c919895612582002e2492ac4c0f44fd5a9035e56c86a7 | FULL |  M assets/maps/city_rebuild_v1/environment_grass.mjs |
| assets/maps/city_rebuild_v1/environment_grass_plan.mjs | 4ea5fef146848102bcabba6418b97752718fe440e9da96f18f6bb98ac14968da | FULL | clean |
| assets/maps/city_rebuild_v1/test_environment_grass_selection.mjs | 52cce4f94251dbb998c573ed52d54d747854f81dd1790c638721fecf78d4d50b | FULL | clean |
| assets/maps/city_rebuild_v1/test_grass_prefix_uploads.mjs | 58001c9aa143da7fc84fc13012e866685240a1e46f04648b2ab662a6c5d7a4ae | FULL | ?? assets/maps/city_rebuild_v1/test_grass_prefix_uploads.mjs |

## Astra 2: npc-adapter-callback-effects-20260919

SOURCE_SNAPSHOT_ID: b757eaf52427091a3d213b636a731a3e90689c45c8f1685ae097ae27d1a95884

| Owner source | SHA256 полных байтов | Переданный текст | Dirty |
|---|---|---|---|
| assets/maps/city_rebuild_v1/mercenary_world.js | 37eaa69b7ee470a2a1a042e1c044568983ae9a708ceb4ac5575371291480f59e | FULL | ?? assets/maps/city_rebuild_v1/mercenary_world.js |

## Astra 3: world-inventory-duplicate-contract-20260919

SOURCE_SNAPSHOT_ID: 9b035d7da3c880a906bd52815a67e1d2852f2e494ace62a5d3607ec30776bdeb

| Owner source | SHA256 полных байтов | Переданный текст | Dirty |
|---|---|---|---|
| assets/maps/city_rebuild_v1/mercenary_world.js | 37eaa69b7ee470a2a1a042e1c044568983ae9a708ceb4ac5575371291480f59e | FULL | ?? assets/maps/city_rebuild_v1/mercenary_world.js |
| world.html | d29a5e895c5a6033be27d8be83e4aeccb43a1bc13a542904f937a7665d789699 | 22508-22520;38280-38330 |  M world.html |

## Astra 5: inventory-test-body-coverage-20260919

SOURCE_SNAPSHOT_ID: d68228da8fc2f539db47ee1c5e15426b2bcdcf94e24c8dadff32fcabc4cdb8a1

| Owner source | SHA256 полных байтов | Переданный текст | Dirty |
|---|---|---|---|
| assets/maps/city_rebuild_v1/mercenary_world.js | 37eaa69b7ee470a2a1a042e1c044568983ae9a708ceb4ac5575371291480f59e | FULL | ?? assets/maps/city_rebuild_v1/mercenary_world.js |
| assets/maps/city_rebuild_v1/test_mercenary_world.mjs | c684aea46898d390dc304c939b9ba6f2bf553e9140695418c05023366059b1a2 | FULL | ?? assets/maps/city_rebuild_v1/test_mercenary_world.mjs |
| world.html | d29a5e895c5a6033be27d8be83e4aeccb43a1bc13a542904f937a7665d789699 | 22508-22520;38280-38330 |  M world.html |

## Astra 4

Узкий отправленный пакет: camera-damping-dt-boundary-20260919
MANIFEST_AT: 2026-09-19T16:45:53.2857992Z
SOURCE_SNAPSHOT_ID: 9ac0a122c0c59bccd2990e57db94bfe049ee4f768c39665fa9c78ff06c070884
assets/maps/city_rebuild_v1/indoor_camera.mjs: SHA256 90e9b3635d189693ed7ee8ec5a087019e67d3e5ca6c7d1b9e8799c7c8eeb577a; boundary FULL; dirty  M assets/maps/city_rebuild_v1/indoor_camera.mjs
assets/maps/city_rebuild_v1/indoor_camera_clearance.mjs: SHA256 df5eb1e4d7c065a3288cc4098710ca43359575c2b7168fa5fa55a9cb8360c027; boundary FULL; dirty ?? assets/maps/city_rebuild_v1/indoor_camera_clearance.mjs
assets/maps/city_rebuild_v1/walk_preview.mjs: SHA256 a83c4db924af347a618638a7505213b21e205b9e2a3d89a91aed88c48a34c61e; boundary complete function clampBuildingCamera(dt); dirty  M assets/maps/city_rebuild_v1/walk_preview.mjs
Скалярные dt/boom границы; vendor/raycast semantics не входят в приёмку. Старый walk_preview был отклонён при freshness и перечитан перед отправкой.

NOT_READY: нет локального vendor-контекста Raycaster/Mesh соответствующего three@0.180.0. Пакет не отправлен. Нужен разрешённый локальный vendor source; запрещённые внешние запросы не выполнялись.

## Astra 5: inventory-dismiss-guard-tests-20260919

MAIN_SHA: 3442bf0d84dd66e787005aa2bbb456caf298b9ca
MANIFEST_AT: 2026-09-19T16:57:27.9148794Z
SOURCE_SNAPSHOT_ID: e08389060a0930c0b49fd5ca47f2ed381b97d47d71921d0e51e5ea560be65934

| Owner source | SHA256 полных байтов | Переданный текст | Dirty |
|---|---|---|---|
| assets/maps/city_rebuild_v1/mercenary_world.js | aadd4a3b86af0bbe2a9e9d9f29f9abbf014cf114f1a87c7fa9f004275f0be476 | FULL | ?? |
| assets/maps/city_rebuild_v1/test_mercenary_world.mjs | 4f0d51e5653095af0ed94af832e9a73a9aa1b3899ca4e51b2323b0cf007d6e2c | FULL | ?? |
| world.html | 445049b43f82b693a0d327b20cfbeca47cfa6815809d2ba93f78fbddc53291ca | complete function _dismissGangMember(memberId) | M |

Назначение: только два ещё полезных test gaps после интеграции duplicate inventory. Fresh-copy/net provenance contract и уже внедрённые duplicate/hospital tests явно исключены.

## Astra 4: camera-visible-ancestor-raycast-parity-20260919

MAIN_SHA: 3442bf0d84dd66e787005aa2bbb456caf298b9ca
MANIFEST_AT: 2026-09-19T17:02:40.1472663Z
SOURCE_SNAPSHOT_ID: 82c3e5502b3af1cf5c4ea6bc59bdfa199feadffb38aa258407907e5e5199f855

| Owner source | SHA256 полных байтов | Переданный текст |
|---|---|---|
| D:/codex_release/artist13_hero_first_DEV_20260907/demo/vendor/build/three.core.js | eb077d2417f61d3e6d9264c317cabc4ea35769ed6b0ab533067292a550784c20 | REVISION 180; Mesh.raycast and Raycaster/intersect excerpts |
| D:/codex_release/artist13_hero_first_DEV_20260907/demo/vendor/build/three.module.js | c8211c69345d2e9949dc7a8ac969380497aa0600a5a8ac6a459c8cd02dd9cb8a | module export linkage |
| assets/maps/city_rebuild_v1/building_entry.mjs | d822be6e32269d4f175a328e09c008a37e56ef2dec0e55b5ea9992ba08be3333 | complete resolveBuildingCameraPosition |
| assets/maps/city_rebuild_v1/test_indoor_camera.mjs | 26da32870a7d5b8cc00a27bf986272e60aadc26a30c41f6e5e07f32383ad3360 | FULL |

Назначение: проверить invisible-ancestor filtering по фактической traversal/sort/layer семантике r180 и предложить только недостающий CPU regression. Renderer/GL/network не используются.
