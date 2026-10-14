# Animation/NPC pause inventory: source-only продолжение

27 сентября 2026. ScenePauseOwner 25 + actual source16 frozen не изменён. Новые файлы: `tools/godot/map_editor_candidate/scripts/map_editor/animation_pause_adapter.gd`, `tests/map_editor/test_animation_pause_adapter.gd`, `tests/map_editor/test_scene_pause_npc_admission.gd`. Production/main/nav/NPC source не менялись, GPU/Git не запускались. Не считать отдельный adapter готовой общей остановкой игры.

## Проверенный animation adapter

Native Godot4.7.2: 17 проверок PASS. AnimationMixer — abstract native class (ClassDB.can_instantiate=false); его реальный API проверен через concrete AnimationPlayer, не вымышленный базовый instance.

API: `configure(current_main, explicit_inventory)`, `pause() -> {ok}`, `verify() -> bool`, `restore() -> {ok}`, `state() -> {paused,fault,resource_changed,busy}`. Все операции только main thread. Inventory:

```gdscript
{
    "mixer": actual_animation_player,
    "identity": {"source_id": existing_source_id, "life_generation": existing_generation},
    "pose_targets": [{"node": actual_target, "properties": ["transform"]}]
}
```

Владелец явно передаёт полный список mixers и animated properties. Adapter не угадывает детей/actor ownership. Mixer+pose targets должны принадлежать текущему main, тот же parent/instance/generation сохраняется. Pose targets это verification, не разрешение переписать позу при чужом изменении.

Pause меняет только AnimationMixer.active=false: **не вызывает** stop/play/pause/seek/advance, поэтому нет restart/seek-to-recreate blend. Сохраняет native current/assigned animation names, position/length, playing flag, speed_scale/playing speed, queue, section bounds, autoplay/auto_capture/blend options, mixer callback modes, root-motion values/accumulators, target poses. Initially inactive Player остаётся inactive после restore. Native test держит playing animation с speed_scale1.7×custom speed0.6 и queued animation; 10 engine frames не меняют phase/pose, после restore clock продолжается с той же точки.

Resource identity и libraries/animation list проверяются. Resource.changed на AnimationLibrary/Animation устанавливает dirty: изменённый shared resource не выдаётся за сохранённое качество. Adapter не мутирует/клонирует Mesh/Material/Animation ресурсов. При changed resource нужна настоящая source-owner repair/session replacement; автоматического fake-restore по сохранённому имени нет. Lifetime/pose parent drift отказывает restore, оставляет owned mixer inactive; после exact parent/generation repair restore допустим.

AnimationTree требует собственного state-machine/blend-stack owner, пока explicitly refused. Manual `advance()` callers должны быть остановлены собственным Node/clock lease: active=false останавливает native auto processing, не запрещает владельцу вручную advance. Audio voices/deferred method-track side effects и GPU particles этим adapter не останавливаются. Их callbacks/resources требуют отдельных реальных owner receipts. Тест не доказывает полный animated actor inventory или source authored rigs/GPU pixels.

Команда:

```powershell
& 'C:/Users/Слава/AppData/Local/MafioziTools/Godot-4.7.2/Godot_v4.7.2-stable_win64_console.exe' --headless --path tools/godot/map_editor_candidate --quit-after 1200 --script res://tests/map_editor/test_animation_pause_adapter.gd
```

## Совместный caller: условия до подключения

Frozen ScenePauseOwner deliberately refuses AnimationMixer участников: animation adapter должен владеть ими отдельно, обычные process flags не заменяют active=false. Root compound pause owner должен захватить общий receipt и удерживать body/node lease, пока animation owner не подтвердил phase. Host.verify_pause обязан требовать **оба** verify; transaction_ready ещё и real NPC/nav/water readiness.

Если pause любой части отказал, root должен откатить обе либо оставить весь inventory stopped и recovery. Нельзя сначала успешно вернуть body physics, а затем обнаружить отказ animation restore. Нужен all-owner restore-preflight для compound coordinator; frozen ScenePauseOwner не предоставляет отдельного prepare_restore, поэтому safe compound rollback при partial failure ещё требует narrow approved extension/owner orchestrator. При отказе второй restore сохранять/reassert первую паузу до следующего physics frame. Нельзя заменять это callbacks `{ok:true}`. Никакого main/Host wiring здесь не выполнялось.

## Реальный NPC-enabled main: что найдено

