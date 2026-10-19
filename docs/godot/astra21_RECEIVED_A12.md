# Астра 12 — exact received prefix

Collection date: 2026-09-26. Thread: `6ab3155c-b0f0-83e9-965e-4c8033b0e66e`. AgentMessage: `1f6c1068-8529-4bcb-85fd-cfbd39a97044`. Turn: `f2aea023-99e8-4305-84a3-1699b20199d7`.
CompletedAt: 1790452096.515477 (2026-09-26T19:48:16.515Z); updatedAt: 1790452099.153678.
Received characters: 20000; server truncated: true.

**PARTIAL PACKAGE: 20000-character prefix only.** Statements below about complete files/bundles describe the author's full answer, not what read_thread delivered. Sandbox attachments not downloaded. Claimed PASS counts are not independently repeated. Godot/runtime/GPU/integration not run by collector; no production changed.

Closed file blocks extracted only: `outputs/astra21_a12_review/chunk_lifecycle.gd`, `outputs/astra21_a12_review/chunk_lifecycle.mjs`. Remaining schema/test/runtime blocks are unavailable or incomplete. Original claimed hashes and computed local hashes are distinct in review manifest. No final integration acceptance.

<!-- BEGIN EXACT RECEIVED PREFIX -->
# Художнику21 — S00 / ChunkLifecycle: пакет для приёмки

**TASK_ID:** `ASTRA12-S00-STREAMING-20260926`  
**Статус:** `READY_FOR_ARTIST21_REVIEW` · **Интеграция: `NOT_READY`**  
**Подтверждённая база:** `3612fa62f8d3bcb6888c7028ed0791fe0c928085`. Shared worktree и dirty service WIP не читались; их совпадение с этой базой не утверждаю. Production, main, Git, server и saves не менял. 

:chatgpt-content-reference{index="7"}[Архив пакета](sandbox:/mnt/data/ASTRA12_S00_ChunkLifecycle_3612fa6.zip). Ниже приведены **полные тексты всех файлов кода, JSON, тестов и SHA256**.

**Выполнено:** JS-reference — **9/9 групп PASS**, 14 общих протокольных сценариев, 100 unload/reload-циклов, два одинаковых прогона по 10 000 adversarial-событий, **146 834 проверки, подсчитанные стендом**. Повторный запуск из пустой временной папки также прошёл.

**Не выполнено:** Godot runtime, реальная регистрация/удаление коллизий, физические NOT_READY-барьеры и настоящий durable save-backend — **`NOT_RUN`**. GDScript-кандидат подготовлен, но его исполняемое соответствие JS-reference ещё не подтверждено. Целевая версия **Godot 4.7.2-stable** подтверждается официальным выпуском от **18 августа 2026 года**. :chatgpt-content-reference{index="1"}

## Что именно предлагается

Это **жизненный цикл одного chunk**, а не root streamer, менеджер города или новая система сохранений.

```text
ABSENT → LOADING → STAGING → READY
READY → QUIESCING → SAVING → DRAINING → ABSENT

LOADING / STAGING → DRAINING                    отмена/смена revision
LOADING / STAGING → DRAINING → FAILED           ошибка загрузки
SAVING → SAVE_FAILED → SAVING                   явный retry
SAVE_FAILED → DRAINING                         поздний подтверждённый ACK
DRAINING → LOADING                             отложенный последний запрос
```

**Поколение запроса:** полный token `epoch/chunk/generation/asset_revision`. Старый ACK не может активировать, выгрузить или снять pin у нового поколения. Новая загрузка не начинается, пока предыдущий запрос не завершён и его ресурсы не освобождены. Быстрые изменения направления/желания загрузки схлопываются в **один последний target**.

**Готовность:** `loaded` означает только наличие ресурса. Для `READY` нужны отдельные подтверждения collision/navigation/bindings/hydration и более поздний проверенный physics fence. Пустой или неполный набор проверяемых chunks возвращает **`NOT_READY`**, не «коллизий нет».

**Выгрузка:** сначала закрытие входа и подтверждение quiescence, затем checkpoint конкретной версии, затем совпадающий atomic/durable ACK, и только после этого освобождение представления. Ошибка сохранения **удерживает представление**, а не удаляет его.

