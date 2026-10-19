# Native editor pause owner — source-only candidate

27 сентября 2026. Для Координатора21. Production main/player не изменены; GPU/Git не выполнялись. Общая миграция/full-map задача остаётся открытой.

## Файлы и реальное доказательство

`tools/godot/map_editor_candidate/scripts/map_editor/scene_pause_owner.gd` — RefCounted explicit owner helper; возвращает callbacks для EditorHostAdapter. `tests/map_editor/test_scene_pause_owner.gd` — настоящие Node/RigidBody3D, clocks/process flags, partial failure, reentry, generation/parent repair. `tests/map_editor/test_scene_pause_actual_preview.gd` — настоящий source main с player/transport/NativeVehicleBody, original map без редактирования, actual source-floor ray admission, held-W polling. Не считать эти тесты завершением pause всей игры: NPC выключены, debris/ragdoll и async NPC/nav владельцы не включены в этот inventory.

Команды (Godot4.7.2, headless):

```powershell
& 'C:/Users/Слава/AppData/Local/MafioziTools/Godot-4.7.2/Godot_v4.7.2-stable_win64_console.exe' --headless --path tools/godot/map_editor_candidate --quit-after 1200 --script res://tests/map_editor/test_scene_pause_owner.gd
& 'C:/Users/Слава/AppData/Local/MafioziTools/Godot-4.7.2/Godot_v4.7.2-stable_win64_console.exe' --headless --path godot/mafiozi_walk --quit-after 1200 --script 'C:/Users/Слава/Desktop/Мафиози/tools/godot/map_editor_candidate/tests/map_editor/test_scene_pause_actual_preview.gd'
```

## Caller API

`configure(main, node_inventory, body_inventory, callbacks)` однократно. Inventory явно выдан существующим игровым владельцем; никакого discovery/find_children, нового actor authority или source override. Все nodes принадлежат main, unique instance IDs; parent и metadata identity фиксируются при configure.

Node descriptor:

```gdscript
{
    "node": existing_node,
    "identity": {"actor_id": actual_id, "life_generation": actual_generation},
    "fields": ["logical_clock", "ticks"],
    "guard_fields": [],
    "stop_process": true,
    "stop_physics": true,
    "stop_input": true,
    "stop_unhandled": true,
    "stop_unhandled_key": true,
    "stop_shortcut": true
}
```

Body descriptor — тот же формат, node только RigidBody3D. Сохраняет и Node callbacks/явные fields, и physics transform, velocities, freeze, freeze_mode, sleeping, custom_integrator, collision layer/mask. `guard_fields` — subset fields, которые запрещено автоматически откатывать при изменении внешним владельцем: например NativeBody `_control_sequence`, `_control_source_clock`. Их drift отказывает restore и удерживает оставшихся собственных участников stopped; owner должен разрешить source authority отдельно. Нельзя списком fields пытаться вернуть server clock/control revision назад. Поля Resource/Object не принимаются; opaque RefCounted NPC lifecycle требует отдельный approved owner adapter.

Явно включённые Timer останавливаются через Timer.paused: ordinary set_process(false) не останавливает их внутренний engine clock. Сохраняется paused, time_left/полуфаза, wait_time, stopped/one_shot/autostart/process_callback; никакого start/stop restart. При чужом изменении Timer phase restore отказывает и удерживает паузу до owner repair. Не включённые child Timer helper не обнаруживает автоматически.

Обязательные callbacks:

| Callback | Конкретная обязанность настоящего владельца |
| --- | --- |
| `admit_pause(request)` | Проверить actual session, complete inventory, safe player/transport phase, отсутствие неподхваченных actor/body clocks. Не менять authority. При отказе никаких node mutations ещё нет |
| `transaction_ready(receipt)` | Проверить Atomic/terrain/nav/water/access/policy состояние и pending receipts; возвращать false пока real dependencies не готовы |
| `validate_resume(receipt, objects, ground)` | Проверить оба validated текущих документа и actual source support/actor clearance, nav READY version, water material/depth receipt, special owner authority. Callback должен **только admit**, не unfreeze участников и не публиковать половину мира |
| `ground_patch()` | Вернуть настоящий admitted GroundDoc patch; actual-preview тест намеренно использует unchanged-source receipt, а не притворяется редакторской картой |

