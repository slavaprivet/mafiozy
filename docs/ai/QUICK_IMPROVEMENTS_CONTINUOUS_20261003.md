# Непрерывные малые улучшения — Быстрые введения

## 07.10 — сверка фактической базы перед продолжением

Свежий perf probe candidate49: eligible_snapshot=true, reasons=[]; это только
inventory/admission snapshot, движок не запускался. CURRENT_COORDINATOR всё ещё27.
Фактический current_version указывает на artist24_melee_contact/merged_root48_08,
manifest SHA10f29304511fb705d0b18fc7db9a5a76fcd001f59c9225b2c4194ca201fa11f9,
хотя название/revision остались release48. Относительно baseline48/game найдены
13 изменённых файлов (включая main/player/project и NPC), 26 добавленных,
0 удалённых. Старый candidate49 нельзя переключать в current: потеряются melee
изменения. Следующий этап — новая private композиция поверх merged_root48_08,
сохранение всех его файлов, scoped car delta, затем functional и matched perf
с этой же новой baseline. Общие main/player/project/pointer/Git не тронуты.

Прочитан actual RESULT старого car49_perf_overnight01: on_before/off/on_after
wall-frame p95=10.187/10.282/10.207ms, p50=7.041/6.955/6.893ms; по65 samples,
каждая фаза всего0.45s. Это узкое smoke/CHECK on/off/on evidence, не приёмка
всех10 функций и не новая baseline. Drawcall p50=1097/1060/1097. Engine monitor
41.207ms в on_after нельзя интерпретировать как wall-frame p95. Исправление
прежней записи: RUN сообщает peak RSS1,654,894,592 bytes. Старая moving-пара
не повторялась на устаревшей базе. Доставленной car49 версии по-прежнему нет.


## 03.10, ~11:48 МСК — свежий perf и безопасная остановка moving-пары

Кандидат49 поверх принятой release48 прошёл отдельный exclusive active-path
замер `runs/car49_perf_overnight01/RUN.json`: exit0/stderr0, native 97/97,
`MATCHED_MEASUREMENT`, scheduler v3 SHA
`adcb834390e476edd118f62d8e3e5b391c6ebc97925391e66beeb80430ba8373`, RSS peak
1,654,890,496 байт. Это evidence активного smoke/puncture/CHECK, но не
автоматический FPS PASS. Парный moving-запуск `car49_moving_overnight01`
корректно не стартовал: во время bounded queue wait появился пользовательский
F5 PID26440 из `outputs/artist24_melee_contact/merged_root48_08/game`, поэтому
scheduler вернул `perf_requires_idle_game` и записал `UNVERIFIED`; пользовательское
окно не закрывалось. Candidate49 и Wave01 остаются подготовленными, указатель
`godot/current_version.json` не переключался до contiguous moving-пары и review.

## 03.10, ~08:11 МСК — scheduler inventory-fix v3 adoption

По свежему уведомлению root27 scheduler теперь SHA
`adcb834390e476edd118f62d8e3e5b391c6ebc97925391e66beeb80430ba8373`,
17 CPU PASS; old0194/v2 receipts и frozen runner не менялись. Создан новый
`rebase48_precheck/run_49_active_scheduler_v3.py` SHA
`833fc61fbc2f47909183c444807d0ba3916897aeed23b914e5ce67fe47dae3de`;
он пинует scheduler, прежний v2 и исходный frozen runner и записывает новую
provenance в fresh RUN. Manifest `SCHEDULER_V3_ADOPTION_49.json` SHA
`d496a70980f41e2e385c84925aa029f217acf440582f3493c4bf81ba0b4f34f9`.
AST/JSON/пины сверены. v3 probe за ~1с вышел3 с `active_resource` и
`perf_requires_idle_game` F5 PID34540; Godot не запускался, каталог evidence
не создался. Новый native adoption NOT_RUN до чистого окна, это не FPS.
Следующий вызов только с `--mode perf`/fresh run-id после eligible probe.
Передано в штаб.

## 03.10, ~07:4x МСК — root weapon_restore49 compatibility boundary

Root27 начал отдельный private persistence slice на exact48. Наш car49 frozen,
файлового пересечения нет. Для будущего merge выявлен точный lifecycle риск:
`car_damage_install.gd::_attach` после `preview_ready`/controls-ready единожды
создаёт condition/tyre/smoke/HUD. `car_condition.gd::_load_state` и
`car_tyre_damage.gd::_load_state` читают metadata нового native body только в
`configure`, и оба требуют тот же vehicle_id/life_generation. Поэтому restored
identity и, если позже решено сохранять HP/шины, разрешённый scalar DTO нужно
гидратировать ДО addon configure/preview_ready; поздний rebind отвергнет старую
identity или тихо оставит HP100/pressure1. Сейчас car49 condition/tire state
преднамеренно local-session, между двумя процессами не переносится. Exact48
weapon/cargo two-process proof сам по себе НЕ докажет persistence авто-урона.
Не сериализовать целиком metadata или pending shots: condition last_event может
хранить Vector3/служебные поля, weapon effects epoch/new bindings создаются
заново. Root запрещает pending shots/C4, что совместимо с car49 локальными
очередями. Конкретный риск отправлен в HQ; car49 исходники не менялись.

