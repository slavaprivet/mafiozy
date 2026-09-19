# Интерактивный комнатный сейф — контракт источника

12 сентября 2026. Владелец представления: задача «Автомобили — продолжение архитектора», текущий этап интерьеров. Владелец world/mercenary hooks: Координатор16. Готовы geometry helper, отдельный source adapter и серверный persistence service; наличие этих модулей не означает уже подключённый HTTP route/авторизованный серверный roster.

## Новый source для native-комнат

`native_interior_safes.py` не импортирует и не меняет `mafiozi_bot.py`. `NativeInteriorSafeService` выполняет SQLite-работу через `asyncio.to_thread`, на взаимодействие, без покадрового обновления. Канонический registry загружается один раз из **серверного** `assets/maps/city_rebuild_v1/interior_safe_manifest.v1.json` (манифест фактических размещений генерирует root):

```json
{"version":1,"safes":[{"id":"interior-safe:hotel_01:floor:1:room:0","buildingId":"hotel_01","roomId":"hotel_01:floor:1:room:0","purpose":"hotel","position":[10,3.4,20],"reward":57}]}
```

`position` — реальные мировые X/Y/Z в метрах. ID строго `interior-safe:${roomId}`; roomId содержит buildingId и стабилен: `${buildingId}:floor:${level}:main` или `${buildingId}:floor:${level}:room:${privateIndex}`. Не более одного сейфа на roomId. Манифест отклоняет дубликаты, несовпадающие ID, неизвестное назначение, нечисловые координаты и неверную сумму. Если reward не задан, фиксированное значение15–80 вычисляется по FNV-1a UTF-8 от safeId (тот же алгоритм в JS); это диапазон старых обычных кейсов. Ничего из registry/reward/position не принимается от HTTP клиента.

Предлагаемое подключение владельцем backend:

```python
service = NativeInteriorSafeService(
    DB_PATH,
    registry=load_safe_registry(),
    resolve_authority=None,  # До подключения настоящего server-owned roster.
)

# POST /world/interior-safes/{uid}
async def h_native_safe(req):
    uid = str(req.match_info['uid'])
    await resolve_request_identity(req.headers, expected_character=uid)
    payload = await req.json()
    result = await service.handle(uid, payload)
    return web.json_response(result)
```

Это пример стыка: владелец добавляет существующие CORS/error handling и регистрацию маршрута. Путь нужно включить в `_requires_actor_binding` **или** явно выполнить проверку выше; строка uid из URL не авторизация. Нельзя добавлять route без привязки Telegram/Steam identity. После принятого ответа source синхронизирует `cash`/live `_cash` обычным существующим способом, **без второго начисления**.

Тело POST:

- `{action:'hydrate',safeIds:[...]}` (до128 ID; без списка — registry целиком до128).
- `{action:'unlock',safeId,buildingId,roomId,requestId: safeId+':unlock'}`.
- `{action:'collect',safeId,buildingId,roomId,requestId: safeId+':collect'}`.

Сейф глобально одноразовый: первый принятый unlock в одной `BEGIN IMMEDIATE` создаёт `native_interior_safe_states`, уникальную строку `native_interior_safe_rewards` и выполняет `UPDATE characters SET cash=COALESCE(cash,0)+reward WHERE telegram_id=uid`. Повтор/гонка другого игрока возвращает opened/collected с gained0; сумма не зачисляется снова. При ошибке любой записи откатываются **все три изменения**. Повторный receipt содержит текущий баланс самого вызывающего персонажа, не исторический баланс первого открытия. Идентификаторы старых major/bank систем не используются.

`resolve_authority(uid, definition)` должен читать серверный roster/action и вернуть **NativeSafeAuthority**, а не клиентский dict. Проверяются владельческий допуск медвежатника, профессия `safecracker`, жизнь игрока и наёмника, свежесть поз до3с, текущая комната/здание наёмника, подтверждённый свободный подход, дистанции и высота. Игрок до12м, медвежатник до1.8м от сейфа и в пределах0.75м поY. JSON с полями `profession`, `mercenary_authorized`, `cash`, `position`, `registry` не даёт полномочий и игнорируется.

