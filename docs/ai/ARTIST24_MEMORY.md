## 2026-10-03 — актуально: candidate36 functional retry PASS, perf ещё открыт

## Latest scheduler pin after the functional freeze

Root27 updated the scheduler to `adcb834390e476edd118f62d8e3e5b391c6ebc97925391e66beeb80430ba8373`. New `outputs/artist24_melee_contact/run_contact_v3.py` and `run_perf_pair_v3.py` differ only by that explicit reviewed pin; provenance is `SCHEDULER_ADOPTION_V3.json`. Historical v2/0194 native proofs and pair10 remain untouched. No extra engine was started solely for this dependency update. At the next necessary run use v3 and prepare a fresh performance pair after checking the current accepted Root27 revision. Candidate36 is still FUNCTIONAL_PASS_PERFORMANCE_UNACCEPTED.


Финальный статус закреплён в [CANDIDATE36_GATE.json](../../outputs/artist24_melee_contact/CANDIDATE36_GATE.json):
FUNCTIONAL_PASS_PERFORMANCE_UNACCEPTED,525 проверок разного scope/совместимых
версий; это НЕ единый LIVE/perf PASS. [PERF_PROBE_CANDIDATE36.json](../../outputs/artist24_melee_contact/PERF_PROBE_CANDIDATE36.json)
фиксирует блокировку: игра34540, зарегистрированная headlessработа и ещё один
unregistered engine. Очереди/закрытия нет. Parent лично просмотрел36latestACTIVE249,
но settled=false сохранён. Finalfreeze report отправлен в штаб. Дальше только
admittedexclusive actualperformance; accepted48pointer/игра неизменны, будущие
Root27/root49 изменения обязательно сохранить при интеграции.

Фактические ASSEMBLY SHA256:

- candidate33: `4a2eb3b9d3b09f27ecaefae0936020eed55be8946fd949a1e0987762b530b6e1`.
- candidate34: `76aa87940aa7c477150eeceea40ea037debae88fd3f0270df3bf91bf9d061c0e`.
- candidate35: `1a698677a0b423e23d18fd4206decf439875e9c6d85c897c6734bc94a403a507`.
- candidate36: `ede8af391981209779a02ddcdd7db97dec0e997a070b851bfa43e547e6b8d39f`.
- merged_root48_07: `72238cf49276dea51a4f89f1a10e16f184b3843c19265678f30ec4bcbc557663`.

33 import FAIL: parent пропустил explicit Callable type у двух confirmation;
exit0 не отменяет parse/compile errors в stderr. В34 исправлено: importPASS,
limb69/retaliation32/wall27PASS. Но native34_gun_burst01 выполняет83проверки с FAIL
вставания на границе соседних roadBoxes. Не превращать это в83PASS.

Recovery35 runtime4e53e9b5292fbc2aac2e5d1bb73223877f2fc0ee1adc3175e22f13748e00e631:
singleBox proof теперь необязателен при нехватке покрытия padded skin sweep;
поза заново вычисляется через прежние native floor rays и все исходные proofs.
Потеря identity опоры НЕ разрешает fallback; standing/capsule/whole-skin препятствия
не обходятся, допуски пола не ослаблены, general slopes не реализованы.
native35_gun_burst01:83PASS actual Uzi input,60→15 HP; первая→третья375мс,
RECOVERING+2405мс/walking_ready+3301мс после последней. native35_bullet1_diag01:
73PASS resident169. Авторские anchors и coreформы остались прежними.

36 объединяет35recovery и limb d9d95e7871101026d26b9840b39a68c053d010e62d55b56f1290524d1128bd2d:
same-time lo/hi endpoint separation уже до BVH descent/face visits, query-local
cache повторных bounds. Все faces,2мм contact и бюджеты сохранены. Native36limb77,
fallback18PASS; успешные runner exit0/stderr0/pins unchanged.

Дополнительно36: retaliation32/dropkick28/bullet0 иbullet2 по73PASS. Actor16973 и
actualgun83 остаются успешными35-сценариями на идентичном recovery4e53.
Pair09 camera06 FAIL сохранён: frame_face_budget8192/distance34/query121126µs.
Pair10 camera07 baseline Иcandidate теперь functionalPASS:2реальных попадания,
combat_error/failures пусты. Прежний facebudgetFAIL не повторился в этом прогоне.
Но querymax по сериям5020/80423/9123/15199µs при параллельных headlessjobs;
performance_metrics_usable=false. Нет доказанного ускорения/приёмки стоимости.

native36_combo_gpu01 уже41PASS:3касания→24HP→physicalfall/getup, combat_error пуст;
runnerexit0/stderr0/pins unchanged. LatestACTIVE249 за6кадров до первого observed
RECOVERING, chestskin clearance0.048060м, settled=false. Actual36captures есть,
эта запись проверяет receipts и не заменяет визуальную приёмку изображений.

Frozen36/merged07 иpair10 ждут EXCLUSIVE сопоставимого perf. Свежий rootprobe:
perf_requires_idle_game, пользовательская игра48PID34540 идругиеenginejobs; очередь
допуска не создавали. PID — наблюдение, не разрешение закрыть. Стоимость не принята
до чистого замера, все пакеты НЕ ПРИНЯТЫ/неrelease-ready. Accepted48pointer и
пользовательская игра неизменны. Root27 владеет
release/F5/Git, отчёты только через штаб. Эта правка только docs, история сохранена.

## 2026-10-03 — candidate32 (сохранённая история)

Фактические ASSEMBLY SHA256:

- candidate29: `f0ce1d2876bab86b9e4c5e97d57e7b3dc25987a706ead0dbb97859bbdf365711`.
- candidate30: `97fa473b57a86a1c31a22f81ee5904af1ee9a04ecad8fea5d48cd409090119c7`.
- candidate31: `3df2d05ffa30744645fc507019192216affb7a3b52c306be3311ae241d891859`.
- candidate32: `5db6d87d7ff26f9e7c573c82dd602a2e66c10355eece80b7c4103ed09d13795e`.
- Текущий изолированный merged_root48_05:
  `7848854149f99ae36bfabf14687bb4a058b3350053dfa4874ebef7da2a3ba088`.

Native29 доказал источник floor refusal: угол coarse grid вне тела попал в
соседний PlazaApproach ramp (normal−.161514,.986870,0; Y+.017248м), тогда как
фактическое тело поддерживал плоский Box. Исправление доказывает точную native
Box-плоскость и inset footprint; весь padded skin sweep должен помещаться перед
begin/step/commit. Проверки RID/shape/transform/filter,9лучей стояния, исходная
капсула и nativewhole-skin obstacle query сохранены; support collider не исключён.
Рампа/стена в настоящем пути всё ещё блокирует. Это НЕ общее вставание на склонах.
См. `outputs/artist24_melee_contact/bullet_recovery/FLAT_SUPPORT_PATCH.md`;
recovery runtime SHA b27f7fc7b7a54729acf74f5242a26dd443679306b6be3bed1fbabd217fee8449.

