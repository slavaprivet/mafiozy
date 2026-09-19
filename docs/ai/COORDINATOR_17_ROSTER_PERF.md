# Аудит стоимости roster — Координатор 17

13 сентября 2026. Подзадача `roster_cost_audit`. Первоначально read-only аудит; после явного разрешения root реализована только гипотеза A. Гипотеза B не реализована. Браузер/GPU и тяжёлые CPU-прогоны не запускались. ToolSearch/Ruflo в доступном каталоге не обнаружены.

## Реализованная A и проверка

- `mercenary_core.mjs`: добавлен `getRecord(id)`, возвращающий свежую глубокую копию одной записи с актуальным `hospitalRemaining`; существующий `getRoster()` не изменён.
- `mercenary_world.js`: только `record(id)` переведён с `core.getRoster().find(...)` на `core.getRecord(id)`. Нет time/frame cache, новых частот или изменения кандидатов.
- Новый `test_mercenary_record.mjs`: actual core parity с прежним getRoster/find, nested skills/cooldowns/weapon/array isolation, немедленная свежесть после XP/upgrade/setWeapon/dismiss/recruit, точные/unknown ID, hospital lifecycle и now без tick.
- Actual source VM A/B использует production `mercenary_world.js`/`mercenary_core.mjs`; baseline меняет обратно только прежний record helper. Проверяются равенство source roster/actions/inventory/identity, HP без tick, aliases, equip/upgrade, command/cancel, cooldown expiry без tick, hospital/countdown и dismiss с возвратом оружия.
- Счётчики actual `copy()` для `getActions` запертой машины при пяти бойцах: **вызовов deep copy 2 → 2; полных roster copies 2 → 0; скопированных member records 10 → 2**. Это структурный подсчёт, не замер миллисекунд или FPS.
- Команда `node --test` для `test_mercenary_record.mjs`, `test_mercenary_core.mjs`, `test_mercenary_world.mjs`, `test_mercenary_walk.mjs`, `test_mercenary_command_ui.mjs`: **54/54 PASS**, общий runner завершился примерно за 0.6 с. В существующем core suite есть лёгкий встроенный 5000-tick CPU check; его времена не используются как оценка FPS общей сцены.

Сцену не перезагружали, чтобы не прервать held A/B координатора. LIVE и производительность общей сцены после A не проверены; это остаётся этапом root после согласованного reload.

## Вывод

`mercenary_command_ui.update()` уже читает source `getRoster()` **ровно один раз** после своих throttle guards. Внутри этой функции нет повторного полного source snapshot для карточек и больницы. Поэтому добавление общего time/frame cache к UI не является обоснованным исправлением.

Есть конкретные лишние работы:

1. Source `record(id)` получает и JSON-копирует весь core roster ради одного бойца. Через `getMember()` это вызывается при `getActions()`, проверках владения update, декорировании NPC и других запросах. Безопаснее добавить свежий single-record accessor в core, чем кешировать весь мир по времени.
2. `adoptCandidates()` раз в две секунды фильтрует и сортирует всех подходящих NPC даже когда все пять профессий уже заняты. Ранний выход после существующих cleanup/occupied сохраняет поведение и устраняет ненужный полный поиск.
3. В одном `mercenary_walk.update()` отдельные UI/dialogue/prompt/aim consumers могут повторно читать source roster. Общий стековый cache требует явных границ мутаций; механически обернуть весь update нельзя.

Это кандидаты уменьшения CPU/allocations. Нет измерения выигрыша FPS. По переданному root профилю renderer доминирует; `healthHud` — составной участок, его p95 нельзя приписывать roster целиком. **Производительность общей сцены не проверена.**

## Фактические цепочки

Ориентиры строк на момент чтения; соседние файлы меняются другими авторами:

