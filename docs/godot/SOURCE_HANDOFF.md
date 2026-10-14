# Передача актуальной сборки между ПК

`tools/godot/source_handoff.py` переносит существующие байты. Он не создаёт
город, не объединяет разные версии и не подтверждает работоспособность Godot.
Published main от 4 октября 2026 не содержит `dsh_living_city_01/game`.
Для продолжения нужен подлинный current286 и пакеты первого ПК.

## Подготовка владельцем исходников

Остановить собственные записи в выбранные файлы на время упаковки. Игру
пользователя закрывать не требуется. Указать полный game, все runtime-зависимости
за его пределами и отдельные пакеты C4/vehicle/gang в JSON. Не выбирать весь
Desktop/репозиторий: support-файлы передавать точным списком `files`.

Пример структуры спецификации (пути и pins заполняет владелец):

```json
{
  "source_identity": {
    "repository": "https://github.com/slavaprivet/mafiozy",
    "head": "EXACT_LOCAL_HEAD",
    "working_tree": "modified source; preserve all WIP",
    "population": 286,
    "status": "SOURCE_ONLY_NOT_ACCEPTED_UNIFIED_GAME"
  },
  "owner_declares_dependencies_complete": true,
  "roots": [
    {
      "label": "Desktop/Мафиози/outputs/dsh_living_city_01/game",
      "source": "C:/Users/Слава/Desktop/Мафиози/outputs/dsh_living_city_01/game",
      "role": "game",
      "entry": "scenes/main_city.tscn"
    },
    {
      "label": "Desktop/Мафиози",
      "source": "C:/Users/Слава/Desktop/Мафиози",
      "role": "support",
      "files": ["AGENTS.md", "tools/godot/test_scheduler.py", "docs/godot/TEST_SCHEDULER.md"]
    }
  ],
  "expected_pins": {}
}
```

Дополнить roots точными исходными пакетами и receipts, а `expected_pins` —
проверенными SHA256 относительно архива, например
`Desktop/Мафиози/outputs/dsh_living_city_01/game/scripts/main.gd`.
Для gang delta передать patch, его exact preimage и candidate hashes; для C4
и vehicle — original source, bindings/default flags, native и GUI receipts.
Не смешивать старые snapshots с актуальными NPC R2. Не включать perf-кандидат
только на основании component PASS. Наличие 286 в описании ещё не доказывает
число фактически загруженных жителей.

Все labels должны сохранять исходный относительный layout под одним общим
anchor (в примере `C:/Users/Слава`). Нельзя уплощать `outputs/.../game` в `game`,
если вместе с ним переносятся внешние относительные зависимости. Корни на разных
дисках требуют отдельных архивов и явного плана адаптации; единый архив их отклонит.
Полноту зависимостей объявляет source owner. Инструмент не способен определить
динамические пути Godot и не переписывает абсолютные пути в коде/manifest.
Все зависимости вне game надо включить явно; после распаковки любые абсолютные
ссылки потребуют отдельной проверенной адаптации. Исторические receipts сохраняют
оригинальные пути и не становятся доказательством нового запуска.

## Упаковка и проверка

Нужен Python 3.12+; библиотек вне стандартной не требуется.

```powershell
python -B tools/godot/source_handoff.py collect --spec transfer.json --out D:/Mafiozy_QA_Work/current286-source.zip
python -B tools/godot/source_handoff.py verify D:/Mafiozy_QA_Work/current286-source.zip
```

Выходной ZIP должен быть новым и вне всех source roots. Секретные имена и
распознанные ключи останавливают упаковку; `.git`, `.godot`, caches и logs
исключаются. Это не универсальный сканер секретов: владелец проверяет список
перед публикацией. Бинарные runtime-assets сохраняются, включая `.scn`, `.res`,
`.glb`, исходные `.import`, `.uid` и JSON. Источники не меняются; повторный
inventory и SHA выявляют изменения во время чтения, но не заменяют согласованное
окно без записи. Нельзя считать такой обход атомарным снимком файловой системы.

Архив содержит `HANDOFF.json`, source identity, роль каждого корня, SHA256/размер
каждого payload-файла и список исключений. Отправитель передаёт SHA256 ZIP отдельно
от архива; получатель сравнивает его с `Get-FileHash` до `verify`. Сам manifest
не является подписью автора. `verify` не извлекает и не исполняет файлы.
Результат `TRANSPORT_VERIFIED` означает лишь целостность передачи.

После проверки извлечь в **новую изолированную папку**, сверить source pins с
пакетами авторов, пройти import и smoke через scheduler, затем actual286 functional
и парные performance-проверки. Интегратор переносит проверенные изменения в main
с проверкой свежего remote SHA. Не менять обычный launcher до приёмки единой сцены.

## Локальная проверка инструмента

```powershell
python -B -m unittest discover -s tools/godot -p test_source_handoff.py -v
```

Эти проверки касаются транспорта; они не запускают Godot и не принимают игру.

## Изолированный import/smoke полученного commit

`tools/godot/qa_isolated.py` принимает чистый checkout и точный 40-символьный
commit SHA, создаёт отдельный clone без hardlinks и запускает его через pinned
scheduler. Без `--run` выводится только план. Пример для проверки окружения
на старой release48 (это **не current286**):

```powershell
python -B tools/godot/qa_isolated.py --source C:/path/to/mafiozy --sha EXACT_COMMIT_SHA --project-subdir outputs/coordinator27_release48/game --godot C:/path/to/Godot_v4.7.2-stable_win64.exe --version 4.7.2.stable.official.ed1daf0bf --renderer forward_plus --out C:/path/to/new-qa-dir --run
```

После доставки current286 указать реальный проверенный `--project-subdir`,
сохранить population/default flags и выполнить игровую проверку отдельно.
`HEADLESS_SMOKE_PASS_ONLY` не проверяет GUI, функциональный цикл или FPS.
Исторические absolute paths в receipts — сведения об исходном ПК.
