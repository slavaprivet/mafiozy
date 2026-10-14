# NPC recovery: независимый аудит20

20 сентября 2026. Read-only production аудит, actual male/female GLB CPU.
`npc_actor.mjs` занят автором2: не изменялся. Навигация, gesture и vehicle scope
не проверялись/не менялись. Добавлен только `test_npc_recovery_audit20.mjs`.

## Подтверждённый дефект: прерывание подъёма сбрасывает наклон

Восстанавливающийся NPC мгновенно встаёт почти вертикально, если приходит новый
source stun либо новая подтверждённая смерть. Затем начинается падение с нуля.
Это один класс ошибки continuity, воспроизведённый двумя trigger на обоих GLB.

Сценарий в `assets/maps/city_rebuild_v1/test_npc_recovery_audit20.mjs`:

1. time=10, source stun active с age=1: NPC уже лежит.
2. time=10.01, stun снят, endedAge=0: начало подъёма.
3. time=10.16: NPC ещё почти лежит, идёт recovery.
4. Через 1 мс: новый stun age=0 **или** lifecycle dead с новым key/age=0.

| GLB | Trigger | Скачок visualPivot | Head Y до → после |
|---|---|---|---|
| male | повторный stun | 1.5011096 rad ≈86° | 0.250489 → 1.358721 м |
| male | смерть | 1.5011096 rad ≈86° | 0.250489 → 1.358721 м |
| female | повторный stun | 1.5011096 rad ≈86° | 0.301816 → 1.435210 м |
| female | смерть | 1.5011096 rad ≈86° | 0.301816 → 1.435210 м |

Во всех случаях проверены неизменные world root=(4,0,-3), yaw=.4, identity
смонтированного weapon object, длины/scale реальных костей. Поэтому скачок —
не teleport source координат и не повреждение skeleton/оружия.

Причина: `npc_actor.mjs:205` при новом active stun без учёта незавершённого
recovery ставит `sourceDown.at=time`. `:213–215` переключает на fall age=0;
`hero_artist14_pose.mjs:16` даёт weight=0 и upright нейтральную позу. Fresh death
аналогично получает новый `sourceDeathAt` в `npc_actor.mjs:191`, отключает
sourceFall (`:215`), затем age=0 death pose обнуляет текущий наклон.

Минимальное направление fix для владельца2: сохранять текущий авторский вес
fall/recovery при переключении, а новый fall/death визуально начинать с этого
веса. Не менять source timestamps, dead/stun semantics и root. Presentation
offset/transition должен отдельно учитывать absolute age и save/restore.
Простое изменение deathAt в будущем ломает first-frame corpse/timestamp
hydration; его делать не следует. Это предложение, fix в данном аудите НЕ применён.

## Что прошло

- Новый audit20: male/female confirmed head injury → короткий stun → release
  сохраняет наклон → восстановление/ходьба. Bruise сохраняется, receipt не повторён.
- Male/female recovery сохранён и восстановлен после 30 секунд отсутствия:
  истёкшая реакция не переигрывается, NPC вертикален и unlocked для ходьбы.
- `test_npc_death_all.mjs`: PASS, 24 source families, 9 edge cases, 71 catalogue
  entries, 26 posed roles; старые corpses, clocks, first-frame/respawn/cull.
- `test_npc_surface_state.mjs`: PASS с offline setup; сериализация, травмы,
  receipts, 45-second wet aging, corpse, atomic-invalid cases.
- `test_npc_pose_continuity.mjs`: PASS 8 сценариев continuous slow frames,
  реальных hidden gaps и reentry. Они не покрывали повторный stun в подъёме.

Полный новый тест сейчас ожидаемо красный: 4 PASS, 4 FAIL именно continuity.
Команда: `node --test assets/maps/city_rebuild_v1/test_npc_recovery_audit20.mjs`.
Отдельно passing subset после добавления injury assertions: 4/4 PASS,
`--test-name-pattern='short source|long skipped'`. Прежние three suites PASS.

GPU/LIVE и производительность общей сцены не проверены. Числа высот/углов —
actual GLB/controller CPU доказательство; это не визуальная приёмка всей игры.
Owner2/root должны согласовать fix; параллельных production правок нет.
