# RPG source route: actual CPU audit20

20 сентября 2026. Новый приоритет пользователя: видимый взрыв РПГ не наносит урон.
Citycop metadata candidate и medical bleedout отложены; production world в этом
аудите не изменялся. C4/авто принадлежат другим исполнителям19.

## Подтверждённое source поведение

`assets/maps/city_rebuild_v1/test_rpg_source_route20_audit.mjs`: 3/3 PASS.
Исполняются реальные `_fireRpgRound`, `_scheduleBallisticFx`,
`_spawnRpgExplosion`, `_localBallisticTargets`, `_weaponWallDistance`,
`_walkShotPhysicalContact`, `_walkShotAllows`, `_projectTargetOnRay`, `hitNpc`.
Карты/визуальные эффекты/таймеры — контролируемый CPU fixture; native projectile
не исполняется. Поэтому это доказательство несовпадения доступных source входов,
а не LIVE подтверждение конкретного пользовательского попадания.

1. При отсутствии NPC contact и свободной source сетке выстрел из (0,0) вдоль C
   на range15 планирует source взрыв (0,15) через1000мс. NPC (1,1), HP1000,
   остаётся HP1000. Входа native floor/object impact (0,1) у source функции нет.
   Прямой вызов того же actual resolver в (0,1) уменьшает HP этого NPC.
2. При physical NPC contact source выбирает точку попадания. После реального
   delayed boundary / очистки контекста повреждаются и цель, и соседний NPC.
3. Если вызвать explosion синхронно под active missed-contact context, список
   NPC пуст. Обычный production timer исполняется после очистки контекста,
   поэтому это ограничение само по себе не объясняет обычный delayed случай.

## Exact anchors и границы

- `world.html`, `_fireRpgRound`: endpoint = 2D wall distance, затем ближайший
  local/remote NPC ray projection. Native floor/mesh collision здесь не принят.
- `world.html`, `_spawnRpgExplosion`: radius2.7 source tiles, damage falloff
  cfg.dmg*(1-d/radius*.72), прежние крит/скилл. Actual local HP path исправен
  при правильной точке. Менять баланс или радиус для маскировки не следует.
- `world.html`, `fire`: `hitGasPump` и `hitDamageableCar` return расположены
  до dispatch `_fireRpgRound`. RPG может уйти в обычный gun handler вместо
  radius resolver. Нужен отдельный test/review dispatch fix после решения
  владельцем native impact, чтобы не применить взрыв дважды.
- `_localBallisticTargets` включает street NPCS, beach, gang cars, cityCops
  либо текущий bank/building interior roster. Server worldCops/Michael/convoy/
  gangNests сюда не входят. `_remoteBallisticTarget` возвращает одну aim-цель;
  source не должен выдумывать local HP для server-authoritative соседей.
- Generic shot critical globals читаются на позднем impact; потенциальный
  weapon-switch/next-shot balance drift существует отдельно, не zero-damage
  причина, не изменён в этом scope.

## Следующий согласуемый контракт

Связать фактическую native точку взрыва с уже принятым source shotId: исходный
RPG должен исполняться ровно один раз в этой точке, сохраняя local damage и
server authority. Проверять актуальность, weapon, координаты и space/epoch;
не принимать произвольный визуальный взрыв как разрешение на урон. Parent
разбирает native projectile→bridge. До согласования точного hook source
production не меняется. LIVE/FPS общей сцены не проверены.
