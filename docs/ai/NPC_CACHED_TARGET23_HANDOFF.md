# Cached boss targets — IMPLEMENTED / CPU TESTED / LIVE PENDING

23 сентября 2026, Художник21. Root разрешил cached-target + Nico footprint
после brief review на main `272d12c`; применено только в двух согласованных
участках world. Guardkind, collect, squad teleport/vehicle не внедрялись.

`world.html`:
- `_empireTargetFootprintPassable23`, `_nearestEmpireWalkPoint`,
  `refreshEmpireCachedTargets23` рядом с11549.
- `registerWalkNpcNavigationResolver` рядом с70258.

Только невалидные cached **offline patrol** targets обновляются при новом
ненулевом native resolver. Прежние action/key/generation, координаты NPC,
порядок обеих очередей и cohort сохраняются. 13 valid targets не меняются.
Машины, бой, активный field encounter/боевой target, арест, другие владельцы
и медицинские состояния исключены. Последние три combat/custody gates
добавлены в тот же helper при финальной проверке требования excluding combat.
Новый target выбирается прежним конечным nearest поиском с full footprint;
оптимизирован только порядок прежних probes. Повтор same resolver не сканирует.

## Water readiness

`walk_preview.start` ждёт `refresh`, который создаёт topology/landscape/коллизии,
затем инициализирует native navigation. `createNpcNativeNavigation.query`
синхронно возвращает finite depth из переданных waterAt/groundHeight.
`_npcNavigationAt` предпочитает этот depth перед `_walkNpcWaterResolver`,
а `_empireBossPassable` также проверяет depth>.025. Поэтому отдельный secondary
water adapter не требуется. Все19 actual geometry regression выполнены при
`_walkNpcWaterResolver===null`; этот факт явно asserted в production replay.

## Проверки после apply

- `node test_npc_cached_target23.mjs --require-fixed`: 7 групп, 42 excluded states,
  actual deployed helper/registration дословно; queues/cohort, action/generation,
  stale request, valid/no replacement, renderer/null/same resolver gates PASS.
- `test_empire_live_route_replay23.mjs ... --refresh-candidate --require-fixed`:
  флаг `--require-fixed` читает **actual world helper/nearest/registration без
  substitution**. Историческое имя `--refresh-candidate` включает сценарий hook,
  но не кандидатную реализацию при этом флаге.
- 6 invalid captured goals →6/6 READY, actual walk arrived,0 full-body blocked
  sweeps,13.20–56.25м, без телепортов. Baseline0/6READY сохранён отдельно.
- 13 valid: весь actor JSON unchanged, ownership/generation unchanged.
- `test_empire_target_footprint23.mjs --require-fixed`: actual source, 300 parity,
  legacy/unsupported sweep, clear/body rejection/bounded-no-target PASS.
- Escort cancel/retarget require-fixed, actual cancel geometry, pending slices
 19bosses, unique placement30protected, native empire64/64physicalroutes PASS.
- Local patrol fallback PASS: старый cached scalar goal всё ещё проверяется
  (45EMPTY→1EMPTY/physical alternative); новый normal target selection избегает
  этой старой цели и даёт0EMPTY. Это изменение fixture, а не ослабление проверки.
- `python check_world.py`:7inline scripts PASS. `git diff --check` PASS.

Последний combat/custody gate — только дополнительные early-outs; lifecycle
перепроверен после него. Existing six/thirteen actors не имеют этих flags.

## Exact package paths

Runtime: `world.html` (только описанные два участка).

Focused tests/tools and their imports:
`test_npc_cached_target23.mjs`, `test_empire_target_footprint23.mjs`,
`test_empire_live_route_replay23.mjs`, `npc_cached_target23_candidate.mjs`,
`npc_empire_target_footprint23_candidate.mjs`,
`assets/maps/city_rebuild_v1/test_fixtures/empire_route_capture23.json`.
Candidate modules нужны тестовым импортам/историческому baseline; runtime их
не импортирует.

Шесть старых fixtures теперь также извлекают actual full-footprint helper:
`test_empire_escort_cancel23.mjs`, `test_empire_escort_cancel_geometry23.mjs`,
`test_empire_escort_retarget23.mjs`,
`assets/maps/city_rebuild_v1/test_empire_native_routes19.mjs`,
`assets/maps/city_rebuild_v1/test_unique_placement_body19.mjs`,
`assets/maps/city_rebuild_v1/test_empire_local_patrol_fallback19.mjs`.
У последнего дополнительно сохранён прежний cached scalar goal и проверена
его prevention новым target finder; остальные меняют только dependency list.

Память: этот HANDOFF, `ARTIST21_MEMORY.md`, исторический
`NPC_CACHED_TARGET23_CANDIDATE.md`, `NPC_CACHED_BOSS_TARGET23_REPRO.md`.

Evidence (не нужны runtime): `outputs/empire_live_route_replay23_registration_six_production.json`,
`...registration_valid_thirteen_production.json`, `...registration_baseline_six.json`,
`outputs/npc_cached_target23_candidate.json`, `outputs/npc_cached_target23_cost_summary.json`.

## Ограничения и следующий шаг

CPU cost прежнего isolated AB: aligned sum19 отдельных fixture samples
p50/p95 .0186/.0209 → .9860/1.2162мс; НЕ whole-scene callback/FPS.
Production helper совпадает по функциональному пути, добавлены лишь early-outs.
Производительность общей сцены не проверена. Source stage READY для root reload
после squad пакета. GPU вкладок не открывал, commit/push не делал.

Capture не содержит original activity/base координат: они явно заданы равными
captured target в физическом fixture; независимая base проверена lifecycle.
Бой/транспорт во время единственного ready-scan пропускаются; этот узкий patch
не добавляет deferred recovery после завершения боя и не обрабатывает позднее
streaming изменение геометрии без новой регистрации resolver.

Root LIVE: сравнить target/action/позиции этих шести и поведение после прогрева;
затем при отдельном поручении перейти к guardkind. Весь живой город не принят.