Теперь все3 NPC проходят component73 каждый: native30_bullet1_diag01 resident169,
native31_bullet0_01 resident72, native31_bullet2_01 resident252. Это native-ray/
direct-owner компонентные сценарии; actual Uzi input27 — отдельное доказательство.
Новые PASS: native32_flat_support01:30, native31_limb01:59,
native32_retaliation01:32 (player100→88), native32_wall01:27 (0hit),
native32_dropkick01:28. Все перечисленные runner exit0/stderr0/pins unchanged.

Limb runtime ec776b63748b56e1d2e9b616adc6f39791c3f53eacf81cadaddc6b5631402c3b:
проекции обеих треугольных поверхностей берутся в ОДНО время на lo иhi,
одинаковое направление разделения должно доказать весь интервал. Scalar64,
нормали faces/in-plane edges/edge-cross axes;2мм contact, budgets иposeage неизменны.

Pair07 camera04 FAIL сохранён: distance2048/query300497µs. Pair08 использует новый
reviewed scheduler0194f00db580f2c54e8f2c13cbbde1002cd2429ffdf970d9799328d072cfcdc4,
отдельные run_contact_v2.py/run_perf_pair_v2.py; прежние runners не переписаны.
Camera05 baseline Иcandidate functional smokePASS, candidate combat_error пуст.
Это НЕ FPS/perf приёмка. Functional query max≈32мс всё ещё требует проверки;
presentation-agent готовит для33 безопасный query-local cache повторных bounds.
Final32 native32_combo_gpu01 уже41PASS:3 настоящих удара→24HP→ACTIVE→RECOVERING→getup.
Parent просмотрел contact и latestACTIVE изображения. Кадр238 за1physics frame
до первого наблюдаемого RECOVERING: skinclearance chest0.034117м, spine0.021352м,
pelvis0.017018м, overall0.011731м, head0.076528м. Есть2почти неподвижные coreопоры,
но settled целого кадра НЕ утверждается; QA settled=false. Прежний20см зазор груди
уменьшен при сохранённых исходных моделях. Evidence32/captures — диагностический
ракурс настоящей сцены, НЕ FPS/LIVE. Игроку кандидат ещё не установлен. До следующего
runtimefreeze, перепроверок и matchedperf handoff не ready.

Свежий root probe всё ещё perf_requires_idle при сохранённой пользовательской
игре34540. PID — наблюдение, не разрешение закрытия. Все пакеты НЕ ПРИНЯТЫ,
performance/LIVE/release не завершены. Root27 владеет pointer/F5/Git/release;
отчёты только в существующий штаб. Эта правка только docs, история сохранена.

## 2026-10-03 — candidates25–28 (сохранённая история)

Проверены фактические ASSEMBLY SHA256:

- candidate25: `9bfabdbd8564478c81a3c9886ebada7f78da43f76b2e02853591a5515517eb5c`.
- candidate26: `ee66a80503f52393b65bea5aa38125a4a85e8ba54c9cb5c4c06366a4d3c33468`.
- candidate27: `813f85e94946d4b79b8f0d22489fb2d838c277fd9bc4af54c9672778005542f5`.
- candidate28: `d3adc35ceaa636f4d78bb1c8336e7086bd81a86296ca3c51b2d0233c03cd1b11`.

Во всех четырёх runtime npc_body SHA
`655794ab37b1c957d71637613ec02b006d41acf74c5851dca4a612e36b2d8c82`,
limb BVH `8816c6367a8f102e0d5b5bbe0712debfe8671dbca1042887bf55e7096148f297`.
NPC override восстанавливает неизменные авторские local anchors суставов при
rebind вместо закрепления накопленной ошибки solver. Массы, формы, число
суставов и строгие canonical/clearance сохранены. native26_anchor01:44 PASS
алгебры/native helper; это не доказательство всех вариантов восстановления.

НОВОЕ: `runs/native27_gun_burst01/RESULT.json`83 PASS настоящего input Uzi.
Resident169:60→45→30→15 HP, три обычных попадания по15 урона на7908/8137/8261мс
от начала fixture; первая→третья353мс. Первые две пули дают стоячую отдачу,
третья запускает физическое падение16 частей. От последнего попадания:
ACTIVE+3мс, RECOVERING+2412мс, walking_ready+3308мс,0прерываний восстановления.
Fixture11575мс, исходная стоячая капсула возвращена при15 HP без лечения.
Исходные3 NPC загружены; ownerhit/proof injection, HP/ammo writes и ручного
production step нет. Runner exit0/stderr0/pins unchanged, errors пуст.
Это точные числа27, не прежнего26. Контролируемый фактический оружейный прогон,
НЕ LIVE, НЕ выпуск и НЕ приёмка производительности.

Остаётся отдельная регрессия: native25_bullet0_01 actor0:73 PASS, actor1 в
native25_bullet1_01 FAIL на living recovery `floor_or_pose_changed` после anchorfix.
Ранее pending диагностический28 уже завершился: native28_bullet1_diag01:62 checks
FAIL на25309мс; живой169 при15 HP, WAITING,93 попытки/76 прерываний.
`recovery_pose_failure.proposed.reason=floor-unavailable-or-outside-source-grid`,
canonical_error0.000983782м ниже неизменного4мм порога. Это конкретный отказ
floor/pose sampler, не доказательство старого canonical drift; точную причину
разбирает runtime-владелец. Runner exit1/stderr0/pins unchanged. Компонентный28
использует TEST_ONLY ownerhit после native ray и другое направление/место;
успех настоящей очереди27 не отменяет этот FAIL.

Все25–28 изолированы и НЕ ПРИНЯТЫ. Обычная игра accepted48 сохранена; нужны
актуальные visual/negative проверки, свежая root-композиция и сопоставимый
loaded performance pair. Root27 сохраняет release/pointer/F5/Git, отчёты только
в существующий штаб. Эта правка только в3 документах: runtime и движки не менялись.

## 2026-10-03 — candidates21–23 (сохранённая история)

Проверенные SHA ASSEMBLY:

- candidate21: `54b451be900b072322761ae1e75976c14a712c64357e3ccdbe31f401555a3fe5`.
- candidate22: `5a6ec98ed05ddab30163ff0fe097f93d1554a1bbf75c754f8b00952d18b483f4`.
- candidate23: `0a7ab40297afe8ba2f83979e4339b4cd8493b320e44b88769a9bc0dc24eee1a8`.

Core21: только pelvis/spine/chest получают точнее охватывающие исходную rest skin
BoxShape с15мм reserve;16 тел/15суставов, массы, привязки и13прочих capsule сохранены.
Native corefit198PASS на всех3исходных моделях, headless combo41PASS. Размеры box
даны в системе body; старое поле chest_depth_m означает Z extent body, не доказанную
анатомическую толщину. Native21 GPUcomboFAIL(two hits) сохранён: budget8192face
исчерпан уже при span14.17мс, exactdistance0; дело не только в длинном кадре.