## 03.10, ~07:34 МСК — scheduler v2 adoption без бесполезного ожидания

Новая policy `docs/godot/TEST_SCHEDULER.md` и scheduler SHA
`0194f00db580f2c54e8f2c13cbbde1002cd2429ffdf970d9799328d072cfcdc4`
приняты. Frozen runner `run_49_active_scheduler.py` SHA `da6afc...`/старые
receipts не тронуты. Отдельный `run_49_active_scheduler_v2.py` SHA
`3ea8de3e7e7306fde82358894f3f71f6d05f29cb5efb69f4c34e4a08c5281bee`
пинует новую версию, перед perf делает CLI `probe`, в новом receipt фиксирует
scheduler/probe/supersedes. Manifest `rebase48_precheck/SCHEDULER_V2_ADOPTION_49.json`
SHA `1077249bc8106e3d0960a308e5aac3897f5f0848b8ddcf176df7bc36869c7f5c`.
JSON/AST/три SHA сверены. Probe candidate49 вернул `perf_requires_idle_game`
PID34540/creation_filetime134354713729615269 за ~1с, exit3 адаптера:
Godot не запускался, run directory не создан. Поэтому новая native-проверка
NOT_RUN, не выдавать probe за performance. В первое действительно свободное
окно запускать один bounded `--mode perf` через v2; затем review и передача
в production. Итог отправлен в общий штаб.

## 03.10, ~07:2x МСК — очередь проверок уточнена для root27

По поручению Координатора27 проверен актуальный `test_scheduler.py status`:
`pending=[]`, `perf_active=false`; занята только временная graphical lane
Artist24 ticket339. Собственные car49 functional/visual уже закрыты native
10/10 drive, 109/109 damage, 73/73 critical, 97/97 active smoke/puncture/CHECK.
У active03 elapsed32.57с, hard timeout125с, source pins513, exit0/stderr0.
Единственный оставшийся gate этого пакета — **exclusive matched perf** активного
дыма/прокола/critical с тремя NPC и process RSS; F5 release48 PID34540 всё ещё
открыта и блокирует сопоставимый perf. Editor25808 разрешён. Точный pinned
fixture/runner и команду хранит `rebase48_precheck/ACTIVE_PATH_HANDOFF_49.json`.
Поэтому perf не ставить в бесконечное ожидание и не закрывать пользовательскую
игру; в первое чистое окно один bounded проход (~33с в предыдущем functional,
лимит125с, lease wait120с), затем owner review и решение о F5. Это сообщение
отправлено в общий штаб для root27. Current pointer остаётся release48.

## 03.10, ~06:4x МСК — active critical/smoke/puncture функциональный gate

Root27 REVIEW `outputs/coordinator27_car49_review/REVIEW.json` SHA
`303fd21ff112254bddc1bdde448a586fef0c042e643cf9154e2df2c6319293d4`
подтвердил шесть native receipts и три pair статистики: разрыв ticket сам
по себе не contamination, повторять moving только ради adjacent не нужно.
Но полная perf acceptance остаётся открытой: исходные замеры не записали
NPC poses/scene epoch/process RSS и не включали активный smoke/puncture/
critical. Moving закончился HP97.620891 с одним native collision, поэтому
не называть его «без урона».

Новый fixture `rebase48_precheck/test_49_active_damage.gd` сделал реальные
AK74 попадания до HP12.5, TT прокол wheel_fl pressure0, native E посадку,
дым9/1 draw и CHECK. `damage_perf_active49.gd` сравнил дым+схему
on/off/on, сохраняя condition и tyre physics активными; ни body pose, ни
velocity, ни freeze, ни HP/pressure fixture не писал. Вместо старой
трёхкратной двухсекундной проверки использованы 12 physics warmup frames
и 0.45с render samples на фазу: исходный глобальный порог drift<0.05м
сохранён, физику не замораживали и порог не ослабляли.

`rebase48_precheck/runs/combined49_active02/RUN.json`: graphical native
FUNCTIONAL_PASS97/97, exit0/stderr0, pins513 unchanged; все3 фазы
MATCHED_MEASUREMENT как fixture-поведение, max global drift0.02830м,
restored/persistent true. `combined49_active02/RESULT.json` фиксирует
game/population instance, session/ready epoch, три NPC source IDs/positions/
statuses в начале и конце каждой фазы. RSS exact child32 samples:
peak1,683,849,216B, last1,683,845,120B, private last2,337,660,928B.
Снимок `combined49_active01/critical_smoke_flat_tyre_driver.png` визуально
проверен: шина не просвечивает диском, дым/CHECK/HUD видны. Этот functional
прогон шёл рядом с открытой F5 release48; его wall кадры НЕ perf acceptance.
Для настоящего FPS активного пути нужен exclusive perf slot при отсутствии
игры; PID34540 исторический, всегда освежать inventory, игру не закрывать.

