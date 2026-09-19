# Аудит доставки клика личной карточке — Координатор 17

13 сентября 2026. Исполнитель: subagent `mercenary_input_audit`. Прочитан COORDINATOR_17_HANDOFF.md. Браузер/GPU не использовались. Ruflo/ToolSearch отсутствуют в доступном каталоге инструментов; использована файловая память.

## Итог

Причина отсутствия LIVE `lastPointer` у `#walk-player-hud` **не доказана**. Не менялись click routing, mercenary IDs, UI, разрешения или обработчики мыши. Отдельно доказан и по дополнительному поручению root исправлен конфликт Space с нативной активацией кнопки.

## Что следует из кода

- `walk_player_hud.mjs:59` пишет host `lastPointer` в capture phase до button callback. Callback `:64` пишет `lastAction` до проверки разрешения действия. Поэтому отсутствие обоих атрибутов нельзя объяснить отказом `openMercenaryMember`, `permitted` или controller lock.
- `walk_hud_controller.mjs:42` вызывает `openMercenaryMember` до `lock(true)`. `lock` (`:39`) меняет состояние/отпускает игровой ввод, но не ставит перехватчики событий HUD.
- Карточки повторно используются: `walk_player_hud.mjs:89` создаёт button лишь при новом key, `:105` переставляет только при изменении позиции. Нет безусловного пересоздания карточки каждые 200 мс. Реальный transient unavailable state может удалить карточки, но это не объясняет отсутствие host pointerdown, если событие было отправлено в подключённого потомка host.
- Найденный глобальный capture blocker указательных событий — `render_freeze_qa.mjs:30–38`, только при active hold. Создание gated localhost + `perfqa=1` (`:3–9`). Переданный root URL из handoff не имеет `perfqa=1`, поэтому для **этого точного URL** blocker вообще не создаётся. После добавления perfqa для FPS читать `body.dataset.renderFreeze` и прекращать hold перед проверкой карточки.
- Canvas editors в world.html перехватывают свои canvas, отдельные модальные окна — свои DOM subtrees. Это не ancestors `#walk-player-hud`, добавляемого прямо в body (`walk_hud_controller.mjs:34`). Обычные bubbling listeners source UI также не объясняют отсутствующий HUD capture.

## Проверяемая гипотеза мыши

Pointer lock перенаправляет реальный ввод в renderer canvas. `elementFromPoint` лишь подтверждает геометрическое положение карточки и не исключает захват указателя. `walk_preview.mjs:1593` запрашивает lock при клике сцены; `:1586` корректно учитывает shadowRoot.pointerLockElement.

До проблемного клика прочитать только DOM:

```js
({
  documentLock: document.pointerLockElement?.id || document.pointerLockElement?.tagName || null,
  shadowLock: document.querySelector('#mafiozi-walk-host')?.shadowRoot?.pointerLockElement?.tagName || null,
  active: document.activeElement?.outerHTML?.slice(0,300),
  mouseLook: document.body.dataset.mouseLook,
  renderFreeze: document.body.dataset.renderFreeze,
  lastPointer: document.querySelector('#walk-player-hud')?.dataset.lastPointer
})
```

Если lock есть, обычным UI Escape отпустить и повторить click, проверив оба lock поля. Если lock отсутствует, эта гипотеза опровергнута для данного клика. Само открытие HUD через TAB уже должно отпускать lock (`walk_player_hud.mjs:69` → controller onOpenChange → `walk_preview.mjs:1819`); поэтому наличие lock после TAB нельзя объявлять установленным по коду. Последующий клик сцены может захватить его заново. Доставку CUA в нужный tab/документ подтвердить отдельным видимым HUD control и существующей диагностикой host; не подменять проверку программным `.click()`.

## Доказанный конфликт клавиатуры и исправление

До исправления actual основной listener `walk_preview.mjs:1450` исключал INPUT/SELECT/TEXTAREA и contenteditable, но не BUTTON. В ветке Space выполнялись preventDefault, beginJump и keys.add. Это блокирует native Space activation на сфокусированной кнопке и объясняет неудачу такого fallback независимо от причины мышиного сбоя.

Добавлена **одна строка** в `walk_preview.mjs:1451`: для Space с BUTTON в composedPath (либо target) вернуть управление, сохранив нативную активацию. Все прочие игровые клавиши и canvas Space продолжают прежний путь. Общий файл содержит чужие изменения: не переносить весь git diff как работу этого аудита.

`world.html:70340–70344` также перехватывает Enter на capture window, исключая поля ввода, но не BUTTON: открывает chat с preventDefault + stopImmediatePropagation. Этот независимый конфликт зафиксирован, **не исправлялся** по scoped поручению root.

## Проверка

Новый `assets/maps/city_rebuild_v1/test_walk_hud_keyboard_activation.mjs` исполняет actual handler, извлечённый из production source через VM. До исправления RED: BUTTON → `{prevented:true,jumps:1,held:true}`. После исправления GREEN: BUTTON и BUTTON в composedPath не prevented, без jump/held; INPUT/TEXTAREA/SELECT/contenteditable сохраняют прежний отказ; canvas Space вызывает прыжок; repeat его не повторяет.

После изменения 7 suite PASS:

- test_walk_hud_keyboard_activation.mjs
- test_jump_keyboard.mjs
- test_walk_shadow_mouse.mjs
- test_walk_player_hud.mjs
- test_walk_hud_controller.mjs
- test_cover_walk_input.mjs
- test_window_walk_input.mjs

Изменение работает только на событии Space, без работы за кадр. Производительность общей сцены не проверена; FPS не заявлен. LIVE карточка и доставка указательных событий остаются на проверке координатора, GPU слот не занимался.