Geometry22: spatial KD order + refitted binary AABB hierarchy и bounds только
в реальном clipped window. Исходные faces не удалены,2мм tolerance/caps/poseage
не расширены. Native limb48PASS; native22_combo_gpu01 graphical41PASS:3касания,
combat_error пуст, fall/getup есть. Пользовательская игра продолжала работать;
это functional GPU fixture, НЕ performance/LIVE приёмка.

Реальный latest ACTIVE кадр257: chest skin clearance0.031642м (раньше capsule
кадр0.198787м), global min0.020572м, head0.062173м. Это разные позы, не matched
settled сравнение. Лимит12readbacks исчерпан, до первого наблюдаемогоRECOVERING327
ещё70кадров, native settled=false. Parent просмотрел изображение; окончательная
лежачая поза/отсутствие зависания ещё НЕ приняты. Evidence:
`outputs/artist24_melee_contact/runs/native22_combo_gpu01/captures/`:
`CAPTURE_RECEIPT.json`, `combo_00_combo_latest_active.png`.

Открытая регрессия Core21: bullet actors72/252 по73PASS, actor169 suite62FAIL
на восстановлении живого. `native22_bullet1_diag01`:5прерванных recovery, foot_r
canonical drift≈4.2мм при joint anchor error≈0.269мм. Предполагаемый rebind/cancel
drift исправляет `/root/melee_retaliation` в scoped
`outputs/artist24_melee_contact/ragdoll_fit/patch/scripts/npc_visual/npc_body.gd`.
Не ослаблять canonical/clearance. Bullet-agent отдал владение body и сейчас только
обновляет документацию; geometry22 не редактировать параллельно. Старые13all3PASS
исторические и не отменяют новую регрессию.

Candidate23 добавляет QA настоящей очереди через input. Вторая пуля нанесла19:
это допустимая source-вариация, ошибочно ожидались15в QA. Presentation-agent
исправляет ожидание, runtimeоружия не меняется. Полный burst23PASS не заявлен.
Camera03 pair06 оба functional smoke завершились, но snapshot старого21candidate
содержит late query error. Parent добавил запрет непустогоcombat_error в mutable
perfQA; прежний smokePASS не принимает ошибку и НЕ даёт FPS/performanceclaim.

Все21/22/23 и существующий merged03 НЕ ПРИНЯТЫ. Обычная accepted48 игра открыта,
сопоставимое performanceокно заблокировано. После canonicalfix нужны фактические
functional/visual перепроверки, свежий root merged04 и НОВАЯ matchedloaded perfpair.
Root27 сохраняет pointer/F5/release/Git. Ни sharedruntime, ни указатель этой правкой
не менялись. Подробности и пути — INTEGRATION_HANDOFF/NATIVE_PROGRESS пакета.

## 2026-10-03 — candidate20 (сохранённая история)

Свежий блокер QA05: merged48_combo_gpu05 native41PASS, но последний ACTIVE
кадр242 за4кадра доRECOVERING подтверждает зазор лежащего корпуса. Настоящая
posed skin minY0.007731м (бедро), chest min0.198787м, head0.085765м при floor0;
native chest capsule r0.367556/h0.881559м, скорость≈0.021м/с. Это уже доказанный
дефект слишком крупной физической оболочки, а не только начальное падение.
bullet-agent владеет pending scoped npc_body3 core Box fit; builder25runtime
allowlist source7testsPASS не означает native/visual приёмку исправления.
QA05 ASM `397f46008998aecc03ddc62bb69b1c8f6e5254cf7113ea186fef84a997354fb3`.
Данные: `outputs/artist24_melee_contact/runs/merged48_combo_gpu05/RESULT.json`,
`captures/CAPTURE_RECEIPT.json` и `captures/combo_00_combo_latest_active.png`
в том же каталоге прогона. HQ уведомлён о lying-blocker. Все текущие merged02
НЕ ПРИНЯТЫ; обычная пользовательская игра accepted48 остаётся открытой.

Pair02 отклонён для включения: полная сцена во время ударов, physics p95
baseline2.338 → candidate11.149 мс, максимум68.229 мс; contact-host max65.61 мс.
Функциональные PASS не отменяют эту просадку. Pair03 не запустился; pair04 подготовлен.

`outputs/artist24_melee_contact/candidate20/ASSEMBLY.json`:
`27a7cb9a6a607016d2ee7b102988dd7877af23694870b286a79751195396980c`.
Оптимизация читает только нужную руку текущей серии, повторно использует один
sample в том же кадре и сохраняет только нужные palettes целевых моделей.
Последовательные позы, последний отрезок окна удара и все проверки касания
сохранены; NPC, модели и анимации не убирались.

Native20 combo01 PASS41: три настоящих попадания →24HP→падение/вставание.
Native20 retaliation01 PASS32: ответный контакт NPC, player100→88. Ошибок нет.
Дополнительно native20 contact36 / wall27 / limb40 PASS.
Это функциональные native fixtures, не LIVE и не приёмка производительности.
`merged_root48_02` собран, НЕ ПРИНЯТ; ASSEMBLY SHA
`41829cef476165997a84306d3feaa17b53cc4a0cda2fd47aa33b776aa079101c`.

Graphical `merged_root48_qa04`: merged48_combo_gpu04 PASS41 с настоящим кадром
ground_contact; merged48_dropkick_gpu02 PASS28. Parent лично просмотрел обе
стопы, кровь и косметический след одежды. QA05 выше подтвердил дефект лежащей
позы: НЕ объявлять settled-позу визуально принятой.
Контакты по ткани не доказывают видимый синяк на коже. merged48_gun02 actual
Uzi PASS42:69.874Ns и0.13674м сдвига исходной капсулы.

Root accepted48 pointer теперь
`51484885ce069970cecb234b7c016d5cc7e3b5611c3422ddeaa915a0d9c712b7`;
source pins точно равны base48. Это НЕ включение NPC merge02.
Pair03 baseline NEVER_LAUNCHED: scheduler180s `Bound queue wait expired`,
ordinary game34540 и editor25808 сохранены; candidate03run не было. PID —
исторический inventory, перед действиями нужен свежий. Parent запросил окно
через штаб; pair04 уже PREPARED: свежий baseline ASSEMBLY513c и отдельный
`ACCEPTED48_BASE_IDENTITY.json` доказывают те же486pins/game accepted5148
при известном filename gate. Оба pair04 importPASS, но perf НЕ ЗАПУСКАЛСЯ.
functional_smoke camera01 FAIL на1ULP parent matrix; mutable QA-камера исправлена
на exact root attachment. Pair05 camera02 baseline graphical functional PASS
по120px gate (player180/victim179), candidate FAIL до camera approach; диагностический
фикс готовится. Smoke параллельно игре пользователя — явно НЕ perf comparison.
Сопоставимый замер ждёт свободного окна. Perf STILL_UNPROVEN,
NPC promotion запрещён до приёмки. Движки/production этой правкой не менялись.