**Важный случай выхода:** chunk, ожидающий выгрузки, не должен лишать уже находящегося в нём игрока опоры. Поэтому существующий **собственный occupancy pin** допускает завершение выхода по сохранённой геометрии; новым объектам вход остаётся закрыт. Чужой или устаревший pin не даёт такого разрешения.

## Сверка с исходниками и обязательные seams root

В текущем `world_walk_health.mjs` существующий world прямо сохраняет владение HP/lifecycle; замена визуального actor не должна повторять старое событие смерти. Это соответствует выбранному разделению: **ChunkLifecycle не владеет здоровьем и не восстанавливает его из сценических defaults**. 

В `vehicle_fleet.mjs::addCar` повторный ID может получить суффикс, а `state.seats` берётся из описания машины. Поэтому повторная загрузка chunk **не должна превращаться в повторный spawn через addCar**, а описание мест нельзя принимать за полный журнал фактических пассажиров. 

`npc_vehicle_access.mjs` откладывает доступ при отсутствии подходящего actor/seat, а `npc_logical_vehicle_binding.mjs` отдельно поддерживает логические source-proxy без добавления в сцену. Отсутствие видимой модели не является разрешением удалить логическую машину или освободить её места. 

| Seam root | Что должно быть подтверждено до подключения |
|---|---|
| Exporter / manifest | Stable chunk ID, asset revision и source SHA. Dirty WIP не маркируется как `3612fa62…`. |
| Loader adapter | Идемпотентность по `command.key`; один фактический запрос; завершение старого I/O перед новым поколением. Поздний результат освобождается по своему ticket, не по текущему chunk ID. |
| Physics / movement | Полное swept/support coverage. `NOT_READY` останавливает допуск, но не создаёт урон от «удара о стену». Барьеры принадлежат root, а не выгружаемой сцене. |
| Occupancy pins | Lease привязан к конкретному владельцу и поколению. Сохраняется до выхода тела/машины и связанных пассажиров из области опоры. Физический барьер нельзя вставлять через удерживаемое тело. |
| Authority registry | ID, раны, деньги, death/tombstones и фактические seats существуют независимо от Node. При reload читается актуальная authority revision, а не старый scene snapshot. |
| Persistence | Freeze lease покрывает весь связанный набор «машина—пассажиры—места». ACK подтверждает **тот же** cut/hash/bytes/lease. Неизвестный исход записи проверяется по прежнему transaction key. |
| Disposal | Удаляется только представление и его ссылки. `drained` принимается после нового проверенного physics fence; logical records не удаляются. |
| Godot acceptance | Запуск GDScript-тестов, реальные barrier/physics probes и проверка адаптера настоящих saves. Эти gates пока открытыми не считаются. |

У Godot `load_threaded_get()` может заблокировать вызывающий поток, если загрузка ещё не завершилась; поэтому adapter должен сначала проверить статус. Работа с активным SceneTree также требует main-thread дисциплины. В кандидате нет вызовов загрузчика, вмешательства в SceneTree или вымышленного физического cancel фоновой загрузки. :chatgpt-content-reference{index="5"}

**Лимиты:** один outstanding load, один pending target, один checkpoint, максимум 64 pin-lease и 1 048 576 байт checkpoint payload. Lifecycle хранит только descriptor, не весь payload. Общий бюджет chunks/resources задаёт root. **Zero-allocation и стоимость Godot-сцены не заявлены.** При зависшем drain или неразрешённой ошибке persistence действует fail-closed, а не принудительное освобождение.

**Реальная схема денег/ран/seats в dirty WIP не установлена.** `authority_fixture` ниже — специально обозначенный тестовый формат, не готовый mapper настоящих saves.

## Запуск

Все файлы положить рядом в **отдельной review-папке**, не в production:

```bash
node test_chunk_lifecycle.mjs
```

Подготовленная команда Godot-приёмки, **здесь не запускалась**:

```bash
godot --headless --path . --script test_chunk_lifecycle.gd
```

---

## 1. `chunk_lifecycle.gd`

