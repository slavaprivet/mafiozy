# NPC recovery continuity20 — production handoff

20 сентября 2026. **READY для согласованного reload19: IMPLEMENTED /
TESTED CPU, LIVE pending.** Root явно разрешил actor-only перенос после
ревью prototype и external sync regression. Production scope — только
`assets/maps/city_rebuild_v1/npc_actor.mjs`.

Повторный source stun и смерть во время подъёма больше не обнуляют
наклон и не поднимают NPC на1.1м перед повторным падением. На actual GLB
male/female скачок головы **1.1082/1.1334м → 0.000377/0.000369м**;
visualPivot **1.50111rad → 0.000935rad**. Смерть от confirmed receipt
с противоположной side также непрерывна.

## Что изменено

В actor добавлены локальные presentation offsets и helper
`presentReaction(s, sourceHeld)`: reusable record содержит rawAge,
adjusted age, visualWeight и side для renderer. `applySwim` использует
его для sourceFall, `applyReaction` для surface fall/death. Существующий
shared hero pose и surface/blood не изменялись. Это точка подключения
будущего отдельного NPC death renderer; cause profile здесь ещё не выбран.

Raw sourceDeathAt/sourceDown.at/sourceFall.age/saved surface reaction age
сохранены. Source flags/HP/receipt semantics не менялись; dead/stun
активируются сразу. На смене side только визуальный переход. Обычная
standing death остаётся точно прежней. Recovery entry использует
фактический presentation weight, не сбрасывается в upright.

`receive(event, presentationAt=time)` принимает atTime от внешнего
syncSourceLifecycle; это предотвращает наследование устаревшего recovery
после скрытого gap до следующего update, без сдвига source/surfaceclock.
Version1 save имеет optional reactionVisual; старые payload допустимы,
новое поле валидируется до мутаций. Root/weapon/scale/contact сохранены.
Phone/cash/help/talk/surrender блоки предыдущих владельцев не заменялись.

## Проверки

- Исходный `test_npc_recovery_audit20.mjs` напрямую на production: **8/8 PASS**.
- `test_npc_recovery_prototype20.mjs --audit` теперь **production regression**
  (историческое имя сохранено): baseline точным откатом только наших
  substitutions в памяти. PASS repeat-stun, source/receipt death,
  surface knockdown, смерть на sourcefall .1/.3/.55/1с и surfacefall
  .3/1/1.8с, opposite side, пять повторных циклов, same/30s save-restore,
  legacy payload, atomic invalid presentation payload, source clocks,
  source/receipt idempotency, actual skin floor contact, root/weapon/bones.
  External sync atTime при private clock отстающем5с также PASS.
- `test_npc_actor.mjs` с offline setup — PASS.
- `test_npc_death_all.mjs` — PASS: 24 families,9 edge cases,71 catalogue
  entry,26 posed roles; clock/corpse/respawn/eviction/fatal priority.
- `test_npc_surface_state.mjs` с offline setup — PASS: serialization,
  receipts/wounds/bruises/dry aging и atomic invalid.
- `test_npc_lifecycle.mjs` — PASS: обе GLB, source stun/recover,
  armed/custody/source clocks/death priority.
- `test_npc_gesture_exit20.mjs` — PASS после recovery integration,
  включая 26 priority cases и8longgap cases.

## Известный отдельный случай и стоимость

**Одновременные давно истёкший source stun endedAge + свежая death в одном
late snapshot ещё НЕ решены этим патчем.** Lifecycle сейчас обрабатывается
до stun snapshot; existing sourceDown может восприниматься удерживаемым.
По прямому указанию root это не расширялось в production. Следующий
ограниченный prototype должен проверить этот случай отдельно.

Лёгкий A/B одинаковых held-source-fall poses,80samples каждой версии:
before p50/p95 **1.3740/1.4850мс**, after **1.3686/1.4684мс**. Это не
доказательство ускорения, только отсутствие заметного роста в этом CPU
сценарии. **Производительность общей сцены не проверена.** Browser/GPU0.
Reload/LIVE и FPS контролируют root/Художник19.
