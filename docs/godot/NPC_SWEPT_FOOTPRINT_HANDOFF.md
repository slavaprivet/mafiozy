# NPC swept footprint — exact scalar64 module

27 сентября 2026. Реализован самостоятельный source-equivalent planar sweep; **main/NPC/навигация не подключены**. Godot native headless: **6 889 checks PASS, exit 0**. Текущие GPU PID12540/session49876 не затронуты.

## Передаваемые файлы

- `godot/mafiozi_walk/scripts/navigation/npc_swept_footprint.gd`
- `godot/mafiozi_walk/scripts/tests/test_npc_swept_footprint.gd`
- `godot/mafiozi_walk/scripts/tests/fixtures/npc_sweep_oracle.json` — immutable reproducible oracle для Git, ~661 KB.
- `tools/godot/build_npc_sweep_oracle.mjs` — exact source execution/fixture generator для Git; пути от собственного location, не от cwd.
- `outputs/coordinator21_npc_port/sweep_headless_result.txt` — последний actual native report.

Также по прямому scope root предыдущий queue generator **перемещён** из outputs в `tools/godot/build_path_queue_oracle.cjs`; корень определяется через `__dirname/../..`, выход по-прежнему generated `outputs/coordinator21_next_package/oracle.json`. Команда в `PATH_JOB_QUEUE_HANDOFF.md` обновлена. Проверено выполнение generator из `C:/Users/Слава` и последующий queue native headless: **7 075 checks PASS / 10 scenarios / 11 375 operations / exit 0**. Queue runtime не менялся.

## Источник и точность

Полный source `assets/maps/city_rebuild_v1/npc_swept_footprint.mjs`, SHA256 `918467e987c06cbdc88af5772113d8492f1d58e9198d0e86e7050b2c1c617258`.

Алгоритм сохранён: восемь углов квадратного NPC footprint в начале/конце сегмента → convex hull **footprint**, не obstacle → AABB reject → polygon-in-hull/hull-in-polygon → точные пересечения граней. Concave obstacle остаётся concave. Collinear/contact endpoint rules, candidate-contact order и epsilon `1e-10`, `1e-18`, `1e-15` сохранены. Source сортирует восемь points; native stable insertion sort даёт тот же порядок, но убирает Callable comparator overhead.

Все координаты — scalar GDScript `float` (binary64) в Array; нет промежуточных `Vector2`/`PackedVector2Array`, которые в текущем engine хранят float32. Условия и алгебра не заменены engine geometry helper с другой точностью. Если будущий host уже получил rounded Vector3/physics координаты, модуль не восстановит потерянные биты; этот proof не распространяется автоматически на весь physics engine pipeline.

При первом сравнении decimal JSON выявилась потеря последних binary bits при чтении некоторых десятичных значений в Godot. Поэтому fixture хранит **каждое входное и ожидаемое число** как `{"$f64le":"<16 hex>"}`: Node `writeDoubleLE` → Godot `hex_decode().decode_double(0)`. Godot сравнивает bounds и contact coordinates строгим `==`, без geometric tolerance/округления. Таким образом PASS не маскирует отличие алгоритма неточным transport format. SHA fixture sources проверяется при каждом тесте.

## API и границы authority

```gdscript
const Footprint = preload("res://scripts/navigation/npc_swept_footprint.gd")
var footprint = Footprint.new()
if not footprint.set_segment(from_rc, to_rc, 0.18):
    # Host treats this as blocked, never a clear path.
    return
var query_bounds = footprint.bounds()
# Host obtains current authored candidates from its own spatial index.
# For each candidate: overlaps(polygon_cr, current_height_contact_predicate).
```

`set_segment(from_rc,to_rc,radius=0.18)->bool`; endpoints Dictionary `{r,c}`. Имя отличается от JS `set`, поскольку Godot Object уже имеет property setter `set`.

`overlaps(polygon,test_point=Callable())->bool`; polygon Array of `[c,r]`, без перестановки координат. Callback `(c:float,r:float)->bool`: true означает этот контакт действительно solid по текущему floor/height правилу; false продолжает проверку следующего геометрического контакта. Отсутствующий callback означает любую planar коллизию. Он не означает «проход разрешён».

`bounds()->Dictionary`: `valid,minC,minR,maxC,maxR,hull_count`; detached diagnostics. Bounds можно использовать для broadphase, но сам этот модуль его не строит. Runtime не сохраняет polygon/endpoint/callback references, не мутирует входы и не создаёт NPC/маршруты/geometry nodes.

**Единицы — source клетки**. Source default half-width `.18` означает `.738 m` при scale4.1; это square footprint, не `.18 m` capsule. `polygonCR` и endpoint r/c должны быть в одной source системе. Для Godot local metres host сначала учитывает block origin и 4.1; нельзя применять метры к исходному radius.

В реальном `npc_native_navigation.mjs:9–26` callback `solidAtContact` берёт `groundHeight(c*worldScale,r*worldScale)` **в контактной точке**, затем отвергает body below floor+.05 или above floor+height. Это сохраняет ramp corner support и headroom. `overlaps=false` всё ещё не доказывает проходимость: terrain, water depth, dynamic actors/vehicles, passage exceptions и physical controller sweep остаются отдельными существующими gates. Этот пакет их не переписывает и не обходит.

