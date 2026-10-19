# Astra 7 — exact received prefix

Collection date: 2026-09-26. Thread: `6ab2d09b-22ec-83ea-84a8-c75478bfb5bb`. AgentMessage: `fe4e9424-8ef3-4d1a-a435-20958d778911`. Turn: `72e5606b-e3a1-4583-a4df-d0b448d3d2fc`.
CompletedAt: 1790452480.5189 (2026-09-26T19:54:40.518Z); updatedAt: 1790452489.507473.
Received characters: 20000; server truncated: true.

**PARTIAL PACKAGE: 20000-character prefix only.** Statements below about complete files/bundles describe the author's full answer, not what read_thread delivered. Sandbox attachments not downloaded. Claimed PASS counts are not independently repeated. Godot/runtime/GPU/integration not run by collector; no production changed.

Closed file blocks extracted only: `outputs/astra21_a7_review/SOURCE_AND_CONTRACT.md`, `outputs/astra21_a7_review/save_schema_v2.json`, `outputs/astra21_a7_review/save_schema.gd`. Remaining schema/test/runtime blocks are unavailable or incomplete. Original claimed hashes and computed local hashes are distinct in review manifest. No final integration acceptance.

<!-- BEGIN EXACT RECEIVED PREFIX -->
## S00 SaveStore — полный пакет для local review

**TASK_ID:** `walk-godot-s00-savestore-3612fa6`  
**BASE_SHA:** `3612fa62f8d3bcb6888c7028ed0791fe0c928085`  
**Статус:** `PROPOSAL_FOR_LOCAL_REVIEW`, **не интегрирован**. Целевой выпуск Godot 4.7.2-stable подтверждён официальным архивом. :chatgpt-content-reference{index="0"}

**Выполнено:** чтение исходников, подготовка GDScript/schema/tests, проверка синтаксиса Python-harness, структурная проверка JSON Schema и расчёт SHA256. **GDScript parse/type/runtime, native-файловые тесты, перенос прогресса, серверная интеграция и GPU — NOT_RUN.** Локальный запуск harness завершился `GODOT_NOT_FOUND`, exit code `2`. Реальные saves, auth, local/session storage и DB не читались и не изменялись.

**Inventory — проверенный срез, не полный перечень всех legacy-сохранений.** Подтверждены preview-only сохранение наёмников и его `core.version=1`; незавершённые транзакции в этой схеме требуют reconciliation, а не повторного исполнения после загрузки.  Отдельные localStorage-ключи ограждений и питания находятся под `canUseLocalEffects()`.  Маркер готовности персонажа записывается после серверного подтверждения, а награды native-сейфов принадлежат серверной authority — локальный SaveStore их не восстанавливает. 

Предлагаемый протокол использует **два committed-слота и временный файл**, не перезаписывает активный слот, проверяет содержимое перед публикацией и требует явного подтверждения восстановления старой версии. `flush/close/rename` не выдаются за доказанную защиту от аппаратного отключения питания: этот предел отдельно зафиксирован в контракте. :chatgpt-content-reference{index="4"}

:chatgpt-content-reference{index="10"}[Дополнительная копия всего пакета](sandbox:/mnt/data/s00_savestore_3612fa6.zip). Ниже — **полный текст каждого файла**, включая schema, тесты и SHA256; архив для передачи не обязателен.

---

## 1. `SOURCE_AND_CONTRACT.md`

