# 19 боссов: серверное поручение → Walk → физическое действие

23 сентября 2026, Художник21. READ-ONLY AUDIT; runtime freeze сохранён.
Статус: source wiring проверен, authenticated LIVE сценарии этим аудитом НЕ приняты.

## Что подтверждает последняя запись

`assets/maps/city_rebuild_v1/test_fixtures/empire_route_capture23.json`,
capturedAt `2026-09-22T22:29:59.531Z`: все 19 уникальных боссов имеют
`patrol:offline:<leader>:offline`, generation 0. Это `_installNpcEmpireFallbacks`
(`world.html:21086`), не серверные collect/raid/recruit.

| Состояние одного снимка | Боссы |
|---|---|
| walking=true, 9 | vera, arsen, damir, alisa, boris, timur, emil, roman, sofia |
| pending=true, 5 | leila, rustam, marat, inga, yana |
| arrived=true, 2 | marco, zara |
| retry/backoff, 3 | niko, viktor, musa |

Снимок не является таймлайном: standing/arrived не доказывает зависание, а
walking=true не доказывает пройденный путь. Производительность общей сцены не проверена.

## Уже существующие связи

| Действие | Фактическое исполнение и предел |
|---|---|
| Все задания | `loadNpcEmpireState` (`world.html:22173`, искать имя) принимает activity, generation и цель; `_empireActivityTarget:11649` выбирает точку; boss-ветка `updateNpcs:18667` планирует `empire_action` и физически проходит маршрут. |
| collect / inspect / invest / defend / return_hq | Доход/решения существуют на сервере: `npc_empire.py:_visible_activity_candidate:1703`, `_visible_activity:1840`, `advance:3289`. После прибытия Walk использует общий `_empireBossWorkWaypoint:11663` и idle-речь. Отдельного исполнения осмотра кассы, сделки или проверки поста в этой ветке нет. |
| Охрана | `_syncEmpireHoldingGuards:11412` создаёт ограниченный ближний набор из holdings; `_spawnEmpireHoldingGuard` сохраняет лидера/объект/слот. Guard-ветка updateNpcs ходит по постам с `empire_holding_guard`; `_empireFieldCombatThink:11927` даёт физический бой. Охрана уже существует, это не только флаги. |
| Сопровождение | `_syncEmpireBossCrews:11457` связывает численность/лидера/боевой приказ; peaceful crew-ветка физически следует напрямую или по `empire_escort`. Cancel/retarget исправлены отдельно, LIVE проверяется координатором. |
| recruit | Кандидаты физически идут к месту встречи; `_syncEmpireBossCrews` продвигает их по полученной численности. `advance:3331` завершает набор по серверному времени, а не подтверждению физического прибытия. Уличный набор отдельно: `_adoptEmpireStreetRecruit`, `_confirmEmpireStreetRecruit:11342`, подход/разговор и POST `/street-recruit` → `recruit_street_fighter`; это реальная связка, не одна подпись. |
| retreat | `_empireRetreatStep:11920`: физический маршрут к текущим HQ-координатам, остановка и локальное восстановление battle HP. Это тактическая ветка withdraw/reserve, не отдельный подтверждённый сервером поход в native HQ. |
| gang_war | `_war_activity` (`npc_empire.py:2085`) публикует врага/stance; Walk отслеживает соперника, стреляет с LOS и проектилями, `_hitEmpireCombatant:11874` / `_downEmpireCombatant` меняют локальное боевое состояние. Сервер `advance:3710–3836` отдельно вычисляет потери/победу/владение. Связи «итог именно этого физического NPC-vs-NPC боя → этот серверный захват» в просмотренном пути нет. |
| player_business_raid | Прибытие вызывает `_markPlayerBusinessRaidBreached:20945`; есть физические защитники, alert и отдельные interior casualty/resolve callbacks (`world.html:65407`, `65421`, сервер `resolve_interior_raid:4456`). Нельзя переносить эту готовность на gang_war или считать preview доказательством native-интерьера. |

Номера строк — снимок текущего shared source; имена функций надёжнее при следующих правках.

## Конкретные недостающие связи

1. **Идентичность реального объекта → цель и посты.** `_empireActivityTarget`
   первым принимает числовые target_r/c; business-anchor fallback поэтому часто
   вообще не вызывается. Building id `r,c` преобразуется в старый центр блока.
   `_npcEmpireHoldingPoint:21291` также использует BUSINESS_POIS или старый
   `_playerEmpireBuildingMeta`. В этих функциях нет разрешения authoritative
   native site/instance и его доступного входа. Исправление принадлежит root
   native-site authority; отдельные координаты или новый HQ здесь не создавать.
2. **Прибытие → смысл поручения.** `updateNpcs:18681–18705` имеет специальный
   arrival hook для player_business_raid, но collect/inspect/defend/invest
   проходят общий круг и idle-речь. Нужен короткий обработчик конкретного
   поручения с once-per-action-generation и отменой при смене приказа/бое.
   Начисление денег уже серверное; локальный повторный доход добавлять нельзя.
3. **Охрана/найм/отступление → полный native directed planner.**
   `_planNpcRouteTo:9638` допускает в `_npcPlanNativeVisitRoute` empire_action
   и empire_escort, но не empire_holding_guard / empire_recruit /
   empire_street_recruit / empire_retreat. Они физически движутся через общий
   coarse planner; это пробел точной навигации, НЕ отсутствие их механики.
   `_npcAdvanceRoute:9717` тоже ограничивает точность промежуточных точек двумя
   empire kinds. Расширять список без геометрического repro и стоимости нельзя.
4. **Физический NPC-vs-NPC итог → authoritative война.**
   `_hitEmpireCombatant`/`_downEmpireCombatant` не передают этот итог в
   `npc_empire.advance`; серверная победа рассчитывается отдельно. Нужен
   самостоятельный контракт encounter/участников/цели/потерь/идемпотентного
   результата. Это больше короткого визуального patch и остаётся root scope.

Набор в Логове также завершает серверный таймер независимо от прибытия; это
существующий контракт, не предлагается незаметно менять его в Walk.

## Первый ограниченный сценарий следующей реализации

**Один collect-визит у уже существующего собственного бизнеса.** Root предоставляет
однозначный native site для server holding_id, существующий вход и безопасную
точку встречи с охраной. До этого — только isolated candidate.

Босс получает настоящий collect с неизменяемым action key, физически подходит,
останавливается у точки, на короткое время поворачивается к существующему
охраннику и произносит фразу проверки дохода. По завершении возвращается к
обычному движению; при бою, новом action key, смерти или утрате владения сцена
прерывается. Никаких новых домов/HQ, спавна кассира и клиентского начисления денег.
Если guards нет, допустима короткая проверка у входа без выдуманного собеседника.

Приёмка: одна сцена на generation даже при повторных state polls; отсутствие
сцены при offline/preview/missing site; реальный подход без телепорта и
пересечения solid; сохранённая охрана/сопровождение; экономическое состояние
меняется только прежним серверным путём. Измерить стоимость новой ветки CPU,
затем root снимает одинаковую загруженную LIVE сцену p50/p95 и draw calls/triangles.

Runtime и backend этим аудитом не изменены; backend не импортировался, БД не открывалась.
