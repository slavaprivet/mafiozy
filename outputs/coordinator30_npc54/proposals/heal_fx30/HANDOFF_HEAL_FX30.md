# Heal FX30 — готов к интеграции

**READY_SCOPED_NATIVE_AND_RENDERED**. Розовые полупрозрачные крестики появляются только после настоящего положительного изменения HP в двух native hospital commit paths. Поднимаются вместе с текущим телом, плавно затухают; ожидание лечения, урон, downed0→1 и создание полной HP новой жизни их не запускают.

## Ровно три runtime файла

- Новый `scripts/npc_visual/npc_heal_fx30.gd`: проверка authoritative receipt и bounded reusable scene pool.
- `scripts/npc_daily_life.gd`: одна строка после записи hospital51 receipt в `health.last_result`.
- `scripts/hospital/npc_hospital_treatment_port.gd`: такая же одна строка после прежнего hospital receipt.

HP/ревизии/навигация/сервис/health owner не менялись. Helper проверяет тот же current owner/binding/row/adapter receipt/revision, actual hospital reason и конечный HP; `hp_after > hp_before > 0`. Повторная доставка той же или более старой ревизии не создаёт новый эффект. Никакого polling сравнения HP с прошлым кадром и ложного эффекта от respawn.

`BASE_HEAL_FX30.json` хранит base/proposed SHA. `apply_heal_fx30.py` проверяет все три файла до записи, принимает только base/proposed и идемпотентен; first/second apply проверены в `apply_validation`. CLI сам получает write lease:

```powershell
python -B outputs/coordinator30_npc54/proposals/heal_fx30/apply_heal_fx30.py outputs/coordinator30_npc54/game --report outputs/coordinator30_npc54/HEAL_FX30_APPLY.json
```

Если root уже держит write lease, вызвать функцию `apply(game,report)` внутри него. При последующих lifecycle/threat изменениях `npc_daily_life.gd` не заменять чужой файл целиком: использовать сохранённый однострочный `.patch` с точным контекстом и собственным receipt интеграции.

## Native/rendered доказательства

`runs/visual03`: **110 checks PASS**, failures=[], import/native exit0, stderr0, source drift0. Настоящая main_city, настоящий один житель, физический подход к медику и лечение **29.4→60 HP**. В момент подтверждения ровно4 active crosses/1 event. Через2.07с active0, allocated4, processingfalse; pool спит.

`runs/visual03/observed/heal_actual_hospital.png` просмотрен: четыре лёгких розовых плюса ясно читаются около лечившегося NPC на выходе; за ним настоящий медик/кейс. Это native rendering, не макет.

Дополнительные native checks внутри того же прогона: forged event rejected, replay rejected, no effect while waiting, flood ограничен12 слотами, reuse без роста, damage/death/disposed owner/new generation/freed body немедленно очищают активные эффекты. Flood/cleanup проверены на отдельно обозначенном synthetic pool fixture без изменения настоящего NPC или его receipt; настоящий hospital commit проверен отдельно в том же runtime.

`native01` сохранён как неудача QA observer: старое имя поля направления маршрута. Runtime helper компилировался; собственный exact child после ошибки остановлен. `visual02` прошёл110 checks, но NPC заслонял отставшие крестики на выходе; в final03 cosmetic origins следуют текущему телу, новая native/rendered проверка прошла.

## Стоимость и срок жизни

- Lazy pool на сцену; обычный heal создаёт1 Node3D +4 MeshInstance3D. Жёсткий максимум1+12 узлов.
- Один shared cross ArrayMesh:12 вершин/10 треугольников, один shared unshaded pink alpha material. Обычный пик4 mesh instances/40 rendered triangles; hard cap12/120.
- На событие4 крестика с задержками0/.12/.24/.36с, размер.16/.185м, lifetime1.45с после задержки, подъём.52м/с; последний исчезает через1.81с.
- Нет коллизий, костей, теней, timer/tween на частицу, постоянного health polling или per-frame работы в покое. Все owner/body refs слабые, scene tree владеет пулом.
- Geometry/cost accounting не заменяет FPS-приёмку; performance_accepted=false. Shared game не менялась; root выполняет общую интеграцию/приёмку55.

Повторный native/rendered тест использует `run_heal_fx30.py <new-name> --mode graphical`, scheduler и существующий reusable private ambient30/oracle01/project; новых full clones нет.