```gdscript
class_name S00ChunkLifecycle
extends RefCounted
# S00 only. No Node, ResourceLoader, FileAccess, save owner or world streamer.
const SOURCE = "3612fa62f8d3bcb6888c7028ed0791fe0c928085"
const MAX_INT = 2147483647
const MAX_BYTES = 1048576
const MAX_PINS = 64
var _s: Dictionary = {}
var _pins: Dictionary = {}
var _atom_re = RegEx.create_from_string("[^A-Za-z0-9_.:-]")
var _hash_re = RegEx.create_from_string("[^a-f0-9]")

func _atom(value: Variant) -> bool:
	return value is String and value.length() >= 1 and value.length() <= 96 \
		and _atom_re.search(value) == null

func _uint(value: Variant) -> bool:
	return (typeof(value) == TYPE_INT or typeof(value) == TYPE_FLOAT) \
		and is_finite(float(value)) and value >= 0 and value <= MAX_INT \
		and floor(float(value)) == float(value)

func _yes(value: Variant) -> bool:
	return typeof(value) == TYPE_BOOL and value

func configure(epoch: Variant, chunk: Variant, revision: Variant = 0) -> bool:
	if not _s.is_empty() or not _atom(epoch) or not _atom(chunk) or not _uint(revision):
		return false
	_s = {"epoch":epoch,"chunk":chunk,"phase":"ABSENT","target":"","asset":"",
		"gen":0,"token":"","fence":0,"seen":int(revision),"durable":int(revision),
		"cut":0,"digest":"","bytes":0,"lease":"","failed":false}
	return true

func ready() -> bool:
	return not _s.is_empty() and _s.phase == "READY" and _s.target == _s.asset

func retained(id: Variant, token: Variant) -> bool:
	return not _s.is_empty() and _s.phase == "READY" \
		and token == _s.token and _pins.has(id)

func inspect() -> Dictionary:
	var result = _s.duplicate(true)
	var pins = _pins.keys()
	pins.sort()
	result["pins"] = pins
	return result

func command() -> Variant:
	var kinds = {"LOADING":"LOAD","STAGING":"STAGE_VERIFY",
		"QUIESCING":"CLOSE_CAPTURE","SAVING":"PERSIST","DRAINING":"DRAIN"}
	if _s.is_empty() or not kinds.has(_s.phase):
		return null
	var kind = kinds[_s.phase]
	return {"kind":kind,"key":_s.token+"/"+kind,"token":_s.token,"chunk":_s.chunk,
		"asset":_s.asset,"source":SOURCE,"minimumRevision":max(_s.seen,_s.durable),
		"cut":_s.cut,"digest":_s.digest,"bytes":_s.bytes,"lease":_s.lease}

func _begin() -> void:
	if _s.target == "":
		return
	if _s.gen == MAX_INT:
		_s.phase = "EXHAUSTED"
		return
	_s.gen += 1
	_s.asset = _s.target
	_s.token = _s.epoch+"/"+_s.chunk+"/"+str(_s.gen)+"/"+_s.asset
	_s.phase = "LOADING"
	_s.failed = false
	_s.cut = 0
	_s.digest = ""
	_s.bytes = 0
	_s.lease = ""

func _reconcile() -> void:
	if _s.phase == "ABSENT":
		_begin()
	elif _s.target != _s.asset:
		if _s.phase in ["LOADING","STAGING"]:
			_s.phase = "DRAINING"
		elif _s.phase == "READY" and _pins.is_empty():
			_s.phase = "QUIESCING"
		elif _s.phase == "FAILED":
			_s.phase = "ABSENT"
			_begin()

func send(e: Dictionary) -> bool:
	if _s.is_empty():
		return false
	var op = e.get("op", "")
	if op == "want":
		var asset = e.get("asset")
		if asset != "" and not _atom(asset):
			return false
		_s.target = asset
		_reconcile()
		return true
	if op == "pin":
		var id = e.get("id")
		if e.get("token") != _s.token or not _atom(id) or not ready():
			return false
		if not _pins.has(id) and _pins.size() == MAX_PINS:
			return false
		_pins[id] = true
		return true
	if op == "unpin":
		if e.get("token") != _s.token or not _pins.has(e.get("id")):
			return false
		_pins.erase(e.id)
		_reconcile()
		return true
	if op == "retry":
		if _s.token == "" or e.get("token") != _s.token:
			return false
		if _s.phase == "SAVE_FAILED":
			_s.phase = "SAVING"
			return true
		if _s.phase == "FAILED":
			_s.phase = "ABSENT"
			_begin()
			return true
		return false
	if _s.token == "" or e.get("token") != _s.token:
		return false
	if op == "loaded" and _s.phase == "LOADING":
		if e.get("source") != SOURCE or e.get("asset") != _s.asset:
			return false
		_s.phase = "STAGING"
		return true
	if op == "load_failed" and _s.phase in ["LOADING","STAGING"]:
		_s.failed = true
		_s.phase = "DRAINING"
		return true
	if op == "activated" and _s.phase == "STAGING":
		if not _uint(e.get("fence")) or e.fence <= _s.fence \
			or not _uint(e.get("revision")) or e.revision < max(_s.seen,_s.durable) \
			or not _yes(e.get("collision")) or not _yes(e.get("navigation")) \
			or not _yes(e.get("bindings")) or not _yes(e.get("hydrated")) \
			or not _yes(e.get("barrierReleased")):
			return false
		_s.fence = int(e.fence)
		_s.seen = int(e.revision)
		_s.phase = "READY"
		return true
	if op == "captured" and _s.phase == "QUIESCING":
		if not _yes(e.get("barrierClosed")) or not _yes(e.get("quiescent")) \
			or not _yes(e.get("closureVerified")) \
			or not _uint(e.get("fence")) or e.fence <= _s.fence \
			or not _uint(e.get("cut")) or e.cut < max(_s.seen,_s.durable) \
			or not (e.get("digest") is String) or e.digest.length() != 64 \
			or _hash_re.search(e.digest) != null \
			or not _uint(e.get("bytes")) or e.bytes < 1 or e.bytes > MAX_BYTES \
			or not _atom(e.get("lease")):
			return false
		_s.fence = int(e.fence)
		_s.cut = int(e.cut)
		_s.digest = e.digest
		_s.bytes = int(e.bytes)
		_s.lease = e.lease
		_s.phase = "SAVING"
		return true
	if op == "save_failed" and _s.phase == "SAVING":
		_s.phase = "SAVE_FAILED"
		return true
	if op == "persisted" and _s.phase in ["SAVING","SAVE_FAILED"]:
		if not _uint(e.get("cut")) or not _uint(e.get("bytes")) \
			or not _yes(e.get("atomic")) or not _yes(e.get("durable")) \
			or e.get("cut") != _s.cut or e.get("digest") != _s.digest \
			or e.get("bytes") != _s.bytes or e.get("lease") != _s.lease:
			return false
		_s.durable = _s.cut
		_s.seen = _s.cut
		_s.phase = "DRAINING"
		return true
	if op == "drained" and _s.phase == "DRAINING":
		if not _yes(e.get("ioSettled")) or not _yes(e.get("viewsReleased")) \
			or not _yes(e.get("barrierClosed")) or not _uint(e.get("fence")) \
			or e.fence <= _s.fence:
			return false
		_s.fence = int(e.fence)
		_s.phase = "FAILED" if _s.failed and _s.target == _s.asset else "ABSENT"
		if _s.phase == "ABSENT":
			_begin()
		return true
	return false

static func coverage(complete: Variant, chunks: Variant, held: Variant = []) -> String:
	if typeof(complete) != TYPE_BOOL or not complete or not (chunks is Array) \
		or chunks.is_empty() or not (held is Array):
		return "NOT_READY"
	for i in range(chunks.size()):
		var chunk = chunks[i]
		var pin = held[i] if i < held.size() else null
		if not (chunk is S00ChunkLifecycle):
			return "NOT_READY"
		if not chunk.ready() and not (pin is Dictionary \
			and chunk.retained(pin.get("id"),pin.get("token"))):
			return "NOT_READY"
	return "READY"
```