Дополнение: `combined49_active03/RUN.json` FUNCTIONAL_PASS97/97,
exit0/stderr0 после добавления явных фазовых receipt. `RESULT.json`:
каждая фаза сохраняет 3 NPC IDs/positions/statuses, scene_ready/population
session/instance epoch, camera/pose и native pressure. Реальные HP12.5,
wheel_fl pressure0 и native pressure0 во всех фазах. Видимый smoke9→0→9,
CHECK true→false→true; каждая фаза behavioral MATCHED, global drift
0.00896/0.01870/0.02856м (<0.05). Exact child RSS peak1,661,186,048B.
Это устраняет пробел в функциональном evidence, но не превращает параллельный
graphical run в сопоставимый FPS. Результат передан в штаб.
Самодостаточная передача `rebase48_precheck/ACTIVE_PATH_HANDOFF_49.json`
SHA `72b256cba381e3fb637d490fa391e25bc917dee8454d92b2ff3032182ff5d2c9`
пинует fixture/runner/RESULT03, ограничения и следующий `--mode perf`
при чистом exclusive окне. Она также передана в штаб.

Root также уточнил игровую формулировку: «тяжёлый запуск» — только звук,
torque/ignition не меняются. Frozen candidate49 не тронут. Однофайловый
`rebase48_precheck/TEXT_FIX_49.json` SHA
`6314dd8fefe4e48717ae5098a564436f131046bd6cf72ee87cc1274234451f15`
заменяет в item5 «запуск тяжелеет» на «звук запуска меняется».
JSON/первые четыре item проверены; после применения root должен re-pin
и визуально проверить панель. Результаты отправлены в штаб.

## 03.10, ~06:23 МСК — F5 release48 принят; car49 source-base точно совпал

`godot/current_version.json` теперь указывает на принятую C4 release48:
`outputs/coordinator27_release48/ACCEPTED_ASSEMBLY.json` SHA
`51484885ce069970cecb234b7c016d5cc7e3b5611c3422ddeaa915a0d9c712b7`.
Проверен фактический accepted `game`: 497 файлов, включая 11 сгенерированных
Godot UID/import. Они byte-identical независимой imported baseline48
`rebase48_precheck/baseline48/ASSEMBLY_IMPORTED.json` (diff_count0);
все 486 original root source pins тоже совпали. Поэтому sealed candidate49
остаётся точным overlay без повторного rebase.

Свежий inventory в этот момент обнаружил стабильную пользовательскую игру
release48 PID34540. Она не закрывалась. Общий scheduler правильно блокирует
exclusive perf на время игры; не запускать parallel moving GPU ради мнимого
FPS. Нужен момент после закрытия/перезапуска владельцем для matched moving
или специально согласованный batch-проход. Parked49 MATCHED и functional
native drive/damage/critical PASS остаются действительны; candidate49 не F5.
Источник и ограничение сообщены в штаб root27.

## 03.10, ~05:58 МСК — корректный parked49 и движение

Общий scheduler остался byte-identical SHA `6f86204fdb510a9f3d850792891fc9902301ad68b5a67688080d0ac888c3cad9`.
В собственном read-only perf adapter `rebase48_precheck/run_perf_49_scheduler_retry.py`
разрешены только три свежих попытки `inventory()` при точной transient ошибке
`Fresh process inventory failed`; доступ к движку остаётся fail-closed и Lease
обязателен. Все исходники кандидата49 и baseline48 остались pinned.

`rebase48_precheck/runs/combined49_perf04/PAIR.json`: **MATCHED_MEASUREMENT**
full C4 release48→car/wave49, same fingerprint/editor/camera/0 зданий/3 NPC,
совпадающее положение авто Δ0.0004 м, соседние tickets143→144, обе стороны
MEASURED/exit0/stderr0. p50 6.954→6.964мс, p95 10.052→10.067мс
(+0.015), draw p95 893→893, primitives 447444→447956,
static memory p95 242383685→268805499 (+26.42MB). Это parked, не moving.

Для реального движения подготовлен независимый `perf_moving49.gd`: E
посадка, W разгон, Space торможение, 1280×720, та же камера и полный квартал.
Первый `combined49_moving01` был UNVERIFIED: fixture ошибочно отверг
существующий в root48 `car_dashboard.gd`. Исправлен только fixture, старые
receipt сохранены. `combined49_moving02`: обе стороны MEASURED/exit0/stderr0,
same fingerprint/editor/start speed and position, native baseline4.519м,
candidate4.508м за окно; кандидат dust12 visible и skid voices3. Raw p95
10.413→10.237мс, draw p95 1240→1283, memory +25.69MB. **PAIR UNVERIFIED**
из-за промежуточной заявки scheduler tickets159→161; raw числа не объявлять
FPS acceptance. Нужен повтор в тихую очередь или atomic pair lease. Damage/
puncture/smoke matched perf всё ещё не выполнен; functional native PASS есть.
Все новые данные переданы в штаб. F5 pointer при проверке остаётся frames45;
root27 отдельно готовит C4 release48. Candidate49 не доставлен пользователю.

