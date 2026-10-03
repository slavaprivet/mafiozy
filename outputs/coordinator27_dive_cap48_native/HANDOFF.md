# Короткий нырок на реальном player48 — native PASS

Принятая48 и её pointer не изменены. В двух отдельных копиях по486 source pins
единственное runtime-различие — `scripts/preview_dive.gd:133`: горизонтальное
движение ограничено `FLIGHT=.8` вместо `CINEMATIC_FLIGHT=1.25`.
До: `32be580dbbfdc9169225e822acafb7c73c68c6e33a139c0b0970585808927ceb`.
После: `93a4e9fad1f5d91a57d3463ee51b7f1066a3e6dccc3acc1bfc3c61a5d11e2858`.
Это exact A3 `preview_dive_patched_r12.gd`, без присоединения39/40/41.

Оба импорта и оба игровых headless прогона завершились exit0/stderr0;
baseline404 и candidate404 checks PASS. `REVIEW.json` содержит точные hashes
RUN/RESULT, source freeze и итоговую проверку всех pins. Каждый запуск использовал
общий scheduler; пользовательская игра и editor сохранили точные identity.

| Настоящий ввод | Baseline, м | Candidate, м |
| --- | ---: | ---: |
| Обычный Space | 2.800392 | 2.800392 |
| Второй Space сразу, wall age0ms | 5.250340 | 3.360348 |
| Второй Space на elapsed.416667, wall414/420ms | 4.958687 | 3.068695 |
| Поздний Space, wall801ms: отказ upgrade | 2.800392 | 2.800392 |

Это реальные конечные положения `Main._player`. Его настоящий `.30×1.9`
collider, bound hero/sampler, floor/permission guard и `move_and_slide` сохранены.
LMB проходит через viewport, W/Space — через настоящие input events с release.
Нет прямых jump/upgrade вызовов, подставного времени или записей jump state;
позиция ставится только один раз до начала каждого случая на существующий пол.
После первого Space W отпускается: направление уже сохранено в jump state.

После.8 у кандидата сохранённые native displacement и source-linked proposal
равны0 по горизонтали; baseline проходит ещё1.889992м. Во всех сохранённых ticks
последняя native receipt совпадает с независимо измеренным tick displacement.
Физический контакт cinematic остался1.25s, конец recovery1.716667s у обоих;
обычный контроль завершается1.25s. Node/shape/размеры/filters/epoch не менялись.

Source-linked proposal намеренно отдельно от actual movement. Математический
early cap3.36м; измеренный native endpoint выше на0.348мм из-за численного/contact
разрешения, comparable normal surplus0.392мм остался прежним. Не заявлять строгий
physical endpoint≤3.360000м. Fixture допускает1см, фактическая погрешность сохранена.

Независимый source review `/root/c4_runner_review` не нашёл blocker для этого
узкого утверждения. Сам404PASS не требует native post-.8 zero; это дополнительно
проверено по сохранённым ticks и записано в REVIEW. Metadata actor_id/life_generation
отдельно не проверялись; переходы lifetime не заявлены.

Это headless functional proof в текущем Main на свободном существующем полу,
не performance/visual приёмка. Нет доказательства всех направлений/препятствий/
потолков, rotated full-body39/40, owner-return41, weapon IK или C4 pose44.
Чужие residents/vehicles не отключались, GPU не запускался. Сценовые стоимость,
память и видимую приёмку root решает отдельно перед выпуском.

Новые labels обязательны; runner отказывается перезаписывать stage/receipt.
Сохранённые команды: `runner.py stage baseline|candidate`, затем
`runner.py import baseline|candidate --label <fresh>`,
`runner.py run baseline|candidate --label <fresh>`.
Для нового запуска сохраняются exact source/engine/fixture pins и100s watchdog;
копии замороженных текущих результатов не менять.
