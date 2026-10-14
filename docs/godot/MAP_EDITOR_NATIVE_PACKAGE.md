# Редактор Godot — пакет к интеграции, 27 сентября

## Повторная проверка кеша оригинальных изображений объектов

Root независимо создал свежий `outputs/captured-image-loader-VcFeeS` из
`tools/godot/map_editor_captured_image_candidate`: staging проверил 92 файла.
Godot 4.7.2 headless: **289 checks PASS**, failures=[], без ScriptError.
Все 43 исходных изображения / 55 033 856 байт RGBA сохранены точно;
проверены независимые копии, отказ при подмене и смена поколения кеша.

Отдельный повторный замер: 1 прогрев + 7 последовательных пар, p50/p95
нового поколения **434.917/444.128 мс**, повторных копий того же поколения
**0.823/1.123 мс**. Холодная ветка делает 86 чтений/хешей и 43 декодирования;
повторная — без новых чтений, хешей или декодирования. Кеш ОС прогрет,
configure не включён: это стоимость повторной CPU-подготовки изображений,
НЕ старт всей игры, FPS или загрузка GPU. Пакет не подключён production;
шрифты, sampler, кубическое окружение/IBL и игровые владельцы остаются HOLD.
Модели, пиксели, размеры, исходные sampler descriptors и коллизии не упрощены.

## Авторитетное состояние

Новая системная цель ACTIVE. Редактор ещё НЕ подключён main и НЕ принят LIVE.
Производственные scripts/map_editor заморожены по просьбе Координатора21:
редактор Godot обнаруживал промежуточные ошибки незавершённых скриптов.
Текущие производственные скрипты прошли check-only, но финальные исправления
и проверки находятся в отдельном `outputs/map_editor_wip`.

## Проверенный кандидат

`outputs/map_editor_wip` — отдельный Godot-проект без второй GPU-игры.
Frozen source copy для scoped Git/интеграции: `tools/godot/map_editor_candidate`.
Все семь suites там независимо повторены official4.7.2 headless, exit0.

- camera/panel: K host input contract; fly/top; русский UI, поиск, категории,
  ограниченные 160 результатов, шаг перемещения X/Y/Z, rotate, add/delete,
  undo/redo, save/load, import/export, точное восстановление игровой камеры.
- document/store: 42 и 29 headless-проверок; резервное сохранение и read-back,
  JSON numeric round-trip не меняет доверенные исходные данные.
- map_patch: 28 проверок; отдельные изменения и SHA256 неизменяемой базы.
- registry: 16 проверок; внешние коллизии следуют transform-delta здания,
  удаление выключает визуал/физику, undo восстанавливает прежние layers/masks.
  Неравномерный локальный масштаб и вращение сохраняются.
- controller: actual headless K/text/RMB click/drag/hold/focus, move/rotate,
  undo/redo, test-path save/load, версия базы и edit/play gate PASS.
- additions: shared mesh/material/shape, source offsets/scale/new IDs,
  удалённый исходный шаблон, свежая сцена из сохранения, защита source data,
  откат неуспешного импорта PASS.
- Выбор имеет отдельную рамку только в редакторе; исходные материалы не
  перекрашиваются, подсветка выключается при возвращении в игру.

Эти тесты используют синтетическую сцену. Они НЕ доказывают поведение полной
карты или FPS в пользовательской игре. Оригинальные GLB отдельно проверяет
`outputs/map_editor_assets_factory`: импортированы 196 оригинальных GLB,
созданы 242 authored placements, 355 source convex colliders, 1666 проверок
PASS. Дополнительный security/parity review фабрики и общая сцена ещё в работе.

## Контракт владельцу main

### Текущая производительность, не скрывать при приёмке

Полный authored integration test: 242 настоящих объекта, 1608 checks PASS,
свежая сцена 243 объектов из сохранения. Исходные вершины коллизий проверены.
Найден CPU hitch редактора: действие p50/p95 121/135 мс, load 277 мс,
pick исходного дома 1.08 мс. Сохранность графики доказана сравнением геометрии,
но производительность полной игры NOT_RUN.