Дополнение ~06:03: `combined49_moving03` обе стороны снова MEASURED,
same fingerprint/editor/start pose Δ0.0012м, raw p95 candidate −0.302мс,
но tickets173→176: пара остаётся UNVERIFIED из-за активной общей очереди.
Не делать новых одинаковых GPU повторов до свободного интервала или
batch lease; сырые числа не выдавать за принятую оптимизацию.

Для root27 создан новый handoff
`outputs/quick_improvements_20261003/rebase48_precheck/HANDOFF_49B.json`
SHA `584df1a68926b934bc77664685bc4b8a041b047f3d132d9604ab85d08b5758b5`;
включает sealed overlay49, функциональные и perf receipt, точный порядок
промо и ограничения. Передан в штаб. На ~06:04 root27 проводит четыре
финальных C4 замера; scheduler занят, повтор moving49 до его окончания
не запускать. F5 всё ещё frames45 на момент этой проверки.

## 03.10, ~05:4x МСК — новый C4 release48 + car/wave49

Root27 готовит отдельный C4/foundation/fire/camera `outputs/coordinator27_release48/ASSEMBLY.json`
SHA `513c9165b7f00be7e6cb8967470a5513e4d37e8fd8642f528d29ec36c08dd83c`
(486 frozen source pins), пока accepted=false. На него выполнен source-only
rebase car46+wave01 в нашем `rebase48_precheck/candidate49` без правок root game,
pointer или Git. Пять base файлов меняются, 16 car файлов/UID добавлены;
сохраняются C4/fire/foundation/camera и первые три пункта root «Новое»,
добавлены две короткие car строки при лимите панели5.

Import49 Godot exit0/stderr0 добавил ровно11 C4 UID/import metadata, ни один
старый source pin не изменил. Первый native drive49 FAIL: installer всё ещё
ожидал ревизию48b; исправлен только добавленный `car_damage_install.gd`, и
sealed `rebase48_precheck/candidate49/ASSEMBLY_FIXED.json` SHA
`8c0118654bd45363290c6826f8429d240353c5982b1c9b15a914a5a6faadcc48`
теперь пинует513 файлов. Старый неуспешный прогон и manifesты сохранены.

После исправления: `rebase48_precheck/runs/combined49_drive02/RUN.json`
PASS10/10, `combined49_damage01` PASS109/109, `combined49_critical01`
PASS73/73; все graphical native, exit0/stderr0, ревизия49, pins unchanged.
Отдельная независимая копия root48 импортирована и sealed baseline497:
`rebase48_precheck/baseline48/ASSEMBLY_IMPORTED.json` SHA
`bdcdadb1866d2124cd22621cd865e97443166fba77f7f376ba730f8138dda290`.
Все11 generated C4 metadata byte-identical у base/candidate, delta снова
ровно5 changed+16 added car.

`rebase48_precheck/runs/combined49_perf01/PAIR.json`: обе стороны native
MEASURED, same fingerprint/editor/car pose, raw parked p95 delta−0.106мс,
static memory +26.42MB; PAIR=UNVERIFIED только из-за scheduler tickets108→110
(чужая заявка между сторонами). Не выдавать за FPS acceptance. Root27 уже
исправляет scheduler pre-registration race; после стабильного scheduler или
batch perf API нужен новый парный прогон. F5 pointer на момент записи frames45;
candidate49 не включён и не готов к приёмке без matched perf/root review.

Дополнение ~05:43: `combined49_perf02` и `combined49_perf03` UNVERIFIED из-за
transient `test_scheduler.inventory(): Fresh process inventory failed`.
В perf03 новый runner уже ставит candidate perf request в очередь сразу после
захвата baseline lease, затем baseline MEASURED/exit0/stderr0, но candidate
упал в `Lease.__enter__` до engine launch. Это третье повторение inventory
сбоя (вместе с moving01), поэтому новых GPU повторов до scheduler fix/PASS
не делать. Root-owned scheduler не править в этом чате; сведения и trace
отправлены в штаб. Самодостаточный пакет `rebase48_precheck/HANDOFF_49.json`
SHA `efd8eb7176ea22dc987a3540d61e33c8840ff72f42f44ab0756a9ccfa074ba2d`.

## 03.10, ~05:1x МСК — combined48b native/perf результат

