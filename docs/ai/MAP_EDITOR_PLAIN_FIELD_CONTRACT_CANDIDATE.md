# Plain script field admission — HOLD, отрицательный native proof

27 сентября 2026. Frozen synchronous1624 pipeline и owners не изменять.
Отдельный tools-only guard закончен; разрешающего derived pipeline НЕТ.
Production integration и ускоренное чтение script fields НЕ допущены.

Точный inventory от настоящего source owner, configure-time Node+GDScript
references, expected source-code SHA, выбранные поля, original parent/lifetime
metadata. Данные JSON карты не могут выдать этот контракт. Source Script должен
напрямую extends указанный native класс (no base Script/inheritance ambiguity).
Каждое разрешённое поле — direct top-level plain `var`, без getter/setter,
аннотаций/динамической property override либо неоднозначного объявления.

Предварительно рассмотренные реальные кандидаты:

- `scripts/main.gd`: direct Node3D, `_clock:float`, `_runtime_seconds:float`.
- `scripts/preview_player.gd`: direct CharacterBody3D, `_pose_epoch:int`,
  `_jump:Dictionary`, `_jump_pose:Dictionary`.
- `scripts/preview_transport.gd`: direct Node3D, `_clock`, `_sequence`,
  `_e_down`, `phase`, `_pending_exit`.
- `scripts/vehicle_physics/vehicle_native_body.gd`: direct RigidBody3D,
  `_control_sequence`, `_control_source_clock`, `_throttle`, `_steering_input`,
  `_brake`, `_handbrake`, `_physics_tick`.

Это не whitelist по названию поля: разрешение только для admitted exact
Script/resource/source hash и конкретного instance/parent/generation.
Read-only getters не означают право менять packet, clocks либо authority.
Control packet согласованность остаётся обязательной в исходном pause capsule.

На каждом dispatch ДО field get/native owner preflight сравнивать текущее
`Script.source_code` с exact сохранённым source String, Script instance и
node binding. FileAccess и hash больших source strings на mousemotion не
использовать. Replacement, source change, getter/inheritance/hot-reload
неоднозначность — retained HOLD; не invoke подозрительное поле и НЕ передавать
событие старому Host. Такой fallback сам может прочитать изменённый getter.
После каждого настоящего owner Callable снова field-contract admission до
full all-owner postflight, иначе retained freeze, не чтение нового getter.

Критическая дополнительная проверка перед реализацией: source String может
отличаться от уже скомпилированного bytecode после reload и обратной подмены
source text. Нужно native evidence о Resource.changed/reload notifications и
compiled getter metadata; если native API не даёт надёжного hot-reload proof,
этот случай честно запретить/требовать source-owner session lifecycle barrier.
Нельзя назвать обычную source String equality доказательством bytecode в таком
случае. Изолированный native probe будет определять фактический контракт.

## Реально воспроизведённая причина отказа

Godot 4.7.2, headless, `test_plain_field_hot_reload_gap.gd`: 11 PASS.
Сначала компилируется обычный `var clock := 0` и существующий `read_clock()`.
Затем поле компилируется с `get = read_clock`; после этого исходный source text
возвращается БЕЗ reload. Получается одновременно:

- тот же GDScript resource/instance, source String и SHA;
- тот же base script/native base, method list и property list;
- `Resource.changed` не сообщает ни source setter, ни reload;
- чтение `clock` всё равно вызывает getter и возвращает 9 вместо 0.

Именованный getter не имеет отличительного generated getter method в этом
случае. Native публичные API, исследованные probe, не выдают достаточный
compiled-member generation/bytecode proof. Source hash, имя поля, regex,
Resource.changed и equality исходного текста НЕ являются attestation.

Это касается также reviewed Host, Workspace, Controller, Camera и самих
scripted owner helpers: совпадение их source text после reload не доказывает
неизменность исполняемой ветки. Frozen synchronous 1624 — результат native
fixture, не разрешение на production lifecycle. Actual main positive proof
не проводился: соответствующий lifecycle prerequisite отсутствует.