**До подключения серверной профессии, принадлежности, текущего action и 3D-поз resolver остаётся отсутствующим: новый unlock возвращает `mercenary_not_authorized`.** Source 2D x/y и клиентская фраза о профессии не заменяют авторитетную высоту/принадлежность. Чтение сохранённого opened и повтор уже принятой выдачи разрешены без нового выполнения профессии, но HTTP identity всё равно обязательна.

## Клиентский source adapter

`assets/maps/city_rebuild_v1/interior_safe_source.mjs`:

```js
const safeSource = createInteriorSafeSource({
  userId: '111',
  registry: manifest.safes,
  request: (url, options) => _apiRequest(url, options),
});
// credentials остаются в существующем _apiRequest.
const safe = createInteriorSafe(THREE, {
  id: definition.id, buildingId: definition.buildingId,
  roomId: definition.roomId, position: definition.position,
  onUnlock: (safeId, request) => safeSource.unlock({safeId, ...request}),
  onCollect: (safeId, request) => safeSource.collect({safeId, ...request}),
});
const result = await safeSource.hydrate({safeIds: [definition.id]});
if (result.ok) safe.applySourceState(safeSource.getState(definition.id));
```

API: `unlock(args)`, `collect(args)`, `hydrate({safeIds})`, `getState(id)`, `subscribe(listener)`, `getLocalLedger()`, `dispose()`. RequestId проверяется независимо от содержимого context. Одновременные одинаковые запросы объединяются. Только подтверждённые `opened:true,collected:true` попадают в cache; stale hydrate не закрывает и не наполняет сейф.

Для **изолированной** сцены: `{standalone:true, userId:'local-player', registry, authorize}` + настоящий loopback HTTP(S) URL с `?standalone=1`. Для **source world local preview**, по согласованию Координатора16/root:

```js
createInteriorSafeSource({
  localPreview: true,
  allowLocal: () => source.canUseLocalEffects() === true,
  userId: 'local-preview', registry: manifest.safes,
  authorize: ({safe, action, context}) => source.authorizeOwnedSafeAction(safe, action, context),
});
```

`authorizeOwnedSafeAction` — обозначение требуемого host callback, не существующий метод. Владелец проверяет свой действующий local squad/action. Этот режим допускается на `/world.html?direct=1&previewcity=1&renderer=walk` только на loopback, с явным `localPreview:true` **и** пока host-owned `allowLocal()` возвращает строго true. Допуск повторно проверяется перед записью после асинхронной проверки профессии. Подмена query не требуется; на внешнем хосте или при отключении host допуска локальный источник не работает. `authorize` обязателен и здесь, и в standalone.

`context` поступает из настоящего mercenary effect без изменений, включая числовые actionId/memberId и прежний context.requestId. Callback сейфа сохраняет свой канонический requestId `${safeId}:unlock`, а context.actionId доступен проверке действия и записывается в локальный ledger. Authenticated transport намеренно не передаёт клиентские профессию/позицию/cash; будущий серверный resolver обязан искать своё действующее действие по safe/uid.

Локальное сохранение — отдельные ключи `mafiozi.native-interior-safes.standalone.v1` и `mafiozi.native-interior-safes.local-preview.v1`, с состояниями, журналом выдачи и балансами local source. Это **не** world `myCash`/UI и не игровая БД. Web Locks сериализуют вкладки; без API есть очередь в одном JS runtime. Локальный ledger предназначен только для одиночной preview-сессии; серверная одноразовость на нём не основана. Отказ localStorage/испорченная запись не превращается в успешную выдачу и не затирается пустым состоянием.

Source возвращает `{ok:true,opened:true,collected:true,gained,localBalance,source:'standalone'|'local-preview'}` только после сохранения. Добыча уже выдана источником, второй collect не платит. Между пересозданиями адаптера и другим preview userId тот же сейф остаётся пустым.

## Представление

`assets/maps/city_rebuild_v1/interior_interactive_safe.mjs` экспортирует:

