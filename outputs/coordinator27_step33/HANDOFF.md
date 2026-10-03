# Step33 на accepted45 — source-only пакет root27

Единственный runtime patch: `patch/scripts/preview_player.gd`. Это **точные байты** прежнего `outputs/coordinator25_step33/files/scripts/preview_player.gd`, SHA `b33505b2bbadcadb5754e474f1a9cbb7b218f0abcbfa7ea7b70db8facff19d6c`. Новая реализация не изобреталась.

Accepted45 player совпадает с историческим baseline33: `64707b7c6d72d863651c3ce2d277af3ed2b14facbca6bb8801f41c95a2904e70`. Поэтому API merge не требуется. Base ASSEMBLY45 закреплена SHA `f797214092875a9e91cd47aa30cf751b99909f089d9b3b6bb8f4be34c6336b21`; все473 исходных pins сверяются подготовкой. Полный game stage не создаётся.

Предложения Астра3 `step33_r3.patch` и `response04.md` прочитаны и закреплены в MANIFEST. R3 содержит те же caller и оба helper; отличается размещением helper перед `_body_motion_delta` вместо `set_preview_jump_surface_guard`. Выбран exact исторический runtime, на котором root25 действительно получил результаты, а не новая byte-variant. Ответ04 не предлагал нового diff. Прежние malformed hunk headers не используются: review diff здесь построен заново из фактических base/after bytes.

## Сохранённые пути

Исходная капсула 1.9м×radius0.30, безопасный отступ, floor_snap0.25, угол46°, masks/layers/exceptions и scene wiring не меняются. Вся декларация полей/констант и44 прежние функции сохранены. Изменён только ordinary `_physics_process`; добавлены два bounded admission helper. Отдельные dive39, rotation40, return41 не включены. `_body_motion_delta`, authority/epoch/lifetime, jump/dive, corpse owner/mask negotiation, pressure receipts, seat/physical ownership, ввод и pose decoration сохраняются.

Step query вызывается только в ordinary on-foot пути после прежних early returns, при grounded movement и разрешённых controls. Он требует неподвижное `StaticBody3D` world-layer1, отклоняет Rigid/Animatable/moving-static и проверяет всю неизменённую капсулу вверх/вперёд/на опоре/по фактической диагонали. Новых teleport, `move_and_collide`, второго `move_and_slide` или mask overrides нет. Вертикальная прибавка попадает в существующий единственный native move и очищается после него; capture/seal/body receipts остаются вокруг этого движения.

Общий helper путь ограничен максимум5 `test_move` и2 rays на попытку, с ранними отказами; flat walking добавляет начальный collision query. **Цена не измерена**: считать это бесплатным по source нельзя.

## Что прежняя приёмка доказывает и что нужно проверить заново

`newfixture/ACCEPTANCE33.json` — исторический root headless на25a: passage1997 и corpse2738 checks; production/GPU/perf не приняты. Это не новый PASS на45. Прежний townhouse остаётся архивом и не возвращается ради fixture.

**Палаццо:** admission остаётся120мм; фактический фундамент над plaza имеет210мм (.30−.09). Этот пакет намеренно не расширяет limit и не обещает проход через такой фундамент. Если настоящий новый Palazzo test фиксирует блокировку foundation, это отдельный root/Buildings3 design/fix, а не повод увеличивать limit до.21, опускать площадку, скрывать коллизию или телепортировать игрока в QA.

Новая QA на текущем Palazzo-only мире должна записывать настоящий collider/shape, фазу PREBLOCK/POSTBLAST, ground/top height, native slide contacts, W/S displacement и pressure receipt. Использовать настоящий доступный малый статический порог/край≤120мм или отдельно разрешённый isolated component fixture; не выдавать искусственный малый порог за реальный Palazzo210мм. Сохранить source world/body/shape identities, дверь/основание/J, три NPC и транспорт. При блокировке210мм записывать реальный отказ, не обходить его.

Обязательные будущие проверки:106/120/121/210мм (120 требует измерения float boundary, без заранее расширенного epsilon), высокий барьер/низкий потолок, world-layer rigid/animatable/moving-static, flat ground, отсутствие управления/Q/authority interruption, sprint3.2/5.8 и motion>120мм/tick negative. Новый corpse-pressure прогон должен подтвердить один native displacement, serial/epoch и неизменные corpse owner IDs/masks. Затем отдельный GPU и одинаковая loaded45/step33 сцена с полным movement/contact path, p50/p95/max и RSS; не уменьшать состав/геометрию.

## Подготовка

```powershell
# Только read-only source verification.
python -B outputs/coordinator27_step33/prepare33.py

# Только собственный one-file patch/diff/manifest, уже выполнено автором.
python -B outputs/coordinator27_step33/prepare33.py --prepare
```

Движок, GDScript native parser, Git, shared/runtime/pointer и старая QA не менялись. MANIFEST имеет статус `SOURCE_READY_NOT_STAGED_NOT_PARSED_NOT_RUN`; никаких native/perf/production PASS для45 не заявляется. При смене accepted base нужна новая явная сборка manifest, автоматического repin или подключения к C4 candidate47 нет.