## Завершённый отрицательный helper

`tools/godot/map_editor_candidate/scripts/map_editor/plain_field_hold_guard.gd`
имеет только `configure(owner, source_bindings, native_hold_inventory)` и
`before_input()`. Configure принимает явные live Object/Script references,
SHA, полную base chain, выбранные поля, parent/instance/lifetime metadata.
Conservative source-shape screening отказывает неоднозначным declarations,
getter/setter/inherited fields; это screening, НЕ compiled plainness proof.

Configure `ok:true` означает только `configured_only:true`, `state:HOLD`,
`compiled_plainness_attested:false`. Before-input ВСЕГДА возвращает HOLD,
`legacy_authorized:false`, не читает ни одного script field и не вызывает
старый Host/owner Callable. Текст сравнивается напрямую; FileAccess и hashing
на каждом событии отсутствуют. Выявленная mutation оставляет retained fault;
возврат текста или metadata не очищает его. Разрешающего переключателя нет.

Явно переданные surviving native participants удерживаются native-флагами:
process/input off, Timer paused, RigidBody frozen, AnimationMixer inactive.
Новые parent/generation/foreign nodes не присваиваются. Guard не восстанавливает
clocks, control payload, позы/velocity/filters и не заменяет compound pause
receipt или owner-authorized recovery. Caller обязан сохранить редакторную
паузу/маршрут ввода отдельно и не трактовать HOLD как разрешение старому Host.

`test_plain_field_hold_guard.gd`: 21 PASS, реальные RigidBody3D + Timer +
AnimationPlayer; alias getter reload, возврат текста, Script replacement,
parent/generation, SHA, inheritance, off-thread refusal. Getter invocations 0,
legacy Host invocations 0. Fresh guard с идеально совпавшим text также HOLD.

Для дальнейшего разрешения нужен настоящий configure-time source owner,
контролирующий первоначальную compile/load и ВСЕ reload/source-code changes
на протяжении lease, либо достаточная native compiled-member attestation.
Generic trust bool/обещание не менять скрипты такой контракт не создают.
NPC/nav/water quiescent capsules остаются отдельными mandatory gates.
Нет whole-game pause approval; main/player/transport/GPU/Git не изменены.

## Read-only actual source inventory

Снимок SHA-256 27 сентября; production source может меняться другим владельцем.
Это inventory, не runtime admission и не lifecycle capsule.

| Source в godot/mafiozi_walk | SHA-256 |
| --- | --- |
| scripts/main.gd | 9C8965C0FE530E5836FC4BE85B7E7C5F265C7985BC3C955110AB081F318CB6FE |
| scripts/preview_player.gd | 63E9560F7F463D24F7844FEB109FB701EE419A04F44E34D6AAF2C78C9A3B9BA2 |
| scripts/preview_transport.gd | 4ABD577E319E198CE2D6155E6A4FB4F968A3A7CA303497735D1A983F320EC15A |
| scripts/vehicle_physics/vehicle_native_body.gd | A382537914FE9494B72C042A35D9BA76948AB90FB79397E05767DD9D7CA59401 |

Отсутствие явных reload/set_script вызовов в этих файлах не исключает editor,
engine или привилегированные внешние changes. Поэтому blanket plainvar
allowlist по именам реальных полей не реализован.

## Воспроизводимый прогон

Из workspace PowerShell, без GPU и production writes:

```powershell
& 'C:/Users/Слава/AppData/Local/MafioziTools/Godot-4.7.2/Godot_v4.7.2-stable_win64_console.exe' --headless --path tools/godot/map_editor_candidate --quit-after 1200 --script res://tests/map_editor/test_plain_field_hot_reload_gap.gd
& 'C:/Users/Слава/AppData/Local/MafioziTools/Godot-4.7.2/Godot_v4.7.2-stable_win64_console.exe' --headless --path tools/godot/map_editor_candidate --quit-after 1200 --script res://tests/map_editor/test_plain_field_hold_guard.gd
```