```markdown
# S00 / SaveStore / отдельный proposal

TASK_ID: walk-godot-s00-savestore-3612fa6
BASE_SHA: 3612fa62f8d3bcb6888c7028ed0791fe0c928085
TARGET: Godot 4.7.2-stable
OWNER: отдельный proposal под Художником21; root20 владеет actual project/exporter/player/S00+LIVE.
STATUS: PROPOSAL_FOR_LOCAL_REVIEW. Интеграция, native Godot, перенос прогресса: NOT_RUN.

## Source inventory: проверенный срез, НЕ полный перечень всех сохранений

Прочитан только код на BASE_SHA. Настоящие local/session storage, saves, auth и DB не открывались.

1. assets/maps/city_rebuild_v1/mercenary_world.js: local(), persist(), memberKey.
   localStorage: mafiozi.mercenaries.v1, JSON {core, rows}.
   rows: id/sourceBotId/name/look/r/c/hp/max_hp/weapon/faction/gangName/baseHp,
   lifeGeneration и подтверждение смерти, order/rally, условные QA-поля.
   Запись разрешена только local preview без serverAuthoritativeAmmo/customGang;
   restoreBlocked также запрещает запись. Это не серверная authority.
   memberKey снимает префиксы npc:/npc_crew_/crew_; при будущей миграции
   нельзя молча повторять нормализацию и сливать конфликтующие ID.

2. assets/maps/city_rebuild_v1/mercenary_core.mjs: snapshot(), restore().
   core.version=1: sequence, settledActionIds, pendingTransactions, charges, members.
   members включают progression/skills/weapon/status/hospital/queued/resumeWork.
   cooldowns экспортируются как остатки времени; hospitalUntil и bomb deadlines
   не являются тем же типом времени. Pending transactions требуют reconciliation.
   Повторное применение effects/rewards при миграции запрещено.
   Это ИСХОДНАЯ схема; она НЕ является v1 нашего S00-конвертера.

3. assets/maps/city_rebuild_v1/walk_preview.mjs:1494-1526.
   mafiozi.mercenary-fences.v1: JSON-массив cutIds.
   mafiozi.mercenary-yard-power.v1: строка off; отсутствие означает включено.
   Оба находятся под canUseLocalEffects(). Ни один ключ не импортируется.

4. creator.html:1300-1450 и test_creator_authoritative_save_dom.js.
   mafiozi_profile_creation_v1_<account>: idempotency token создания профиля;
   mafiozi_profile_creation_confirmed_v1_<account>: {token, character_id};
   mafiozi_character_ready_v1_<character>: строка 1 после подтверждения сервера.
   Авторитетен подтверждённый ответ profiles/<account> или character/<id>/look,
   а не localStorage-флаг. Tokens/receipts/auth context не переносятся в SaveStore.
   Чтение mafiozi_police_missions_<id>.employed подтверждает только UI-проверку,
   не полную схему или владельца полицейского прогресса.

5. Browser sessionStorage: точные ключи и полный serializer НЕ установлены.
   Reader world.html вернул пустое содержание, а пустой поиск не доказывает
   отсутствие sessionStorage. Это GAP; session migration/import: NOT_RUN.

6. _preview_ws_server.py:17-21: players/race_best/clients объявлены в памяти процесса.
   test_vehicle_session_reload_contract.py описывает owner_uid/driver_uid,
   driver reconnect и временную grace, не постоянный browser-save.
   Тест прочитан, НЕ запускался; он не доказывает production DB durability.

7. native_interior_safes.py:1-6, canonical_safe_id, SCHEMA.
   Серверные таблицы native_interior_safe_states:
   safe_id PK, building_id, room_id, opened_by, opened_at, reward, revision, request_id.
   native_interior_safe_rewards:
   safe_id PK/FK, character_id, amount, awarded_at, request_id.
   NativeSafeAuthority создаётся доверенным серверным адаптером; клиентские
   money/position/profession/registry не считаются authority. DB не открывалась.

8. test_custom_gang_persistence.py: объявленный тестовый legacy/DB-контракт,
   НЕ исполненный init_db: custom_gangs, custom_gang_members, treasury,
   custom_gang_npcs/custom_gang_audit, уникальность лидера/имени/HQ и hire receipt.
   Полный initializer/schema mafiozi_bot.py не проинвентаризирован.
   server.py — статический HTTP file server, не владелец игровых сохранений.

## Новый dev-only формат

save_schema_v2.json — форма payload; save_schema.gd — обязательная валидация
с уникальностью ID, конечностью чисел и migration guard.
Payload: authority=dev_only, settings.volume, entities[{id,kind,position_m,enabled}].
Допускается только kind=marker и ID dev:[a-z0-9_-]{1,64}; максимум 256 записей.
Никаких cash/HP/ownership/inventory/roster/credentials и произвольных объектов.

Envelope — JSON-массив ровно пяти строк:
["WALK_SAVE_DEV_S00", "2", "generation", "canonical_payload_json", "sha256"]
SHA256 считается от JSON первых четырёх строк. Он защищает также generation
и schema version от случайного повреждения, но НЕ аутентифицирует игрока.
Generation: 1..2147483647, десятичная строка без ведущих нулей.
Канонизация: JSON.stringify(value, "", true, true) целевым Godot.
Повторная сериализация должна совпасть; duplicate JSON keys не принимаются.
Размер файла <=262144 байт, глубина JSON <=8, coordinates в метрах +/-100000.

## Atomic commit / recovery

Только user://dev/s00_savestore_3612fa6/<lowercase_namespace>/.
open_dev(enabled=false) выключен по умолчанию; требуется debug engine.
Main-thread API; одна in-process lease; cooperative writer.lock между процессами.
Все пути фиксированы, links отвергаются; это не sandbox против враждебных OS-races.

1. Валидировать новый DTO; захватить writer.lock через создание каталога.
2. Прочитать committed slot_a.json/slot_b.json; сверить expected_head.
3. Записать pending.tmp, flush/close, проверить полное чтение и checksum/schema.
4. Удалить только НЕАКТИВНЫЙ слот; rename temp в этот слот — commit point.
5. Проверить опубликованный слот; отпустить lock. Активный прежний слот не трогать.

load_dev не пишет/не удаляет и никогда не повышает pending.tmp до committed.
Выбирается старшая валидная generation. При повреждённом втором слоте возвращается
recovered=true; новая запись требует accept_recovery=true. Это явный rollback.
Оба слота повреждены: NO_VALID_SNAPSHOT, не автоматический новый пустой мир.
Новый schema version: FUTURE_SCHEMA, без fallback/overwrite.
Равная generation с разными head: SPLIT_BRAIN. Ошибка чтения: IO, fail closed.
После commit point потеря подтверждения: COMMIT_UNCERTAIN; сначала load_dev,
не воспроизводить игровые эффекты. commit вообще не вызывает эффекты.
Stale writer.lock не снимается автоматически: чтение возможно, запись блокируется
до отдельной проверки завершения владельца. dispose не удаляет saves/lock.

Схема гарантирует old-or-complete-new при кооперативной записи и корректном
same-filesystem rename. fsync родительского каталога, аппаратный power loss,
network filesystems и Web IDBFS НЕ доказаны: NOT_RUN. Это не production durability.
Операции синхронны и ограничены по размеру; вызовы из покадрового update не планируются.

## Миграция

Только искусственный S00 v1: position -> position_m при неизменных ID и единицах.
Проверки до и после миграции, исходный файл не переписывается при чтении.
Настоящие mercenary_core.version=1, браузерные данные и серверная БД сюда НЕ подходят.
Перенос пользовательского прогресса и применение DTO к сцене: NOT_RUN.

## Проверка и границы передачи

run_review.py создаёт временный headless harness, не проект root20; требуются
локальный Godot 4.7.2-stable и явный запуск координатора. Нет network/GPU действий.
Тесты создают только fabricated marker saves в уникальных qa_* пространствах.
Проверяются old/new commit boundaries, lost acknowledgement, corruption,
migration/duplicate IDs, future schema, stale head/lock, namespace, limits,
main-thread guard и dispose/reopen. Убийство процесса/power-loss тесты: NOT_RUN.

Здесь: Python harness syntax checked; отсутствие Godot даёт NOT_RUN и exit 2.
GDScript parse/type/runtime и файловые native-тесты: NOT_RUN.
Root20 reviews -> отдельный native headless gate -> отдельно разрешённая интеграция.
S00 проекта целиком, экспорт, player, LIVE и следующие stages этим proposal не закрыты.
```