Точные сведения: `outputs/artist24_melee_contact/INTEGRATION_HANDOFF.md` и
`NATIVE_PROGRESS.md`. Root27 сохраняет main/player/release/pointer/F5/Git,
игру пользователя и более новые свои изменения. Прежние frozen и история
ниже сохранены; runtime acceptance остаётся открытой. Отчёты — только штаб.

## 2026-10-03 — latest native result, candidates13–16 (история)

All three original residents PASS73 each: runs/candidate13_bullet0_01,
candidate13_bullet1_01, candidate13_bullet2_01. Standing stronger single bullet,
burst16part fall/getup, repeat medical1HP getup and absorbing final death pass.
Root cause fixed: prepared unskinned BoneAttachment vertices must use authored
local descendant transforms, not temporarily stale attachment world transforms
after previous recovery. Floor/clearance tolerances unchanged. These bullet tests
use TEST_ONLY owner hit after native ray; actual input/fire QA frozen16 pending.

Strict full1.25s dropkick originalfeet18HP/nativeground PASS headless11 and
rendered candidate12_dropkick_gpu03; GPU run without captures. No perf acceptance.
Native15_contact01 PASS36: contact12HP+blood, far/away misses, no errors. Precise
closest points retained through barycentric computation; float32 world roundtrip
could wrongly reject real triangle edges. Original2mm contact tolerance retained.

Combo OPEN: native15_combo01 has real W and source left/right/left clicks, but
only2contacts. Budget2048 evaluations creates128–264ms query hitches and skips
peak poses. Do not compensate with wider hit volumes or fake HP. Geometry owner
subagent bullet_recovery optimizes exact query; hand aim/W unchanged.16 adds actual
gun-input QA and world-coordinate edge regression, import pending. Frozen13–16
retained. Accepted pointer still45; root27 staging48 camera/C4/buildings changes,
preserve them on merge. Runtime/full-scene perf and release integration NOT_DONE.

## 2026-10-03 — earlier user-authorized native combat tests in progress

Current evidence and exact runner matrix: `outputs/artist24_melee_contact/NATIVE_PROGRESS.md`.
Real contact/wall and NPC retaliation now pass functional fixtures. Dropkick real
contact passes but strengthened full-cycle QA pending11. Medical1HP recovery is
blocked by initial_skin_blocked;11 diagnostic pending. No LIVE/perf/release claim.
Scheduler is accepted, no per-run root GO; preserve user editor and use Lease API.
Candidate11 SHA154c0d2126d24a5ab1670bb2ed1ad0e05e5668c0549901c207043182cf1b6e8e.
All original actors/resources/source candidates retained, accepted45 untouched.

# Художник24 — текущая память, 30 сентября 2026

## 03.10 — новое userGO: проверять самому и включать только после успеха

Пользователь прямо: «проверяй сам. добавляй в игру если успешно». Старое ожидание
личного GO ниже отменено. Запущены настоящие headless проверки с сохранением
user editor, общим mutex, exact pins и watchdog только собственного child.
Runner `outputs/artist24_melee_contact/run_contact.py`; текущие результаты в
`outputs/artist24_melee_contact/NATIVE_PROGRESS.md`. Boot actualmain3 PASS20,
geometrycomponent PASS27, combopolicy PASS19, poseclock/playerimpulse PASS.
Gameplay contact пока FAIL: typedArray02 исправлен03; 03/04 surface narrowphase
отказывает distance_budget_or_unresolved. Оптимизировать и проверить05; не
объявлять бой готовым. Pointer45 не изменён.

Root27 сообщил новое userпоручение убрать очереди: готовит общий scheduler
2headless functional +1graphical/input, perf отдельно. После завершённого
playerimpulse01 наш старый mutex освобождён для C4diagnostic8, enginesOFF до
подключения новогоadmission. Runner/guard пути переданы черезштаб. Личное GO
на каждый краткийтест больше не требуется. Все отчёты по-прежнему толькоштаб.

## 03.10 — пользовательский приоритет: настоящий ближний бой и импульсы

Последний source freeze: `outputs/artist24_melee_contact/candidate02/ASSEMBLY.json`,
SHA `72883e7f11117d8b463180c7a4c9618ae2417589ee60c8a9dda12363c7b0146c`,
497pins/26overlay paths. SOURCE_REVIEW.json: pins PASS, grammar34 PASS,
missing preloads0. Native/engine/LIVE/perf NOT_RUN; делегированного GO ещё нет.
Candidate01 не использовать для приёмки. В02 учтены moving target samealpha,
настоящая barypoint траектория конечности для wallcast, pose epoch cache reset
и rollback только собственных bindings. Source GLB hand276/foot332 каждого
из четырёх оригинальных моделей в пределах лимита. В QA добавлен dropkick
с actual Space/newairLMB и строгим одним18HP; ранняя native capsule cancellation
остаётся проверяемым риском. Frozen02 не редактировать: исправления →candidate03.
Передача с hash/границами отправлена в штаб. Следующий ход — согласованный
import/native boot/components/contact/wall/retaliation/dropkick, потом GPU/perf.

Текущий root27: `docs/ai/CURRENT_COORDINATOR.json`. Старые назначения ниже
исторические. Пользователь просит контактный бой, кровь/синяки/рваную одежду,
ответные удары NPC, сильнее импульсы пуль и ударов, восстановление выживших,
более удобное попадание, исходный удар двумя ногами и падение от связки ударов.

Работа изолирована в `outputs/artist24_melee_contact/`; сначала читать его
`HANDOFF.md`. Базовая принятая45 имеет manifest f7972140…; candidate01 сохранён
как исходный source-only freeze, ещё НЕ проверялся движком. Ревью выявило
поздний clock вместо возраста записанной позы и приблизительную сферу кулака.
Timing исправлен в mutable contact overlay; actual limb mesh narrowphase
дорабатывается. Новый candidate собирается только под новым именем.

Подготовлены presentation/v2, bullet_recovery, retaliation_v2, dropkick и
contact overlays. Source-политика быстрых подтверждённых ударов накапливает
потерю равновесия; отдельный тест учитывает допустимый исходный темп360ms.
Getup выжившего требует native clearance и owner proof, final death не снимает.
Blood32/48 — сознательное усиление source20/32; pool112 ограничен. Одежда —
визуальные прикреплённые следы, не cloth/topology sever. Local playerHP100
введён явным отдельным владельцем с отказом при конфликте прежнего owner.

QA `qa/test_contact_loaded.gd` грузит настоящий main/три original NPC и ввод,
поддерживает раздельные boot/contact/wall/retaliation <=55s soft,60s hard.
Нативные тесты ещё НЕ ЗАПУСКАЛИСЬ. Pure gdtoolkit grammar PASS не заменяет
Godot compile, реальный контакт, LIVE или производительность общей сцены.
Движки удерживает root; через штаб запрошен короткий HEADLESS GO. Пока его
нет, не запускать Godot/GPU/экспорт. Accepted pointer, чужие runtime/Git не менять.
Все отчёты только в общий штаб; напрямую root/старым координаторам не писать.

