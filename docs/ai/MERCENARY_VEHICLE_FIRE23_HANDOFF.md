# Ответный огонь пассажиров — 23 сентября 2026

Статус: production CPU READY; LIVE новой механики проводит Координатор20 в единственной игре. Полная производительность общей сцены не проверена. Это заменяет прежний вариант X/eliminate по выбранной цели.

## Текущий контракт

В машине X включает или выключает ответный огонь. Вооружённые пассажиры сразу плавно высовывают верх корпуса, голову и текущее оружие через своё окно; до реального нападения находятся в готовности, без выстрелов и урона. Нет выбора гражданского под курсором, приказа идти, высадки или замены пешей цели/очереди. Повторный X доступен даже после потери последнего подходящего стрелка. Выход, смерть героя, смена машины и bindTargets(null) сбрасывают режим; перезагрузка начинает с выключенным режимом.

Source хранит максимум 16 настоящих входящих нападений с TTL 6 секунд. Проверяет текущий объект источника, принадлежность/здоровье, жертву (герой, свой боец или текущая машина), дистанцию и сторону окна. Общий _gangAlertThreat не является доказательством: туда попадают и цели собственной атаки игрока. Renderer заново строит текущую посадку и принимает выстрел только после проверки настоящего дула, достижимости рук, головы, своего кузова, всех видимых NPC, героя и препятствий. Source повторно проверяет identity/weapon/seat/target/car/attackSequence перед существующим hit dispatch.

Сохранены единственные source cooldown, shot sequence, hit и XP. По завершении dispatch восстанавливается прежняя пешая targetKind/targetRef/targetId. Физическая проверка ограничена одним пассажиром за source tick, очередь круговая; отказ допускает повтор не раньше 250 мс и не меняет damage cooldown/HP/инвентарь. Геройское ammo API не используется, сетевого обхода нет.

Все 13 ballistic моделей ARSENAL поддерживаются: Наган, TT, револьвер, Deagle, золотой Colt, Uzi/золотой Uzi, Tommy, обрез, дробовик, AK74, M16, снайперская винтовка. Используются существующие NPC aliases, включая rifle/golden_ak→AK74 и smg→Uzi. RPG/bazooka явно отвергается с причиной отсутствия подтверждаемого запуска ракеты; melee/throwables/неизвестные модели тоже не становятся фальшивым hitscan. Текущее оружие не подменяется TT.

## API и файлы

- `mercenary_world.js`: get/set/toggleVehicleDefenseFire, canIssueVehicleFireCommand, noteVehicleAttack, qaVehicleDefenseAttack, get/validateVehicleFireIntent; отдельные mercenaryVehicleReady и mercenaryVehicleFire metadata. Readiness не содержит target/ref и не может разрешить урон.
- `mercenary_vehicle_fire.mjs`: pose/admission factory, lean-in 0.18 с, torso return 0.22 с, окно только своего места, fail-closed при отсутствующем окне. Source-authority не дублирует.
- `npc_actor.mjs`: только vehicle fire pose и prepareVehicleShot; общий gait/death/save/restore принадлежит художнику. Binding actor/fallback vehiclePose в npc_vehicle_pose принадлежит Transport3.
- `npc_shot_effects.mjs`: неизменяемая accepted ray из реального дула, сохраняет место выстрела после движения машины; неверная ray не заменяется догадкой.
- `world.html`: seated branch/acceptedGangShot и узкие реальные incoming hooks. Остальные общие изменения имеют иных владельцев.
- `test_mercenary_vehicle_fire23.mjs`, `test_mercenary_vehicle_defense23.mjs`, `test_mercenary_vehicle_lean23.mjs`: текущая приемка.
- Root владеет Walk factory init, X UI и QA кнопкой. mercenary_targets возвращён к baseline; старый optional ignored-root/pick пакет более не нужен и исключён из checkpoint.

Factory принимает `{THREE,getActors,getActor,getPlayer,obstacles,getHost,diagnostics}`. getActors — все текущие NPC `{id,object}`; getActor — actual NPC; getPlayer — actual hero; obstacles — текущие Object3D включая машины. Source вызывает recordAccepted только после dispatch. QA stats различает attempts/ready/rejected/accepted/sequence; ready не означает HP hit. Никакой targetRef не сериализуется. Root публикует stats и состояние режима в dataset.mercenaryVehicleFire максимум раз в секунду при QA.

