# RPG explicit blast metadata20 — production source READY

20 сентября 2026. Новый изолированный classic helper
`npc_blast_record20_source.js` + `test_npc_blast_record20_source.mjs`.
После явного review Координатора20 script include и точный RPG hunk применены.
Тесты переведены на actual production source; baseline получается удалением
только двух новых hook строк внутри памяти теста. RPG+gas+source **13/13 PASS**,
world-walk-shots PASS, inline world syntax PASS. Source scope освобождён.
Root ведёт normalizer/actor/host controller отдельно; эти файлы здесь не менялись.
City cop replacement corpse пока требует отдельного согласованного callback
destination binding. Ниже сохранены контракт и исходный review patch.

## Helper

`enrichNpcBlastRecord20({entity,previousRecord,originSource})` возвращает новый
frozen record либо null. Сам entity/старый record не мутирует. Допускается только
новый `_deathRecord20` после t.hit: source dead=true, !medicalDowned, finite
positive deadAt, record confirmed/fatal/version1/cause=blast и exact deathKey.
targetId/eventId сохраняются буквальными, новых ID helper не выводит.
Отклоняются прежний объект, копия прежнего event/target/epoch, уже дополненная
запись, невалидный origin и recordless классы. Это presentation metadata,
не новая HP/authority проверка и не сетевое подтверждение.

Добавленное поле:

```js
blastPresentation: {
  version: 1,
  originSource: {r, c}, // центр ЭТОГО принятого source explosion, в source tiles
  visualSpeed: 5       // выбранная скорость эффекта в м/с, НЕ измеренный impulse
}
```

Все три новые оболочки immutable: result, blastPresentation, originSource.
Исходный frozen record остаётся без поля; никаких nearby FX/look/severMask/HP
догадок. Нулевое расстояние до центра не заставляет helper придумывать направление.

## Предлагаемый точный world patch (ожидает review)

После существующего include `npc_death_record20_source.js` добавить:

```html
<script src="assets/maps/city_rebuild_v1/npc_blast_record20_source.js"></script>
```

Только внутри `_spawnRpgExplosion`, вокруг существующего t.hit:

```diff
     const pendingId=_authoritativeShotId;_authoritativeShotId=shotId;
+    const previousDeathRecord=t.key?._deathRecord20;
     try{t.hit(dmg, d > 0.01 ? (t.r-r)/d : 0, d > 0.01 ? (t.c-c)/d : 1);}finally{_authoritativeShotId=pendingId;}
+    if(typeof enrichNpcBlastRecord20==='function'){const record=enrichNpcBlastRecord20({entity:t.key,previousRecord:previousDeathRecord,originSource:{r,c}});if(record)t.key._deathRecord20=record;}
     if(!reservedBefore&&_authoritativeTargetClaims.has(String(shotId||'')))authoritativeTarget=true;
```

После synchronous callback return никто не увидит частично изменённый record:
заменяется одна ссылка, старый object не трогаем. Callback exception сохраняет
существующий finally восстановления shot context и не доходит до enrichment.
Асинхронные server callbacks/recordless citycop не получают metadata и этим
пакетом не объявляются поддержанными. NPC medical survival сохраняется.

## Проверки

`node --test assets/maps/city_rebuild_v1/test_npc_blast_record20_source.mjs`:
**5/5 PASS**, около182мс CPU. Три tests явно помечены REVIEW CANDIDATE: исполняют
настоящую `_spawnRpgExplosion` с указанным hunk **только в памяти**, actual
`_localBallisticTargets` и actual `hitNpc`. Сравнивают до/после HP/deadAt/position/
eventId, medical HP1/downed, nonfatal/outside/recordless cop, повторный взрыв по
старому трупу и исключение callback. Два tests проверяют pure helper validation,
immutability, stale epoch/event и origin copy. Никакой production RPG PASS пока нет.

При принятии patch candidate test следует перевести на actual integrated source,
сохранив baseline comparison через удаление только этих строк в памяти теста.

SHA256 helper: `3c9469433dfbf77b1ce1d6fc3e96dccd1f5f5d5185f4a2d874bda271ea432310`.
SHA256 test: `c23c2a119a180c51eaef09943122028753832483fa2ee9c9ae0ee847bfa17564`.

Runtime helper теперь загружается через world. GPU/LIVE не проводились, производительность
общей сцены не проверена. Плановая работа только в accepted-hit callback,
enrichment allocations только на новом окончательном blast death, не каждый кадр.
