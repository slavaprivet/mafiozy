# Collect-визит: изолированный жизненный цикл

23 сентября 2026, Художник21. CANDIDATE ONLY, НЕ runtime и НЕ LIVE.

Файлы: `npc_collect_visit23_candidate.mjs`, `test_npc_collect_visit23.mjs`,
`outputs/npc_collect_visit23_candidate.json`. Никакого импорта в world/Walk нет.

Модель принимает подготовленные action/generation, provenance, native binding,
actor, optional guard и результат фактического прибытия. Эти входы синтетические
в тесте: adapter координатора ещё не подключён. Строка provenance='server' сама
по себе не является авторизацией или доказательством authentic state.

Фазы: approach → checking (2.4 секунды) → done. У каждой generation только один
begin-check. В пределах этой generation отменённая сцена не запускается заново.
Бой, смерть, скрытие, смена владельца/site, исчезнувший приказ и уход от точки
освобождают паузу. Более старая generation игнорируется. Новая generation начинает
с подхода и освобождает прежнюю паузу. Offline/preview и отсутствие точной связи
holding/owner/site не допускают сцену. Дальнего, мёртвого или чужого охранника
модель не использует в качестве собеседника.

Модель не пишет в actor, не перемещает NPC, не создаёт путь/охранников/здания,
не вызывает сеть и не начисляет денег. Эффекты только begin-check, hold, release;
адаптер должен ограничить их peaceful boss веткой, не перекрывая combat priority.
Native вход/точка уже существующего бизнеса предоставляется root; локального
fallback по центру блока здесь нет. При интеграции нужен устойчивый site identity,
проверка актуального ownership и правильная provenance до передачи в модель.

Проверено `node test_npc_collect_visit23.mjs`: 7 групп поведенческих сценариев,
включая 100 повторных state polls, exact-route+distance gate, прекращение hold,
stale generation и отсутствие мутаций. 19 вызовов checking после прогрева:
CPU p50/p95 0.0029/0.0034 мс. Это стоимость только pure helper в синтетическом
стенде, не полный update, не FPS и не стоимость native binding.

Открыто: production adapter/точка existing native business, реальный физический
подход, видимая поза/речь, проверка authenticated state и замер общей сцены.
До согласованного следующего пакета runtime freeze сохранён.