- `mercenary_core.mjs:223`: `getRoster()` делает `JSON.parse(JSON.stringify(...))` всего массива, включая skills/cooldowns/weapon и `hospitalRemaining`.
- `mercenary_world.js:20`: `record = id => core?.getRoster().find(...)`.
- `mercenary_world.js:65`: `getMember()` использует `record(m.id)` для проверки hospital; HP и position получает из актуального source actor.
- `mercenary_core.mjs:218–220`: `availableActions()` вызывает source `getMember()` для подходящих действий каждого не госпитализированного бойца; source `getActions()` лишь оформляет результат (`mercenary_world.js:260`).
- Для запертой пригодной машины с одним медвежатником и одним подрывником это до двух полных core roster copies только ради доступности действий. У NPC/сейфа обычно меньше; не следует утверждать копирование для всех пяти бойцов на каждой цели: `validTarget()` фильтрует действия раньше, hospital short-circuit тоже пропускает `getMember`.
- `record()` используется также в `isMercenary`, `ownsUpdate`, `decorateEntities`, XP, equip/dismiss/restore/effects. Map `records` не годится как готовый свежий cache: там сохранены копии, которые могут отставать от `core.update`, XP, hospital или оружия.
- Source `getRoster()` (`world:169`) всегда формирует weapons, всех members/skills/action projections и всех candidates. Кандидаты фильтруются по текущим объектам `NPCS`, состоянию и дистанции. Это реальная проверка источника, её нельзя заменить старым roster из предыдущего кадра.
- `getActions()` сам не вызывает source `getRoster()`: он вызывает **core** roster косвенно через `getMember/record`. Cache только вокруг host `getRoster()` эту цепочку не исправит.

## Стековый reuse: где допустим и где нет

`mercenary_command_ui.mjs:59–68`:

- Закрытая панель читает roster для hospital примерно раз в 300 мс; открытая — не чаще раз в 100 мс. `force=true` обходит эти guards для действий.
- Локальный `const roster=readRoster()` уже передан всем частям рендера. Здесь можно один раз за этот update вычислить `JSON.stringify(currentWeapons)` и передать в два `renderPeople`, вместо вычисления одинаковой строки для каждой карточки. Это чистый локальный reuse без удержания snapshot между вызовами.
- Click listeners намеренно читают заново доступность. `invoke()` выполняет forced update до callback и в `finally` после `await`. Их нельзя объединять: callback может нанять/уволить/экипировать/прокачать бойца, а hospital/HP могут измениться до completion.
- `openMember()` читает roster для проверки, вызывает `setOpen(true)` с forced update, затем forced update персональной карточки. В adapter `openMember()` тоже есть предварительное чтение. Это 3–4 source snapshots при успешном переходе из закрытой панели, но это редкое пользовательское событие, не постоянный render hotspot.

`mercenary_walk.mjs:49–55`:

- `ui.update()` может прочитать один roster.
- `dialogue.update()` при открытом диалоге и своём 300 мс guard читает ещё один через `candidate(id)`.
- Каждые 0.2 с prompt сначала вызывает `nearestCandidate()` (тот может выполнить `adoptCandidates()`), затем `candidate(id)` → полный roster, если кандидат найден.
- Каждые 0.25 с aim читает полный roster только ради `members.length` перед raycast.
- У закрытых dialogue/UI при совпадении сроков и ближайшем кандидате может быть три source roster reads за update: hospital + prompt + aim. Открытый dialogue блокирует prompt/aim через текущие условия, поэтому нельзя суммировать все ветви как четыре обязательных чтения.

Если вводить stack reuse в adapter позже, его безопасный контракт: ленивый read scope только для presentation; snapshot удаляется до любого source callback и в `finally`, не переносится через await или следующий update; смена host тоже сбрасывает scope. Не использовать last timestamp, кадр, RAF или microtask как идентификатор свежести.

