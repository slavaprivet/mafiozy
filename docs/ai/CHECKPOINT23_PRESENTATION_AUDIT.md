# Checkpoint23 — NPC presentation review

23 сентября 2026. Review production diff и actual-function CPU tests, без
production правок, staging, commit, push и браузера. Scope: npc_actor,
npc_population, hero_artist14_surface, npc_contact_ray и их death/blast helpers.
World/navigation/C4/server и транспорт остаются у соответствующих владельцев.

## Вердикт

**READY для development checkpoint в проверенном presentation scope.**
Новых доказанных gameplay blockers не найдено. Это не приёмка LIVE/FPS или
всего живого города. Есть один воспроизводимый дефект тестового harness,
который нужно учитывать при общей проверке.

## Проверено

На текущих файлах 22 test entrypoints прошли обычным запуском. Ещё один
survivor entrypoint прошёл после исправления исключительно CRLF extraction
в памяти; исходные файлы оставлены без изменений.

| Участок | Проверки и результат |
|---|---|
| Death actor integration | 26 checks: реальные male/female GLB, binding события/epoch, frozen pose choice, save/recreate, atomic invalid restore, legacy, respawn — PASS |
| Entry origins | 62 checks: vehicle/prone inheritance, строгие P/Q/S, legacy, blast replacement persistence, partial-prone fallback — PASS |
| Death clock | 12 male/female clock variants и actual population cull/reentry — PASS |
| Ground memo | 68 helper cases и 6 actual actor integrations, по 89 hits/1 miss steady — PASS |
| Death families | 24 source families, 9 edge cases, 71 catalogue entries, 26 posed roles — PASS |
| Death pose/profile | 12 actual male/female pose cases и 5 authority/epoch/direction contract tests — PASS |
| Population | 23 normalization/culling/creation/motion/persistence checks — PASS |
| Surface | Serialization/atomic restore, lifecycle, actual hit surface contract, cached diagnostics, 44 wet/dry parity checks — PASS |
| Contact + combat | 20 actual skin ray cases; public aim without firing, obstruction/range/hidden rejection, accepted/rejected receipts — PASS |
| Blast runtime | Actual source metadata → actor → bounded parts → atomic hide → save/recreate → TTL/respawn, обе модели — PASS |
| Blast helper | 6 host cases, 12 cold/prepared fixtures, TTL/capacity/300 later cycles; ground 12 parts, ≤180/192 queries, этажи 3/6 м — PASS |
| RPG regression | Actual native flight floor damage при 7/15/60 FPS, moving skin/range/wall; 8 source impact validation/once/accounting cases — PASS |

Запускались: test_npc_death_integration20, test_npc_death_ground_integration20,
test_npc_death_entry_origins20, test_npc_death_clock_persistence_prototype20,
test_npc_population, test_npc_surface_state, test_npc_surface_diagnostics,
test_npc_lifecycle, test_npc_contact_ray, test_world_walk_combat,
test_npc_blast_runtime20, test_npc_blast_presentation20,
test_npc_blast_parts_ground20, test_rpg_flight_integration21,
test_rpg_native_impact21, test_npc_ground_correction_memo,
test_npc_blast_parts_prototype20, test_npc_death_pose20,
test_npc_death_profile20, test_npc_death_all, test_npc_hit_surface_contract,
test_npc_wet_dry_cost, test_npc_blast_survivor_priority21. Все имеют суффикс .mjs
и находятся в assets/maps/city_rebuild_v1.

## Единственный FAIL обычного запуска: harness CRLF

`test_npc_blast_survivor_priority21.mjs:34–35` ищет в прочитанном world.html
разделитель `,\n`, но файл содержит `,\r\n`. Assertion возникает до создания
фикстур и проверки actor. Это не провал crawling presentation.

Одноразовый Node load hook заменил в памяти только чтение world на
`fs.readFileSync(...,'utf8').replaceAll('\r','')`. После этого **12 survivor
scenarios + 12 control scenarios PASS** на тех же production GLB/actor:
голова у раненого находится на .412/.435 м, stale cower/seat/phone/surrender
не перетирают medical prone, bone difference относительно чистого crawl=0.
Root затем применил это узкое CRLF исправление в тестовый файл; обычный запуск 12 survivor +12 controls теперь PASS.

## Файлы, которые нельзя забыть в checkpoint

Новые runtime зависимости actor/population:

- npc_death_pose20.mjs
- npc_death_entry20.mjs
- npc_death_presentation20.mjs
- npc_death_profile20.mjs
- npc_ground_correction_memo.mjs
- npc_surface_diagnostics.mjs

Уже подключённые Walk blast runtime зависимости:

- npc_blast_presentation20.mjs
- npc_blast_parts_prototype20.mjs
- npc_blast_ground20.mjs

Также нужны согласованные изменения npc_source_lifecycle.mjs и
artist14/wet_clothing.mjs, от которых зависят проверенные actor/surface
контракты. Source fatal-record helpers и source projectile bridge входят в
проверку другого владельца. Никаких файлов здесь не staging.

Имя и шапка `npc_blast_parts_prototype20.mjs` исторические: модуль уже импортирован
в Walk. Его комментарий «no gameplay import» устарел и не доказывает изоляцию.

## Оставшиеся границы приёмки

CPU тесты не доказывают FPS общей сцены. Взрывные части ограничены двумя
одновременными жертвами, имеют soft CPU budget и могут появляться с задержкой
на низком FPS; сохранены TTL и целое тело до завершения подготовки. Seam caps,
полная коллизия со стенами и GPU upgrade этим checkpoint не реализованы.
Authenticated server AoE этим review также не подтверждён.

Root должен завершить один согласованный браузерный прогон; создавать
дополнительную игровую вкладку ради этого аудита не требуется.