```js
const safe = createInteriorSafe(THREE, {
  id: 'interior-safe:hotel_01:floor:1:room:0', // стабильный ID экземпляра
  buildingId: 'hotel_01',
  roomId: 'hotel_01:floor:1:room:0',
  position: [x, floorY, z],
  yaw: 0,
  metresPerCell: 4.1,
  sourceState: { opened: false, collected: false, revision: 0 },
  onUnlock: (id, request) => source.commitSafeUnlock(id, request),
  onCollect: (id, request) => source.collectSafeLoot(id, request),
});
roomRoot.add(safe.object);
```

`source.commitSafeUnlock` / `source.collectSafeLoot` здесь имена предлагаемого адаптера, **не уже существующие методы world**. Helper не вызывает API самостоятельно и не изменяет деньги, инвентарь, навыки или собственность.

- `safe.object.userData.mercenaryTarget = {id, kind:'safe', label:'Сейф', locked:true, lockable:true, buildingId, roomId}`.
- `object.userData.locked`, `.lockable`, `.mercenaryOpened`, `.collected` отражают подтверждённое состояние.
- `object.userData.interiorSafe.{unlock,collect,getState}` и aliases `mercenaryTarget.{unlock,collect,getState}` позволяют targets найти конкретный контроллер через адресуемый Object3D.
- `safe.unlock(context)` / `safe.collect(context)` возвращают **Promise**. Callback получает `(id, {buildingId, roomId, requestId, context})`. `requestId` стабилен: `${id}:unlock` или `${id}:collect`. `context` передаётся как отдельное поле и не может заменить адрес/ключ.
- Подтверждение открытия: `{ok:true, opened:true, collected?:true, revision?:number, targetId?:id}`. Подтверждение получения: `{ok:true, collected:true, revision?:number}`. `true` или `{ok:true}` без фактического состояния не считается подтверждением.
- Ошибка, отказ, чужой `targetId`, устаревшая revision оставляют замок/содержимое без изменений. Одновременные одинаковые команды делят один Promise. После подтверждённой операции повтор не вызывает источник. Между пересозданиями/перезаходами одноразовость обязан обеспечивать источник; локальной копии денег/сохранения в helper нет.
- `applySourceState(snapshot,{animate:true})` применяет авторитетное обновление. Открытый сейф не закрывается старым snapshot, полученный лут не возвращается. Для другого игрового цикла нужен новый lifecycle/source state, а не локальная кнопка reset.
- `update(dt)` вызывается только при `safe.needsUpdate`; створка поворачивается на 112° за 0.85 с, кадр ограничен 0.1 с. Никакого сканирования сцены или работы обновления в покое. `getCollisionBodies()` возвращает кешированный массив пяти тонких стенок и отдельной створки; при повороте или перемещении сейфа массив меняется. `dispose()` идемпотентен.

Габариты `INTERIOR_SAFE_DIMENSIONS`: ширина0.86м, высота1.28м, полная закрытая глубина0.88м, глубина корпуса0.68м. Root в центре корпуса у пола; задняя грань z−0.34м, фурнитура до z+0.54м, свободная зона спереди для полного хода до z+1.12м. Передняя сторона +Z. Учитывать дверной ход при размещении, оставлять проход к лицу сейфа. Не включать всю открытую створку в неподвижный AABB комнаты.

## Уже существующие источники world

### Сейфы штурма крупных предприятий

`world.html` отправляет `ws.send({t:'major_safe_open', d:{object_id, safe_id}})` в обработчике `major_safe`. Источник `_majorRaidLocal.safes` сохраняет исходные ID/координаты/opened; `getInteriorState()` уже публикует их в `businessLayout.safes` / `layout.safes`.

`mafiozi_bot.py::WorldSim.major_safe_open` проверяет участие, жизнь игрока, текущий интерьер, фазу после охраны, наличие ещё закрытого сейфа и дистанцию3.2 source units. Затем помечает opened и формирует awards. WebSocket handler начисляет награду в БД и отправляет `major_safe_open` event. **Не переносить сейф в произвольную комнату, оставив серверные r/c прежними.** Для нового размещения нужно согласовать source координаты или их отображение.

Адаптер открывает Promise по `{object_id,safe_id}`, отправляет существующий пакет и разрешает его лишь по соответствующему event / подтверждённому snapshot. Сам `ws.send` не успех. При `{ok:true}` источник уже распределяет награду: возвратить helper `{ok:true,opened:true,collected:true,...}` и применить авторитетный `new_cash` существующим source способом. Не вызывать второе получение денег. Серверный `already_open` без актуального snapshot не превращать автоматически в новую награду.

