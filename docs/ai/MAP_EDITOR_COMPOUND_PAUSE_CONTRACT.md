# Совместная остановка и возобновление владельцев редактора Godot

Source-only candidate, 27 сентября 2026. Production/main/GPU не изменялись.
Frozen `scene_pause_owner.gd` (25 + actual-source 16) и
`animation_pause_adapter.gd` (17) сохранены без изменений.

## Подключение владельцем игровой сцены

Новые файлы в `tools/godot/map_editor_candidate/scripts/map_editor/`:

- `scene_pause_owner_v2.gd` наследует frozen scene owner, сохраняет explicit
  Node/Timer/RigidBody3D inventory, exact metadata/parent/lifetime и реальные
  callbacks source support/nav/water/authority.
- `animation_pause_adapter_v2.gd` наследует frozen animation owner. Нужны
  explicit AnimationPlayer и pose_targets; без stop/play/seek/advance.
- `compound_pause_owner.gd` принимает оба уже настроенных child owners и
  обязательный bound trusted `external_inventory_gate(phase, details)`.

`compound.callbacks()` имеет шесть обработчиков HostAdapter:
`pause_gameplay`, `cancel_pause`, `verify_pause`, `resume_gameplay`,
`transaction_ready`, `ground_patch`. Root передаёт этот словарь в
`EditorHostAdapter.mount(current_main, callbacks)`.

Оба child owner `prepare_pause` возвращают issued `RefCounted` capsule,
связанный именно с их текущим private snapshot. Поддельный/чужой handle
отклоняется; JSON и сохранённая карта никогда не дают pause authority.
`preflight_restore(handle)` читает состояние, не вызывает owner callbacks,
не изменяет clocks, поля, flags или frame barrier. `hold(handle)` удерживает
только ещё принадлежащие прежнему lifetime участники. Новую generation или
переподчинённый узел не присваивает себе.

## Обязательный внешний gate — не заглушка готовности

| Phase | Что настоящий владелец обязан подтвердить |
| --- | --- |
| `pause` | Полный текущий inventory; собственные NPC/async query/audio/deferred/particles/traversal owners готовы к остановке. Missing NPC capsule — отказ до mutation. |
| `ready` | Все эти owners продолжают held; jobs/bakes/deferred query completions действительно quiescent по owner receipt. READY nav map сам по себе не означает это. |
| `resume` | Новые object/ground документы admitted реальными source owners; support, nav, water, authority и placement leases пригодны для возобновления. |
| `cancel` | Оригинальная или owner-repaired сцена по-прежнему имеет реальную support/nav/water/authority admission. Отмена не разрешает запуск тела на удалённой опоре. |

Gate — configure-time trusted callback, не JSON. Вызовы завершаются синхронно
до финальных проверок. Изменивший состояние callback будет обнаружен
повторным preflight; публичный compound reentry во время callback отклоняется.
Для NPC production сейчас нет публичного checkpoint/pause transaction и
реальный enabled preview остаётся PENDING_PLACEMENT. Этот gate обязан отказать,
пока владелец NPC не предоставит настоящую capsule. Нельзя подставить `true`,
назвать VALIDATING готовым path или считать main.set_physics_process(false)
остановкой engine async callbacks.

## Финальная последовательность

1. Реальные owner admissions/callbacks, включая resume support validation.
2. Read-only preflight **всех** child owners; при отказе второго первый не
   восстанавливается. Сохранённые capsules остаются для owner repair.
3. В том же synchronous call/frame, без await или owner Callable:
   `scene.apply_restore`, `animation.apply_restore`, postflight обоих.
4. Только после двух успешных postflight — `finish_restore` обоих. Иначе
   re-hold обоих ещё принадлежащих inventory owners и retained fault.

Restore пишет только exact первоначальные engine processing flags,
Timer.paused, body freeze/freeze_mode/sleeping и mixer.active. Не пишет
source fields, pose, velocities, collision filters или clocks: они должны
оставаться прежними и пройти preflight. Initially-disabled flags не превращает
в true. Изначально frozen тело остаётся frozen. Никогда SceneTree.paused.
Нет пользовательских callbacks между all-preflight и all-postflight. Native
property setters всё равно принадлежат движку: неизвестный derived script с
побочными setter/signal effects требует отдельной owner admission, а не
обещания подавить произвольные callbacks. Ошибка postflight повторно удерживает
surviving owned actors до возврата результата; stale owners не захватываются.

## Новый source control и owner-authorized recovery

По умолчанию изменившееся **любое** captured field запрещает restore. Новая
server sequence никогда не перезаписывается старой. V2 имеет narrow API:

`scene.configure_control_reconciliation(actual_inventory_owner, bound_callable)`
настраивается до первой lease, один раз. Callable должен быть bound именно
этому live inventory Node и guard_fields обязаны быть explicit. Callback:

`authorize(handle, scene_receipt, current_rows) -> {ok, control_owner_id}`.

`scene.reconcile_guard_fields(issued_handle)` проверяет parent/generation,
неизменные non-guard fields/pose/body/timer clocks до и после callback,
действительность bound source owner, точный control_owner_id и unchanged
current guard values во время admission. При успехе обновляет **только private
capsule** текущими guard values; source fields никогда не пишет. Это разрешает
owner-approved same-payload sequence bump без rewind. Guard fields не должны
содержать clock или поля animation phase.

Changed sequence **и** changed non-guard throttle/steering/brake отклоняются,
не допускается replay старого payload. Для нового полного control packet
нужна новая transaction/session настоящего source owner; candidate не умеет
автоматически заменять authority capsule. Clock changes не чинит. Generation
или parent replacement тоже требуют нового owned session; тестовое возвращение
того же exact исходного parent/generation допускает восстановление прежней
session, не даёт захватить новый lifetime. На retained fault допустим только
owner-authorized `cancel_pause(original_request)`; не обход `transaction_ready`.

## Проверки и границы результата

Команда:

`Godot_v4.7.2-stable_win64_console.exe --headless --path tools/godot/map_editor_candidate --quit-after 1200 --script res://tests/map_editor/test_compound_pause_owner.gd`

Actual native RigidBody3D + CollisionShape3D, Timer и AnimationPlayer:
60 checks PASS. Проверены physical-frame freeze barrier, clocks across frames,
read-only/callback-free preflight, forged handles, вторичный owner refusal,
generation/reparent refusal и exact original owner repair, partial pause cleanup
и retained all-held failure при отказе actual support cancellation admission,
reentry refusal, same-payload sequence bump, новый payload/clock сохраняются
новыми и удерживают оба owners. Финальный отрицательный clock/payload сценарий
намеренно не «чинит» authority назад — fixture уничтожается still-held.

Это CPU-proof coordinator для explicit inventory, не pause всей игры, не
реальная готовность NPC/nav/water и не измерение FPS. ProductionWired=false.
Caller обязан подключить independent early editor input router вне stopped
inventory; main._unhandled_input нельзя делать единственным входом редактора
после его выключения. Один видимый игровой экземпляр остаётся у root21.
