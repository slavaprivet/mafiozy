# Скрытое тело после blast parts: isolated review, 23 сентября

**READY FOR ROOT REVIEW — НЕ INTEGRATED.** Изменены только новый тест, этот audit и candidate patch. Production, browser/GPU, git index и commits не менялись. Владелец общей perf-интеграции — Проверщик2; root согласует narrow actor/surface patch.

## Подтверждённый defect

Actual `walk_preview.mjs` вызывает `npcPopulation.update(dt,now)`, затем `npcBlastPresentation.update(now)`. Population делает обычную позу и снова выставляет видимость целого actor; blast host после этого опять скрывает тело, уже заменённое шестью фрагментами. Persisted `isDeathVisualReplaced(deathKey)` существует и переживает TTL фрагментов/сохранение actor.

На настоящих male/female GLB, actual population/actor/walker/surface/parts/host и source fatal-record helpers:

| 60 render updates, settled replacement | Production full walker / surface | Candidate full walker / surface |
|---|---:|---:|
| 5 м | 60 / 60 | 0 / 0 |
| 45 м | 10 / 10 | 0 / 0 |

**Дешёвый вход `actor.update` сохраняется**: 60/10 вызовов согласно прежнему LOD. Он обновляет часы, источник, receipt/stun lifecycle и transform, затем возвращает существующий `lastSurface`. Это существенно: нельзя просто выкинуть все actor calls.

Geometry position/index hashes всех шести фрагментов совпадают с baseline для обоих полов и расстояний. Момент readiness совпал: t=1.316667 при deathAt=1 и детерминированном work budget2048. До readiness, завершения authored fall (.62 s) и `gait===0` обычная поза сохраняется. Проверка движущегося NPC перед смертью отдельно подтверждает, что остаток gait не замораживается раньше времени.

## Окончательный кандидат — только actor + surface

[NPC_BLAST_POSE_SKIP23_CANDIDATE.patch](NPC_BLAST_POSE_SKIP23_CANDIDATE.patch) содержит два маленьких блока:

1. `hero_artist14_surface.mjs`: read-only `hasActiveContactEffects()` видит private pending particles, active bleed, воду и пятисекундное окно shedding. `advanceReplacedVisualClock(now)` разрешает fast path только для dead surface, конечного неубывающего времени и отсутствия этих эффектов; меняет только scalar clock.
2. `npc_actor.mjs`: после обычных clock/lifecycle/receipt/stun шагов, перед skeletal/visual work, проверяет точный persistent death replacement, предыдущую полную settled pose и нулевой gait. Если surface принимает clock-only update, прячет целое тело/пустой particle draw, обновляет возраст в `lastSurface` и возвращает его.

**`npc_population.mjs`, blast host, parts geometry/TTL/grounding, source authority и LOD не меняются.** Состояние respawn/new death сбрасывается обычной `syncSourceLifecycle` раньше fast path. Частицы с живыми эффектами продолжают прежнюю полную ветку, включая прежний LOD. Существующий sibling particle draw не удаляется ради CPU выигрыша.

Patch проверен `git apply --check --ignore-space-change docs/ai/NPC_BLAST_POSE_SKIP23_CANDIDATE.patch`. Обычный check без флага видит CRLF/LF mismatch у surface; runtime patch **не применялся**.

Audited production hashes:

- `npc_population.mjs`: `fc3c4cc243ccb7700526b6680fa7ee83e7fbad9e83798880458cb1dd8c0816ad`
- `npc_actor.mjs`: `bf5df4dc3adb3f32e28b5df255e2503e25fabd9f987a814a8d94cd6d573b9991`
- `hero_artist14_surface.mjs`: `30de352fc12723343aafad5c7b04a3a46a40f417a246953f85bc60c48b0af243`

## Почему отвергнут population-only skip

Тест сохраняет две отдельные отрицательные гипотезы, чтобы reviewer мог воспроизвести ошибку:

- `visible && !replaced`: новый confirmed contact уже добавляет кровь в private particle array, но public `mesh.count` ещё0. Такой skip теряет видимый эффект.
- Такой же skip плюс read-only effect guard: после двух секунд простоя внутренние actor/surface часы остановлены; существующий population `poseInterrupted` restore стирает свежие private particles перед возобновлением. Позднее кровотечение также рискует получить неверный TTL.

Оба дефекта воспроизведены actual functions, не искусственным mock-аналогом surface. Поэтому **не применять первые population snippets из обсуждения**. Окончательная версия оставляет clocks/lifecycle на прежней cadence и пропускает только дорогую визуальную часть actor.

## Validation

`node --test test_npc_blast_pose_skip23.mjs` — **17 PASS**. Тест импортирует baseline production напрямую и строит isolated data-URL кандидаты из точных production anchors. Actor semantics меняются только указанным fast path; в test loader заменён import surface и база `import.meta.url` для настоящих GLB. До/после теста bytes population/actor/surface сравниваются: production не изменяется.

Проверены:

- male/female, near/far, actual GLBs, six complete fragments and identical geometry/readiness;
- 7/15/60 Hz, inspection-forced near LOD, far/focus culling и возврат;
- pending/rejected geometry и обычная bullet death не пропускают позу;
- source TTL8 s; отсутствие повторного целого тела после expiry;
- snapshot absence, GPU eviction и actual actor recreation, сохранение source death clock/возраста;
- explicit alive, fresh death epoch и reuse того же ID, включая retained source row до очередного .1 s poll;
- sparse snapshot/temporary downing не оживляют corpse;
- свежий accepted contact после двух секунд hidden idle: visible particle instance matrices, цвета/count совпадают с production побитно;
- persistent bleed плюс финальные капли: **570-frame trace exact**, в том числе после TTL fragments;
- water entry/exit и пятисекундное shedding window консервативно сохраняют полные effect updates;
- actual alive walking → fatal blast: fall и остаточный gait заканчиваются перед fast path;
- disposal без оставшихся scene children; source row/HP/position не мутируются.

## CPU evidence и границы

Изолированные 60 samples после завершения падения, одинаковые actor/scene position/LOD/work budget. Измеряется production population `pose` stage; render/GPU отсутствуют. Один последний запуск, ms p50/p95:

| Модель / расстояние | До | Candidate |
|---|---:|---:|
| male / 5 м | .6807 /1.1242 | .0127 /.0545 |
| male /45 м | .0030 /1.1593 | .0025 /.0149 |
| female /5 м | .6372 /.8961 | .0087 /.0294 |
| female /45 м | .0032 /.7006 | .0025 /.0109 |

У far p50 низок уже в baseline, потому что пять из шести кадров — transform-only. CPU данные показывают устранённую работу, **не FPS и не loaded scene performance**. Нет изменения draw calls/triangles у видимых фрагментов. Нужны review точного patch root/Проверщиком2, затем production regression через прямые imports и согласованный LIVE в существующей вкладке. До этого данный этап остаётся isolated candidate.