`test_scene_pause_npc_admission.gd` запускает настоящий `res://scenes/main.tscn` с preview_residents_enabled=true. Native6 admission-negative checks PASS:

| Наблюдение | Реальное значение |
| --- | --- |
| main preview_ready | true |
| population_status | pending_placement |
| admitted source rows | 3 |
| реально созданные NPC occupants | 0 |
| source IDs / причина | resident_72, resident_169, resident_252 — support_unknown, PENDING_PLACEMENT |
| nav state/jobs/bakes/records | READY / 0 / 0 / 0 |
| 8NPC stable while paused | НЕ ПРОВЕРЕНО: таких 8 NPC в текущей admitted main-сцене нет |

Не создавались подставные residents, clones или guessed placement. Actor cache и source IDs не заменены. Missing NPC/nav pause receipt привёл к явному отказу editor entry **до** изменения flags/body/phase; actual game состояние осталось прежним. Наличие будущего метода само по себе не выдаётся за readiness.

Команда (source read-only, headless):

```powershell
& 'C:/Users/Слава/AppData/Local/MafioziTools/Godot-4.7.2/Godot_v4.7.2-stable_win64_console.exe' --headless --path godot/mafiozi_walk --quit-after 1200 --script 'C:/Users/Слава/Desktop/Мафиози/tools/godot/map_editor_candidate/tests/map_editor/test_scene_pause_npc_admission.gd'
```

## Точные существующие API и отсутствующий owner contract

| Реальный метод | Почему его недостаточно / требуемая новая гарантия |
| --- | --- |
| preview_population.gd `step(delta)` → navigation.pump + residents.step | Main._physics_process stop остановит вызовы, но не deferred server callbacks. Нет public population pause/checkpoint/resume capsule, no owned pending-query receipt |
| preview_resident_host.gd `snapshot()`, `occupants()` | Diagnostics/current positions; не сохраняют gait blend/clock, request ID, source owner lifecycle для exact resume. `dispose()` уничтожает actor bodies/ownership — не pause |
| preview_navigation_host.gd `state()`, `diagnostics()`, `cancel(id)` | Общий READY означает map, не все jobs. Cancel меняет record registry и body velocity; не выдаёт восстановимый old job/path/gait capsule. Нельзя отменить все queries и назвать exact unchanged resume |
| preview_engine_navigation.gd `diagnostics()` | Показывает jobs/bakes_inflight/queued_snapshots/epoch, но jobs включает разные phases/status. Нужен owner read-only pending-phase classification + held-lifetime receipt, не `jobs==0` за доказательство fullNPCpause |
| preview_engine_navigation.gd `_query_callback` → deferred `_finish_query` | Callback может превратить QUERY_WAIT в VALIDATING или terminal status даже без main.pump. Это пока НЕ готовый путь: validation требует pump. Parent Node pause не отменяет callback и не фиксирует immutable receipt |
| engine backend `publish_source()` | Сразу frees old map/invalidates jobs, затем async BAKING/SYNCING. Rebuild/edit rollback по-прежнему требует staged owner, не oldmap destruction |
| PathJobQueue `cancel(owner)`, `dispose()` | Меняют очередь/deadline/epoch, не pause snapshot. Нужен owner protocol сохранить current/batch/wait/deadline и не запускать резервирования после pause |
| ScenePauseOwner Timer support | Реальные explicitly supplied Timer clocks paused без restart. RefCounted NPC/nav cache/queue не Timer и не Node: покрытие надо выдать настоящему owner отдельно |

Предлагаемый новый контракт (имена согласовать с navigation/NPC владельцами, этих APIs **сейчас нет**): prepare_editor_pause(captured actors/jobs/owner generation), verify_editor_pause(receipt), prepare_resume(both documents/native support/nav epoch), commit_resume/rollback_resume. Должен удерживать/отбрасывать async completions по exact epoch/lifetime, сохранять source owner identities + gait state, не выдавать pending/VALIDATING как READY. Root связывает verified compound receipt с Host и принимает pause только после all-owner barrier.

Следующий настоящий тест после owner/package admission: текущие реально admitted 8 NPC + их запросы/позы/gait/timers, supplied RigidBody ragdoll/debris inventory, pause через early input, actual clock/transform/state stable across physics frames, callbacks finishing whilepaused не меняют published source state; failure/reentry/parent/lifetime/source-authority cases. Пока placement/live8 не admitted, не обещать выполненную общую паузу и не менять source authority ради теста. Full-map editor goal не сужен; зависимости передаются Координатору21.