Сессионный reconnect здесь намеренно отделён от постоянного сохранения: соответствующий исходный тест описывает восстановление серверного состояния автомобиля, а не универсальный формат browser-save.  Перечень таблиц custom gang взят из **исходника теста**, не из открытой БД или выполненного `init_db`. 

---

## 2. `save_schema_v2.json`

JSON Schema описывает payload. **Проверка уникальности `entity.id` и конечности чисел дополнительно обязательна в `save_schema.gd`.**

```json
{
  "$schema": "https://json-schema.org/draft/2020-12/schema",
  "$id": "urn:mafiozi:s00:dev-save:2",
  "$comment": "Synthetic S00 DTO only. save_schema.gd additionally enforces finite numbers and global uniqueness of entity.id. No browser/server import.",
  "type": "object",
  "additionalProperties": false,
  "required": ["authority", "settings", "entities"],
  "properties": {
    "authority": {"const": "dev_only"},
    "settings": {
      "type": "object", "additionalProperties": false,
      "required": ["volume"],
      "properties": {"volume": {"type": "number", "minimum": 0, "maximum": 1}}
    },
    "entities": {
      "type": "array", "maxItems": 256,
      "items": {
        "type": "object", "additionalProperties": false,
        "required": ["id", "kind", "position_m", "enabled"],
        "properties": {
          "id": {"type": "string", "pattern": "^dev:[a-z0-9_-]{1,64}(?![\\s\\S])"},
          "kind": {"const": "marker"},
          "position_m": {
            "type": "array", "minItems": 3, "maxItems": 3,
            "items": {"type": "number", "minimum": -100000, "maximum": 100000}
          },
          "enabled": {"type": "boolean"}
        }
      }
    }
  }
}
```