Single-record hotpath завершён и independently checked: точный прогретый
сценарий 40 чередующихся move/undo на тех же 242 объектах, той же камере:
до p50/p95 129187/168267 us, после 1208/1871 us (~1.21/1.87 ms).
Ускорение CPU действия 106.94x/89.93x. 1614 checks PASS; порядок, opaque source,
история, коллизии, свежая сцена 243 объектов и отказ при stale collider сохранены.
Это не FPS/GPU/LIVE. Полный load 314 ms остаётся тяжелее одиночного действия.
Document/registry/controller frozen; отдельный hotpath test 359 checks PASS,
подтверждает отсутствие whole-document clone и посещение одной registry entry.

`preview_host_bridge.attach(host, block, camera, begin_edit, end_edit)`
регистрирует существующие source_id корни и внешние коллизии одним проходом.
Требуются явные callbacks, возвращающие `{ok: bool}`:

1. begin_edit останавливает игровое управление, transport/actors physics,
   resident navigation jobs/receipts и возвращает edit lease.
2. Main вызывает controller.handle_input(event) ДО player/transport. Во время
   edit lease даже текст/GUI события не должны попадать в gameplay handlers.
3. end_edit(document) проверяет controller.get_versioned_patch(), обновляет
   physics/navigation/sourcegeometry leases и только затем возобновляет play.
   При отказе редактор остаётся открытым с сообщением, игра не возобновляется.

Main/player/project/preset этот автор не изменял. Просьба владельцу интегрировать
проверенный кандидат последовательно, без новых WIP parse-fail в res://.

## Оставшийся полный объём

Atomic object+ground candidate now independently66599PASS on actual242source/
fresh243objects and200x180ground, CPU successfulimport817275us. Narrow source
extensions saved to tools core+ground candidates; source availability is not
gameplay authority. Precommit failures exact rollback, postcommit cleanup
retainsbothmodels andpausedownerreceipts, notifications onlyaftercoherentfinalize.
Root7checkpointownershipchecks additionally reject detached/reparented source
participants before any rollback writes. Genuine main/LIVE acceptance pending.

Unified editor_persistence.gd11checksPASS: save+exportcombinedfile/text, load+
importdelegateonlytoAtomic, no sequential half-install; pending/reentry actions
held. retry_pending exposedthroughbothpanels and routedbefore ordinaryready gate.
Full editor UI+nativeactualscene assembly test is in independent subtask.