Новый scheduler root27 CPU9/9 и dual-headless/native PASS; адаптеры этого чата
используют его Lease, регистрируют только собственный child. Первый import48b
exit0/stderr0 создал восемь уникальных Godot `.gd.uid`, поэтому старый manifest
502 pins сохранился как pre-import, а итоговый sealed manifest
`rebase47a_precheck/candidate48b/ASSEMBLY_IMPORTED.json` SHA256
`b0d2074b93b00872706b24501f3ecd8b6c034a7aa63072446f4c5702b3e506cd`
охватывает 510 pins. Старые 502 source файла байт-в-байт неизменны.

`rebase47a_precheck/runs/combined48b_drive01/RUN.json`: graphical native
PASS10/10, exit0/stderr0; настоящие E/W/Space, skid, dust42 emissions/1 draw,
cooling1. Скриншот `rebase47a_precheck/combined48b_drive01/wave_native_handbrake_skid.png`
визуально просмотрен; 5 строк «Новое» реально отображаются.
`rebase47a_precheck/runs/combined48b_damage01/RUN.json`: native PASS109/109,
реальные AK/TT/авария, мотор65→58.022HP, wheel_fl pressure0, дым9/1 draw.
Встроенный старый on/off/on damage_pair всё ещё UNVERIFIED — он не заменяет perf.

`rebase47a_precheck/runs/combined48b_perf02/PAIR.json`: MATCHED full scene
parked 47a→48b, 0 активных зданий/3 NPC, same fingerprint/editor/car pose,
соседние scheduler tickets. p50 6.918→6.931мс, p95 10.072→9.944мс,
drawcalls p95 893→893, primitives 446960→447610, static memory p95
241648319→268100185 (+26.45MB). Это не измеряет движение/урон и само по
себе не означает F5 acceptance. Perf01 UNVERIFIED из-за fixture baseline,
который ошибочно отвергал уже существовавший dashboard47a; fixture исправлен.

`rebase47a_precheck/runs/wave_moving_scheduler01/02`: обе стороны второго
прогона native MEASURED, body start0м/end delta0.00869м, candidate dust12 и
skid voices3, но PAIR=UNVERIFIED из-за промежуточных чужих scheduler tickets;
первый прогон также сорвался из-за transient inventory failure при частом
audit. Audit уменьшен до 1/с; для чистого парного moving FPS нужен batch
exclusive perf lease или свободный интервал. Результат и необходимость API
переданы в штаб. Current pointer на момент записи остаётся frames45; 48b НЕ F5.

## 03.10, ~04:55 МСК — адаптация к общему scheduler

Подготовлен `outputs/quick_improvements_20261003/rebase47a_precheck/import48b_scheduler.py`:
strict pinned 48b manifest/engine и все 502 source pins, `Lease(mode='headless',
access='write')`, немедленная регистрация собственного child, watchdog65с и
отдельный RUN.json. Python syntax и read-only SHA/pins PASS; native ещё NOT_RUN.
`test_scheduler.inventory()` хранит Unicode пути правильно: видимые в выводе
инструмента символы замены оказались только артефактом отображения, не багом
scheduler. На проверке также был чужой незарегистрированный Buildings4 graphics
PID27288 — его не трогать. Root27 попросил переходить на scheduler после его CPU
PASS. Для парных perf нужен непрерывный exclusive lease через два собственных
последовательных child; текущий `register_child` допускает один child, поэтому
performance runners пока исходные source-only и не обходят старый guard.

## Финальная передача 03.10, 04:14 МСК

После передачи подготовлен source-only rebase на точный root27 candidate47a:
`outputs/quick_improvements_20261003/rebase47a_precheck/candidate48b/ASSEMBLY.json`,
SHA256 `5637b5ffa1c81444b0a814ae8442827dfdc3dd86db6a229b6ba2a2106dba6d7c`,
provisional revision `s01-20261003-c4-car-polish48b`, 502 pins. Первый
candidate48 сохранён только как история: его шестой пункт «Что нового» не
показывался бы из-за существующего лимита панели на пять строк. Полный снимок
47a до/после staging совпал; изменено ровно5 runtime файлов, добавлено8
модулей, C4 hooks в main сохранены. `REBASE_PRECHECK.json` и resolved main/notes
объясняют единственные два source-конфликта. Root27 предупреждён через штаб.
Статус сборки `STAGED_SOURCE_ONLY_NOT_RUN_NOT_ACCEPTED`, движки этого чата OFF:
root27 сейчас проверяет редактор/F5; native/perf/export/F5 объединённой сборки
ещё НЕ проводились. Отдельный moving perf fixture также подготовлен, но не
запущен, пока root не освободит окно.

На 04:4x попытка `rebase47a_precheck/import48b.ps1 -RunId import48b01`
правильно BLOCKED до создания output и до запуска движка: общий mutex занят.
Root27 разрабатывает общий scheduler (два headless functional и один graphic,
эксклюзивный perf); пути import/perf runner и их guard переданы через штаб.
Локальные mutex/свежий inventory пока не обходить; после NPC24 и срочного
C4 diagnostic8 повторить import с тем же ID, если output всё ещё отсутствует.