## 3. `save_schema.gd`

```gdscript
extends RefCounted
# S00 synthetic dev DTO. This is NOT a browser/server save migration.
const VERSION = 2
const MAX_ENTITIES = 256
const MAX_POSITION = 100000.0

static func fail(code: String) -> Dictionary:
	return {"ok": false, "code": code}

static func exact_keys(value: Variant, keys: Array) -> bool:
	if typeof(value) != TYPE_DICTIONARY or value.size() != keys.size():
		return false
	for key in keys:
		if not value.has(key):
			return false
	return true

static func number(value: Variant) -> bool:
	return typeof(value) in [TYPE_INT, TYPE_FLOAT] and is_finite(float(value))

static func ascii_id(value: Variant, prefix: String, limit: int) -> bool:
	if typeof(value) != TYPE_STRING or not value.begins_with(prefix):
		return false
	var tail: String = value.substr(prefix.length())
	if tail.is_empty() or tail.length() > limit:
		return false
	for c in tail:
		if not "abcdefghijklmnopqrstuvwxyz0123456789_-".contains(c):
			return false
	return true

static func empty() -> Dictionary:
	return {"authority": "dev_only", "settings": {"volume": 1.0}, "entities": []}

static func validate(value: Variant, version: int = VERSION) -> Dictionary:
	if version not in [1, VERSION]:
		return fail("UNSUPPORTED_SCHEMA")
	if not exact_keys(value, ["authority", "settings", "entities"]):
		return fail("ROOT_FIELDS")
	if value.authority != "dev_only":
		return fail("AUTHORITY")
	if not exact_keys(value.settings, ["volume"]):
		return fail("SETTINGS_FIELDS")
	var volume = value.settings.volume
	if not number(volume) or volume < 0.0 or volume > 1.0:
		return fail("VOLUME")
	if typeof(value.entities) != TYPE_ARRAY or value.entities.size() > MAX_ENTITIES:
		return fail("ENTITY_LIMIT")
	var position_key = "position" if version == 1 else "position_m"
	var ids: Dictionary = {}
	var rows: Array = []
	for row in value.entities:
		if not exact_keys(row, ["id", "kind", position_key, "enabled"]):
			return fail("ENTITY_FIELDS")
		if not ascii_id(row.id, "dev:", 64):
			return fail("ID")
		if ids.has(row.id):
			return fail("DUPLICATE_ID")
		ids[row.id] = true
		if row.kind != "marker" or typeof(row.enabled) != TYPE_BOOL:
			return fail("ENTITY_TYPE")
		var point = row[position_key]
		if typeof(point) != TYPE_ARRAY or point.size() != 3:
			return fail("POSITION")
		var xyz: Array = []
		for axis in point:
			if not number(axis) or abs(float(axis)) > MAX_POSITION:
				return fail("POSITION")
			xyz.append(float(axis))
		var copy = {"id": row.id, "kind": "marker", "enabled": row.enabled}
		copy[position_key] = xyz
		rows.append(copy)
	return {"ok": true, "code": "VALID", "data": {
		"authority": "dev_only", "settings": {"volume": float(volume)}, "entities": rows}}

static func migrate(value: Variant, version: int) -> Dictionary:
	var checked = validate(value, version)
	if not checked.ok:
		return checked
	var data: Dictionary = checked.data
	if version == 1:
		for row in data.entities:
			row["position_m"] = row.position
			row.erase("position")
	# Duplicate/shape checks run again AFTER migration. No ID normalization.
	var result = validate(data, VERSION)
	result["migrated"] = version != VERSION
	return result
```

