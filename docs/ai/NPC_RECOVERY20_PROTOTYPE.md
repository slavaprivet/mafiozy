# Recovery interruption20 — actual-GLB prototype, not integrated

**Последний статус: после отдельного root-разрешения точный reviewed
actor-only patch интегрирован. Актуальная передача `NPC_RECOVERY20_HANDOFF.md`.
Ниже история прототипа; test с прежним именем теперь production regression.**

20 сентября 2026. **PROTOTYPE READY FOR REVIEW / production recovery
НЕ ИЗМЕНЯЛСЯ.** Help/talk production patch передан отдельно. Source/health,
hero pose, кровяные эффекты, melee contact и разные damage-type смерти
не редактировались.

## Результат

Новый `test_npc_recovery_prototype20.mjs` подставляет только actor source
в памяти. Повторное оглушение или смерть во время подъёма больше не
заставляют человека сначала встать вертикально и заново упасть.

| Сценарий через1мс после recovery frame | Было, male / female | Prototype |
|---|---:|---:|
| Повторный source stun: скачок головы | 1.1082 / 1.1334 м | 0.000377 / 0.000369 м |
| Source death: скачок головы | 1.1082 / 1.1334 м | 0.000377 / 0.000369 м |
| Confirmed receipt death, противоположная side | 1.1082 / 1.1334 м | 0.000355 / 0.000348 м |
| Поворот visualPivot | 1.50111 rad (~86°) | 0.000882–0.000935 rad |

Dead/stun состояния переключаются сразу. Нет искусственного moving или
задержки получения урона; pose продолжается с текущего авторского веса.

## Предлагаемый контракт для production review

Текущий `hero_artist14_pose.reaction` уже выражает fall/death/recovery
через один authored weight. Не менять его геометрию, root, groundPose или
длины костей. Перед новым событием вычислить прежний вес на **текущее
абсолютное время**, включая продолжившееся recovery, затем обратить
smoothstep fall `.03..62` в эквивалентный pose age.

Два presentation-only offset:
- sourceDownVisualBias применяется к age, передаваемому source fall pose;
- deathVisualBias применяется только к age, передаваемому death callback.

Extension point для будущего **отдельного NPC death renderer**:
локальный `presentReaction(s, sourceHeld=false)` в actor возвращает
повторно используемый presentation record `{kind, rawAge, age,
visualWeight, side, unit, zone}`. rawAge — существующий source/surface age;
age — adjusted presentation age; visualWeight — готовый authored weight.
Входной `s` не мутируется, hit/block возвращаются вообще без изменений.

Точки вызова:
```js
// applySwim: existing sourceFall overlay, still before surface callbacks
pose.reaction(presentReaction(sourceFall, sourceDown.active), c);
// applyReaction: source/surface fall or death
pose.reaction(presentReaction(s), c);
```
В будущем только renderer dispatch получает отдельный NPC death pose и
explicit fatalrecord; никаких guessed причин из HP/nearhit. Этот прототип
пока передаёт processed record прежнему renderer и не меняет shared
hero_artist14_pose или blood surface. Raw sourceFall.age теперь также
остаётся без bias: всё преобразование находится в presentation helper.

`sourceDown.at`, `sourceDeathAt`, `surface.state.at`, исходные dead/stun
flags и raw saved `surface.reaction.age` остаются прежними. При отпускании
повторного stun existing recovery-entry inversion использует фактический
визуальный вес. `sourceDown.releaseAt` и раньше являлся вычисленным
presentation recovery start, не серверным временем события.

При смене death side current authored side плавно переходит к новой за
0.3с; это только presentation. Standing death имеет bias0 и сразу прежний
target side — точная прежняя нормальная death pose. Повторные receipts
не перезапускают bias. ExplicitAlive/new epoch сбрасывают presentation.

Для persistence добавить optional `reactionVisual` в version1 payload:
`sourceDownBias`, `deathBias` (0..0.62), `deathSide` (-1..1). Validate до
`surface.restore`, затем восстанавливать поля. Старый payload без блока
использует bias0 и свою `surface.reaction.side`, а не произвольную side1.
Точные source replacements находятся в начале prototype test; каждый
anchor требует единственного совпадения, не допускается broad file copy.

## Проверки

`node assets/maps/city_rebuild_v1/test_npc_recovery_prototype20.mjs --audit`
— PASS. Этот режим также прогоняет **исходный** recovery audit с actor,
подменённым лишь in memory: прежние **4 PASS / 4 FAIL → 8/8 PASS**.
Сам audit и production actor recovery на диске не менялись.

Дополнительный regression:
- actual male/female, repeat-stun / source-death / confirmed-death;
- смерть на стадиях source fall `.1/.3/.55/1с` (включая уже лежащего),
  в том числе противоположная side;
- смерть на surface knockdown `.3/1/1.8с`, где последнее — recovery;
- пять последовательных release→repeat-stun циклов;
- точная baseline standing death side±1 на нескольких ages;
- raw death clock/receipt idempotency, unchanged root/yaw/weapon identity,
  bone rest translations/scales; actual skinned floor minimum <2мм;
- save/restore без gap: тот же head/pivot; elapsed30с: завершённый подъём
  не переигрывается, corpse остаётся dead; malformed visual payload atomic;
- старый save без reactionVisual сохраняет обе стороны death;
- прямой новый death после5сек скрытого recovery не возрождает старую позу.

Root-review regression подтверждён отдельно: `syncSourceLifecycle(dead,
atTime=15.16)` вызывается до update при private time10.16. Прежняя версия
prototype провалила этот тест и возвращала старую recovery позу. Исправлено
только presentation: `receive(event, presentationAt=time)` получает atTime
из syncSourceLifecycle и использует его в continuityAt. Source/surface
clock не присваивается этому времени. Новые external-sync cases male/female
с gap1мс/5с PASS: близкий death непрерывен, после5с — обычный upright
start, raw saved source death age0. Исходный audit снова8/8PASS.

Предел gap-контракта: проверен известный ранее recovery и сохранённый
elapsed. Если последний authoritative snapshot держал sourceDown active,
он считается удерживаемым до новой информации. Отдельный late snapshot,
в котором одновременно пришли **давно истёкший stun endedAge и новая death**,
нужно проверить при production review: текущий actor вызывает lifecycle
до обновления source stun. Не объявлять этот порядок решённым прототипом.

## CPU / LIVE

Лёгкий чередующийся A/B одинаковых held-source-fall poses, 80 samples
каждой версии после прогрева: before p50/p95 **1.4056 / 1.5683мс**,
prototype **1.4045 / 1.5521мс**. Стоимость определяется существующим
groundPose; эти малые выборки не доказывают ускорение или scene FPS.
Вычисление inverse идёт на событии, не каждый кадр. Дополнительная
проверка/сериализация маленького presentation payload не профилирована
как отдельная нагрузка массового восстановления.

**Производительность общей сцены не проверена.** GPU/browser0; новые
damage-type trajectories, blast parts и кровь — отдельные владельцы.
Для integrated continuity нужен review root и явный scoped release;
production recovery пока не менять.