## Происхождение нападений и QA

Реальные hooks: _empirePlayerCombatThink; _updatePrisonStaffCop; две уличные полицейские ветки _updateCityCops (включая direct retaliation); _murderCopShootPlayer; street NPC fight loop; _applyNpcEmpireWeaponHit по собственной банде; _hurtLocal с переданным настоящим source/cop officer перед cover. При реальной попытке выстрела receipt не требует попадания. _hurtLocal предпочитает deathMode.source и лишь при его отсутствии cop: выстрел turret фургона не должен обвинять сидящего в нём офицера. Неподдержанные vehicle attackers не подменяются ближайшим NPC.

qaVehicleDefenseAttack доступна только local preview + localhost + carqa/существующий QA и сидящему игроку. Выбирает ближайшего существующего живого патрульного в ограничении 0.7..50 source cells без требования начального LOS и вызывает только _cityCopEngagePlayerAfterHit. Сам штатный pursuit ограничен max(24,CITYCOP_PURSUE_R): для более дальнего офицера QA честно просит приблизиться. Внутри этого радиуса knownDirect сохраняет последнюю позицию игрока даже за препятствием; подход и последующая видимость/стрельба остаются штатными. Не создаёт/не переносит NPC, не меняет HP, не выдаёт receipt и не включает режим. Receipt появится только в реальном последующем attack loop. При отсутствии подходящего патрульного возвращает честный отказ.

## Проверка и пределы

`node assets/maps/city_rebuild_v1/test_mercenary_vehicle_fire23.mjs`: 2039 PASS. 72 TT/Uzi комбинации: compact sedan и настоящая Kingswell DemoCar, local/source quest, male/female, все три пассажирских места, yaw 0/1.1. Ещё 22 реальные геометрии остальных 11 ballistic моделей (оба пола, обе стороны). 43 отрицательных случая: friendly/player skin, стены, чужое окно, stale car/target/weapon, чужая identity, wounded/hidden/disposed, board/exit/pending exit, online/custom authority, неподдержанное оружие. Повторные proofs сохраняют source root и все шесть суставов ног. Нулевой incoming/общая threat/focus не разрешают fire. X-ready и возврат анимируются без смены места. Missing-window→X-off не падает.

Moving test использует настоящий createMercenaryVehicleBridge: source advance → новая позиция/поворот actual car и moving attacker → intent → prepareShot без предшествующего passenger render → один dispatch. Для quest source coordinates намеренно опережают модель; fire pose правильно берётся от actual rendered bridge. Предыдущая proof невалидна. Допуск .05 м/.01 рад не ослаблен.

`node assets/maps/city_rebuild_v1/test_mercenary_vehicle_defense23.mjs`: 110 PASS. Actual source host и настоящая direct-police attack ветка, без переписывания production. Проверены режим/пешие приказы, TTL/reference/life/friendly/authority, все source weapon aliases, возможность off при eligible=0, context reset, QA gating/nearest/bounded range/no teleport/no HP; настоящий knownDirect target при 84 м и отсутствующем начальном LOS. QA сама не создаёт receipt; реальный полицейский выстрел, включая промах, создаёт его.

Совместимость: focus_source 8 PASS; npc_shot_effects 7 PASS; squad_transport23 23 PASS; vehicle_window_fire 1680 геометрий (1638 admitted, 42 честных отказа) PASS. `test_npc_vehicle_transition_continuity.mjs` выявил female first-board jump >0.1 м в текущем совместном дереве. В этом тесте вообще нет fire/readiness и helper не создаётся; координатор передал художнику свежий gait/transition review. Не считать этот тест прошедшим до его исправления.

Последний isolated CPU после усиления lean (один NPC, 12 прогревов + 40 samples): seated idle p50/p95 0.922/1.209 мс; active pose 2.049/2.305 мс; полный actual-skin physical admission 29.715/39.192 мс. Ранее до усиления lean в том же harness: idle 0.367/0.406, pose 0.821/1.018, admission 13.238/13.830 мс. Одновременно выросла и baseline idle без fire: общий фон измерений несопоставим, поэтому эти сырые результаты не доказывают величину регрессии или улучшения. Стоимость текущей проверки небесплатна, source по-прежнему допускает не более одного физического probe за tick, а отказ повторяется не чаще 250 мс/боец. Нужен последовательный замер координатора в общей сцене после завершения CPU процессов; это не FPS города и не GPU-приемка.