---

## 4. `save_store.gd`

```gdscript
extends RefCounted
# Proposal only. No autoload, world callbacks, auth, HTTP or legacy save paths.
const Schema = preload("./save_schema.gd")
const ROOT = "user://dev/s00_savestore_3612fa6"
const MAGIC = "WALK_SAVE_DEV_S00"
const MAX_BYTES = 262144
const MAX_GENERATION = 2147483647
const FILES = ["slot_a.json", "slot_b.json", "pending.tmp"]
const FAULTS = ["", "half_temp", "after_temp", "after_remove", "after_commit"]
static var _owners: Dictionary = {}
var _space = ""
var _closed = true
var _busy = false

func _error(code: String) -> Dictionary:
	return Schema.fail(code)

func _path(name: String) -> String:
	return ROOT.path_join(_space).path_join(name)

func _guard() -> String:
	if not Thread.is_main_thread():
		return "MAIN_THREAD_REQUIRED"
	if _closed:
		return "CLOSED"
	return "BUSY" if _busy else ""

func _directory(create: bool) -> String:
	# No enumeration and no following links outside the dedicated namespace.
	var dir = DirAccess.open("user://")
	if dir == null:
		return "DIRECTORY_IO"
	for component in ["dev", "s00_savestore_3612fa6", _space]:
		if dir.is_link(component):
			return "UNSAFE_PATH"
		if not dir.dir_exists(component):
			if not create or dir.make_dir(component) != OK:
				return "DIRECTORY_IO"
		if dir.change_dir(component) != OK:
			return "DIRECTORY_IO"
	for name in FILES + ["writer.lock"]:
		if dir.is_link(name):
			return "UNSAFE_PATH"
		if name in FILES and dir.dir_exists(name):
			return "UNSAFE_PATH"
	return ""

func open_dev(space: String, enabled: bool = false) -> Dictionary:
	if not Thread.is_main_thread():
		return _error("MAIN_THREAD_REQUIRED")
	if not _closed:
		return _error("ALREADY_OPEN")
	if not enabled or not OS.is_debug_build():
		return _error("DEV_DISABLED")
	if not Schema.ascii_id(space, "", 48):
		return _error("NAMESPACE")
	if _owners.has(space) and _owners[space].get_ref() != null:
		return _error("OWNER_EXISTS")
	_space = space
	var problem = _directory(true)
	if not problem.is_empty():
		return _error(problem)
	_owners[space] = weakref(self)
	_closed = false
	return {"ok": true, "code": "OPEN"}

func dispose() -> Dictionary:
	if not Thread.is_main_thread() or _busy:
		return _error("BUSY_OR_THREAD")
	if not _closed and _owners.has(_space) and _owners[_space].get_ref() == self:
		_owners.erase(_space)
	_closed = true
	# Never deletes snapshots, pending data or a lock left by a crashed process.
	return {"ok": true, "code": "CLOSED"}

static func _json(value: Variant) -> String:
	return JSON.stringify(value, "", true, true)

static func _positive_integer(text: String) -> bool:
	return text.length() <= 10 and text.is_valid_int() and int(text) > 0 \
		and int(text) <= MAX_GENERATION and str(int(text)) == text

static func _bounded_json(text: String) -> bool:
	var depth = 0
	var quoted = false
	var escaped = false
	for c in text:
		if quoted:
			if escaped:
				escaped = false
			elif c == "\\":
				escaped = true
			elif c == "\"":
				quoted = false
		elif c == "\"":
			quoted = true
		elif c in ["[", "{"]:
			depth += 1
			if depth > 8:
				return false
		elif c in ["]", "}"]:
			depth -= 1
			if depth < 0:
				return false
	return depth == 0 and not quoted

func _read(name: String) -> Dictionary:
	var path = _path(name)
	if not FileAccess.file_exists(path):
		return _error("MISSING")
	var file = FileAccess.open(path, FileAccess.READ)
	if file == null:
		return _error("IO")
	var size = file.get_length()
	if size <= 0 or size > MAX_BYTES:
		file.close()
		return _error("CORRUPT")
	var bytes = file.get_buffer(size)
	var io_error = file.get_error()
	file.close()
	if bytes.size() != size or io_error not in [OK, ERR_FILE_EOF]:
		return _error("IO")
	var text = bytes.get_string_from_utf8()
	if text.to_utf8_buffer() != bytes or not _bounded_json(text):
		return _error("CORRUPT")
	var parser = JSON.new()
	if parser.parse(text) != OK:
		return _error("CORRUPT")
	var frame = parser.data
	if typeof(frame) != TYPE_ARRAY or frame.size() != 5:
		return _error("CORRUPT")
	for field in frame:
		if typeof(field) != TYPE_STRING:
			return _error("CORRUPT")
	if _json(frame) != text or frame[0] != MAGIC:
		return _error("CORRUPT")
	if not _positive_integer(frame[1]) or not _positive_integer(frame[2]):
		return _error("CORRUPT")
	var digest = _json(frame.slice(0, 4)).sha256_text()
	if frame[4] != digest:
		return _error("CORRUPT")
	var version = int(frame[1])
	if version > Schema.VERSION:
		return _error("FUTURE_SCHEMA")
	if not _bounded_json(frame[3]):
		return _error("CORRUPT")
	if parser.parse(frame[3]) != OK or _json(parser.data) != frame[3]:
		return _error("CORRUPT")
	var migrated = Schema.migrate(parser.data, version)
	if not migrated.ok:
		return _error("CORRUPT")
	return {"ok": true, "code": "LOADED", "data": migrated.data,
		"generation": int(frame[2]), "head": digest, "migrated": migrated.migrated}

func _scan() -> Dictionary:
	var valid: Array = []
	var bad: Array = []
	for index in range(2):
		var row = _read(FILES[index])
		# Do not silently fall back across an unreadable or newer-format slot.
		if row.code in ["IO", "FUTURE_SCHEMA"]:
			return row
		if row.ok:
			row["slot"] = index
			valid.append(row)
		elif row.code != "MISSING":
			bad.append(FILES[index])
	if valid.is_empty():
		if not bad.is_empty():
			return _error("NO_VALID_SNAPSHOT")
		return {"ok": true, "code": "EMPTY", "data": Schema.empty(),
			"generation": 0, "head": "empty", "slot
<!-- END EXACT RECEIVED PREFIX -->