Native catalogue UI:9checks PASS/full9901sourceobjects. Original Russian labels,
registry-only availability (sourceflags don't authorize edits), protected vs
missing reasons, narrow records without heavy source/geometry duplication,
bounded160 visible rows. One-time full UIbuild95992us in this run, not frameFPS.
preview_host_bridge optional source_catalog populates labels after live registry
admission; doesn't unlock locked interiors/protected IDs or build absent objects.

Independent parking native repeat232229checks PASS:36exactgeometries,
42sharedMM/856parts, sourceIDs/routes metadata + targeted edits/undo. Railway
stillHOLD exactstationCanvas pixels/trustedtrainhost; not full rail acceptance.

Unified editor_workspace sourcecandidate:25actual native UI/inputchecks PASS
на synthetic сцене. Панели Objects/Ground переключаются реальными кнопками;
ground RMB не вызывает objectdelete; общие persistence actions только через
trusted combinedowner. Focus/textK guards, cleanupfailure/recoveryfailure
удерживают editoractive и gameplaypause. Требуется main hook, не объявленоLIVE.

Координатор21 разрешил отдельный editor_host_adapter.gd, но НЕ main/player edits:
mount(existingmain,callbacks), explicitly supplied gamepause/input/nav/water owners,
no node-name guessing or authority/source-receipt overrides. Sourcecandidate готов,
13native checks PASS: exact owner/main lifetime receipt, reentrancy denial,
unfinished transaction/owner refusal holds pause, malformed pause rollback,
failed owner rollback keeps fault/input blocked. Main wiring/GPU остаются у21.

Frozen procedural sourcecandidate tools/godot/map_editor_procedural_native
independently repeated:448582exploration+134894roadchecks PASS. 2440trees/decor
IDs,505controls+6449markings. 464+8bulkMMuploads вместо per-partsetters,
original geometry/material descriptors/colors/normal inputs сохранены.
Source normal direction octpacking error0.0001294055; rawnormal bytes exact.
Dummy readback не доказываетGPUstorage/visualparity. Source roadculling/phase,
collisions/traffic/nav owneradapters и общая производительность ещёpending.

Новый сохранённый source-кандидат земли вне live res:
`tools/godot/map_editor_ground_candidate`. Независимый повторный прогон
Godot4.7.2:126model+66brush+19956rendererchecks PASS. Actual200x180 и31x31crop,
156shared render chunks/200physical rows; мазок меняет только dirty chunk/row.
40CPU transactions p50/p95 3336/4781us, initialsetup1112454us; не общийFPS.
Навигация/вода обязательные trusted callbacks. Cleanup failure после modelcommit
удерживает pause и retry_finalize; render-only rollback запрещён.

`tools/godot/map_editor_candidate/scripts/map_editor/map_bundle.gd`: data-only
publication envelope с baseline-bound objectpatch, groundpatch и assetSHA256.
11native checks PASS; ground требует trustedvalidator, checksum не authority.
Combined persistence и игровой publication workflow ещё не приняты.

Portable file storage `map_bundle_store.gd`:13native checks PASS. Единственный
JSON содержит object/ground patches, проверяется после записи и перед заменой;
healthy backup переживает повреждённый primary, stale source/missing resources
не обходятся через backup. Это local file workflow, не server upload и не
atomic scene install. Ground validator обязан принимать JSON numeric roundtrip.

Root follow-up source candidate: controller SHA BE30B77477F79E4DF89F0F6B2B29737339E65545EF7850DB196B38EE2D3353B1
fixes second scene admission failure during import: model/history remain intact,
staged clones removed, notifications only after scene+data agree.12checks PASS,
four controller/additions/controls/hotpath suites repeated PASS.
Ground brush69 +brush/renderer integration12 PASS: undo/redo finalize staged
resources through committed signal, unchanged strokes skip absent transaction.

Combined actual242/fullground200x180 file/fresh243 reconstruction1482checks
PASS separately in outputs/map_editor_combined_persistence. Sequential install
failure deliberately reproduces incomplete half-install; atomicImportReady:false.
Trusted joint transaction under implementation; not full publication acceptance.

Native dependency audit196GLBs PASS. Galleria AO PNG is embedded original image,
not absent source:577360bytes/db5173358ae98b7fe2b3dc0122e0960e881c9e8469bb587592fb4338d3c17859.
tools/godot/inspect_map_editor_embedded_images.mjs records source receipts;
8checks PASS. Fresh native extraction/resource resolution still required;
copied import/UID caches do not prove portable availability.

- Подключение K и gameplay gates в main владельцем, один LIVE прогон и FPS.
- Принять импорт всех GLB/полной authored карты; каталог учитывает 9901 объект,
  но inventory не означает готовый renderer/factory.
- Генерируемые деревья/памятники/дорожные элементы/слои земли и дороги.
- Интерьеры/полицейский комплекс/мост: согласованные adapters и навигация;
  printshop пока защищён в bridge, а не объявлен редактируемым.
- Применение сохранённой карты при новом игровом запуске и publish workflow.

Список «Что нового» не обновлять как будто editor уже доступен пользователю.

## Независимая повторная проверка — 27 сентября 2026

Предыдущие пометки `atomicImportReady:false` выше относятся к раннему
последовательному прототипу. Новый source-кандидат `atomic_map_import.gd`
сохранён вне live res в `tools/godot/map_editor_candidate/scripts/map_editor`.
Root повторил полную сборку `outputs/map_editor_editor_assembly`: **12777
проверок, 0 ошибок**, 242 исходных объекта, 243 после загрузки копии,
земля 200×180. Реальный маршрут K → host receipt → workspace, мазок,
undo/redo, combined save/load/export/import → persistence → atomic import.
CPU загрузка в этом прогоне 867940 мкс; это не время старта игры и не FPS.
Отказы staging/rollback/finalize сохраняют блокировку игры до успешного
восстановления. `productionWired:false`: подключение в main и LIVE не выполнены.

Отдельный повтор atomic import: 66599 проверок, 0 ошибок, CPU успешной
транзакции 817275 мкс. Текущий registry проверяет исходного родителя и
владение ресурсами до rollback; переподключённые/удалённые владельцы не
перезаписываются старым checkpoint. Игровые nav/water callbacks пока fixtures.

Оптимизация объектов остаётся обязательной частью приёмки: shared meshes,
materials и bulk MultiMesh uploads, только изменённые записи/чанки;
не снижать разрешение, детализацию, исходный LOD или состав карты ради FPS.
Процедурный registry/copy/fresh-load ещё готовится отдельным пакетом.

Root повторил `test_station_capture.gd`: **465 проверок, 0 ошибок**.
Точные исходные RGBA, единственный UV flip и базовый native upload проверены.
Mipmaps/filtering, GPU appearance и настоящие rail/gameplay owners ещё
не приняты; эти проверки не подтверждают визуальную паритетность в игре.

Root также сохранил воспроизводимую сборку вне outputs:
`tools/godot/map_editor_assembly_candidate` и
`tools/godot/stage_map_editor_assembly.mjs`. Проверка исходников15PASS;
новая уникальная stage директория,196 оригинальных GLB/30212460байт,
225 source files, все SHA/readback проверены. Старые `.godot`/`.import`/UID
не копируются; абсолютные машинные пути заменены на staged res paths.
Свежий native import завершён exit0, затем реальная сборка12777PASS,
loadCPU897902мкс. Это отдельная CPU-проверка пересоздания ресурсов,
не доказательство переносимости полного игрового проекта или LIVE/FPS.

Транспорт исходных чисел: новый `trusted_json.gd` закрывает реальный случай
IEEE64 source66→Godot JSON67 ULP без допуска произвольных соседних значений.
Сравнение caller выполняется с exactsource или exact trustedroundtrip,
caller не нормализуется и epsilon запрещён. Source/header/transformopaque
после допуска возвращаются к доверенному оригиналу, variant кешируется при
регистрации объекта.133 native checks PASS:30 save/load cycles + forged68bits,
string/extra/header/transformopaque отказ. Hotpath359/controller/additions/
composite36 PASS; synthetic242 p50/p95 479/627мкс — не игровойFPS.
Повтор fresh native assembly со stricthelper12777PASS/load838435мкс;
последнее расширение transformextra отдельно покрыто133/controller/additions.
Production ещё не подключён. Координатор21 разрешил следующий отдельный
source-only pause-owner пакет; native/gameplay production edits остаются у21.

Кисть земли теперь подключена к отдельным native editor-only подсказкам:
`ground_preview.gd`, optionalworkspaceargument7. Изменённые клетки только в
dirtychunks; размер курсора1..8, круг максимум149клеток, защищённые клетки
отмечены отдельно. Материалы карты/вода/физика не изменяются; нет ложного
water preview.24preview+126document+69brush+25workspace PASS. Свежий import
196originalGLB → реальная assembly12782PASS с nativeLMB preview/cursor,
clear aftercommit/Kexit, actual242/fresh243/full200x180, loadCPU874829мкс.
Подсветка ещё не проверена визуально наGPU. Production remains unwired.

Root independently V3 original registry9458 + actualController26 PASS.
New source-only stage `--procedural` combines actual242 authored GLB +9394
procedural IDs through the REAL composite registry and single controller.
Mixed house/tree move/undo/redo/copy, real file save→fresh two native factories:
**29910 checks PASS**,9636 baseline/fresh9638. All opaque descriptors and
native float32 frame bytes checked individually. Default callbacks remain
test fixtures; full9901 plus protected landmark/gameplay/GPU still pending.
First reported15483324us includes post-install verification, not pure load.
Current test splits install/verification counters to avoid misleading FPS or
startup claims. Composite source header check no longer deep-copies all9636
records merely to erase them; same guards/composite36 PASS preserved.

Root independently repeated scene_pause_owner25 and ACTUAL main/player/
transport/NativeBody16 PASS, source8buildings/8decor/27colliders, NPC disabled.
Only unchanged-map support is admitted; whole-game/NPC/edited-nav/water not
proven. New accepted server control cannot be rewound to cancel pause.
Protected landmark source companion also independently778source +204687native
bounds PASS; textures38 and real ownership/GPU remain HOLD.

Root full source assembly `--procedural --transport`, fresh imported resources:
30718 checks PASS; 9901 baseline records / 9904 after house/tree/parking copies.
Real composite registry, one controller, real file save and fresh factories.
Transport V1 includes32 rail inventory HOLD records, not32 admitted visuals.
Pure install CPU15505473us, subsequent verification555087us; this is a measured
candidate import bottleneck, not game startup/FPS. Dedicated source-only stage
profiling delegated; original metadata/resource/rollback checks must remain.
Root independently repeated V2 railway789 checks (32 native resource links,
3 source cars/27 actual parts) and landmarks353646 checks. Landmark resource
build CPU62496us; warm bridge preview p50/p95 1547/2742us. Shared267 meshes and
22 instance groups retain933 source parts; no geometry reduction. Textures38,
real owners, GPU visual acceptance and production K integration remain HOLD.

MapDocument full-catalog data-only optimization: avoid two unused whole-object
deep copies when copying header fields. All JSON/depth/duplicate/transform
validation and deep-detached input/output semantics remain. Actual9901 catalog
metadata benchmark (one warmup +5 samples): loadCPU p50/p95
1987395/2081729us before ->1695288/1730590us after (-14.7%/-16.9%).
This fixture measures only the data model, not factory import/game startup.
14 full-catalog checks PASS; model42/trustedJSON133/patch28/installfailure12/
checkpoint7/composite36/hotpath359/compoundpause60 regression PASS.

New explicit `editor_input_router.gd` stays outside stopped gameplay inventory;
host binds exactly its existing owner, no inferred main/flag edits/globalpause.
Actual native viewport K opens/closes the real controller while main input,
unhandled/process/physics flags are disabled; echo/foreignowner/reparent gates
14 PASS. Host callbacks are test fixtures; real NPC/nav/water still mandatory.
Gameplay owner MUST still gate every update/input path when GUI routing returns
false. No production K hookup is claimed. Portable source stage includes router
and full-catalog test, no import/UID caches;18 readonly staging checks.

Original landmark texture closure independently137+1037PASS:38textures require
43 original rasters,39 recipe imagegroups, estimated baseRGBA8 55033856bytes/
allmips73377244bytes. No captured pixel hashes yet.35labels require original
system-ui font metrology (not railwayArial). Three180 PMREM/fromCubemap IBL must
be accepted along with native environment, not silently replaced by rawcube.
All38 visual dependencies remain HOLD; no bitmap/font/lighting fallback used.

Root independently landmark deferred owner-plan cache652 + original353646
checks PASS. Same933sourceparts/exactorderedplans/tightbounds/materialrecipes:
bridge CPU p50/p95 1339/1768→316/438us; island5113/5702→1348/1782us in one
interleaved test. Cold resource build60230→60469us unchanged, firstbridgeplan
1686→1876us has deferred setup. Candidate remains isolated/scene_admitted=false;
no original visual or ownership gate is waived. Source resource closure audit
for fresh-PC publication is next; data JSON alone is not a portable fullgame.

Root integrated an explicit optional source stage `--registry-perf` (requires
`--procedural --transport`), frozen performance receiptSHA7c8b0b818982a479…
and all source/runtime hashes verified before copying. Frozen original registries
remain unchanged. Virtual test constructors select the new subclasses while
reusing the very same full combined assertions. Fresh196GLB source import,
exact comparator30351 + full30718 checks PASS;9901→fresh9904. Combined latest
MapDocument+registry candidate installCPU12891217us/verification572316us in
this run; independent baseline15505473us was earlier, not a paired FPS test.
Agent controlled3pairs with original MapDocument isolated registry effect:
median15430803→13792279us(-10.6%), all6runs30718PASS; procedural9458 and
transport852 mutation/rollback/checkpoint regressions passed before freeze.
Native geometry/material/resource rules and owner callbacks are unchanged.
Production remains unwired; rail32V1inventory still HOLD. Stager19 readonly
checks include refusal to enable performance package without its dependencies.

Root fresh actual production-main readonly headless pause16PASS on current
8buildings/8decor/27colliders with printshop/water ready, NPCdisabled and
unchangedMapOnly=true. This does not validate edited geometry or whole-game
pause. Root native inclusive input74PASS confirms mousemotion4.473/5.301ms,
6scene+4animationchecks, pick=0,50bodies/8Timers/8AnimationPlayers fixture.
Synchronous one-shot proof optimization is being reviewed separately; no
across-event/frame cache or skipped authority admission is accepted.

Root selection candidate checks334synthetic+195actual9394 PASS. Actual WORLD
AABB reference pick4717/6711us vsBVH53/100us, refit43us/cloneinsert167us;
initialbuild519235us remains an explicit paused/prewarm cost, not hidden on
each click. Requires exhaustive trusted ownerrevision/journal receipt and
stale rejection; not hooked to the core picker yet. Native per-mesh LOCAL
picker has different semantics and cannot be silently replaced by this BVH.

Root fresh authored optimization proof:8960 exact native scene/resource/shape
checks PASS;242objects use33placedGLBs, original196palette admitted. Warm
original median178359us→both153170us(-14.1%,~25ms preparation), earlieragent
16.6%; original Mesh/Materials/shadow/collider points/margins/bodymasks retained.
Root actual atomic66599+assembly12782 PASS, full200×180ground/243freshobjects.
Cold sourceGLB loading and liveFPS not measured/changed.355shape resources
remain private: shared mutable point payloads would break owner isolation.

Root optional combined `--authored-perf` source stage requires procedural,
transport andregistry-perf; frozenreceipt/source/runtime hashes checked, no
cache/UID/import copied. Fresh196GLBimport+combined30718 PASS,9901→9904;
install13278619us/verification580152us single run, not pairedgame startup.
NativeproductionK/gameplay/nav/water/lifecycle remain unconnected. The
extended fresh test30767PASS additionally covers originalfamily rotate/delete/
undo/redo and top/fly actions; exact rotatedrecords restored on freshload,
install13666523us/verification592314us notpairedgain. Stager31PASS. An earlier
extended run had test-side Nil bounds access/SCRIPT ERROR and is NOT accepted;
later corrected fresh assemblyYztcIA has noSCRIPT ERROR.

Root independent pagedPanel9996PASS: all9901catalogIDs reachable over62pages,
≤160nativeItemListrows, cachedlabel/IDtext only, currentavailability/reasons
uncached. Russianprev/next/counts and IDtooltip/search preserve correctaddID.
Panel remains optionalsource-only; realregistry admission must supply flags.
Actual oldController RMB input suite exposed stalepress→textfocus→ignored
release→blur→secondrelease deletion for all3actualfamilies. Root clears pending
RMB state on both textfocused input and early K-text guard in sourcecandidate;
production main unchanged. Freshoriginal196GLB import native73PASS on actual
house/tree707/hospitalparkinglot; realray LMB/RMB selection, shortclickdelete,
exactnativeGLB/collider/MMshadow restore, drag/UI/textfocus+focusedKinterruptions.
Root independent same73PASS/noSCRIPT ERROR on freshstagexzhZTw. Parking coverage is lot, NOT all
baycenter rays: broaderlotbounds can win. Source-only explicitcatalog-ID
existingobject selection is being implemented, no pickingsemantics change.

Initial-only paged Controller adapter now frozen outside core: receipt
694b160720396dce61e5b257623c344b13b1cea77e05f4baac2b3f8a02ca1139, runtime
186577739edae1e178d624dea685068794929f26a8c80e36777b19a93298a438.
Agent703nativePASS actual242authored/236admitted (6specialstillprotected):
catalog 'Выбрать на карте' resolves realcurrentID, originalmove/undo works;
deleted/absent/protected/atomic IDs refuse without stale selection change.
No camera teleport or fakepick; truthful ownedhints distinguish LMBselection
from explicit Addbutton. Pre-tree initial construction and singleWorkspace
handler checked. Root adds --paged-editor explicitsource stage with exact
base/runtimehash admission, newfullUIfixture and43file-onlystagechecksPASS.
Full nativepaged proof pending; Coordinator21 reserves upcoming GPU window,
explicitly requests no longheadless/import during preparation. No actualmain
integration scope changed; priority there remains actualmelee/NPC.

Agent full genuineCatalogUI proof79711PASS on actualComposite9901/document:
allIDs resolve,0missing/reason/label/category/availability mismatches;
9863geometry-fixtureavailable/38protected (3banks+3detention+32rail), all233
parking fullprefix IDs correct. Not whole-game actor/nav/water authority;
this does not waive remaining38owner adapters or bayrayselection issue.

Root independently exactprintshop CPU-shadowV2:546PASS,15batches/280instances/
215colors. V1 explicitlyrejectedforpositive reuse; V2 exactsignedzero/native
parsedsource+uniformbytes, expectedMM-onlysignalsuppression, nestedresource
poisoning, thread/lifetime postcallback gates. ActualSourceOwner sealedwriter/
RID/script lifecycle +GPUstorage/door/nav/world integration STILLHOLD. Root
safeportableV2stager10file-onlyPASS: newuniqueoutputs,7pinnedsourcefiles,
sourcejunction/outputjunction/overwrite refusals andeveryhashreadback; no
sharedimport/UID/cache. Prefer tools/godot/stage_printshop_shadow_v2.mjs to
frozen legacyfixed-outputstager. Unique stage native rerun pendingwindow.

New source printshop placement candidate remains NOT admitted: actual15
MultiMesh batches/280instances/215colors cannot be proven unchanged through
changed signals or Dummy readback. Default gate refuses actualscene;127
branch checks only explicitly TEST-ONLY bypass the negativeMMgate to exercise
transaction failures/originalgeometry/doorphase. No productionfakeapproval.
Readonly descriptor adoption guard136261→1818us branch median, notfullFPS.
Review corrected forged/reentrantrollback state mutation, exactchildinventory
and silentshaderuniform mutation. Native compiledScript reload+restoredtext
also defeats identity/SHA proof; genuine sealed source-owner lifecycle needed
for all reviewed script-method/field fast routes. Existing1624conformance
suite does not provide this; see synchronousproof contract lateHOLDwarning.
# Independent full paged source verification — 27 September 2026

Later same-day actual asset proof:43 original Canvas2D rasters captured on a
Coordinator21-approved browser slot,3 repeats identical. Source PNG/RGBA
saved in `outputs/landmark-canvas-capture-ZQyA1N`; Godot native Image decoder
304checks PASS, all55,033,856RGBA bytes exact. See
`tools/godot/map_editor_landmark_canvas_capture/ROOT_CAPTURE_VERIFICATION.md`.
No WebGL/game/main change. Resolved font backend, GPU samplers/cube/PMREM/IBL
and gameplay owners still HOLD; existing53 closure gates not auto-approved.

Fresh stage `outputs/map_editor_source_assembly_z6tlla`,196 original GLBs
fresh-imported. Root native script run after Coordinator21 ended the reserved
GPU window:80452 checks PASS,9901 originals /9904 saved and freshly loaded.
Actual Composite/CatalogUI/controller, all62 pages,38 protected owners,
original house/tree/parking selection/move/delete/undo. Undo additionally
compares native node/collision/mesh identity and CPU MultiMesh submission
shadows, not headless renderer getters. No SCRIPT ERROR in the reported run.
Install CPU13018405us, separate verification583167us (single run, not paired
FPS or whole-game startup). Test owner callbacks remain fixtures; no main
installation, GPU visual or gameplay authority acceptance is claimed.

Publication materializer V1 is not accepted for release: review reproduced
late host-receipt getter mutation and Proxy reflection before refusal.
New separate V2 independently verified by root:91 file-only checks PASS,
getter/Proxy/Map-override calls0, partial writes retained/no false success;
actual resource closure remains53 HOLD with0 output writes. Positive bundle
tests use synthetic11 blobs only. Real map approval/installed owner freshness
and native importer/graphics acceptance remain necessary.