Зависимости: tracked NPC/vehicle GLB и tools/vehicle_fleet_qa/RoundedBoxGeometry.mjs; Three vendor задаётся MAFIOZI_THREE_VENDOR, default существующий D:/codex_release/artist13_hero_first_DEV_20260907/demo/vendor. Ни geometry archive 95 MB, ни backend import не нужны. Audit/prototype files fire23_audit/pick23_audit/старый pick23 acceptance не включать.

## LIVE осталось

В существующей игре: посадить реальный вооружённый отряд, X → увидеть lean-ready всех подходящих пассажиров и ноль accepted без атаки; QA штатная провокация патрульного → actual incoming выстрел → accepted seq/HP/XP только у пассажира со свободным собственным окном. Затем коротко проехать/повернуть, проверить стену/своего, повторный X/выход/повторную посадку. Снять frame p50/p95 в той же населённой сцене и отметить настоящие отказы. CPU READY не закрывает эту приемку.


## Финальная поза для reload5

Предыдущий read-only ready audit (голова примерно 40 см внутри) более не описывает текущий helper. Runtime SHA256 `834C0A76EB75394204950D5D8F0DA3EACFFD99A89F9F607D9B7587B562947E6E` заменяет загруженную у координатора WIP-версию `4c7fd996`.

Усилена только пассажирская поза: плечи и голова выходят через своё окно за счёт бокового наклона и смещения spine_01; таз/root/ноги не перемещаются. В первые фазы 0.18 с руки поднимаются над sill, затем корпус наклоняется наружу; обратные 0.22 с сохраняют реальные кисти относительно машины до ухода корпуса внутрь, затем опускают руки. При переходе голова слегка пригибается под рамкой. На полном lean голова минимум 14 см снаружи плоскости окна, внешнее плечо минимум 6.264 см. Это проверено по настоящим костям и всем skinned triangles, пересекающим плоскость окна, в течение входа/готовности/выстрела/возврата.

План оружия дополнительно сдвигается вперед по оси машины на 30 см (длинное) / 18 см (пистолет), с ограничением настоящими оконной рамкой, reach, головой и кузовом. Для Kingswell TT/Uzi/AK и двух полов × трёх мест реальная origin рукояти на 13.7–36.2 см впереди груди по оси машины; receiver Uzi/AK ниже головы на 23–36 см. Обе ладони длинного оружия находятся на реальных authored trigger/support grips; у пистолета стрелковая ладонь на рукояти, свободная рука опирается на внутренний край окна. Отдельно проверяем рабочую часть оружия перед развернутой грудью, а не только дуло снаружи. Приклад может находиться возле плеча. Эти метрики не заменяют визуального сравнения в браузере: отзыв пользователя о неестественном оружии в WIP не считается закрытым только на основании CPU.

`test_mercenary_vehicle_lean23.mjs`: полная геометрия 156 сочетаний compact/Kingswell × male/female × 3 пассажирских места × 13 ballistic families. Четыре реальных кадра входа по .045 с и возврата по .055 с, готовность и огонь: отсутствие кожи через дверь/раму/крышу в плоскости окна (числовой допуск 2 мм), неизменные pelvis/6 суставов ног/root, нулевой intent без нападающего, неизменяемое настоящее дуло после опоры свободной рукой, отмена урона на off. Окончательный прогон: 2880 assertions PASS, 156 cases, 0 нарушений. Рабочий сегмент оружия минимум на 6.533 см впереди горизонтальной оси развернутой груди; максимальная ошибка стрелковой/поддерживающей ладони 9.86e-8/9.22e-8 м. Длинное оружие находится ниже головы; реальная геометрия во всех фазах проходит через собственное окно. Main fire после runtime freeze: 2039 PASS (72 basic geometry, 22 дополнительные weapon geometry, 43 negatives). Все CPU процессы завершены перед передачей координатору.

В checkpoint добавить этот новый production regression. Исторические `test_mercenary_vehicle_ready23_audit.mjs`, `test_mercenary_vehicle_posture23_audit.mjs` и `test_mercenary_vehicle_lean23_candidate.mjs` исключить; они не обязательные зависимости. Новые runtime импорты или внешние fixture архивы для lean не добавлены.
