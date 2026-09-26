# Vehicle pose host seams / actual 6DOF review

27 сентября 2026. Bounded review после пользовательского LIVE замечания «посадка медленная, анимация некрасивая». Изменений root `preview_transport.gd`, player, transport provider, exporter и production `vehicle_occupant_pose.gd` нет. Новый независимый тест проверяет actual current main/transport pose writer и source-imported city_hatchback wheel/door; никаких GPU запусков.

## Результат

`scripts/tests/test_vehicle_occupant_pose_rotated.gd`: **125 checks PASS**, actual Godot 4.7.2 headless, exit 0, без SCRIPT ERROR. Запуск:

```powershell
& 'C:/Users/Слава/AppData/Local/MafioziTools/Godot-4.7.2/Godot_v4.7.2-stable_win64_console.exe' --headless --path godot/mafiozi_walk --script res://scripts/tests/test_vehicle_occupant_pose_rotated.gd
```

Generated результат: `outputs/coordinator21_npc_port/vehicle_pose_rotated_result.txt`.

Тест инстанцирует настоящую main, использует её existing player, actual imported vehicle/wheel/door и вызывает имеющийся `_apply_transport_pose`. Для seated и staged door-reaching pose сравниваются все bones в vehicle-local frame при identity и двух произвольных yaw/pitch/roll + translations. Test-only физическое движение заморожено; проверяется геометрия позы, не travel/collision admission.

При `player.global_basis = vehicle.global_basis` и `VisualHeading` local `RY(PI)` native pose ковариантна full 6DOF: max vehicle-local bone-position difference **0.000011543 м**, max basis-axis error **0.000017517**. Sample по умолчанию берёт `motion.parent.global_transform`, поэтому actual world grips корректно возвращаются в source +Z hero frame и после pose снова оказываются в правильном мире. Двойной yaw/roll внутри sampler не обнаружен. При таком seated root не нужно дополнительно поворачивать grips или добавлять ещё один PI в sampler.

## Подтверждённый резкий переход

Independent sampler на **том же actual wheel** при fold `.8799 → .8801`:

| Режим | Перемещение левой ладони между соседними samples |
|---|---:|
| Текущий source default, без `gripBlend` | **0.270674 м** |
| `gripBlend = smoothstep(.62, 1.0, fold)` | **0.00019063 м** |

Это не ошибка переноса: `createArtistVehicle.poseOccupant` при отсутствующем gripBlend включает actual wheel IK только когда fold>.88. Current root pose_writer не передавал gripBlend на момент review. Уже имеющийся source `npc_vehicle_pose.mjs` использует непрерывную кривую `(fold-.62)/.38` с smoothstep. Для пользовательской более быстрой посадки рекомендуется передать эту кривую из root options; sampler поддерживает её и JS oracle проверяет continuity branch. При SEATED значение равно 1. Epoch не менять на BOARDING→SEATED: иначе теряется cache назначения кистей и head state. Production sampler остаётся source-compatible.

## Остальные root seams, установленные чтением control flow

1. **Первый yaw handoff.** On-foot body обычно имеет yaw 0, а heading хранится у VisualHeading. `_apply_transport_pose` выставляет VisualHeading local yaw PI. Без предварительного переноса current visual heading в body начало boarding может резко сбросить мировую ориентацию. В root перед началом физического provider transition следует перенести текущий heading в actor frame с сохранением мирового visual frame. Далее provider может плавно довести yaw до двери/сиденья. Полный vehicle basis нужен seated; переход от upright к наклонённому сиденью тоже следует учитывать отдельно, а не делать дополнительный sampler rotation.
2. **Grips обновлялись на кадр позже рук.** Current tick вызывал pose_writer до финального `set_door_amount` и `update_wheels`. Таким образом, sampler видел предыдущий hinge/wheel transform, а rendered controls затем двигались. Root следует сначала получить transition pose, применить соответствующие текущему кадру hinge/wheel transforms, затем **один раз** вызвать pose writer. Второй дополнительный вызов не эквивалентен: source head smoothing state изменится дважды.
3. **Approach без gait.** Authority vehicle выбиралась уже на APPROACH, тогда как player `_update_owned_pose` работает только on_foot; тело продолжало двигаться к двери. Это объясняет возможное скольжение в неподвижной позе до entry. Root нужен явный single-writer подход к approach gait; нельзя одновременно включить vehicle sampler и player locomotion.
4. **Уход из полного 6DOF.** После принятия full vehicle basis возврат on_foot должен восстановить upright basis полностью и передать yaw в visual/heading. Старое `player.global_rotation.y = 0` сбрасывает только yaw и оставляет roll/pitch после наклонённой машины; тот же риск в session-replaced cleanup. Это требуется проверить root вместе с его изменением seated attachment/collision lease.

Скорость 1.2 с относится к source transport timing/provider, которым владеет Transport3. Этот review не меняет длительности и не выдаёт более короткую анимацию за исправление authority. Headless тест подтверждает pose math и один конкретный seam; красоту итоговой посадки, форму движения body и дверные коллизии должен подтвердить root в единственном LIVE окне.
