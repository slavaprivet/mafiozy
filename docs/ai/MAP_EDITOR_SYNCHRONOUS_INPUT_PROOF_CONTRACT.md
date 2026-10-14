# Одноразовый synchronous motion proof — candidate, не production

## Поздний native admission gap: production HOLD

27 сентября readonly native probe подтвердил: GDScript `source_code` setter
и `reload(true)` не испускают Resource.changed. Компиляция named getter через
существующий метод и восстановление исходного source text без reload оставляют
Script identity/source SHA/method/property lists прежними, но исполняемый getter
новым. Следовательно нижеописанные identity/source guards и1624 fixture checks
НЕ доказывают неизменность compiled code reviewed Host/Controller/Camera либо
captured source-field accessors. До подключения нужен настоящий root-owned
sealed code lifecycle, предотвращающий/учитывающий ВСЕ reload/source writes
в течение lease. Его пока нет; actual-main fast route остаётся HOLD.

Обнаруженная смена кода уже admitted session требует retained fault/hold ДО
вызова old Host: old route тоже может прочитать изменённый script getter.
Fallback ниже допустим только для изначально не admitted inventory, не как
восстановление доверия после code replacement. Не принимать bool/hash/signal
как замену lifecycle owner. Probe11PASS описан агентомcontrols отдельно.

27 сентября 2026. Новый независимый
`tools/godot/map_editor_candidate/scripts/map_editor/synchronous_motion_pipeline.gd`.
Frozen Host/Workspace/Controller/registries/pause modules не менялись.

## Область допустимого применения

Только native `InputEventMouseMotion` без script, object-mode, существующий
редактор с подтверждённой held lease и теми же instance/parent/issued child
capsules. Нет ускорения K, click/RMB release, save/load/import, mutations,
ground mode, atomic install, cleanup/recovery или неизвестного owner.

`configure(host, workspace, compound, scene_v2, animation_v2)` требует именно
reviewed module Scripts, не произвольные subclasses. Exact current
Controller/Camera/Panel экземпляры и родители запоминаются; смена binding,
script или появление ребёнка у editor camera отказывает. Camera-only native
motion branch не вызывает source owner callbacks, не выбирает/меняет карту.
Script hot-reload требует уничтожить admission и пересоздать pipeline в новой
owner session: нельзя объявлять старый proof новой проверкой кода.

`Workspace._transaction_ready` должен быть **точно Host.transaction_ready**.
Если root передал дополнительный ground/Atomic readiness Callable, этот
candidate отказывает, не обходит gate. Для него потребуется отдельно
admitted callback barrier с mandatory all-owner postflight. Блокирующие
Workspace cleanup/recovery и Controller atomic flags продолжают учитываться.

`admit_current_lease()` проверяет исходные receipts/request и обе issued
RefCounted capsules. Captured scene fields и animation pose fields должны
быть нативными property из ClassDB. Unknown script getter field отказывает
**без его вызова**. Scripted/derived AnimationPlayer отказывает. Это осознанное
ограничение: public API Godot не доказывает effect-free произвольный getter.
В частности, script `_clock`, throttle/control dictionaries настоящего
NativeVehicleBody/NPC пока не получают этот fast-proof. Нужен explicit
trusted source-owner readonly contract, не bool из JSON и не guessed cachetrue.

## Что изменяется внутри одного input call

Root после owner admission может вызвать `try_motion(event)`:

1. Initial **обоих** owners preflight. Все source parent/lifetime/flags/body/
   timer/animation/resource/pose checks остаются настоящими v2 checks.
2. Выдаётся opaque RefCounted token, bound к private current call sequence,
   callback epoch, owner request/receipts, обеим issued capsules, текущему
   main-thread process/physics frame. Consume один раз; повтор/подделка/
   off-thread/outside-call/across-event/across-frame запрещены.
3. Перед **каждым** external owner Callable token уничтожается. Флаг inflight
   запрещает даже новое internal diagnostic issuance во время callback.
   Host/Compound/оба child owners reentry закрыт на всё время callback.
4. После scene transaction_ready Callable — mandatory full postflight **обоих**
   owners, даже если owner callback уже поменял route binding или отказал.
5. После mandatory external gate ready Callable — снова full postflight **обоих**.
   Каждый успешный postflight выдаёт новый одноразовый proof; прежний не оживает.
6. Только exact reviewed native-motion Controller method выполняет focus/
   pointer GUI guards, camera/drag bookkeeping. Никакого следующего owner
   Callable нет. На выходе proof уничтожается и synchronous scope закрывается.

Итого initial+2callback postflights = **3 all-owner проверки** вместо 6scene+
4animation проходов old Host/Workspace route. Нет межсобытийного или
межкадрового кеша результатов. Receipt token не заменяет реальную проверку
состояния перед каждым событием и после любого owner callback.

Root router использует result:

- `eligible:false` — **прежний Host.handle_input(event)**, без пропуска его
  checks. Не запускать camera напрямую.
- `eligible:true` — вернуть `handled`, не выполнять второй раз старый маршрут.
- unready owner — pending, событие поглощается, camera keys очищаются как в
  Workspace; held lease сохраняется без выдуманной готовности.
- callback изменил Timer/control/pose/lifetime/binding — retained Host+Compound
  fault, оба ещё принадлежащих owners hold; source clock/control не переписываются.
  Нужна owner-authorized recovery/new session, не автоматическое продолжение.

Состояние scene/animation fault учитывается отдельно от их cancellation
preflight (который может быть пригоден только для repair). Token не разрешает
возобновление игры или nav/water/NPC readiness. Mandatory external capsule gate
остаётся тем же настоящим root-owned callback. Тестовый `true` допустим только
в isolated native fixture, не для production.

## Native conformance и стоимость

`test_synchronous_motion_pipeline.gd`: **1624 PASS**, Godot4.7.2 headless.
50 настоящих RigidBody3D+shape, 8Timer, 8AnimationPlayer, реальные frozen
Host/Workspace object branch/Controller, новые v2/Compound callbacks.
Same inventory/camera/settings, warm alternating old/candidate120samples:

| Route | p50 us | p95 us |
| --- | --- | --- |
| Old inclusive Host route | 4366 | 5251 |
| Candidate one-call motion | 2436 | 3092 |

CPU уменьшился примерно44% p50 /41% p95. Измерение содержит те же callback
conformance probes в обоих маршрутах. Это не FPS и не full-game NPC scene.

Проверены forged/reused/out-of-call/off-thread tokens, issuance/consume
запрещены внутри callbacks, callback dispatch reentry, GUIfocus/pointer,
click/ground exclusion, changed Workspace readiness callback, pending readiness
clears camera keys. Scene-ready и external-ready callbacks отдельно меняют
real Timer configuration либо real body control-sequence metadata: route
отказывается, тела и mixers остаются held, новый sequence не rewound. Добавление
camera child в callback тоже блокирует route. Unknown custom getter отказывает
без invocation; old Host route остаётся fallback.

Fullground Workspace.setup в этом fixture не claimed: object branch wiring
намеренно изолирован. Actual NPC admission=false; productionWired=false;
GPU/main/Git не тронуты. Whole-map integration остаётся у Coordinator21/root.

Запуск: Godot console `--headless --path tools/godot/map_editor_candidate
--quit-after 1200 --script res://tests/map_editor/test_synchronous_motion_pipeline.gd`.