Optional `pause_step({kind,instance_id,request})` — synchronous owner fault/admission hook после каждого реально остановленного Node/body. Отказ возвращает fault с retained capsule; EditorHostAdapter затем вызывает cancel_pause. Это не подмена physics pause: реальные flags/freeze уже установлены.

`callbacks()` возвращает шесть методов для `EditorHostAdapter.mount(...)`: pause_gameplay, cancel_pause, verify_pause, resume_gameplay, transaction_ready, ground_patch. `state()` показывает leased/fault/busy/physics_barrier_ready. Capsule CPU-only приватная, не JSON/publication authority.

## Жизненный цикл и гарантии

Pause проверяет owner_id/request_id, сохраняет **реальные прежние** flags и bodies, отключает выбранные callbacks и freeze=STATIC. Не вызывает clear_control (который будит native body), не меняет velocities/authority/collision filters, не ставит SceneTree.paused. Verify сверяет live parent+metadata generation, flags, explicit clocks, transform/velocities/body properties. Transaction_ready требует хотя бы следующий engine physics frame после stable verify и настоящую readiness callback; один синхронный freeze не выдаётся за physics barrier.

Cancel matching request восстанавливает private capsule. До восстановления всех участников preflight проверяет каждый parent/generation и guard fields; при missing ownership никто не unfreezes. После восстановления проверяются exact restored flags/state. При postrestore отказе re-freeze только всё ещё собственных live participants, retained fault. Не захватывать «нового» actor с тем же именем, не трогать сменившего generation чужого владельца. Повтор cancel после явного owner repair допускается; receipt после успеха становится недействительным.

Resume требует valid settled lease + real readiness + actual support admission; только затем restores body/Node state и возвращает owner_id/request_id. Не переписывает map authority и не rebuild nav/water самостоятельно. Если ground под actor удалён или дом сдвинут внутрь capsule — refusal, не телепортация на старт.

## Input integration нельзя пропустить

Текущий main имеет только `_unhandled_input`; кандидат сам маршрутизацию не добавляет. Root обязан отдельным ранним `_input`/always-on editor node вызывать Host.handle_input **до** gameplay callbacks. Этот routing node не должен быть остановленным participant. Main `stop_input:false` пригоден только после появления такого early router; существующий `_unhandled_input` выключается как gameplay. Даже GUI event не consumed: Host.gameplay_blocked() всё равно блокирует игрока. Сами physics flags остановлены, поэтому held-W polling не двигает player.

InputMap/физические клавиши не сериализуются и не переигрываются: модуль не восстанавливает устаревшее состояние клавиши «нажата». Владелец должен согласовать свои E/jump/RMB latches и Input focus с реальными актуальными клавишами; первый admission может явно отказать active transition/held interaction, но это не отменяет будущую полную поддержку.

## Что нужно включить root до production

- Все real actors, nested RigidBody (vehicle/ragdoll/debris), timers и callback owners. Изолированный список main/player/transport не доказывает полный inventory. Исторические disabled flags восстанавливаются exact, не alltrue.
- RefCounted NPC/navigation clocks не управляются Node flags автоматически. Stop parent caller **и** retain/cancel owned asynchronous work through validated lifecycle receipt.
- AnimationMixer/AnimationPlayer и GPUParticles3D/CPUParticles3D имеют внутреннюю simulation; обычные process flags не являются их паузой. Helper explicitly refuses такие participants, пока настоящий visual/effects owner не выдаст отдельный adapter. Не скрывать отсутствие этих владельцев исключением их из полного inventory.
- Real edited-map support/nav/water/terrain/source-policy admission по `MAP_EDITOR_HOST_CALLBACK_AUDIT.md`; unchanged-map source тест не является callback для изменённой карты.
- Scene generation/session replacement must retire old inventory. Configure новую helper только после owner-authorized replacement; не маскировать lifetime mismatch.
- Main wall-clock perf sample `_last_frame_usec` и input presentation требуют owner-side корректного resume: не считать editor pause frame игровым лагом; helper не придумывает новый source clock.
- Один согласованный LIVE и сравнимые frame-time замеры — отдельно. Никаких новых gameplay «K готово» в preview updates до этого.