## 21:27 local — coordinator handoff and CPU/GPU quiet

Fresh `COORDINATOR_25_HANDOFF.md` confirms the user appointed Root25 as successor
to Root24; Root25 now owns integration/LIVE/Git. Artist24 remains NPC owner and
reports only through HQ. Root25 paused even headless Godot during the street-lamps
matched GPU measurement; no NPC Godot runs until that owner reports RELEASED.
The isolated run21 evidence below remains the latest usable NPC canary. Do not
promote the staged profiler additions or claim LIVE/performance acceptance.

## 21:17 local — service candidate repeated; performance still unresolved

Same actual75 / normal player-car-weapons, two-original-resident headless service
canary passed 14/14 in runs14–19 and21. Resident191 deposited48 from80 and
resident252 bought the $3 newspaper; balances conserved and both returned to
walking. Run20 is excluded because a temporary profiler read an optional nested
field after visit completion; that diagnostic error was fixed before run21.
Candidate remains isolated in `outputs/artist24_daily_cycle/city/scene_project`.

Run21 logic p50/p95/max was 6.018/8.911/77.957ms; daily-controller max20.090ms.
Bank ownership-check and entry-poll parts each peaked below1.8ms; they do not
explain the largest daily/population samples. Runs15–18 similarly left a large
component gap. Keep performance HOLD and do not call it optimized or LIVE. Full
run notes: `city/NPC_BANK_FLOOR_SEAM_HANDOFF.md`; run traces in `city/run14`–`run21`.
Only the narrow pinned-bank-floor route change is a behavior candidate. Later
bounded profiling edits are staged instrumentation; exclude them from promotion.
HQ was updated at21:17, no Root integration/LIVE/GPU action was taken by Artist24.

## После20:06 — actual75 движение PASS; массовый запуск и посещения требуют исправления

Пользователь дважды требует результат/срок. Ответил честно: полного живого города
ещё нет в его игре; ориентир2–4часа на основные цепочки с низкойуверенностью,
не обещаниеготовности. Продолжать реализацию, не останавливаться на отчётах.
Root24d/main/player/GPU/Git не трогались. Штаб уведомлён о точных ограничениях.

city/run05 actual75+hospital411colliders+bank139+normalplayer/car/weapons PASS:
original3 прошли12.331/17.550/17.143m, одинwalkcomplete; setup16.925s.
Политикаpopulationlogic p50/p95=3.782/5.853ms, NOTwholeFPS, слишкомдорого287.
Nav71tiles8973polygons72782triangles,6048actualstaticshapes, READY.
Sourceheightvisual1.65..2.05 отделён отphysicalcapsule1.9 (110tall не удалять).
Healthcachedpacket city/health_runtime f8885e...18purechecks; старые3pins исправлены.

run06 whole287 timeout90s вfallbackplacement:219bodies(101birth118local),68pending,
4893rejects,5780sourcecalls,last189; navigationREADY,0healthowners. Причиналишний
fulltree find_children доcheapfloorrejection; recovery делает startup_runtime
guard reorder +2ms/32attempts budgets, все287сохраняются. Footprint rigcache
policy_hotpath hostbd1b0937...45PASS, sameframeSceneTree.tree_changedinvalidates.
Parent _startup_current guards afterawait addedcanonical. Stagewriterполучил
bootstrap+main_city.tscn; Rootlatest24d сохранять приmerge, base25неpromoteцеликом.

Actualservice run08 двоеsource191/252черезsetup_city optional QAcohort
(normalcallstillall287), goal timersdueforbank/shop only.141.963s resultFAIL:
bank walk/openingthen source_native_corner_floor atentry, unwindsphysically;
shop walks36.9→19.365m then bounded_detour_exhausted / path_point_off_native_map.
Neithertransactionperformed; nofakeHP/cash/bodywrites. run07 QAArraytypeerror
interruptedownheadless31236/15788only. run08 completed. Parent instrumented
entryfloor_failure/nativehit, DailyWalkpath_admission/last_leg_failure, events,
shopwalk; fixed Godot get_meta(null) error viahas_meta. Nextactualrunneeded.
Banksharedshop3files frozen23PASS,139shapes,39893→139subscriptions,287bind250→218ms
componentonly; top-levelshopupdated and staged. Visitorhelper preparing actual
hospital245 TTtorso1shot→36/60→medicalroutecanary, notrunyet.


## 19:53 — actual75 scene собрана, устранение реальных seams

Задача «собери живой город» активна; НЕзакончена. Parentoutputs:
`outputs/artist24_daily_cycle/city/scene_project` — isolatedclone frozenRoot25,
`stage_city.py` reproducible scopedmerge; shared/rootmain/GPU/Git не менялись.
`test_city_scene.gd` actualmain75+originalplayer/weapons/car; ownCityPopulation.
run01/02 сохранены. run02 actual75/159/353+printshopREADY, но hospital
Invalid source collision body иbank Ambiguous source mesh отказали.
Recovery сейчас исправляет точные причины: hospital staticBodies53 roof sign
min11.715>max11 malformed sourceinterval, настоящийmesh max13.365; bank normalizer
сливалsign +/-4.68,+/-8.55,+/-0.3. Ничего не пропускать/не уменьшатьcollisions.
Transportclosure4missing files изshared добавлены вstagewriter по
transport/TRANSPORT_CLOSURE.json; Root25 existing3diff files оставлены.
ValidationMAX_SIDE128→200 иexact3sourcebankcolonIDs stage-only; originalIDs intact.
Printshop dooroccupantcap64→512 stage-only, hospitalbankownerделаеттакже.

287actualnative preparedSCN completed6/6. Combinedprepared:
`city/residents/combined/manifest.json` SHA929a5083842a5325ba5d4d823b1ac63c8b56b459ac19b414057ce6190f35f288,
1,511,418bytes. Providerb9packetvariant15f12b88. Cachecity/runtime4fb99472
bounded288/2MiB andsingleverifiedindex; native19purechecksPASS, cold287
300639→85042us (samefixture), no sceneperformanceclaim. No Loaderbytechange.

Tiled nav city_navigation frozenbackend7ea17611, hosta1f4d503:96m tiles,
oneasyncrecast,2ms incrementalprep, actualfixture29PASS300m/seams/doorreuse/stale
asyncdispose. Wholecitysource72782tri/218346verts/71tiles,0drop. Actualcitycapture
ещёНЕrunиззаgeometryabove. Replacesonlystage publicnavigationhost path.

City populationruntime recovery: hostd592636a +hit3075052f,receipt5ab26f8a.
Hostmerge transportdailyclaims+Root25exactNO_PATHfloorfix+cap288+newbounded
admit_city_spawn512attempts onlyneveradmittedpinnednewsession; sourcerawunchanged,
labelLOCAL_CITY_NEW_SESSION_PLACEMENT, nofull326originalplacementclaim.
hitoldmanifest3seam выявлен; visitagent сейчасделает city/health_runtime newhit:
exacthost_manifest andcachedverifiedprovider toavoid287wholepacketparses.

