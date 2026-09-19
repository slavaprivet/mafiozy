# World → Walk: боссы и банды, аудит Художника19

20 сентября 2026. Read-only аудит pipeline; затем по поручению root применён
только `_processEmpireRoutePlanQueue` pending-slice fix. GPU/LIVE не запускался.
Обычные жители, полиция, свидетели и транспорт не изменялись.

## Что уже подключено

- `npc_empire.py::state_for` под `_state_prepare_lock` запускает
  `_apply_player_war_pressure` и `advance`, затем читает серверные empires,
  holdings/relations/diplomacy. Экономика, захваты, союзы и выплаты остаются
  серверными; клиентское достижение точки не равно авторитетному захвату.
- `mafiozi_bot.py::h_npc_empire_state`, `h_npc_empire_diplomacy`,
  `h_npc_empire_interior_raid_resolve`, routes `/npc-empires/{uid}/...`.
- `world.html::loadNpcEmpireState` читает state, hydrates `_npcEmpireById`,
  `_npcEmpireDiplomacy`, districts/holdings/interior raids. Каждые30сек и после
  reconnect. `leader_id` сопоставляется с `_specialistId`, не создаётся новый босс.
- `SPECIALIST_NPCS` содержит19 `unique_<leaderId>`; `ALL_UNIQUE_NPCS` и
  `_placeUniqueNpcsInCity` через `_placeSaidInCity`/`initNpcs` помещают их в NPCS.
  `_syncEmpireBossCrews`, `_syncEmpireHoldingGuards` создают существующие роли
  escort/recruit/guard с `_empireLeaderId`, оружием, doctrine, HP.
- `updateNpcs` реально вызывает crew/holding sync и route pump, исполняет
  `_empirePlayerCombatThink`, `_empireFieldCombatThink`, retreat, recruit,
  formation и branch `_empireBoss && _empireAction`.
- `Mafiozi3DBridge.getDynamicEntities` проецирует NPCS, `aggroZones`,
  `gangNests`, охрану/конвои и другие исходные коллекции. Босс получает
  `npc_unique_<leaderId>` через `_threeNpcEntityId`; snapshot несёт leader ID,
  action label, weapon/profile, colours, tactical role, health, hit/death/state.
- `npc_population.mjs` каждые.1сек вызывает `bridge.getDynamicEntities(65)`;
  `npcAppearanceFromWorld` применяет `npc_boss_art_direction.mjs` для19 имён;
  `normalizeNpcSnapshot` переводит r/c в метры4.1 и передаёт hero rig animation,
  кровь/смерть/намокание в `npc_actor.mjs`. Это presentation, второго AI нет.
- `_installNpcEmpireFallbacks` при offline сохраняет имена и назначает patrol;
  серверной экономики/захватов offline это не реализует. Отдельный
  `lair_fallback_<zone>_<i>` в snapshot — 12 статичных presentation fallback
  бойцов на зону при отсутствии authoritative bots; они не живой серверный AI.

## Доказанные разрывы / следующий scope

1. **Pending считался failure**: `_processEmpireRoutePlanQueue` раньше любой
   false от `_planNpcRouteTo` считал EMPTY и включал failedBackoff. Босс action
   передаёт4000мс. Поэтому нормальный native4ms slice ожидал ещё4сек до
   продолжения. Исправлено узко19: pending сохраняет тот же request/generation,
   встаёт в хвост, продолжает следующий frame, не пишет EMPTY/backoff.
   One slice per actor/source frame, stale generation/action, cancellation,
   dead/hidden/HP0 и настоящий failure защищены.
2. **Targets всё ещё из старой semantic grid**: `_empireActivityTarget` сначала
   принимает `activity.target_r/c`, и только потом смотрит `target_id`.
   `npc_empire.py::_hq_coords` = block*10+6; `BUSINESS_COORDS` фиксированный.
   `_nearestEmpireWalkPoint` проверяет новую физику, но не превращает старый
   адрес магазина в адрес реальной новой двери. `_npcEmpireHoldingPoint`
   business берёт raw BUSINESS_POIS; building — `_playerEmpireBuildingMeta`
   со старым `_connectedBuildingParts` внутри logical block.
   **Не исправлено**: нельзя произвольно менять authority coordinates, IDs,
   ownership keys или серверные combat anchors.
3. **Empire kinds обходят native A***: `_planNpcRouteTo` направляет в
   `_npcPlanNativeVisitRoute` только building_entry/civilian_road_exit/
   civilian_bench. `empire_action/escort/...` остаются coarse BFS. В этой
   BFS edge sweep только для building_entry (который уже обработан выше).
   Значит empire планировщик проверяет footprint узлов, но не соединений;
   исполнение `_npcAdvanceRoute` может закономерно блокироваться у тонких стен.
   Следующий bounded patch после проверки authority: отдельно маршрутизировать
   empire kinds через collision-safe native directed planner, не меняя targets.
4. `_hydrateNpcEmpireFieldEncounter` прямо reconciles серверный anchor при
   distance>4. Его нельзя бездумно remap только на клиенте: hit-session contract
   и серверные дистанции должны видеть согласованные координаты.