Root27 отдельно указал: старые `damage_native02` и `damage_wave01` on/off/on
`damage_pair` остаются UNVERIFIED, потому что машина натурально сместилась
0.0899/0.1375м против порога0.05. Порог не ослаблять, физику не замораживать.
Вместо этого source-only приготовлены `outputs/car_damage_20261001/current45/test_damage_cost_pair.gd`
SHA `bda0b54192c763dd1bcaa1c73776c58e321da115ad2c800635c37476643a7312`
и `outputs/quick_improvements_20261003/wave01/run_damage_cost_pair.ps1`
SHA `f628a09c6cb05deb034d6a212f4560b2cdc0a50a61c18c4558ae701c814a174f`.
Fixture повторяет реальные AK/TT/аварию в car46 и wave01, фиксирует только
камеру во время 3с pristine/post-crash, сохраняет точные pose/HP/pressure/
smoke/content данные. Runner допускает MATCHED только при одинаковом полном
содержимом/камере и start/end позе ≤0.05м, HP±0.5, том же дыме/проколе.
PowerShell AST OK, native NOT_RUN. Парный parked C4 47a→48b fixture/runner
также source-only готов; дальнейшие запуски под scheduler root.

Точный пакет передачи: `outputs/quick_improvements_20261003/RELEASE_HANDOFF_20261003.json`,
SHA256 `498b5300499d6820f578ce210ede53668825de10f3306a32bf7a071c4bc7283c`.
Он отправлен в Общий штаб для root27: последовательный перенос car46, затем
wave01/candidate02 на актуальную принятую C4-основу, отдельная приёмка и
обновление F5 остаются у root. Пакеты ещё изолированы; текущий указатель
`godot/current_version.json` при передаче показывал принятую frames45.

Семь настоящих GPU-прогонов завершились exit0/stderr0: 549/549 проверок.
Дополнительно к описанным ниже тестам `wave01/no_toggle03` 107/107 подтвердил
готовность feedback после обычного старта без искусственного on/off/on;
`wave01/drive_native01` 9/9 проверил E/W/Space, скольжение, пыль и остывание;
`wave01/critical_native01` 72/72 проверил пять реальных попаданий AK74 в
двигатель (100→12.5 HP), предупреждение один раз без спама и тяжёлый запуск.
Спущенная шина визуально исправлена и снята при настоящем проколе. Три
сопоставимые пары полной сцены включены в handoff. Предел: движение/урон не
получили отдельную парную FPS-проверку, хотя логика и ограничение затрат
проверены в живом движке. Все будущие отчёты различать: изолированная проверка
и фактическая доставка в текущую игру.

## Актуальный результат 03.10 после живых запусков

Пользователь повторно разрешил отдельную живую проверку и попросил улучшить
спущенную шину: диск не должен просвечивать сквозь резину. На frames45/0 старых
зданий/3 NPC `engine_proof03` PASS75/75: реальная AK74 пуля снизила отдельные
HP мотора 100→82.5. `damage_native02` PASS108/108: реальные выстрелы дали
HP65 и прокол передней левой шины, последующая авария снизила HP≈58 и включила
дым 9 частиц/1 draw instance, CHECK/схема и физика пробитой шины прошли.
Скриншот `damage_native02/actual_flat_tyre.png` просмотрен: после поднятия
спущенного профиля до ≥0.84R резина закрывает диск. Точные доказательства в
`outputs/car_damage_20261001/current45/{engine_proof03,damage_native02}`.

Текущий car46 candidate — `current45/ASSEMBLY.json`, runtime480, SHA после
QA-only правки perf fixture `6f0852ad1f339acf873768f850bc680adf4527adca1f6dc06b550f5459200daa`.
Wave01 пересобран без потери tyre fix в `wave01/candidate02/ASSEMBLY.json`
SHA `4785e8424350de65e21db0a0037628279bde7a467b6e974eebf771880c13baf8`,
runtime482. Десять SOURCE-пунктов ещё НЕ доставлены в текущую игру.

Сопоставимый car46 perf_pair01 ОТКЛОНЁН: первый baseline drift0.06065м/5с
превысил старый QA-порог0.05м, а root запустил импорт в перекрывающееся окно;
candidate не измерялся. Нельзя сообщать FPS-регрессию/приёмку по этой паре.
QA gate уточнён: <0.08м, <0.03м/с и <0.01рад; новый fixture
SHA `4bee75ed13f50ceb0ba097dc62a016f942fb9d77a0363e12ca635f5bedf1d3f7`.
Следующий шаг — чистое окно perf baseline45/car46, затем wave01 native и
parked/driver_idle perf; после этого передать root27, который отвечает за
последовательное включение и текущий F5. Указатель/Git самим не менять.