Parent new city/runtime/npc_city_population.gd extendsRootpreviewpopulation:
setup_city actualsites+nav+policy+packet;1originalasset/physicsframe;
firstsourcebirth thennearbyboundedlocalinitialresolver; health1/frame;
real dailyhealth/account/visitfactory; existingmain callssolepopulation.step.
Body movementonlyoriginalhost, vehicle onlyownphysics. Logic2048samples recorded,
notGPUFPS. Parent dailydecisions12PASS; allparentmodulesPARSE beforelatestwiring.

Policyexact publicentryleaseforwarding fix e0c5835f, pure11+source36612PASS.
footprintagent prepared separate city/npc_daily_walk_detour_proposal.gd and
city/runtime/npc_native_obstacle_detour.gd; actualnativeobstaclefixture pending,
NOTmergedparentwalk. Need dispose exactcancelunconfirmed fix too.
Recovery visitsalreadyfrozen50ec851f physicalunwind/releasedtrue onlyactualpublic
release; physicalhospital/bankcanarystillUNRUN. Shop generalized subclass
shop/npc_local_shop_visit.gd (not nonexistentshop/npc_local_printshop_visit.gd),
originalbasecomposer remainsRoot25; generalizedwrapper+accountsameactualrows.

Currenthelpers: recoverygeometry, visithealth+reviewparentwiring, footprint
detourfixture+transportclosure. Parentnext rerunactual75 oncegeometryready;
first3fixture thenfull287 andservicecycles+cost, deliverRootviaHQonly.
Root latestwaitcursorfe1894c4-a1f6-44f3-bad0-f45d73bfa688:21 opens24d (markfix).
Root18:43 functionalheadlessallowedalongsideonegame, noFPSclaim; sentHQcityscope
andupcomingfunctionalrun. No activeparentengine currently. Managerpreserve.

Действующий NPC-чат `01a0f291-6661-7430-bbd8-599c42c32c53` принял работу23 по
прямому поручению пользователя. Root24 — `01a0f288-91e5-7092-9d8b-ef7d725cc696`.
Все внешние рабочие отчёты только штаб `01a0df67-44d3-79c0-b243-fa6a9b891fde`.
GPU/source capture требуют отдельного GO; main/player/export/LIVE/Git не наш scope.
ToolSearch/Ruflo недоступны; используется файловая память. Git не менялся.

## Новое главное поручение — СОБРАТЬ ЖИВОЙ ГОРОД

Пользователь: «мало хп — идет в больницу подлечивается — идет гулять — захотел
сел в машину — идет что то купить в здание», затем «закончились деньги — пополняет
в банк идет», затем «так вроде изначально так и планировали ты то чем занимался
все это время? собери мне живой город». Признал ошибку избыточной isolated работы.
Конечный результат — общий живой город с потребностями и действующими услугами,
а не ещё один локальный visit/3 NPC/готовые документы. Старые mechanics сохраняем.

Обнаружена фундаментальная граница: current block только8buildings/3preparedNPC;
hospital и bank в нём отсутствуют. Hospital original localx276.75, bank localx−178.35;
включение маршрутов без расширения реальной сцены невозможно. Root24 получил
конкретные данные и новыйscope черезштаб, по-прежнему владеет main/export/GPU/Git.

Уже сделан outputs-only полный authored building-placement экспорт:
`outputs/artist24_daily_cycle/city/delivery/` и `RECEIPT.json`.
75buildings/159decor/33uniqueGLB/353exteriorcolliders/29014sourcecells,
blockSHA38b4b50ca06fb60172173b04c5b49ff567a84509ea01901a24306ab0d3b41dc7.
Использован неизменённый проверенный exporterEC875A7, исходные8building+8decor
records полностью сохранены, origin прежний; исходныеSHA проверены. Экспорт1.2s,
не Godot/GPU. Это все authored placements, не весь world/landmarks/landscape и
не gameplay acceptance; интеграция и native расширение ещё нужны.

Hospital пакет: `outputs/artist24_daily_cycle/hospital/HANDOFF.md`, receipt
89ee8f8d56b98dcb5e9a9be34c517657be04007de2fbf178370bdd724a1bbe0d.
Source geometry/data51PASS, native GDScript PREPARED_NOT_RUN. Исходные3этажа,
2двери,404sourcecolliders,414floortriangles; service[276.75,1.5,−.6],
street[276.75,0,−19.88], не y=0. Geometry attach_existing заменяет только3envelopes
после успеха; treatmentport меняет тот же HPowner._row+revision только после
реального ARRIVED/пола/4с непрерывного current-life service, не source/save.
Recovery agent завершает bank geometry аналогично, gate в shop/npc_local_bank_site.

Shop/bank runtime: `outputs/artist24_daily_cycle/shop/HANDOFF.md`, receipt
babf1f630434a407946f6a45e5d4375dbf562dd8a4a672aa8666033cae69dbad.
Actual local-session account/source cashseed35..119, initialbank0, перевод только
cash↔bank, покупка3монеты/newspaper после actualprintshopBROWSING. Pendingpurchase
сохраняется приwithdraw, общая сумма сохраняется. Нативныеканарейки PREPARED,
Godot не запускался. Это новая user-authorized localbankservice, не старый server.

Transport agent пишет `outputs/artist24_daily_cycle/transport/`: concrete isolated
host (отee28)/preview_transport/adapter. Existingplayer-only wrapper перетирал
NPCcontrol neutral/brake; добавляет actualNPC roster/seatdriver lease, sourcecar
ownership, board/exit черезсуществующиеRuntime transitions, sourcepathfollower.
Daily activity reserve/release/request/cancel publicAPI исключают только своего
previewproducer, host.step solewalktick сохраняется. Исходный printshop servedlot
отсутствует; делаем честный новый двухэтапный путь к source freebay005 примерно40м
оттипографии → exit → separatewalk, не приписываемтипографиичужуюпарковку.
Source actualparkingeligibility не имеет privateownerpolicies дляresidentialkind;
свободное/размерное место и реальные reservations/overlap всё равно обязательны.

`outputs/artist24_daily_cycle/npc_daily_walk.gd` написан rootArtist: actualasync
native map path proposal→≤5mlegs→publicrequest_daily_walk→physicalARRIVED+floor;
cancel/supersededguard, currentdailyclaim/life, безbodywrites. PREPARED_NOT_PARSED,
ещё не интегрирован с needs/orchestrator. Активныеагенты: footprint=transport+host,
recovery=hospital+bankgeometry, visit=commerce+two-legsource roadpacket.
Нужно собрать общий native needs executor и всю expanded scene, проверитьдвижком
и доставитьоднуигру. Не объявлятькандидатыживымгородом. Corpsev2 отложен.