Door body polygon обязан быть из **текущей** позы двери. Модуль не кеширует obstacle geometry и не открывает/закрывает двери. Printshop door rotation/occupants продолжают принадлежать `PreviewPrintshopInterior` и source host. Oracle содержит actual exported closed-pose door polygons; поведение дверей во всех динамических позах этим тестом не принято.

## Host input/safety contract

- Main-thread, одна операция на instance; callback не reenters instance, не мутирует polygon, не yield/await и не вызывает side effects. Reentry отклоняет nested mutation и делает outer overlap blocked. Worker query также fail-closed, state не меняется. `bounds` — main-thread read-only API по host contract.
- Endpoints/radius/polygon scalars finite numeric, без bool/string coercion, abs<=1e12 source cells. Radius>=0: zero оставлен для exact degenerate geometry tests; полный native navigation source запрещает radius<=0, будущий navigation host обязан сохранить это правило.
- Ограничение 1e12 — явный unsupported-input guard далеко вне существующего мира; оно предотвращает double-product overflow. За его пределами equivalence с permissive JS не заявляется.
- Invalid/uninitialized segment, malformed/nonfinite/out-of-range polygon, wrong callback return type → blocked. Failed `set_segment` инвалидирует старый hull, чтобы ошибка не использовала прежний clear path. Valid subsequent set восстанавливает instance.
- Source empty/null polygon сохраняет false после valid set. Degenerate point/line/repeated vertices также не «исправляются» на новую геометрию: source oracle содержит эти cases.
- Callback должен возвращать bool, как actual `solidAtContact`; JS truthy non-bool не используется для расширения movement authority. Invalid return блокирует.
- Память внутреннего scratch фиксирована: 8 point arrays + hull capacity16. Фиксированного polygon-count/CPU бюджета здесь нет; bounded candidate selection и кооперативный PathJobQueue budget — ответственность будущего navigation host. Нельзя прогонять все городские polygons для каждого NPC каждый frame.

## Проверка

**731 cases**, в том числе **107 actual exported bodies**: 103 printshop static + 4 public/service door body polygons. На каждом actual body проверены crossing, diagonal contact collection с false callback, clear offset segment, stationary inside. Дополнительно thin/concave notch/floor/contained/touching/collinear/near-epsilon/zero-radius/point/line/repeated vertices и 256 deterministic synthetic concave shapes с reverse winding/oblique movement.

Synthetic shapes — только тестовая геометрия; NPC roster/snapshot не создавался. Generator импортирует и исполняет **действующий JS source module**, не копирует его логику в тест.

Native сравнивает overlap decision, четыре bounds, callback count/order и **каждую contact coordinate точно**. Негативные проверки: missing endpoints, NaN/INF/types/ranges/radius, malformed polygon, wrong callback return, reentry, stale hull после failed set, detached inputs/diagnostics, worker denial. Actual Godot `4.7.2.stable.official.ed1daf0bf`, headless: 6 889 checks, failures[], exit0.

Ранее в этом же audit выполнен actual source `test_npc_swept_navigation.mjs`, exit0: thin/concave/contained/touching, spatial bounds/dirty door groups, ramp support/headroom и custom passage guards. Это дополнительный JS source result, не заявленная native water/navigation integration.

## CPU cost и оптимизация

Одинаковый stress workload: 10 warmup + 60 measured batches; каждый batch выполняет **107 отдельных set+overlaps pairs**, пересекающих реальные obstacles. Это намеренно более тяжёлый режим, чем reuse одного hull с broadphase candidates. Search/actor/rendering отсутствуют; injected geometry одинакова до/после.

До caching scalar reads/stable fixed-eight insertion sort: batch p50 **4699 us**, p95 **5464 us**. После оптимизации первый comparable run: p50 **3753 us**, p95 **4077 us**; все точные cases остались PASS. Последний final run с worker negatives: p50 **3918 us**, p95 **5038 us**, max **5463 us**; среднее pair на p50 **36.62 us**. Shared desktop CPU шум заметен; это отдельные measurements, не обещанный процент ускорения или FPS.

Производительность общей сцены не проверена. Не измерялись draw calls/triangles, NPC path latency, loaded-scene frame p50/p95. Перед интеграционной приёмкой root измеряет actual navigation update в той же загруженной сцене; GPU window в этом пакете не запускалось.

## Воспроизведение и Git scope

```powershell
node tools/godot/build_npc_sweep_oracle.mjs
& 'C:/Users/Слава/AppData/Local/MafioziTools/Godot-4.7.2/Godot_v4.7.2-stable_win64_console.exe' --headless --path godot/mafiozi_walk --script res://scripts/tests/test_npc_swept_footprint.gd

node tools/godot/build_path_queue_oracle.cjs
& 'C:/Users/Слава/AppData/Local/MafioziTools/Godot-4.7.2/Godot_v4.7.2-stable_win64_console.exe' --headless --path godot/mafiozi_walk --script res://scripts/tests/test_path_job_queue.gd -- '--oracle=C:/Users/Слава/Desktop/Мафиози/outputs/coordinator21_next_package/oracle.json'
```

Оба generator проверены из другого cwd при абсолютном пути к ним. Для чистого checkout generator, immutable sweep fixture, runtime/test/handoff должны войти в scoped Git checkpoint. Queue output остаётся generated и восстанавливается tracked generator. Автор не выполнял commit/push и не менял main/player/perf/water/dive/Walk sources.