5. Выздоровление boss содержит fixed hospital exits (30,46)/(50,126);
   recruitment yard hardcoded99..108/35.5..44.5. Это дополнительные кандидаты
   на semantic-native binding, не изменены этим патчем.

## Pending fix: проверка

`test_empire_pending_slices19.mjs` выполняет реальные source `_planEmpireRouteTo`,
`_processEmpireRoutePlanQueue`, `_planNpcRouteTo` и shared admission, controlled
.1ms point predicate. Старый pending handling не завершил тот же маршрут за
600 кадров/30сек; новый завершил за17 кадров/~916 simulated ms. Это
детерминированный scheduling contract, **не FPS и не actual geometry**.
PASS: coalescing newest request, та же frontier, generation/action cancellation,
явная отмена, dead/hidden/HP0, повтор pump в одном frame, настоящий EMPTY/backoff.
`test_empire_route_admission_dom.js`, `test_empire_route_generation_dom.js` PASS.
`python check_world.py`: все7 inline scripts PASS.
Root сообщил LIVE affected-case ДО reload этого patch: QA Лейла Беллини,
`npc_unique_leila`, скорость0, стоит с оружием у охраны, route pending,
waitMs259800. Это наблюдение root; этот автор GPU не открывал. После reload
нужно проверить именно этого босса и его маршрут.

## Выдержки для внешнего Астра2 через Проверщик ЧАТОВ2

Нужен read-only review semantic mapping и native route contract, не новый AI.
Файлы/функции выше локальны; эти фрагменты дают минимальный контекст без repo.

```js
// world.html: актуальная политика targets (пока НЕ меняли)
function _empireActivityTarget(empire) {
  const activity=empire?.activity||{},id=String(activity.target_id||'');
  if(Number.isFinite(+activity.target_r)&&Number.isFinite(+activity.target_c))
    return _nearestEmpireWalkPoint(+activity.target_r,+activity.target_c);
  const business=BUSINESS_POIS.find(b=>b.id===id);
  if(business){const anchor=_businessInteractionAnchor(business);
    return _nearestEmpireWalkPoint(anchor.r,anchor.c);}
  const coords=id.match(/^(\d+),(\d+)$/);
  if(coords)return _nearestEmpireWalkPoint(+coords[1]*10+6,+coords[2]*10+6);
  const rival=_npcEmpireById.get(id);
  if(rival)return _nearestEmpireWalkPoint(+rival.hq_r||0,+rival.hq_c||0);
  return _nearestEmpireWalkPoint(+empire?.hq_r||0,+empire?.hq_c||0);
}
```

```js
// Реальная новая дверь уже доступна через resident-access/list:
// npc_resident_building_access.mjs (существенные строки)
const binding=/^(business|bank|major|blackmarket):(.+)$/.exec(
  String(entry.instance.gameplayId||''));
const door={id:'native:'+entry.instance.id,native:true,
  instanceId:entry.instance.id,sourceKind:binding?.[1]||'native',
  sourceId:binding?.[2]||entry.instance.id,
  sourceAliases:binding?[binding[0]]:[],
  r:outside.z/worldScale,c:outside.x/worldScale};
// Получение: _walkTrafficNavigationResolver({mode:'resident-access',action:'list'})
// Не все logical building keys имеют gameplayId alias: здесь нужен явный
// binding authority, не ближайшее случайное здание.
```

```js
// world.html: actual native selection, pending semantics
if(native&&(kind==='building_entry'||kind==='civilian_road_exit'||kind==='civilian_bench'))
  return _npcPlanNativeVisitRoute(npc,goalR,goalC,passFn,goalRadius,maxVisited,kind);
// Остальные kind: coarse BFS; passFn проверяет nodes. Retained search:
if(native&&!goal&&search.qi<queue.length&&nodes.size<maxVisited){
  npc._npcDirectedSearch=search;npc._routeSearchPending=true;return false;
}
// APPLIED19 в boss pump, вместо EMPTY/backoff для pending:
if(!accepted&&npc._routeSearchPending){
  npc._empirePendingRoute=request;npc._empireRouteQueued=true;
  npc._empireRouteRetryAt=0;_empireRoutePlanQueue.push(npc);return true;
}
```

```python
# npc_empire.py: серверное адресование пока logical World
def _hq_coords(key):
    br, bc = (int(x) for x in key.split(',', 1))
    return br * 10 + 6, bc * 10 + 6
# state_for: server authority, НЕ переносить в render loop
async with _state_prepare_lock(db_path):
    await ensure_schema(db_path)
    player_war_events = await _apply_player_war_pressure(db_path, telegram_id, now)
    await advance(db_path, now)
```

Вопрос внешнему аудитору: предложить минимальный descriptor/contract связывания
logical target kind+ID с loaded native instance/door, сохраняя server field
anchors и IDs; перечислить missing/ambiguous binding поведение и тесты.
Отдельно проверить допустимость использования existing native directed planner
для empire_action/escort без переопределения ownership/capture/diplomacy.