Причина осторожности: `dialogue.update()` может вызвать `close()` при исчезновении/death кандидата; `onClose` вызывает `host.endConversation()`, который меняет source NPC, а `onOpenChange` передаётся снаружи. `nearestCandidate()` тоже содержит мутационный adoption. Action listeners должны оставаться вне read scope. Любой общий scope обязан покрыть эти invalidation boundaries, иначе он усложняет корректность ради пока неизвестного выигрыша.

Предпочтительный первый шаг — следующие два точечных изменения, а не общий scope.

## Конкретная гипотеза A: свежий single-record accessor без cache

Внутри `createMercenarySquad` рядом с существующим `getRoster`:

```js
function getRecord(id) {
  const r = roster.get(id);
  return r ? copy({ ...r, hospitalRemaining: Math.max(0, r.hospitalUntil - now()) }) : undefined;
}
// expose getRecord alongside getRoster; leave getRoster unchanged
```

В source adapter:

```js
const record = id => core?.getRecord(id);
```

Это fresh copy только одного бойца, без доступа потребителей к mutable core records. Возвращаемое отсутствие — `undefined`, как у прежнего `.find`. ID не нормализовать дополнительно: существующая точная семантика `record(id)` сохраняется; `raw()/memberKey()` уже отвечают за свои разрешённые aliases. HP и position в `getMember()` по-прежнему читаются из source actor непосредственно при вызове.

Преимущество перед `records.get(id)`: hospital, XP, skills, оружие и dismiss/recruit видны немедленно после source mutation, ничего не нужно инвалидировать. Стоимость копирования одного record вместо всего roster уменьшается структурно; величину runtime/FPS нужно измерять отдельно. На roster из одного бойца выигрыш этого пункта будет небольшим.

Проверки для реализации:

- Deep equality старого `.getRoster().find` и нового `.getRecord` для существующих/отсутствующих ID.
- Изменение возвращённого record/skills/weapon не меняет core.
- Последовательности recruit → getRecord, equip/setWeapon → getRecord, addXP/upgrade → getRecord, hospital/discharge/update → getRecord, dismiss → getRecord не возвращают старое состояние.
- `availableActions` остаются одинаковыми для живого/раненого/госпитализированного/занятого бойца, locked vehicle/safe/fence/revive и cooldown.
- Existing `test_mercenary_core`, `test_mercenary_world`, `test_mercenary_walk`, `test_mercenary_command_ui` после изменения.

## Конкретная гипотеза B: не сортировать NPC без свободной профессии

Внутри `adoptCandidates()` сохранить прежние guard, `lastCandidates=now()`, удаление невалидных кандидатов и формирование `occupied`. Сразу после добавления candidates в `occupied`:

```js
const missing = Object.keys(professions).filter(p => !occupied.has(p));
if (!missing.length) return;
const hired = new Set(gang().map(m => String(m.sourceBotId)));
const choices = /* существующие filter и sort без изменения */;
for (const p of missing) {
  // существующее тело выбора и присвоения NPC
}
```

При полной занятости раньше `choices` вычислялся, но ни одна итерация не использовала его. Cleanup выполняется перед новым return, поэтому исчезновение/смерть/переход кандидата и освобождение профессии сохраняются. Старые `candidateIndoors`, `candidateInTransit`, protected combat roles, personal identity/weapon assignments не менять. Порядок `Object.keys(professions)` тот же.

Нужны проверки: все профессии заняты; после cleanup освободилась одна; candidate indoors/in transit не освобождает её; кандидата нет/он умер/нанят; сохранение NPC object identity, имени, look и личного оружия. Не менять двухсекундный интервал, дальность или число кандидатов ради ускорения.

## Границы передачи

Реализована только разрешённая A в `mercenary_core.mjs`, `mercenary_world.js` и новом `test_mercenary_record.mjs`. `walk_player_hud`, badges и targets принадлежат другим авторам; их не редактировал. B остаётся предложением до рассмотрения root. Повторные snapshots при открытии карточки и общий adapter read scope оставить вторым этапом, если их стоимость подтвердится.
