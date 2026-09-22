# Чтение: плавное завершение и опускание книги — 20 сентября 2026

**READY на диске / TESTED CPU. LIVE pending.**
Production patch завершён до runtime freeze Художника19; во время freeze
production edits остановлены. Root получил статус и разрешение включить
этот файл в согласованный reload. Пакет не объявляется визуально принятым.

## Scope и реальная правка

Разрешение Художника19 через Координатора20: только `npc_social_pose.mjs`
read envelope последних 0.6 с и actual-GLB regression. Source/agenda,
actor, время occupation и cleanup/reservations принадлежат другим авторам.

Причина: source read branch снимает activity прямо в `until`, без finish.
Раньше после последнего кадра чтения руки прыгали на 18.39 см у male и
15.85 см у female при остающейся bench seat.

Изменения `npc_social_pose.mjs`:

- Только `read + active + finite until`: существующий blend умножается
  на `smoothstep(remainingSeconds, 0, 0.6)`. Явный finish по-прежнему
  использует старый переход, source сроки не меняются.
- При частичном read blend существующая книга перемещается по середине
  **фактических palm sockets после IK**, с прежним вертикальным offset.
  Поэтому при опускании рук книга движется вместе с ними. Ориентация
  прежняя; full-weight book transform и все bone matrices точно прежние.
- Используются существующие scratch vectors from/to. Новых meshes,
  ресурсов, таймеров или THREE allocations после прогрева нет.

## Actual GLB и геометрия

`node assets/maps/city_rebuild_v1/test_npc_reading_exit20.mjs` — PASS.
Before строится в памяти откатом только этого social patch. На обеих
реальных моделях source-shaped snapshots удаляют activity точно в until,
без finish; seat сохраняется.

| Метрика | Male до → после | Female до → после |
|---|---:|---:|
| Скачок руки на normal expiry | 0.183947 → 0.000418 м | 0.158498 → 0.000360 м |
| Максимальный шаг за весь переход, 60 FPS | 0.183947 → 0.007657 м | 0.158498 → 0.006597 м |
| Макс. расстояние palm anchor до настоящих треугольников cover/pages | после 0.002174 м | после 0.001501 м |

Это расстояние **до поверхности реально трансформированной геометрии**,
не до центра книги. Положение книги следует поддерживающей паре palm
anchors с ошибкой <2e-15 м. Проверяется контракт контакта по sockets;
полное отсутствие пересечений всех пальцев/skin без LIVE не объявляется.

Дополнительно PASS: feet anchors, root/yaw, прежняя full-weight pose,
no added meshes, warmed THREE constructors 0, отсутствие orphan props
после удаления/просрочки activity, read не превращается в generic gesture,
немедленное прекращение чтения при panic/flee/cuffed/phone. Bone matrices
этих реакций совпадают с baseline в первый же кадр.

Первый старый social suite остановился на legacy NPC_Phone assertion после
concurrent pooled-phone переноса. Проверщик2 затем исправил только тест
на actor.diagnostics().phone.visible и подтвердил shared PASS actual
male/female1.65/2.05, bench/social/interruptions/resources/disposal.
Animationagent20 также повторил этот suite после help/talk integration: PASS.

Позднее обновление: владелец2 обновил устаревший phone assertion.
Повторный scoped прогон после help/talk integration **PASS** на male/female
рост1.65/2.05. Указанный выше blocker снят; тест нами не редактировался.

## Стоимость и ограничения

Лёгкий A/B social overlay на тех же моделях/кадрах, 144 samples на версию,
создание моделей/props/reset вне измерения. Последний run p50/p95:
до **0.0593 / 0.1090 мс**, после **0.0627 / 0.1227 мс**. Дополнительная
работа — чтение положения двух palm sockets и перенос существующего book
только на частичном blend. Никаких новых draw calls и geometry.

**Производительность общей сцены не проверена.** Browser/GPU не открывался.
Художник19/Координатор20 владеют reload, LIVE и FPS в общей игре.

Файлы пакета:
- `assets/maps/city_rebuild_v1/npc_social_pose.mjs` — единственный production.
- `assets/maps/city_rebuild_v1/test_npc_reading_exit20.mjs` — новый regression.
- этот handoff. Root audit `audit_npc_reading_contact20.mjs` не изменялся.
