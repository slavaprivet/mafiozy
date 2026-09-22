# Help/talk exit20 — integrated scoped patch

20 сентября 2026. **IMPLEMENTED / TESTED CPU, LIVE pending.**
После освобождения actor владельцем phone/cash/surrender Проверщик2 и
снятия freeze Художником19 root разрешил три узких вставки в npc_actor.
Recovery/death continuity этим пакетом НЕ исправляется и не менялась.

## Реальный scope

- `npc_actor.mjs`: private outgoing fields, захват только фактически
  применённого help/talk при спокойном завершении, визуальное затухание
  0.3 с. Logical gesture сразу null. Phase фиксируется по последнему
  применённому pose time; долгий пропуск не запускает старый выход заново.
- Любая работа/новое занятие/угроза/бой/движение/оружие/вода сбрасывает
  outgoing перед применением позы. Phone/cash visual и surrender helper
  остаются в своём текущем виде. Root/source/world не изменены.
- `test_npc_gesture_exit20.mjs` теперь production regression, before
  восстанавливается только в памяти точным откатом наших трёх вставок.
- `test_npc_animation_quality20.mjs` больше не ожидает исправленный
  gesture defect: help/talk проверяют continuity; phone лишь измеряется.

## Actual GLB / checks

Основной regression PASS: male/female, 60/10 FPS, конечный exact neutral,
26 priority случаев с bone matrix diff0, 8 случаев observation gap1/5с
при dt1/60, source root/yaw и identity mounted weapon, no phantom generic
talk после social-owned activity, phone release production parity.

При 60 FPS максимальный шаг руки help/talk **42–55 см → 3.5–4.6 см**,
первый кадр выхода 3.9–5.0 мм. При 10 FPS максимальный шаг20–27см вместо
43–56см; это три кадра перехода, не обещание идеальной плавности.

Также PASS:
- actual `test_npc_actor.mjs` с offline setup — assets, skins/resources,
  оружие, death, posture, surrender/cash/phone hooks и disposal;
- `test_npc_phone_visual.mjs` + `test_npc_cash_offer_visual.mjs` — 11/11;
- `test_npc_social_pose.mjs` — оба пола × рост1.65/2.05, anchors/props/
  interruptions/resources/disposal. Старый NPC_Phone assertion уже
  обновлён владельцем2; прежний blocker read handoff снят;
- `test_npc_animation_quality20.mjs` — help/talk и seat regression PASS.

При social suite подавлена только запись старого generated JSON отчёта
через fs wrapper, assertions не менялись. Чужой test не редактировался.

## Стоимость

128 сравнительных CPU samples реального actor update + invariant checks
на кадрах выхода: before p50/p95 **0.0577 / 0.0947 мс**, after
**0.1390 / 0.2153 мс**. Это честная дополнительная IK работа на0.3с,
затем никаких outgoing IK. Новых meshes/props нет; текущий
`applyLifeGesture` сохраняет свои allocations, оптимизация не смешивалась
с чужим phone/cash переносом. Полный FPS из этих цифр не выводится.

**Производительность общей сцены не проверена.** Browser/GPU не открывался;
reload/LIVE и одновременные выходы NPC согласуются root с Художником19.
