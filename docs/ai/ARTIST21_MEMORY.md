# Художник21 — актуальная память

## Последнее: пользователь «продолжай задачи без остановок»

Read-only аудит следующего участка готов: `NPC_BOSS_WALK_BINDINGS23_AUDIT.md`.
Все 19 в capture22:29:59Z имеют offline patrol, не authenticated world activities.
Охрана, сопровождение, набор и отступление физически существуют. Missing:
native site identity в выборе цели/постов (root scope); отдельный collect/inspect/
defend/invest arrival executor; native directed routing для guard/recruit/retreat;
authoritative NPC-vs-NPC итог, поскольку server advance считает войну отдельно.
Root получил audit и предложение одного bounded collect-визита на существующем
собственном native site, без клиентского дохода и нового здания/HQ.
До нового разрешения runtime freeze; возможна isolated модель lifecycle.

Модель теперь сохранена: `NPC_COLLECT_VISIT23_CANDIDATE.md`, pure helper и
7 групп tests PASS. Только isolated, нет импорта world/Walk и нет native adapter.
Exact arrival + holding/owner/site gate, once-generation, отмена/освобождение
паузы при бое/смерти/смене приказа/владения. CPU19calls p50/p95 .0029/.0034ms,
НЕ полныйupdate/FPS. Серверные деньги, позиции и здания не меняются.

Следующий isolated repro готов: `NPC_OTHER_EMPIRE_ROUTES23_CANDIDATE.md`.
Guard/recruit/street_recruit/retreat coarse маршруты на 6 избранных geometryinputs
×4kind:12/24arrived,16unsafe; nativecandidate24/24arrived,0unsafe/blockedsteps.
20actualpump отмена/same-frame PASS. CPUtotal354→65ms, но p50 .846→1.297ms;
не FPS и не representative city. Runtime НЕ менялся. Для next scope сначала
один guardkind+реальный LIVEpost, не автоматически все четыре.

Ещё отдельный repro: `NPC_CACHED_BOSS_TARGET23_REPRO.md`. CapturedViktorцель
в fixturewater2.22м,42kvisited/1.03sCPU EMPTY; Musa bodyblocked/EMPTY.
Повторный СУЩЕСТВУЮЩИЙ nearest helper после geometryready (без Nico нового
фильтра) даёт обоим23/32visitedREADY и physical13.20/42.17м arrival.
Нет production invalidation hook: cachedtarget остаётся при sameaction,
registerNativeResolver только initialsafeplacement. Startup timing — гипотеза,
не captured evidence. Root уведомлён. Runtime freeze сохранён.

Проверка19targetsonly:13point/body/footprintOK,6invalid — Leila/Alisa/Viktor
depth2.22,Inga point/body/footprintblocked,Musa bodyblocked,Nico толькоfootprint.
Leila/Inga activecapturedpending; Alisawalkingtrueнеозначаетsafegoal.
Отчёт `empire_live_route_replay23_all_boss_targets.json`, planningSkipped:true,
это НЕ19routefailures и НЕwholecityLIVE. Production не менялся.

Sixinvalidreselection replay завершён:6/6physicalarrived, fullbodysweeps0blocked,
путь13.20–56.25м; отчёт all_six_invalid_reselected. CLI теперь проверяет каждый
реальный шаг sweep, поддерживает --summary/--inspect-target/--reporttag.
Это кандидатная подмена goals, НЕ lifecyclecachefix; next приоритет именно
cachedtargets invalidation перед collectвизитом, после снятия rootfreeze.

ПОЗЖЕ: координатор20 послеreview разрешил одну строку escortretarget.
Она теперь IMPLEMENTED/READY в world. Production test `--require-fixed` читает
fixed branch дословно, без candidate substitution. Guard/cancel/pending19bosses/
syntax7 PASS. Координатор включит в общий reload вместе с Ehold bugfix.
С этого момента runtime freeze до SHA; Nico дальше только isolated candidate.

Nico candidate готов изолированно: actual pavilion002 goal проходит5bodypoints,
но полный stationary footprint blocked. Кандидат `_nearestEmpireWalkPoint`
выбирает полный свободный footprint26.5/148.5,actual43.804м route/9.571simsec
arrival PASS. Новая стоимость снижена сортировкой прежних finite ring probes,
300parity PASS, isolated p50/p95 .039/.067→.119/.155ms. Production НЕ менялся.
Документ NPC_NICO_TARGET_FOOTPRINT23_CANDIDATE.md описывает ограничения и код.
Сохранён переносимый scalar fixture empire_route_capture23.json, чтобы не
зависеть от Downloads. Следующий шаг — broad bounded target-selection review
по этому fixture и LIVE от координатора; текущие новые targets не объявлять
готовыми для всех NPC по одному стендовому маршруту.