Первый Rootnormalrefusal оказался настоящим local_vehicle_1 в исходном.738square,
несломаннымhost. Root detour24c заменил7waypoints на8 (28total), source/nativeguards
неослаблены. Full04 не стартовал из-за отдельной пользовательской quick-controls
игры; Root согласует единый GPU/CPU слот с еёвладельцем. Наши GodotтестыOFF.

## 18:18 — Root normal-scene выявил первый integration blocker

`outputs/coordinator24_npc_delivery/headless01/observer/RESULT.json`: initial
native_request_refused, resident169 не двигается, остальные2 идут; визит не
начался. Root NPC агент диагностирует; не объявлять прежний isolated33+35
приёмкой общей сцены. Owner isolated approach шёл до public bind и ordinary
preview, player/transport ticks были выключены. Root нормальная комбинация
должна сохранить их; конкретный source/physical/native отказ ещё выясняется.

Независимо найден terminal cleanup bug: при invalid geometry/service-door
cancel ставит CANCELLED, poll переписывает STALE, public host отказывает,
scheduler после3 retries держит lease. Минимальный новый outputs-only candidate
`outputs/artist24_cancel_terminal/` сохраняет уже CANCELLED local terminal до
_current; movement разрешается только READY и host life/claim/request guards
остаются. Source eb6acff8b79f42a61e0024fc2445232439be2ace1a249fbb4250657d9741f3bf,
portable e61579eb4beef9b1faa2517797ab88b8108944b848bbed095c9061769e03ec8c.
PREPARED_NOT_ENGINE_TESTED, frozen manifest0f96/Rootcandidate не менялись.

## 18:11 — пользователь требует видимый NPC результат, marks пакет заморожен

Пользователь разрешил оставить недоступные Астра8–10 и требует результат по NPC
в игре. Повторные попытки связи прекращены. Семь доступных чатов уже дали ответы;
непроверенные предложения не внедрялись. Приоритет — одна игровая сборка Root24,
а не дальнейшее расширение проверок. Root подготовил изолированный candidate21 /
quality24c от cargo24b: `outputs/coordinator24_npc_delivery/ASSEMBLY24C.json`,
218 inputs, обычный scheduler с current player+NPC door occupants. На момент
этой записи он ещё не проверен движком/экспортом/LIVE и не открыт пользователю.

Полностью заморожен `outputs/artist24_postmortem_marks/HANDOFF.md`:
final run09 301/301 PASS, clean log, все3 исходных NPC получают новые отметины
после смерти; HP/deadAt/revision/death hooks/impulses сохраняются. 37 точных
геометрических сравнений сохраняют skin/frayed-cloth art и cap24. Семь настоящих
terminal событий залпа обязательны, отметина одна на цель как в текущем living
пути. Callback retention устранён exact host instance ID вместо сильной ссылки.
Receipt SHA1223739cc91eda50b8740d2c1755b6a8159d8cee680c8611c510584fc236291f.
Три файла: owner114b420d34fefbab4dcf9dc7260ad09d5a99ed24fc702573fdd4a8f0fbe8ca70,
adapter024702f325f699de2d5ba61482cc567523f7309f927371666faffe8c44f1c858,
renderer88bd0604d8a09f8ea9a040802d487ea42289ede29591ed173292a7ac6b3dc970.
Парный full local pipeline p95 16.605→12.805ms, residual cost существенна;
общая FPS/GPU приёмка не выполнена. Оба готовых пакета отправлены в штаб для
ближайшего фактического включения Root24; CPU свободен, нового GPU не запускали.

Толкание/блокировка трупа отдельно: Root предложил bit1024, NPC layer1280/mask257,
player mask1025. Это ещё НЕ согласованный production contract и НЕ готовая
механика. Нужны совместимый NPC owner v2, completed pre-move intent, общий v1/v2
dedup/cooldown и согласование rubble strict player-mask guard. Не включать просто
256, оно также используется medical и player-exit телами. Outputs-only подготовка
не задерживает уже готовый визит/marks.

## Новые действия: фактический исходный житель посетил типографию, isolated

Последний полный успешный прогон `outputs/artist24_street_handoff/full03/`:
33 проверки public visit + 35 adversarial, 0 ошибок приёмки. Не установлен
в игру. Канонический `outputs/artist24_printshop_visit/PUBLIC_VISIT.json`
скопирован byte-for-byte, SHA17d701045f54e9348a02b91e5b719b81aa8f601e8d0ec2c27895f2a7f778905f.
Старые full01/full02, before-street-return и предыдущий canonical сохранены.
Полная передача: `outputs/artist24_printshop_visit/HANDOFF.md`.

Настоящий resident169 прошёл 27 обычных native legs / 64.320178 м от принятого
preview start до типографии, затем реальную дверь/пандус/осмотр3.333с/выход.
Теперь он физически возвращается в фактическую точку начала визита через
RETURNING_TO_STREET и лишь затем COMPLETE/public release. Визит553frames,
все на полу, отдельно pause300frames;309moving, blocked0, локально9.014669м,
maxstep.037477344м. После public release обычная прогулка прошла2.639998м
за180frames. Остальные2 исходных NPC продолжали идти, все3 rows/ID/rig/life
и preview entries сохранены. Не телепорт и не капсула-реплика. Это новая
локальная сессия, не исполнение original agenda/source saved progress.

Финальные tested SHA: routec0d4e21cfa82e134f7898ec2968677403411139bf23aae9e2273b7634fd865c0,
composerd922ff1b2840115f4daeae60098eb630c757f596153465cff78d20f862441cc5,
hostee28d96d44033212109b2aa744d87ff97b5200dcb6930f4ad0fc0713bad3c253.
Executed mainD44BC28B; shared host baselineFCA338454E неизменён этим пакетом.
Full01 выявил untyped Array вместо Array[RID] при native admission возврата;
c0d4 исправляет тип и даёт точные причины initial guards. Collision/source/
identity guard не ослаблялись. Возврат повторно допускается ordinary source +
native collision, затем проходят исходные полные sweeps до actual arrival.

Публичный opt-in host контракт готов: bind_local_navigation_adapter,
cancel_local_walk, release_local_navigation_adapter, local_navigation_adapter_status.
Он приостанавливает только выбранного producer, сохраняет3 entries и один
host movement/gait tick; stale/replaced owner не получает yaw/body/velocity
sideeffects. Missing claim переводит composer в HOLD. Dispose/release умеет
узко возобновить свой same-life actor без claim, не затрагивая заменённый claim.
Physical ACTIVE/dead не возвращается в walking. Отдельный owner receipt58/0
исполнялся на том же final hostee28/composerd922, но route32f7 ДО узкого c0d4
исправления. Его frozen evidence не переписано; последние c0d4 покрыты33+35.
Final-death fixture в owner suite TEST_ONLY, не source combat integration.

