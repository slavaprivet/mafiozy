# NPC: подтверждённые ранения и стоимость контакта — 12 сентября 2026

Область агента npc_damage: `artist14/bullet_wounds.mjs`, `hero_artist14_surface.mjs` и три новых теста. `npc_actor`, `npc_population`, `hero_walk`, source HP/shot admission/AI не изменены. Root отдельно ведёт фактический отказ урона в пользовательском LIVE: наличие этих эффектов не доказывает прохождение source damage.

## Исправления

- Реальный head-contact male/female прежде создавал `RaggedBulletTear`: source receipt не передаёт `clothing`/`boneName`. Теперь материал фактического треугольника `SKIN` создаёт `BulletSkinWound`, костюм — прежнюю рванину. Явный `clothing` сохраняет приоритет. Кровь появляется в точке подтверждённого контакта; ни source death без точки, ни косметика не придумывают попадание.
- Явный `knockdown:false` не заменяется падением от legacy `heavy`/`dropkick`. Подтверждённый `knockdown:true` и прежний fallback без явного поля сохранены. Блок не вызывает новое падение/рану. Уже лежащий персонаж не вскакивает из-за нового блока.
- Смерть с `zone:head`, но без physical point, больше не создаёт синяк. Death reaction без point разрешена, как прежде.
- При создании одной раны сотни повторных skin raycasts заменены одним набором текущих posed vertices и кешем одинаковых точек. Временные CPU meshes никогда не добавляются в сцену, не владеют материалами и освобождают временные геометрии в `finally`. Их данные не переживают receipt и не могут застрять на старой позе. Никакого нового обхода в per-frame update.

## CPU проверка стоимости

`test_npc_hit_surface_cost.mjs`: настоящий GLB, два пола, одинаковые контакты, сброс раны между событиями, 4 прогрева + 8 замеров на сценарий. До/после запущены последовательно; baseline через test-only load hook возвращает исходную классификацию/прямые skin rays/отсутствие кеша. Миллисекунды p50/p95:

| Сценарий | До | После |
|---|---:|---:|
| Мужчина, голова | 291.804 / 313.537 | 28.085 / 30.973 |
| Мужчина, костюм | 441.263 / 451.620 | 47.790 / 48.308 |
| Женщина, голова | 306.233 / 326.097 | 31.154 / 32.675 |
| Женщина, костюм | 444.228 / 460.692 | 48.148 / 51.765 |

Это синхронная обработка одного повреждения, не цена каждого кадра. Голова дополнительно получила правильную skin-геометрию; грудь сравнивает точно тот же внешний вид. Первичное построение синяка не представлено прогретой медианой. Одновременные многочисленные попадания всё ещё могут стоить заметного CPU; общая производительность сцены не проверена. LIVE/FPS и source damage admission остаются root/координатору в единственной игровой вкладке; новую GPU сцену агент не открывал.

## Проверки

- `test_npc_hit_surface_contract.mjs`: red/green head tear; оба GLB, кожа/костюм, матрица частицы в actual ray point, receipt dedupe, knockdown authority, block, death без выдуманной раны.
- `test_npc_wound_contact_cache.mjs`: новый CPU query против прежних прямых skin rays; stand/crouch/prone, перемещение/поворот/nonuniform scale. 1890 компонентов позиций, все треугольные anchors, веса и material groups совпали точно. Геометрия не упрощалась.
- `test_npc_contact_ray.mjs`, `test_npc_melee_contact.mjs`, `test_npc_contact_anchor.mjs`: actual GLB высокие удары промахиваются над crouch/prone; преграды, расстояние, оба стопы, движущиеся delayed anchors и ID сохранены.
- `test_npc_death_all.mjs`: 24 source семейства/9 edge cases/71 catalogue/26 GLB ролей; source clock, свежая/старая смерть, LOD/reentry, respawn, custody/downed, приоритет смерти PASS.
- `test_npc_actor.mjs`, `test_npc_lifecycle.mjs`, `test_npc_surface_state.mjs` PASS с существующим offline bootstrap `node --import ./assets/maps/city_rebuild_v1/test_npc_death_offline_setup.mjs ...`.

Предел: monitor18538 статический. Не проверены authenticated combat ACK, новые NPC damage routes и реальная смерть пользовательского resident112 от выстрела. Данный scope не меняет ID/HP/логику полиции/боссов и не объявляет перенос всех механик завершённым.

## Дополнительный LIVE дефект тяжело раненого — 12 сентября

Root увидел resident110:60→36→12→1HP, source `_medicalDowned=true`, но отображаемый NPC стоял. Аудит подтвердил: source snapshot уже передаёт downed/forcedCrawl; updateNpcs выбирает медленный medical crawl раньше panic. Actor применял и base prone, и отдельный sourceFall вокруг таза; повороты взаимно отменялись. В `npc_actor.mjs` единственное условие выбора neutral base расширено с death на существующий `locked` (death/fall/sourceFall). Mercenary hook/source HP/AI/транспорт не менялись.

Actual male/female GLB regression в test_npc_lifecycle воспроизвёл красное состояние: HP1/downed/forcedCrawl/паника, голова остаётся высоко. После изменения sourceDown=true, голова<.65м, corpse state не возникает. Existing actor/lifecycle +24source families/71catalogue/26death roles PASS. `surfaceReaction:idle` не является доказательством стоячей позы: nonfatal downing хранится отдельно в diagnostics.sourceDown. Новых проходов/ресурсов/update работы нет, заменено условие существующей ветки. Финальный LIVE повторяет root.

## Ранее переданный profession hook

`npc_actor.mjs` агент не изменял. Возможный узкий callback после `walker.update` и `activityPose.apply`, перед `surface.update`; разрешать только без `busyLife`, обычного `gesture`, panic/flee и без перезаписи weapon IK. `busyLife` содержит death/downed/recovery/hit, swim, vehicle/boarding, jump/tumble/melee. Подавать source `life.professionAction`, не создавать новую gameplay authority. Surface reaction/swim остаются последними.
