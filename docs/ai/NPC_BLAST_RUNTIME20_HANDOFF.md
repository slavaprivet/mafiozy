# RPG NPC fragments20 — first runtime slice

20 сентября 2026. IMPLEMENTED + CPU TESTED. LIVE/GPU проверяет Художник19.

## Подключено

- `world.html`: helper include + `_spawnRpgExplosion` enrich только NEW final
  death record после существующего accepted hit. Центр именно этого взрыва;
  speed5м/с — авторская скорость эффекта, не измеренный физический импульс.
- `walk_preview.mjs`: parts pool + host создаются рядом с population;
  source snapshot sync, update СРАЗУ ПОСЛЕ NPC pose, dispose приpagehide,
  diagnostics в существующем npcWorld.blast. Отдельной GPU вкладки нет.
- `npc_blast_presentation20.mjs`: целое тело до полной готовности; atomic
  замена после parts-ready. История очищается после8с, busycapacity повторяется
  доTTL. Удаление source row отменяет pending. Новая жизнь другогоepoch не скрывается.
- `npc_death_presentation20.mjs` + actor methods: visualReplaced хранится в
  существующем save/restore, только для matching blast deathKey. Поэтому expiry
  истории/parts или восстановление actor не собирает обратно целое тело.
- `npc_blast_parts_prototype20.mjs` теперь импортирован runtime, несмотря на
  историческое имя. Поэтапная подготовка, глобальный ground query budget192,
  referenceY выбирает этаж, безопасное владение ресурсами, TTLMap дедупликация.

## Поправка для низкого FPS перед первым LIVE

Hard vertex quota поднята256→2048, softtimebudget1.25ms иworkquota2048 прежние.
Прошлый cap недоиспользовал доступное время:49–51frame при7Hz почти съедалTTL8.
Actual end-to-end male/female:7Hz31/28frames (4.43/4.0с),15Hz32/27frames
(2.13/1.8с),60Hz35/28frames (.58/.47с). Все достигаютreadyдоTTL и сохраняют
atomic/save/expiry/respawn. Максимальныйнаблюдаемыйslice2.18ms, бюджет мягкий.
На7Hz всёещёзаметнаязадержка; это не визуальнаяприёмка и не обещаниемгновенности.
Числа49/51нижеотносятсякпрошлойquota256длясравнения. CPUcache/GPUupgradeотдельно.

## Проверки

Root `test_npc_blast_runtime20.mjs`: настоящие male/female GLB, source helper→
actor/lifecycle→actualparts→host. Ready через51/49кадров (~.85/.82с при60Hz cold),
тело видно до готовности, затем только6частей; actor save/dispose/recreate не
возвращает тело; TTL удаляетгеометрию, history0; явный respawn видимый. PASS.
Source/RPG+gas+host13testsPASS. Actual parts12/ground slope/3m/6m PASS,
180actualqueries<=192; geometry866132bytes/60meshes для двухpolice testvictims.
Parts replay/capacity/TTL/live256 saturation +300cyclesPASS. Death26PASS.
WalksyntaxPASS. Никакого уменьшения жителей/качества/коллизий.

## Реальное покрытие и пределы

RPG finaldeath: жители NPCS (кроме отдельных empire branches), bankguards,
beach, localinterior finalbranch. Medical72% survival и protectedroles прежние.
Citycop создаётreplacementcorpse безэтогоконтекста — следующийsource slice.
Empire/server ACK, mercenary downed, decor/remote corpse, grenade/gas/vehicle
контексты пока не подключены к этому эффекту. Не обещать «любойNPC готов».

Максимум2детальныхvictims/12частей одновременно. Очередь ждётместо до8с;
массовыйвзрыв не гарантируетразлёткаждоготела. Непринятые/expiredостаютсяцелыми.
CPU cold preparation≈.8с при60Hz, дольше принизкомFPS. GPU frozenpalette
feasibility19 отдельно, пока не runtime. Открытые garment seams (торс/руки),
нет caps; нет wall collision. Heightfield samples не гарантируютбесконечнотонкие
препятствия; неизвестный/поднявшийсяпол блокируетдеталь вбезопаснойпозе.

Общая производительность сцены не проверена. Bake1.25ms — мягкийбюджет,
groundqueries идут сверхнего; 192queries на настоящей карте требуютзамера19.
До LIVE визуальнаяприёмка остаётсянепройденной.

## Соседние готовые изменения

Groundmemo actor уже runtime: early exactmeshcapture, cache only settleddeath,
89hits/1miss; actualmale CPU wholeactor p501.37–1.48→.75–.86ms,
female1.21→.63–.67. Root/platform/water movement invalidates. NoFPSclaim.
Vehicle deathentry runtimeREADY: firstframejump до81см→<6.43e-8m,
vehicle-only; prone/crawl отдельный незавершённыйпереход. Clock иrawdeathages
сохранены. GAS station biReferenceError исправленбезdamage/balancechanges.
