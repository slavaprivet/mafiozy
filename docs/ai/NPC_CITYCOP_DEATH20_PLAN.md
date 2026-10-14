# City cop → replacement corpse: approved план20, candidate PASS

20 сентября 2026. План optional sixth acceptedImpact / structured receipt
одобрен Координатором20; существующий runtime пока под freeze19, production
citycop/RPG destination patch **не применён**.

`test_npc_citycop_death20_candidate.mjs`: **4/4 REVIEW CANDIDATE PASS**. Он
исполняет actual hitCityCop, _localBallisticTargets и _spawnRpgExplosion с
точными предложенными изменениями только внутри памяти теста.

## Точные изменения

1. `hitCityCop(cop,dirY,dirX,damage,source=null,acceptedImpact=null)`.
   Existing source fifth argument неизменен. `let deathWitnessAlerted=false`
   дополняется локальным fatalReceipt=null.
2. В existing окончательной `cop.hp<=0` ветке прежний `NPCS.push({...})`
   превращается в `const corpse={...}` с теми же полями/порядком/единственным
   `deadAt:performance.now()`. Create record на corpse с
   `_threeNpcEntityId(corpse)` и `acceptedImpact?.weapon`; затем прежний push.
   Original cop не получает ни fake dead=true, ни record/deadAt.
3. Локальный immutable return receipt:
   `{sourceEntity:cop,fatalEntity:corpse,deathRecord:corpse._deathRecord20}`.
   Вернуть только после прежних murder/backup/witness hooks. Nonfatal/guarded
   returns остаются undefined; generic callers return не используют.
4. City callback `_localBallisticTargets` передаёт
   `hitCityCop(cop,dy,dx,dmg,null,acceptedImpact)`, где acceptedImpact уже содержит
   замороженный firedWeapon конкретного выстрела. Legacy direct calls unknown.
5. RPG перед t.hit сохраняет `previousDeathRecord` и `previousNpcCount=NPCS.length`,
   принимает его return как hitResult. Существующий finally shot context сохраняется.
6. Destination принимается только при выполнении всех условий:

   - `result.sourceEntity === t.key`;
   - `result.fatalEntity !== t.key`;
   - `result.deathRecord === result.fatalEntity._deathRecord20`;
   - record.targetId равен реальному `_threeNpcEntityId(destination)`;
   - record.deathKey равен строке точного destination.deadAt;
   - `NPCS.indexOf(destination, previousNpcCount) >= 0`: actual callback добавила
     этот объект после начала попадания, это не старый или detached труп.

   Затем прежний enrich helper на destination c previousRecord=null либо обычный
   t.key путь, если receipt не принят. Helper повторно проверяет fatal/cause/epoch.
   Входной RPC payload сам по себе такую object-identity/source-list связь не даёт.

## Что проверено

Фактический новый ID `npc_officer7_corpse`, источник остаётся cop.id=officer7;
clock corpse5000, clock original не выдумывается. Weapon switch rpg→pistol
после создания callback не меняет blast cause. Body receives originSource и
visualSpeed5, original cop ничего не получает. Старый corpse, чужой source,
несовпадающий record object/target и detached payload отклонены. Nonfatal,
alive=false service despawn и server convoy early return не создают corpse.
Legacy missing metadata остаётся unknown.

HP, recipients, aura/AI/crime/wanted/protection hooks не переписываются. Новый
destination scan происходит только после structured fatal receipt, не на каждом
кадре. GPU/LIVE и производительность общей сцены не проверены.

## Следующий timed medical bleedout — пока только план

Current `updateNpcs` final branch `_medicalDowned && now>=_medicalBleedoutAt`
уже authoritative dead=true/deadAt=now, но отсутствуют source fromDowned hint,
очистка forcedCrawl/walking и deathRecord. Lifecycle умеет fromDowned.

После отдельного одобрения в **этой** ветке:

- `_deathFromDowned=true`; `_medicalDownedAt=0`, `_medicalBleedoutAt=0`;
- `_forcedCrawl=false`, `walking=false`, `walkPhase=0`, прежний knockedUntil=0;
- сохранить ровно прежний `deadAt=now`, murder incident и resident replacement;
- добавить явный source event label bleedout в helper→cause=bleedout и вызвать
  creator на том же NPC bridge ID после final flags; направление/contact null;
- не использовать прежние hitWeapon/angle, не объявлять старую пулю/гранату
  непосредственной причиной завершения medical timer.

Приёмка: actual branch elapsed/not elapsed/rescued/protected/repeat; exact clock;
one event/murder/replacement, lifecycle.fromDowned; unknown old-hit не влияет.
Actor/pose/root ownership не затрагивается. Это ещё не внесённые изменения.
