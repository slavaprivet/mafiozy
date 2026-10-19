# Pose orchestrator: первая загрузка и смена внешности — review 23 сентября 2026

Статус: pure pose suites PASS, production host не изменён. Текущий
`walk_preview.mjs` ещё не создаёт orchestrator/applicator. До интеграции есть
один обязательный blocker: лестничная поза сейчас вызывается внутри
`verticalNavigation.update(dt)` и ещё раз через `verticalNavigation.pose()` в
кадре. Новый applicator нельзя добавлять поверх этих двух вызовов.

## Короткий checklist интеграции

### Создание и первая загрузка

- Один раз на host создать `createHeroMotionPoseOrchestrator()`,
  `createSurfaceMotionAirbornePoseAdapter()` и
  `createBuildingVerticalNavigationPoseAdapter()`. Они не держат кости героя.
- `createHeroMotionPoseApplicator(THREE, hero.artistContext())` создавать только
  после успешного `loadHeroWalker` и назначения `hero`. Applicator привязан к
  конкретным bones/visualPivot и не может пережить замену GLB.
- После начального `surfaceMotion.reset(hero.object.position)` вызвать
  `surfaceAirborne.reset(surfaceMotion.state)` и `orchestrator.reset()`. Первый
  кадр должен начинаться с чистых `walk`, lead foot `l`, без holster latch.
- Применять orchestrator только после обычного `hero.update(...)`, когда уже
  построена базовая походка/стойка/хват оружия. Он не меняет root position/yaw.

### Rebind в `applyHudHero`

- До commit, в существующем `try`, создать `nextApplicator` из
  `record.hero.artistContext()`. Ошибка должна оставить старого героя,
  applicator и оружие нетронутыми.
- Swap допускать только без death/blast/vehicle/transition/custody/interaction,
  active cover, ladder, water, explicit jump/traversal и ordinary free-fall.
  Текущий `canApplyHudHero()` уже закрывает большую часть, но ему не хватает
  явных `!heroCover.active`, `!heroCustodyActive` и
  `surfaceMotion.state.grounded!==false`. Crouch/prone можно сохранить: новый
  `hero.update(0,...,{posture:heroPosture})` уже восстанавливает базовую стойку.
- Перед `previous.mountWeapon(null)` завершить локальный pose weapon override и
  восстановить сохранённую видимость. Затем выполнить текущие назначение
  `hero=record.hero`, mount существующей модели оружия и `hero.update(0,...)`.
- После `surfaceMotion.reset(newHero.position)` атомарно назначить
  `motionApplicator=nextApplicator`, вызвать `orchestrator.reset()` и
  `surfaceAirborne.reset(surfaceMotion.state)`. Только потом можно dispose
  старые surface/hero. Ни одного кадра со старым applicator и новым `hero` быть
  не должно.
- Старый applicator собственного `dispose()` не имеет: после rebind обнулить
  единственную host-ссылку, чтобы bone references стали доступны GC. На
  `pagehide` восстановление оружия не нужно; reset adapters, присвоить
  applicator `null`, затем выполнять существующий dispose владельца героя.

### Приоритеты владельцев

Передавать ровно один набор владельцев в кадре:

`death > blast > vehicle > custody > interaction > explicit jump > traversal >
explicit airborne > ladder > water > cover > surface fall/landing > auto-step >
slope > walk`.

Для текущего `jump`, который также несёт traversal, критична маска:
`jump.active = !!jump && jumpFrame?.mode !== 'traversal'`; иначе hard jump
поглотит traversal до его pose layer. Обычное падение с края приходит только из
`surfaceMotion` с `source:'surface'` и остаётся ниже ladder/water/cover.
External owners получают `weapon.policy:'external'` и сами владеют позой и
оружием; orchestrator к ним ничего не добавляет.

### Оружие

- Pose-модули возвращают policy и сами не меняют inventory/weapon model. Host
  хранит один флаг `poseWeaponOverride` и исходную `poseWeaponVisible`.
- При первом `holster` сохранить текущую видимость ровно один раз и скрыть
  модель. Повторные holster-кадры не перезаписывают сохранённое значение
  `false`.
- При `restore` вернуть `frame.weapon.restoreVisible`, снять override. При
  `external` снять локальный latch без восстановления: death, blast, vehicle,
  custody, interaction, water или другой внешний владелец решает сам.
- При appearance swap сначала завершить локальный override, потом снять оружие
  со старой руки и смонтировать ту же модель на новом герое. После neutral swap
  видимость должна совпасть со значением до первого holster.

### Лестница: ровно одна поза

- Текущий путь уже применяет `applyRoofLadderPose` дважды: один раз в
  `building_vertical_navigation.update`, второй — в ветке
  `verticalNavigation.pose()` host-кадра. Простого удаления второй host-ветки
  недостаточно для orchestrator: внутренний legacy-вызов останется.
- В отдельном совместном owner slot разделить navigation и presentation:
  `update` продолжает единолично менять root/camera/controls/yaw, но получает
  режим без `applyRoofLadderPose`; host удаляет явный `.pose()` и передаёт
  `adaptLadder(verticalNavigation.state)` только в orchestrator. В итоговом
  кадре вызывается только `motionApplicator.apply(...)`.
- Там же выбрать одного владельца видимости оружия. Предпочтительный контракт —
  navigation сохраняет admission/root/yaw, а orchestrator-host единолично
  выполняет holster/restore. Если navigation сохраняет старый hide/restore, он
  обязан наружу отдать исходную visibility; иначе orchestrator увидит уже
  скрытое оружие, запомнит `false` и оставит его невидимым после выхода.
- E остаётся единственным входом, Ctrl — только slide активной лестницы.
  Ladder state/reset должен очиститься до разрешения appearance swap.

## Проверка после будущего host patch

1. Первая загрузка male/female, armed/unarmed: первый кадр без skin snap,
   `walk`, root/yaw неизменны.
2. Смена male ↔ female на flat/crouch: новый applicator действует на новый
   skeleton; старый hero больше не меняется; оружие остаётся в прежнем состоянии.
3. Попытка swap во время free-fall, cover, ladder, vehicle и custody отклонена;
   после выхода выполняется один чистый swap.
4. Ladder up/down/Ctrl slide: ровно один ladder applicator за кадр, legacy pose
   count 0, оружие скрывается один раз и восстанавливается один раз.
5. Pagehide после default и HUD-owned hero не вызывает double dispose и не
   оставляет ссылок applicator на удалённый skeleton.

Свежий review-прогон: `test_hero_motion_pose_orchestrator.mjs` PASS на
3/5/7/10/15/30/60/144 FPS; `test_hero_airborne_ladder_pose.mjs` PASS на обеих
реальных GLB. Это source/skin gate, не LIVE-проверка.
