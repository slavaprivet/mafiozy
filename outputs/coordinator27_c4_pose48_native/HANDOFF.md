# C4 pose48: private adapter, HOLD

Не публиковать: текущая установка C4 в принятой48 сохранена. GPU и fullscene perf не запускались.

Адаптер построен из exact48 ASM513c9165…dd83c (486 pins): заменены только player (CAS/post-writer hook) и текущий equipment11f9c4…, добавлен pure c4_pose44. Остальные484production files byte-exact. query45/surface45, shared-shape referencecount fix, damage1920/radius3.2, currenticons/visuals/Fire3 сохранены. Root/main/pointer не менялись. Frozen runtime одинаков во всех трёх private revisions.

| Прогон | Результат | Содержание |
|---|---|---|
| r1 import/native | importPASS; nativeFAIL34/1, stderr0 | Настоящие Q/LMB и post-writer receipts; high-wall reach failed |
| r2 import/native | importPASS; nativeFAIL52/1, stderr0 | Записаны конечные ошибки рук; crouch/cancel/return прошли |
| r3 import/native | importPASS; nativeFAIL56/1, stderr0 | Ближний/низкий subcase установил1valid charge; финальный C→stand не подтвердился |

Исходная query45 принимает стену при actor≈(44.68,.091,-3.78), hit≈(45.33,1.584,-3.78), но реальные palm errors: **R .175273m / L .174510m** против .025/.035m. Угол .000691rad проходит. Актёр во время hold неподвижен. Ограничение не скрыто увеличением допуска, изменением range или растяжением рук.

R3 — отдельно обозначенный более низкий/близкий случай, не замена исходной цели. Native settling оставил actor≈(44.78305,.090665,-3.810616), фактический gap≈.547m. Настоящий hold создал заряд через single-use completion frame515/revision514: Rerror.00666054m, Lerror.000000238m. До/после удержания actor/body/capsule/epoch совпали точно. Crouch сохранил тот же capsule resource и radius.30, native height стал1.69. Общий RESULT остаётся FAIL из-за последнего C→stand; причина не приписана solver без доказательства.

Q/GUI,2.9s cancel, foreignCAS/copy/stale receipt negatives, фактические bone frames после единственного writer, отмена приC и stable crouch/affine coexistence проверены. В r2/r3 по380 native receipts. Отдельных positive combat/HP/blast/skin доказательств нет.

Дальше нужны authored foot-preserving standing torso/chest/shoulder reach и отдельная low/kneel pose для пола/склонов. Короткие руки при фиксированных плечах не покрывают нынешний target set; обычный crouch1.69м не заменяет kneel. Автошаг, телепорт, новые capsule правила или сужение range требуют отдельного решения root. Сохранённый C→stand FAIL также остаётся открытым.

Engine bone pose может быть дополнительно изменён modifiers; эти receipts не равны принятой GPU skin. [Godot Skeleton3D](https://docs.godotengine.org/en/4.5/classes/class_skeleton3d.html).

Точные manifests, hashes, input/receipt evidence и перечисленные ограничения: REVIEW.json. Runtime-only patch и минимальные diffs: frozen/. Старые FAIL и все revisions сохранены.