## 2. `chunk_lifecycle.mjs`

Исполняемый CPU-reference того же протокола. В игру одновременно с GDScript не подключается.

```javascript
// S00 proposal only. No I/O, nodes, saves, timers, root streamer or game state.
export const SOURCE = '3612fa62f8d3bcb6888c7028ed0791fe0c928085';
export const LIMIT = Object.freeze({pins:64, bytes:1048576, integer:2147483647});
const atom = x => typeof x === 'string' && x.length>=1 && x.length<=96 && !/[^A-Za-z0-9_.:-]/.test(x);
const uint = x => Number.isInteger(x) && x >= 0 && x <= LIMIT.integer;
const hash = x => typeof x === 'string' && x.length===64 && !/[^a-f0-9]/.test(x);
const yes = x => x === true;

export class ChunkLifecycle {
  #s; #pins = new Set();
  constructor(epoch, chunk, durableRevision = 0) {
    if (!atom(epoch) || !atom(chunk) || !uint(durableRevision))
      throw Error('Invalid lifecycle identity/revision');
    this.#s = {epoch,chunk,phase:'ABSENT',target:'',asset:'',gen:0,token:'',
      fence:0,seen:durableRevision,durable:durableRevision,
      cut:0,digest:'',bytes:0,lease:'',failed:false};
  }
  ready() { const s=this.#s; return s.phase==='READY' && s.target===s.asset; }
  retained(id, token) {
    return this.#s.phase==='READY' && token===this.#s.token && this.#pins.has(id);
  }
  inspect() { return {...this.#s,pins:[...this.#pins].sort()}; }
  command() {
    const s=this.#s;
    const kinds={LOADING:'LOAD',STAGING:'STAGE_VERIFY',QUIESCING:'CLOSE_CAPTURE',
      SAVING:'PERSIST',DRAINING:'DRAIN'};
    const kind=kinds[s.phase];
    if (!kind) return null;
    return {kind,key:s.token+'/'+kind,token:s.token,chunk:s.chunk,asset:s.asset,
      source:SOURCE,minimumRevision:Math.max(s.seen,s.durable),
      cut:s.cut,digest:s.digest,bytes:s.bytes,lease:s.lease};
  }
  #begin() {
    const s=this.#s;
    if (!s.target) return;
    if (s.gen===LIMIT.integer) { s.phase='EXHAUSTED'; return; }
    s.gen++; s.asset=s.target;
    s.token=s.epoch+'/'+s.chunk+'/'+s.gen+'/'+s.asset;
    s.phase='LOADING'; s.failed=false;
    s.cut=0; s.digest=''; s.bytes=0; s.lease='';
  }
  #reconcile() {
    const s=this.#s;
    if (s.phase==='ABSENT') this.#begin();
    else if (s.target!==s.asset) {
      if (s.phase==='LOADING' || s.phase==='STAGING') s.phase='DRAINING';
      else if (s.phase==='READY' && this.#pins.size===0) s.phase='QUIESCING';
      else if (s.phase==='FAILED') {s.phase='ABSENT'; this.#begin();}
    }
  }
  send(e) {
    if (!e || typeof e!=='object') return false;
    const s=this.#s, op=e.op;
    if (op==='want') {
      if (e.asset!=='' && !atom(e.asset)) return false;
      s.target=e.asset; this.#reconcile(); return true;
    }
    if (op==='pin') {
      if (e.token!==s.token || !atom(e.id) || !this.ready()) return false;
      if (!this.#pins.has(e.id) && this.#pins.size===LIMIT.pins) return false;
      this.#pins.add(e.id); return true;
    }
    if (op==='unpin') {
      if (e.token!==s.token || !this.#pins.delete(e.id)) return false;
      this.#reconcile(); return true;
    }
    if (op==='retry') {
      if (!s.token || e.token!==s.token) return false;
      if (s.phase==='SAVE_FAILED') {s.phase='SAVING'; return true;}
      if (s.phase==='FAILED') {s.phase='ABSENT'; this.#begin(); return true;}
      return false;
    }
    // Every asynchronous acknowledgement is fenced by the full token.
    if (!s.token || e.token!==s.token) return false;
    if (op==='loaded' && s.phase==='LOADING') {
      if (e.source!==SOURCE || e.asset!==s.asset) return false;
      s.phase='STAGING'; return true;
    }
    if (op==='load_failed' && ['LOADING','STAGING'].includes(s.phase)) {
      s.failed=true; s.phase='DRAINING'; return true;
    }
    if (op==='activated' && s.phase==='STAGING') {
      if (!uint(e.fence) || e.fence<=s.fence || !uint(e.revision) ||
          e.revision<Math.max(s.seen,s.durable) ||
          !yes(e.collision) || !yes(e.navigation) || !yes(e.bindings) ||
          !yes(e.hydrated) || !yes(e.barrierReleased)) return false;
      s.fence=e.fence; s.seen=e.revision; s.phase='READY';
      return true;
    }
    if (op==='captured' && s.phase==='QUIESCING') {
      if (!yes(e.barrierClosed) || !yes(e.quiescent) || !yes(e.closureVerified) ||
          !uint(e.fence) || e.fence<=s.fence || !uint(e.cut) ||
          e.cut<Math.max(s.seen,s.durable) || !hash(e.digest) ||
          !uint(e.bytes) || e.bytes<1 || e.bytes>LIMIT.bytes || !atom(e.lease))
        return false;
      s.fence=e.fence; s.cut=e.cut; s.digest=e.digest;
      s.bytes=e.bytes; s.lease=e.lease; s.phase='SAVING'; return true;
    }
    if (op==='save_failed' && s.phase==='SAVING') {
      s.phase='SAVE_FAILED'; return true;
    }
    if (op==='persisted' && ['SAVING','SAVE_FAILED'].includes(s.phase)) {
      if (!uint(e.cut) || !uint(e.bytes) || !yes(e.atomic) || !yes(e.durable) || e.cut!==s.cut ||
          e.digest!==s.digest || e.bytes!==s.bytes || e.lease!==s.lease)
        return false;
      s.durable=s.cut; s.seen=s.cut; s.phase='DRAINING'; return true;
    }
    if (op==='drained' && s.phase==='DRAINING') {
      if (!yes(e.ioSettled) || !yes(e.viewsReleased) || !yes(e.barrierClosed) ||
          !uint(e.fence) || e.fence<=s.fence) return false;
      s.fence=e.fence;
      s.phase=s.failed && s.target===s.asset ? 'FAILED' : 'ABSENT';
      if (s.phase==='ABSENT') this.#begin();
      return true;
    }
    return false;
  }
}

// Root must supply the COMPLETE swept/support chunk set, not only destination.
// held[i] is ONLY this mover's existing occupancy lease, never a foreign pin.
// This says data is ready, not that the geometry is collision-free.
export function coverage(complete, chunks, held=[]) {
  if (complete!==true || !Array.isArray(chunks) || chunks.length===0 || !Array.isArray(held))
    return 'NOT_READY';
  for (let i=0;i<chunks.length;i++) {
    const c=chunks[i], p=held[i];
    if (!(c instanceof ChunkLifecycle) ||
        !(c.ready() || (p && c.retained(p.id,p.token)))) return 'NOT_READY';
  }
  return 'READY';
}
```

## 3. `protocol.json`

```json
{
  "schema": "s00.chunk-lifecycle.proposal.v1",
  "source": "3612fa62f8d3bcb6888c7028ed0791fe0c928085",
  "integration_enabled": false,
  "godot_target": "4.7.2-stable",
  "godot_runtime": "NOT_RUN",
  "templates": {
    "want": {"asset":"A"},
    "loaded": {"token":"$TOKEN","source":"$SOURCE","asset":"$ASSET"},
    "load_failed": {"token":"$TOKEN"},
    "activated": {"token":"$TOKEN","fence":"$NEXT_FENCE","revision":"$SEEN","collision":true,"navigation":true,"bindings":true,"hydrated":true,"barrierReleased":true},
    "pin": {"token":"$TOKEN","id":"lease-driver"},
    "unpin": {"token":"$TOKEN","id":"lease-driver"},
    "captured": {"token":"$TOKEN","fence":"$NEXT_FENCE","cut":"$SEEN","digest":"aaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaa","bytes":512,"lease":"freeze-1","barrierClosed":t
<!-- END EXACT RECEIVED PREFIX -->