На момент исходного аудита `mercenary_targets.mjs::performEffect` был синхронным. Координатор16 уже добавил ожидание Promise и использует `mercenaryTarget.unlock(effect)` через `mercenary_walk`; alias в geometry helper подключён. Source callback всё равно должен дождаться настоящего receipt: одной смены `userData.locked` недостаточно.

### Найденные кейсы обычных зданий

`world.html::_probeBuildingCashLoot` / `_claimBuildingCashLoot` используют `POST /world/loot/{uid}`, `{action:'probe'}` и `{action:'claim',claim_token}`. `mafiozi_bot.py::probe_building_loot` / `claim_building_loot` хранят token, сумму, срок и выдачу в БД; claim атомарен, повтор возвращает прежний результат. Это настоящая существующая экономика, но **предмет пока кейс**, а API проверяет присутствие в building-интерьере. Перенос предмета в сейф допустим только согласованным source адаптером; нельзя создавать token или сумму в geometry helper. Старый `_claimBuildingCashLoot` не возвращает receipt — адаптер должен явно возвращать принятое состояние, а не считать отсутствие исключения успешным получением.

### Другие сейфы и банк

`POST /safe/{uid}/loot` — старая боевая система `{safe_lvl,big,boss}` с проверкой навыка игрока и часовым cooldown по боссу. Не подставлять произвольный ID нового комнатного сейфа вместо boss: это нарушит прежние связи и баланс. Наёмный медвежатник также не равен навыку игрока в этом endpoint.

Банковское хранилище имеет собственные crack/room/bag состояния и `interactBank()`. Новый helper не заменяет банковскую дверь, комнаты или перенос мешков. Для остальных новых сейфов требуется source authority/адаптер Координатора16; без callback helper остаётся закрытым, а команда возвращает `source_not_connected`.

## Проверки и стоимость

`node --test assets/maps/city_rebuild_v1/test_interior_interactive_safe.mjs`: 10/10 PASS. Проверены полая геометрия, отдельная реальная створка, точная смена её коллайдера, разрешение/отказ/исключения/ожидание, одновременные и повторные запросы, already-paid major receipt, восстановление пустого сейфа, stale snapshots, последняя ссылка shared ресурсов, поздний ответ после dispose и mercenary alias с сохранением числового actionId/memberId и отдельного канонического requestId.

`test_interior_safe_source.mjs`: 10/10 PASS — transport contract, явный local gating/host revocation/authorize/actionId, persistence между source экземплярами/пользователями, параллельные запросы, недоступное/испорченное storage, отсутствие ложного confirmed state. `python -m unittest test_native_interior_safes -v`: 8/8 PASS — общая SQLite атомарная выдача, восемь одновременных service instances/два пользователя, restart/replay, текущее cash в duplicate, реальные проверки authority, игнорирование JSON-подделок, полный rollback по SQL trigger, канонический manifest. Тесты используют временную БД, реальные пользовательские деньги не меняли.

Геометрия/материалы разделяются всеми сейфами одного THREE runtime; один закрытый или опустошённый сейф: 2 meshes / 2576 triangles; открытый с добычей: 3 meshes / 3152 triangles. Один материал металла с vertex colors и один бумаги; новых текстур/светильников нет. Во время ожидания сетевого ответа ни анимации, ни transform update нет. 160000 idle update вызовов: 0 обновлений анимации; 10000 неизменённых запросов коллайдеров: тот же массив, 1 исходное построение.

Отдельный CPU-прогон, Node без renderer: пустой цикл p50/p95 0.00000393/0.00000996мс на вызов; idle update p50/p95 0.00001457/0.00004512мс; cached collider lookup среднее0.00016438мс. Это микрозамеры, не FPS и не before/after общей игры. **Производительность общей сцены не проверена.** GPU/LIVE не запускались из-за согласованной очереди Координатора16 после Художника16. При интеграции нужны сопоставимые loaded scene frame p50/p95, calls/triangles и путь к сейфу/створке/подтверждённой награде.
