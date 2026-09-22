# LIVE moving intimidation — 23 сентября 2026

Проверено в единственной существующей игре18538, native Walk, localhost
preview без authenticated backend. Общий reload загрузил water/staged follow,
moving intimidation, black phone, cohort drain и два transport patch.
Поздний escort cancellation Художника21 на момент этого наблюдения ещё не загружен.

Штатный инспектор выбрал resident270, businessman, walk_to_shop: скорость
2.01→1.80м/с, готовый маршрут19→16точек. Обычный X отдал intimidation;
браузерные globals/teleport/debug mutation не использовались. Исполнитель
merc_resident_95 (София Манчини) физически догнал жителя, затем шёл рядом.

Read-only DOM actionHistory, epoch ms; r/c source coordinates, scale4.1:

| at | phase/progress | member r/c | target r/c | walking |
|---|---|---|---|---|
|1790116337973|approach/0|33.72068106168098 /30.381414651973135|33.5 /29.96158048781535|true|
|1790116339098|working/.3319999695|33.54147222589098 /29.789729788142324|33.5 /29.5|true|
|1790116340201|working/.7731999397|33.51720538012985 /29.50891824304469|33.5 /29.216741463419865|true|
|1790116341655|completed/1|33.50832152913127 /29.275920702062617|33.5 /28.926809756087092|false|

Во время двух working samples цель действительно сместилась на1.161м,
а прогресс вырос. Между вторым working и completed — ещё1.189м. Громила
сохранял физический контакт; completed ровно один, действие снято.
Screenshot после завершения показывает этих двух персонажей на тротуаре,
плашку «Страх» над resident270, HP-вред данным сценарием не вводился.
Это подтверждение данного движущегося сценария, а не всех скоростей/препятствий.

Другие факты после reload:33/95/192 сначала arrived возле героя40/40,
138 продвинулся от78.5611/19.6893 до47.24175195/35.45597366, чередуя
route_moving/search_pending.187 остаётся сухим на27.7993138477/45.1384447239,
no_route: передан exact native geometry repro, исправленным не объявлен.

При hero-camera сразу после reload frame p50/p95 83.2/92.5ms,
GPU46.73/52.01ms, mercenaryUpdate.1/.3ms, main2273/shadow860calls.
Это другой camera/population state относительно предыдущего113/123ms;
контролируемым ускорением/FPS before-after эти цифры не являются.

В22:34:27.185Z DOM подтвердил и конечное прибытие merc138:
r40.65196808162342,c38.84820809840262,arrived,bodyDepth0. Остальные33/95/192
тоже arrived;95 самостоятельно вернулся после выполненного intimidation.
Итого4/5возле героя,187 остаётся отдельным воспроизводимым блокером.

Root integration checks: phone19checks PASS, intimidation27PASS (baseline
data-module loader исправлен для нового sibling re-export), combined
water/long-follow/parking35PASS, cohort drain/empire QA PASS, world7syntaxPASS.
Phone actual GLB13PASS не заменяет визуальную LIVE приёмку звонка.