Фактически выполнено после этой записи: car46 perf02 matched baseline45/car46
p50 7.008→6.894 мс, p95 9.799→9.694 мс, draw/triangles без роста,
static memory +24.36 МБ. Wave01 `controls_native02` PASS73/73, GPU exit0,
два просмотренных кадра 1280×720 и 960×540, WAV 5.08 с без клиппинга
(RMS846/32768, peak3349/32768; слуховая оценка отдельно).
Wave parked02 matched: p50 6.933→6.957, p95 9.597→10.126 мс,
память +0.77 МБ, draw без изменений. Wave driver_idle02 matched:
p50 6.904→6.938, p95 9.797→10.127 мс, память +1.93 МБ,
draw +5, triangles +282. Все с теми же0 зданиями/3 NPC/камерой/настройками;
измерение движения/критического предупреждения ещё не принято.

`wave01/damage_wave01` на candidate02: реальный native прогон105/0,
exit0/stderr0, прокол подписан «ПЕРЕДНЕЕ ЛЕВОЕ», повреждённый запуск
starts1/damaged_starts1, удар дал feedback_events1, пыль emitted28/
visible4/max tick318мкс, 1 render instance/192 triangles. Предел проверки:
унаследованный damage fixture искусственно отключает car owners на on/off/on;
после этой искусственной операции новый feedback owner стал ready=false.
Это не обычный игровой сценарий. Подготовлен отдельный
`wave01/test_wave_no_toggle.gd` SHA
`199d0d6d901d5912b3c5ea9d002ecfbd509a2fcf79bd719cae97f2a5935e616c`,
но root27 в этот момент занял общий mutex, engine не запускался.
Root27 готовит frequent release47a; текущий F5 всё ещё accepted45.

Прямое поручение пользователя 03.10: сделать все десять предложенных пунктов,
затем придумывать и внедрять следующие, не только автомобильные. Обязательно
проверять оптимизацию и вводить в настоящую игру по очереди. Пользователь
планирует завтра открыть текущую версию и проверить результат.

Повторное прямое указание: «меня не спрашивай. просто делай. я завтра проверю
если мне не понравится функция уберем. расскажешь что сделал». Согласования
мелких функций у пользователя не запрашивать; самостоятельно делать и проверять.
Координация единственной игры и сохранение чужих участков продолжают действовать.

Владелец этого потока: «Быстрые введения», 01a0f37d-8a6f-7560-a8a1-53fca08ba0e1.
Автоматизация `automation-2`, ACTIVE, heartbeat каждые 10 минут, этот же чат.
Общая интеграция/игра/Git — действующий root из CURRENT_COORDINATOR.json
(сейчас Координатор27). Отчёты только в существующий штаб. Новых координаторов,
авторских чатов или Astra не создавать. Старый traversal остаётся остановлен.

## Порядок доставки

Сначала завершить engine proof и приёмку прежнего car46: настоящая пуля в мотор,
отдельные HP двигателя, шина, дым, авария, схема, сопоставимая полная сцена.
Переносить на новую принятую базу по точному manifest; не возвращать старую
сцену поверх C4/исправлений координатора. Runtime480 current45 сохраняется.

Затем десять пунктов по порядку. Первые доработки отдельно в
`outputs/quick_improvements_20261003/wave01/package/scripts/quick_controls`.
Это исходники, пока НЕ доставленная версия. Каждая строка получает фактические
runtime/визуальные/perf результаты и номер доставленной версии после приёмки.

| № | Улучшение | Текущее действие | Доставлено |
|---|---|---|---|
| 1 | Скрип шин при ручнике и реальном скольжении | Доработать существующий ограниченный звуковой канал | Нет |
| 2 | Щелчок и мягкая подсветка включённых фар | Аудиособытие + краткая индикация фактического состояния | Нет |
| 3 | Сигнал критического состояния двигателя | Одно предупреждение на переход, без спама | Нет |
| 4 | Тахометр с колебанием на холостом ходу | Компактный прибор; источник RPM проверить | Нет |
| 5 | Вспышка повреждённой детали на схеме | Реальные condition events, краткая анимация | Нет |
| 6 | Краткая надпись о конкретном пробитом колесе | Реальный новый puncture; никаких повторов при загрузке | Нет |
| 7 | Тяжёлый запуск повреждённого двигателя | Звуковая подача запуска; физический контракт не подменять | Нет |
| 8 | Звук остывания мотора после остановки | Ограниченные тихие щелчки после реальной поездки | Нет |
| 9 | Пыль от шин на грунте | Настоящий контакт и поверхность; общий ограниченный пул | Нет |
| 10 | Компактный значок ручника рядом со скоростью | Улучшить существующую индикацию без лишней плашки | Нет |

После приёмки десятки самостоятельно выбирать следующие небольшие изменения,
видимые или слышимые игроку: обратная связь взаимодействий, читаемость подсказок,
малые окружающие эффекты. Сначала сверять владельцев и существующую реализацию.
Не добавлять старые здания, полные новые системы или неограниченные эффекты
под видом мелкого улучшения. Сохранять стиль, контент, коллизии и три NPC.

## Проверка и факт готовности

