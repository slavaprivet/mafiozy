# World → walk: повторный 2D отбор отменял физическое попадание

Scoped patch npc_damage по поручению root, 12 сентября. Root отдельно исправляет camera crosshair → реальное дуло и ведёт LIVE. Эта передача не устанавливает единственную причину жалобы пользователя о resident112.

## Подтверждённый дефект

`fire()` прежде обрезал range луча `_weaponWallDistance` от ног игрока до вызова renderer `resolveContact`. После подтверждённого skinned контакта NPC снова отбирался 2D лучом от legacy `muzzleWorldPoint`; along<0.2, circle/perp или center-cone 0.985 для полиции могли отменить уже касавшуюся тела пулю. Другие legacy круги машин/колонок/props могли перехватить цель, хотя нативный луч прошёл над/рядом с моделью.

## Изменено в scoped sections world.html

- `_walkShotPhysicalContact` возвращает данные только уже принятого `ctx.ref/contact` с function `resolveContact`. Одного присланного point либо несуществующего ID недостаточно. Никакой новой HP/authority.
- Callback получает canonical weapon range от фактического дула. Если NPC не найден, legacy wall cutoff возвращается для прежней баллистики машин/props/промаха.
- Принятый NPC использует фактические point/dist; legacy 2D круги обычных, beach/decor/interior NPC и center-cone полиции/охранников не выбирают цель повторно. Existing dead/allied/evacuated/mode/weapon/custody guards сохраняются.
- Native muzzleR/C используется в source баллистике. Penetrating/shotgun local/remote targets получают фактическую точку; shotgun продолжает рассчитывать отдельные lanes/spread/pellet damage. Никакого автоматического полного pellet damage.
- Только когда ближайший physical NPC уже принят, старые 2D машины/колонки/props и feet tilewall не отменяют его. **Нативные obstacles renderer должны включать видимые преграды/автомобили.** Root проверяет content/fleet и отсутствие source traffic среди blockers. Эта зависимость остаётся существенной для LIVE, нельзя считать пустой obstacle resolver полноценной проверкой.
- Старый renderer, статический request без callback и physical miss сохраняют прежние пути. `_walkShotNativeRef`, `_walkConfirmDamage`, hitNpc, HP, inventory, ammo/network endpoints не переписаны.

## Проверки

`node test_world_walk_physical_shot_admission.mjs` исполняет актуальные целые `fire`, `hitNpc`, native helpers, penetrating/shotgun functions в VM. Fixed source resident60HP, реальное дуло перед телом, старое дуло за ним и feet tilewall, стоящий в стороне от нативного контакта. Pistol/rifle/sniper/shotgun × civilian/city cop/server cop проходят. Civilian реальным `hitNpc` получает 20урона (округление pellet damage допустимо), один расход round, один source confirmed receipt. City cop вызывается существующий route; его побочные полицейские системы в этом тесте изолированы. Remote cop получает только исходный `cop_shoot`, не optimistic HP/кровь. PvE/dead/empty/miss/unknown ID не дают урона.

`node test_world_walk_shots.mjs` PASS; fixture дополнен явно `_serverAuthoritativeAmmo:false`, поскольку selectWalkWeapon теперь имеет существующий сетевой путь. Проверены native identity, exact confirmed point, pending ACK, dedupe, ownership/equip/reload и legacy isolation.

`node test_world_walk_melee.mjs` PASS: source inline syntax, physical miss, charge/block, remote ACK/нет optimistic HP. Source changes event-only; per-frame AI/pose обходов не добавлено. CPU fixtures не измеряют стоимость нативной 3D геометрии.

## Review и lazy reticle aim — следующий scoped этап

По отдельному поручению root проверены `npc_native_perception`, camera→muzzle convergence, aimOnly и indexed shot obstacles. Найдена и исправлена регрессия: eager camera ray выполнял skin/updateMatrix/obstacle ray до source admission при каждом удерживаемом кадре автоматического оружия, даже когда cooldown запрещал выстрел.

`world_walk_combat` теперь передаёт `request.resolveAim({range})`. Source `fire` вызывает его после mode/death/prison/cooldown/ammo admission, перед единственным sample weapon spread. Callback использует актуальную canonical дальность, возвращает конечные angle/pitch; ошибка или NaN оставляют исходное направление, без дополнительного HP/receipt. Cover penalty применяется один раз. Host не редактировался.

Actual-source тест дополнен: 6 запрещающих условий дают 0 aim calls; принятый выстрел — 1. Throw/NaN не ломают fire. Actual male/female convergence fixture вызывает lazy callback после admission; 30 отклонённых попыток не запрашивают даже getActors. Параллельный старый луч промахивается, новый попадает по reticle skin; muzzle cover и prone high miss PASS. Existing world_walk_combat allocation/idle, source shots/melee и native perception/ray PASS.

Изолированный CPU benchmark: настоящие male GLB, 8/30 NPC в коридоре луча, 5 прогревов + 30 попыток, пустой список obstacles. Камера[-.35,1.4,-2], muzzle[.45,1.2,0], forward+Z; одинаковые расположения NPC. Время p50/p95, ms:

| Фаза | 8 NPC | 30 NPC |
|---|---:|---:|
| Старый parallel, source reject | .009 / .059 | .003 / .018 |
| Eager convergence, source reject | 26.175 / 27.734 | 87.360 / 92.624 |
| Lazy convergence, source reject | .005 / .033 | .003 / .005 |
| Eager convergence, source accepted | 49.466 / 50.940 | 157.396 / 164.680 |
| Lazy convergence, source accepted | 49.796 / 52.673 | 154.550 / 167.036 |

У lazy rejected все aimCalls/resolverCalls/matrixUpdates =0. Реальные принятые выстрелы всё ещё требуют двух точных skin rays; это заметная стоимость и возможный следующий event-only приоритет, не исправленная общая производительность. Renderer obstacles/GPU/вся симуляция в этих цифрах отсутствуют.

LOS read-only benchmark: 357 исходных worldBodies из buildings/decor placement JSON, 20 горизонтальных запросов около равномерно выбранных body centres, 5 прогревов+20 batches; flat ground0, без машин. Все результаты indexed против точного обхода всех polygon/slab совпали. На20запросов brute p50/p95 .413/.658ms, index .077/.252ms. Для actual terrain/позы/машин отдельно существующий `test_npc_native_perception` PASS. Дополнительной воспроизводимой функциональной ошибки LOS не найдено. Это не приёмка качества видимости всего живого города.

## Предел

Проверку действующей вкладки, obstruction от source traffic и crosshair aim ведёт root. Статический18538 не подтверждает server ACK/ownership checks реального backend. Общая производительность сцены не проверена агентом; вторую GPU вкладку не открывал. Существующее RPG explosion/server launch остаётся отдельным контрактом; это не новый authenticated RPG damage.