Bounded actual pavilion matrix выполнена169точек:21старый unsafe footprint,
candidate меняет ровно21 и сохраняет148, missing0, sorted/brute parity169/169.
Это дополнительный readiness candidate, не разрешение менять freeze runtime.

Свежее23Sep01:29local: координатор передал штатный export
`C:/Users/Слава/Downloads/npc-inspection-1790116199540.json` (22:29:59Z).
Новых production edits пока не делать — до следующего общего LIVE-пакета.
QA поля загружены; escort cancel patch был позже reload и ещё неLIVE.

Доказан следующий isolated candidate: София12 ищет старую цель30.5/72.5,
хотя formation уже27.5/80.5 (>5.2 drift). Ready route обновляется, pending
игнорирует drift. Candidate одна строка coalesce, без нового поиска/бюджета.
Actual crew regression PASS; actual target GLB geometry:6000visited/EMPTY
→35visited/READY, физический путь48.785м пройден10.571симулированных секунд,
без телепорта/blocked segments. См. NPC_ESCORT_RETARGET23_CANDIDATE.md.
Это CANDIDATE, НЕ production и НЕ LIVE. У Nico иной текущий failed goal, у
Marat6 уже почти arrived formation — stale pending покрывает прошлый patch.

Работа продолжена. Второй короткий patch: отмена устаревшего empire_escort
при прямом следовании/прибытии, helper+2call в мирной crew ветке world.
Координатор20 явно согласовал scope; actual branch/pump и native geometry PASS.
Подробности/manifest: NPC_ESCORT_CANCEL23_HANDOFF.md. Также готов штатный QA
export empireRequest/empire/search для точного следующего repro Nico/sofia25.
Координатор включил QA в общий reload и обещал экспорт после него; LIVE остаётся
только у него. Ни whole-city behavior, ни FPS ещё не приняты.

23 сентября2026. Чистое продолжение зависшего Художника20; общий координатор20
`01a0bc08-cb3e-7181-be11-a53aaee54535`. Прочитаны ARTIST21_HANDOFF, актуальные
шапки COORDINATOR_20_MEMORY/NPC19_TEAM_BOARD, арт-канон, agenda18 и память19.

Первый bounded patch IMPLEMENTED/CPU TESTED: завершённая группа маршрутов
открывает следующую в том же кадре, сохраняя4мс/8допусков и приоритет старших.
Подробности, проверки, limits и точный пакет: `NPC_COHORT_DRAIN23_HANDOFF.md`.
Из world менялась одна строка `_npcReserveRouteWork`; root согласовал этот scope.
Не трогались `_npcFinishRouteWork`, вода/наёмники/телефон/транспорт/perf-пакеты.

Есть доказанный механизм лишнего ожидания, но не доказано, что он полностью
объясняет LIVE15.863с resident205. У205 agenda walk, seek_shop — stale phase.
Реальная геометрия/actual functions проверены; LIVE и full-scene perf ждут
единственную вкладку координатора20. Новые GPU-вкладки не создавались.

После source READY следующий участок — read-only разбор индивидуальных целей
боссов и физической охраны по actual export (empire_escort долгий pending), затем
согласованный короткий patch. Mercenary staged follow root/vehicle не дублировать.

## Начат read-only разбор следующего участка

В water-before23 охрана Лейлы1–4 имеет age1106–1227сек, но pending=false,
queuePosition=-1, routeRemaining=0. Эти числа — возраст старой заявки, НЕ
доказательство непрерывного ожидания в очереди. Source age/waitMs экспортируется
без pending-gate. Прежде чем чинить очередь охраны, различать намеренное нахождение
рядом с лидером, отсутствие нового заказа и реальный pending.

Доказанный долгий active pending: unique_niko516.433сек,1017expanded/1100visited,
86quanta/298.9ms накопленного CPU, queue105; empire_crew_sofia_25 66.202сек,
expanded3/quanta4/queue190. Niko далеко от текущей ограниченной presentation выборки;
его `_empirePendingRoute.goalR/goalC` в routeReplay отсутствуют (goalR/goalC null).
Для точного actual replay следующего дефекта нужны goal/targetKey/generation,
а не предположенная цель. Production нового участка пока не менялась.