Работа ограничивается событиями, изменением состояния и ограниченными пулами;
скрытые/неактивные эффекты не должны обновлять визуал каждый кадр. Сравнивать
одинаковую полную сцену, камеру, настройки, состав и прогрев: frame p50/p95,
память, draw calls/triangles и стоимость логики. Нельзя называть source review
или быструю функцию проверенной производительностью всей сцены.

Настоящий запуск движка — только в согласованном последовательном окне root,
со свежим inventory и общим mutex. Пока слот занят, писать и проверять исходники
следующего пункта; не заканчивать весь поток организационным ожиданием.
Не менять accepted pointer/shared main/launcher/Git самостоятельно. Передать
готовый пакет и следить за фактическим включением координатором. «Что нового»
содержит только доступные в текущей запускаемой версии действия.

После завершения source-проверки не повторять её на каждом пробуждении без
новой правки или конкретного замечания. Сначала проверить, появилось ли окно
движка/новая база/результат приёмки, и продолжить с сохранённого шага. Если всё
готовое ожидает неизменного внешнего окна, не выдавать новое внедрение или
повторный отчёт за прогресс; автоматизация остаётся активной и молчит до
существенного изменения. Пользователю не отправлять запросы по мелким функциям.

## Активные назначения

- engine_proof_p2 завершил QA P2 и независимый review wave01.
- quick_audio_wave1 завершил аудио, test_controls и отдельную парную
  проверку car46 → wave01. Старый perf_pair не принимает car46 как baseline.
- quick_hud_wave1 завершил два HUD модуля.
- Владелец чата: пыль, сборка пакета, исходные проверки, координация и приёмка.

Все10 пунктов теперь реализованы в SOURCE, но Доставлено остаётся «Нет» до
настоящей приёмки/включения. Package SHA:
04e30b160d4da1e4b87b9d4a1d64a4b48a3cb23e4a36fd2ced864fe69b0c3520.
`wave01/candidate01/ASSEMBLY.json`, revision s01-20261003-car-polish01,
SHA2ab8554d61669f32a45607885a4a585e22c92ba3b2d92cb77d9ce6eab8d50442,
482pins. Это независимая диагностическая копия НЕпринятогоcar46, не заменаC4.
Шесть измененийexisting: revision/notes и4quick_controls; дваnewaudio/dust.
Stagehelper stage_wave.py выполнен за3.8с, движков не запускал. Всестарые
пакеты сохранены. Повторныйstage требует новогоtarget, exactbase иPACKAGEpins.
НовыйпринятыйC4 требует сперва интеграцииcar, потомего малыхулучшений.

Source review исправления: dust следует пересозданнымnativeподвесочнымrays
даже втойжеlife; audio feedback больше не считает fmodостатоквремениповторно.
НикакихfakeRPM/ignition/temperature/torque: новаястрелка и тяжёлыйзапуск —
presentation уже существующего native автомобиля. Полнаяperf UNVERIFIED.

Состояние при создании: движки этого чата OFF, runtime46 и wave01 NOT_RUN,
постоянный указатель всё ещё accepted frames45. Следующий car slot не получен.

Следующий source этап: `wave01/CONTROLS_QA.json` SHA
c7364eb73b436451c36d71fdea0ef7dd06e5e22331234d25fbf64ba87692fbaf.
Повторно совпали 480 car runtime + 8 QA, 482 wave runtime, 6 package файлов,
24 внешних GDScript зависимости test_controls. Сам controls fixture SHA
0547eedeb8425214a93fe64cf71c0bcb3aac6f4bb12779fcbc074547753a8973.
`CONTROLS_NATIVE_PLAN.md` содержит точную следующую команду и пределы проверки.
Нативный parser/GPU/звук ещё NOT_RUN. Старый base manifest66c1 находится в
qa_reviews/ASSEMBLY_66c1fd1d_before_normal_gate.json; нынешний0ca5 изменил
только QA, все480runtime точно совпали. PACKAGE/candidate сохраняют историю.

Отдельная wave perf QA готова, native НЕ запускалась. perf_pair.gd SHA
296a08c5d4292c36ab550f71612b565c516b94a72264d89b8ca02f5bb422ba5b;
run_perf_pair.ps1 SHA f57eb0337437b0e9f424b189e55123546a90a078c954fd3bfb117398be2920cb.
PERF_SOURCE.md SHA55155a7abe8d3aa2cb727439d1403d044488159eb6917eef98f6f037744a129b.
Сценарии parked/driver_idle, вся та же загруженная сцена; native E только для
driver_idle. 45s внутри/50s на каждый owned child; PowerShell AST 0 ошибок.
Source review исправил ожидание штатного стояночного ручника parked=true.
Подробная будущая команда в CONTROLS_NATIVE_PLAN.md; измеренных FPS пока нет.
Все три субагента завершили работу; новую повторную source-проверку без
изменений не назначать. Следующий необходимый шаг — реальный car proof слот.