Исходный квадрат .18cell/.738м сохранён, не заменён capsule radius.36м.
Точный geometry SHAe1bcf7b5ba88008b17362aaedb1d0c094dd7cefd756ec0e7afec0923a2aad618.
Закрытая дверь запрещает все9 lanes, открытый центр BLOCKED; только+.0125cell
(5.125см) даёт alignment/entry/reverse. Source floor15291points maxerror1.216e-14м;
helpers880+26100checks и36sweeps. Контактный floor вычисляется для каждой
polygon contact. Сохранены current land/road/water,5support samples, native
capsule и полный square для новых препятствий. Shape/layer/door/terrain/owner/
reparent/capsule и outside-capsule inside-square blocker guards PASS. Автомобили
no-snag не проверены. Pause не расходует browse time и не меняет position/yaw.

Переносимый outputs-only пакет7files в `outputs/artist24_printshop_visit/delivery/`:
host/route/composer/2helpers/2JSON; только два preload заменены на res://.
Manifest SHA0f96e42bdf74e8e6b1512a6279dbe0de63769d31c26db3e8a79b8849550fee91.
Headless portable parse PASS, exit0, clean log,7hashes/assetpins/4modules;
существующий kernel скопирован лишь для smoke и не входит в7promotion files.
Finalizer выполнен после свежего smoke; итоговый RECEIPT
SHA8ff4f29ca86c874de63bfe442a5fc7922dab976a48018af815ba96704d56f04a.
Host менять только с exactFCA baseline либо scoped rebase с владельцем.

Последние full03 CPU p50/p95/max µs: route589/815/1045, host3NPC1185/1832/2690,
combined door/nav/host/visit1569/2300/5073. Automatic preview во время визита
включён; player/transport ticks выключены. Это component CPU последних файлов,
не matched GPU/frame-time/memory и не весь город. Старые14+14 identical513frames
и2113/2725→1376/1952µs сохраняются как ИСТОРИЧЕСКИЙ baseline/opt, не final-byte
приёмка. Ранний подход64.379м также отдельный исторический прогон.

Оставшийся предел: full02 на тех же final files редко BLOCKED на обычном leg18
до визита, возле(13.123066902,-.032401882,.458165646), несмотря на finite support/
source admit; full03 повтор прошёл. Это не исправлено этим пакетом и не выдаётся
за надёжный scheduler/retry. Оба лога сохранены. Full03 пишет2 старые ошибки
RPG missing actor_id/life_generation из weapons/rpg_effects.gd:42; глобальный
engine log не clean. Оружие не менялось. Root ещё нужны approach reliability,
population/scheduler/export/combat/transport и единственный actual-game GPU/
frame-time/memory прогон. LIVE не было, shared runtime/Git не меняли.

## Исправление устаревшей сводки recovery и новая оптимизация

Начальная ARTIST24_HANDOFF ошибочно сохраняла2.456мм skin-floor как текущий
blocker. Более свежий `outputs/artist23_floor_fix/HANDOFF.md` уже исправляет
контактной reserve15мм и solver настройками NPC; текущий npc_body SHA19479386
точно совпадает с этим пакетом. Не наше новое исправление и не повод ослаблять
skin clearance. На текущем main baseline211/0, все3 встают.

`outputs/artist24_recovery_audit/RECEIPT.json`
SHA d1d333db26d1427e0c51642ec123cf745383d5abcfb5f29ef0001874767e61ff:
single-pass extrema candidate только outputs: micro3894/0 exact poses/vertices/
bounds/floor-query order, actualmain baseline211/0 иcandidate211/0 exact rows,
fixture668/0 включая restun/finaldeath/stale/car obstruction/failed resume.
RISING p50/p95 2169/2989→1729/1979µs,162samples. Source release TEST_ONLY;
gameplay recovery ещё не подключена. Generic character_physics helper — не наш
shared scope, кандидат передать Root/physics owner; самим не устанавливать.

## Повторно используемые source helpers

`outputs/artist24_footprint_port/HANDOFF.md`, RECEIPT SHA48695b46…:
880+26100 Godot checks0FAIL; source floor15291 +36 full closed/open sweep cases.
`npc_contact_sweep.gd` переиспользует существующий navigation kernel, не второй
алгоритм. `npc_printshop_source_floor.gd` — scalar64 bounded floor formula.
Использовать world absolute endpoints, исходные polygonCR и .18*4.1.
Два helper пока outputs-only, LIVE не было.

## Остальные границы

RPG18/19 и багажник у Root24, не дублировать; limbs/medical crawl/no-snag/shadow
LIVE остаются отдельными открытыми задачами. Игру не запускали/не закрывали.
Fresh inventory сначала видел только Manager45268; позднее появился Root-owned
Godot5408 с interactive23h cargo script. PID исторические, проверять заново.

## 3 октября — контактный пакет и открытое превью

`outputs/artist24_melee_contact/kernel38` — изолированный вариант оптимизации
расстояния треугольников. Native parity fixture: 1629 checks / 287 comparisons,
exit0, stderr0; source import clean. Он сохраняет 2мм решение, double witnesses,
degenerate/near-parallel порядок и убирает повторные endpoint/edge вычисления.
Это пока component-only evidence: в production limb не подключён.

`outputs/artist24_melee_contact/capture37` импортирован clean (503 pins).
Загруженный capture `runs/native37_capture01` не принят: native capsule approach
стал `native_obstacle_stalled_13_ticks`, поэтому queries_seen=0 и CAPTURE.bin не
создан. Никакой неполный capture или неподтверждённая оптимизация в игру не
передаются. Frozen candidate36 и merged_root48_07 сохранены без изменений.

По запросу пользователя 03.10 открыто текущее verified превью release48 через
stable launcher: `outputs/current_game/interactive/20261003T083607951Z/OPENED.json`,
revision `s01-20261003-c4-release48`, ready=true, исходный процесс оставлен
открытым. Это preview текущего root release; NPC candidate36 ещё ожидает
свободного matched loaded-scene performance окна и root27 promotion.

По следующему прямому запросу пользователя создан изолированный runtime
`outputs/artist24_melee_contact/merged_root48_08` на базе release48 + candidate36.
Импорт GLB после отдельного editor/import/quit завершился exit0; интерактивное
окно запущено процессом 32144, stderr пуст. Это пользовательское preview
функционального NPC-пакета (не accepted pointer и не Git/publish). QA scripts
намеренно не входят в runtime manifest; их native evidence остаётся в candidate36.

После прямого подтверждения пользователя основной указатель
`godot/current_version.json` переведён на `merged_root48_08/ASSEMBLY.json`
(SHA `10f29304511fb705d0b18fc7db9a5a76fcd001f59c9225b2c4194ca201fa11f9`).
Проверена реальная загрузка основной сцены: `PALAZZO_READY=true`,
`RESIDENT_POPULATION_STATUS ready`, `MELEE_PRACTICE_STATUS local_contact_combat`,
stderr пуст; текущее окно работает в PID26440. Полная loaded-scene performance
acceptance всё ещё не подтверждена и поэтому явно не объявляется готовой.
