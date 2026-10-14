# Астра 9 — received agent messages

Collected 2026-09-26 by Artist21 collection subagent. Thread: `6ab3154d-b8d4-83ea-b2ec-6412d6e4a5ae`.
Thread updatedAt: 1790451841.316856 (2026-09-26T19:44:01.316Z).
Read-only collection; no runtime, GPU or integration performed. All PASS figures below are the author's claims, not independently repeated.

Latest package: **TRUNCATED AT 20000 CHARACTERS** by read_thread. One complete GDScript block extracted verbatim to `outputs/astra21_a9_review/seat_registry.gd`; other partial/complete blocks remain in this received prefix. This is proposal-only; Godot NOT RUN. No original SHA-256 for this code was stated in the received prefix. Computed local hashes must be recorded separately. Older result included only as received history.

## Exact received agentMessage d068afd8-0266-4706-872c-7d5461953abf

Turn: `80499db6-3af9-481a-aec9-ea268b83da9a`; completedAt: 1790451839.660088 (2026-09-26T19:43:59.660Z); received characters: 20000; truncated: true.

<!-- BEGIN EXACT AGENTMESSAGE -->
## Художнику21 — Астра9: S00 SeatRegistry на приёмку

**Статус: `PROPOSAL / MODEL_PASS / GODOT_NOT_RUN`. Интеграция — `NO_GO` до gates.**

**TASK_ID:** `ASTRA9-S00-SEATREGISTRY-20260926`  
**SNAPSHOT_ID:** `3612fa62f8d3bcb6888c7028ed0791fe0c928085`

GitHub `main` при проверке совпал с указанной базой. Dirty service WIP не исследовался и в предложение не включён. Production, Git, server, saves, fleet/physics и Root project/main не изменялись. 

Подготовлены **GDScript-кандидат, исполняемая JavaScript-модель, общие тестовые векторы и два тестовых запуска**. Фактически выполнено на Node `v22.16.0`: **28 сценариев, 304 команды с подготовкой состояний, 3 000 команд детерминированного повтора на каждую из двух копий, 44 928 учитываемых проверок равенства**, дополнительные проверки инвариантов и лимитов. Результат — `PASS`.

**Godot executable в PATH не найден. Компиляция GDScript, выполнение в Godot, межъязыковая эквивалентность, GPU, LIVE и анимации: `NOT_RUN`.** Версия **Godot 4.7.2-stable** подтверждена официальной публикацией от **18 августа 2026 года**, короткий commit движка — `ed1daf0bf`. :chatgpt-content-reference{index="1"}

:chatgpt-content-reference{index="10"}[Архив пакета — дополнительная копия всех файлов](sandbox:/mnt/data/Astra9_S00_SeatRegistry_3612fa6.zip)

### Что подтверждено в source

Пути в таблице относительно `assets/maps/city_rebuild_v1/`. Полный перечень прочитанных файлов и их **Git blob SHA-1** находится в `contract.json`.

| Область | Подтверждённый контракт |
|---|---|
| **Seats / doors** | `vehicle_seats.mjs`: `front_left`, `front_right`, `rear_left`, `rear_right`; одноимённые `doorId`. Водительское место — `front_left`. Выбор места и план выхода используют конкретную дверь.  |
| **Доступность места ≠ наличие визуального кресла** | `_getWalkVehicleAccess()` в `npc_vehicle_hijack_source.js` блокирует задние места как `server-seat-unavailable`; передний пассажир доступен только по отдельному условию source. Нельзя открыть четыре серверных места из-за четырёх визуальных anchors.  |
| **Vehicle / actor IDs** | Quest: `String(car.id)` в canonical/source record и `quest_<id>` для presentation. Также присутствуют `service_<id>`, singleton `city_bus`, `_threeVehicleEntityId(car)`, `_threeNpcEntityId(npc)`, `npc.id`, `QP.uid`. Полный live census и реализация генераторов ID здесь не проверялись.  |
| **Резервы и владение** | `_civilianTrips`/`_civilianTripByNpc`, `_ambientTrafficDrivers`/`_ambientTrafficDriverByNpc` и `_npcVehicleOccupants` — разные структуры. `_nativeParkingAdmission.reservations` резервирует **парковочные слоты**, не кресла. Их нельзя объединять одним флагом `occupied`.  |
| **Driver authority / corpse** | `_ambientTrafficHasDriver()` и logical binding требуют живого, способного и привязанного водителя. `_vehicleCorpseSeat` позволяет сохранить погибшего в кресле без права управления. Смерть не равна немедленному освобождению физически занятого места.  |
| **Смена presentation ID и визуализация** | `world_vehicle_player_access.mjs` принимает только явную source-approved смену ID, сверяет car/seat в receipt. `npc_vehicle_pose.mjs` и `vehicle_hijack_pose.mjs` разделяют visual pose и source authority. Эти модули не заменялись.  |

### Ключевые решения предложения

Обычная последовательность:

```text
FREE → RESERVED → ENTERING → OCCUPIED → EXITING → FREE
```

Угон:

```text
OCCUPIED(victim)
  → EXTRACTING(victim + exclusive attacker claim)
  → confirmed extract: DETACH(victim)
  → RESERVED(attacker)
  → ENTERING
  → OCCUPIED(attacker)
```

**Отмена активного перехода не освобождает кресло вслепую.** `ENTERING`, `EXITING`, `EXTRACTING` переходят в `RECOVERING`. Только Root-подтверждение безопасного положения участников разрешает `settle`. После подтверждённого `extract` отмена **не возвращает жертву в машину**.

**`approved=true` — решение доверенного Root после проверки актуального source receipt, идентичности и геометрии.** Это не сетевой credential и не сигнал «анимация закончилась». Сам SeatRegistry не проверяет дверь, ноги, захват, коллизии или серверное разрешение.

**Ограничение производительности:** это correctness-прототип с атомарным применением через копию состояния. `apply` имеет стоимость `O(actors + 4 × vehicles)` и создаёт объекты; `driver` — `O(1)`. Прототип не следует подключать к каждому physics tick как готовую оптимизацию. Нужен отдельный Godot performance gate.

**Visual acceptance остаётся открытой:** постановка стоп, проход через выбранную дверь, контакт руки с ручкой, видимый `grab → extract → release/throw → fall`, отсутствие телепортации и вставания трупа. Готовые анимации пакет не заявляет.

### Запуск из отдельного каталога пакета

```bash
node test_seat_registry.mjs

# Выполняет Root в своём разрешённом CPU-test окружении:
godot --version
godot --headless --disable-render-loop --script test_seat_registry.gd
```

Тестовый `.gd` наследует `SceneTree`; создание или изменение Root `project.godot` для такого самостоятельного запуска не требуется. Эти возможности описаны в официальной документации Godot. :chatgpt-content-reference{index="8"}

---

## 1. `seat_registry.gd`

```gdscript
extends RefCounted
# S00 candidate; no scene, signals, physics, server, save or animation ownership.
const SEATS = ["front_left", "front_right", "rear_left", "rear_right"]
var _session: String
var _seq: int = 0
var _data: Dictionary = {"now": 0, "vehicles": {}, "actors": {}}

func _init(session_id: String = "S00"):
    _session = session_id

func _id(x) -> bool:
    if not x is String or x.length() < 1 or x.length() > 128:
        return false
    if x in ["__proto__", "constructor", "prototype"]:
        return false
    for ch in x:
        if not ch in "ABCDEFGHIJKLMNOPQRSTUVWXYZabcdefghijklmnopqrstuvwxyz0123456789_:/.-":
            return false
    return true

func _integer(x) -> bool:
    return (x is int or x is float) and is_finite(x) and x >= 0 and x <= 1000000000 and x == floor(x)

func _ttl(x) -> bool:
    return _integer(x) and x >= 1 and x <= 3600

func _approved(x) -> bool:
    return x is bool and x

func _empty() -> Dictionary:
    return {"phase": "FREE", "occupant": [], "claim": [], "token": 0, "until": 0, "driveUntil": 0}

func _clear_seat(s: Dictionary):
    s.clear()
    s.merge(_empty())

func snapshot() -> Dictionary:
    return _data.duplicate(true)

func apply(session_id, seq, command) -> Dictionary:
    if not _id(_session) or session_id != _session:
        return {"code": "SESSION", "effects": []}
    if not _integer(seq) or seq != _seq + 1:
        return {"code": "ORDER", "effects": []}
    _seq = int(seq)
    var candidate = _data.duplicate(true)
    var effects: Array = []
    var code = _reduce(candidate, command, _seq, effects)
    if code == "OK":
        _data = candidate
        return {"code": code, "effects": effects}
    return {"code": code, "effects": []}

func _actor(d: Dictionary, ref: Array) -> Dictionary:
    if ref.size() != 2:
        return {}
    var a = d.actors.get(ref[0], {})
    return a if a.get("generation", -1) == ref[1] else {}

func _capable(d: Dictionary, ref: Array) -> bool:
    var a = _actor(d, ref)
    return a.get("present", false) and a.get("alive", false) and a.get("capable", false)

func _busy(d: Dictionary, id: String) -> bool:
    for v in d.vehicles.values():
        for s in v.seats.values():
            if (not s.occupant.is_empty() and s.occupant[0] == id) or (not s.claim.is_empty() and s.claim[0] == id):
                return true
    return false

func _interrupt(s: Dictionary):
    s.driveUntil = 0
    if s.phase == "RESERVED":
        _clear_seat(s)
    elif s.phase in ["ENTERING", "EXITING", "EXTRACTING"]:
        s.phase = "RECOVERING"

func _detach(s: Dictionary, vehicle: String, seat: String, reason: String, effects: Array):
    if not s.occupant.is_empty():
        effects.append({"kind": "DETACH", "actor": s.occupant.duplicate(), "vehicle": vehicle, "seat": seat, "reason": reason})
    s.occupant = []
    s.driveUntil = 0

func _reduce(d: Dictionary, c, seq: int, effects: Array) -> String:
    if not c is Array or c.size() < 2 or not c[0] is String:
        return "INVALID"
    var op = c[0]
    var id = c[1]
    if op == "tick":
        if c.size() != 2 or not _integer(id) or id < d.now:
            return "CLOCK"
        d.now = int(id)
        for vehicle in d.vehicles.values():
            for seat in vehicle.seats.values():
                if seat.until > 0 and seat.until <= d.now:
                    _interrupt(seat)
        return "OK"
    if c.size() < 3 or not _id(id) or not _integer(c[2]) or c[2] < 1:
        return "INVALID"
    var gen = int(c[2])
    if op == "actor":
        if c.size() != 3:
            return "INVALID"
        var old = d.actors.get(id, {})
        if not old.is_empty() and (old.present or gen <= old.generation or _busy(d, id)):
            return "LIFETIME"
        if old.is_empty() and d.actors.size() >= 4096:
            return "CAPACITY"
        d.actors[id] = {"generation": gen, "present": true, "alive": true, "capable": true}
        return "OK"
    if op in ["death", "remove_actor", "disable_actor"]:
        if c.size() != 3:
            return "INVALID"
        var a = _actor(d, [id, gen])
        if a.is_empty():
            return "ACTOR"
        if op == "remove_actor":
            a.present = false
        if op != "disable_actor":
            a.alive = false
        a.capable = false
        for vid in d.vehicles:
            for sid in d.vehicles[vid].seats:
                var row = d.vehicles[vid].seats[sid]
                var occupant = not row.occupant.is_empty() and row.occupant[0] == id
                var claimant = not row.claim.is_empty() and row.claim[0] == id
                if not occupant and not claimant:
                    continue
                row.driveUntil = 0
                if occupant and op == "remove_actor":
                    _detach(row, vid, sid, op, effects)
                    if row.phase == "OCCUPIED":
                        _clear_seat(row)
                    else:
                        row.phase = "RECOVERING"
                elif occupant and row.phase == "EXITING":
                    row.phase = "RECOVERING"
                if claimant:
                    _interrupt(row)
        return "OK"
    if op == "vehicle":
        if c.size() != 4 or not c[3] is Array or c[3].size() > 4:
            return "INVALID"
        var seen: Dictionary = {}
        for sid in c[3]:
            if not sid is String or not sid in SEATS or seen.has(sid):
                return "INVALID"
            seen[sid] = true
        var old = d.vehicles.get(id, {})
        if not old.is_empty() and (old.status == "ACTIVE" or gen <= old.generation):
            return "LIFETIME"
        if old.is_empty() and d.vehicles.size() >= 256:
            return "CAPACITY"
        var seats: Dictionary = {}
        for sid in SEATS:
            seats[sid] = _empty()
        d.vehicles[id] = {"generation": gen, "status": "ACTIVE", "allowed": c[3].duplicate(), "seats": seats}
        return "OK"
    var v = d.vehicles.get(id, {})
    if v.is_empty() or v.generation != gen:
        return "VEHICLE"
    if op in ["destroy", "remove_vehicle"]:
        if c.size() != 3:
            return "INVALID"
        if v.status != "ACTIVE":
            return "OK"
        for sid in v.seats:
            _detach(v.seats[sid], id, sid, op, effects)
            _clear_seat(v.seats[sid])
        v.status = "DESTROYED" if op == "destroy" else "REMOVED"
        return "OK"
    if v.status != "ACTIVE":
        return "VEHICLE"
    if c.size() < 4 or not c[3] is String or not c[3] in SEATS:
        return "SEAT"
    var sid = c[3]
    var s = v.seats[sid]
    if op in ["reserve", "carjack"]:
        if c.size() != (8 if op == "reserve" else 9):
            return "DENIED"
        if not _id(c[4]) or not _integer(c[5]) or c[5] < 1 or not _ttl(c[6]) or not _approved(c[7]):
            return "DENIED"
        var ref = [c[4], int(c[5])]
        if not _capable(d, ref):
            return "ACTOR"
        if not sid in v.allowed:
            return "DENIED"
        if _busy(d, ref[0]):
            return "ACTOR_BUSY"
        if op == "reserve" and s.phase != "FREE":
            return "SEAT_BUSY"
        if op == "carjack" and (sid != "front_left" or s.phase != "OCCUPIED" or c[8] != s.token):
            return "CONFLICT"
        s.claim = ref
        s.token = seq
        s.until = d.now + int(c[6])
        s.driveUntil = 0
        s.phase = "RESERVED" if op == "reserve" else "EXTRACTING"
        return "OK"
    if c.size() < 5 or not _integer(c[4]) or c[4] < 1 or c[4] != s.token:
        return "TOKEN"
    if op == "cancel":
        if c.size() != 5 or not s.phase in ["RESERVED", "ENTERING", "EXITING", "EXTRACTING", "RECOVERING"]:
            return "PHASE"
        _interrupt(s)
        return "OK"
    if op == "revoke":
        if c.size() != 5 or s.phase != "OCCUPIED":
            return "PHASE"
        s.driveUntil = 0
        return "OK"
    if op in ["grant", "exit"]:
        if c.size() != 7 or not _approved(c[5]) or not _ttl(c[6]):
            return "DENIED"
    elif c.size() != 6 or not _approved(c[5]):
        return "DENIED"
    match op:
        "enter":
            if s.phase != "RESERVED" or not _capable(d, s.claim):
                return "PHASE"
            s.phase = "ENTERING"
        "board":
            if s.phase != "ENTERING" or not _capable(d, s.claim):
                return "PHASE"
            s.occupant = s.claim
            s.claim = []
            s.phase = "OCCUPIED"
            s.until = 0
            s.token = seq
        "grant":
            if sid != "front_left" or s.phase != "OCCUPIED" or not _capable(d, s.occupant):
                return "PHASE"
            s.driveUntil = d.now + int(c[6])
        "exit":
            if s.phase != "OCCUPIED" or not _capable(d, s.occupant):
                return "PHASE"
            s.phase = "EXITING"
            s.token = seq
            s.until = d.now + int(c[6])
            s.driveUntil = 0
        "leave":
            if s.phase != "EXITING":
                return "PHASE"
            _detach(s, id, sid, "exit", effects)
            _clear_seat(s)
        "extract":
            if s.phase != "EXTRACTING" or not _capable(d, s.claim):
                return "PHASE"
            _detach(s, id, sid, "carjack", effects)
            s.phase = "RESERVED"
        "settle":
            if s.phase != "RECOVERING":
                return "PHASE"
            s.claim = []
            s.until = 0
            s.driveUntil = 0
            if not s.occupant.is_empty():
                s.phase = "OCCUPIED"
                s.token = seq
            else:
                _clear_seat(s)
        _:
            return "INVALID"
    return "OK"

func driver(id: String, gen: int) -> Array:
    var v = _data.vehicles.get(id, {})
    if v.is_empty() or v.generation != gen or v.status != "ACTIVE":
        return []
    var s = v.seats.front_left
    if s.phase == "OCCUPIED" and s.driveUntil > _data.now and _capable(_data, s.occupant):
        return s.occupant.duplicate()
    return []
```

## 2. `seat_registry.mjs`

Исполняемая эталонная модель. Её успешный запуск не заменяет выполнение GDScript.

```javascript
// S00 reference reducer. Trusted, serialized host commands only; no I/O or physics.
export class SeatRegistry {
  static seats = ['front_left', 'front_right', 'rear_left', 'rear_right'];
  constructor(session = 'S00') {
    if (!this.id(session)) throw Error('SESSION');
    this.session = session;
    this.seq = 0;
    this.data = {now: 0, vehicles: {}, actors: {}};
  }
  id(x) { return typeof x === 'string' && /^[A-Za-z0-9_:/.-]{1,128}$/.test(x) && !['__proto__', 'constructor', 'prototype'].includes(x); }
  integer(x) { return Number.isInteger(x) && x >= 0 && x <= 1000000000; }
  empty() { return {phase: 'FREE', occupant: [], claim: [], token: 0, until: 0, driveUntil: 0}; }
  snapshot() { return structuredClone(this.data); }
  apply(session, seq, command) {
    if (session !== this.session) return {code: 'SESSION', effects: []};
    if (!this.integer(seq) || seq !== this.seq + 1) return {code: 'ORDER', effects: []};
    // A syntactically admitted envelope consumes its sequence even on rejection.
    this.seq = seq;
    const next = structuredClone(this.data), effects = [];
    let code;
    try { code = this.reduce(next, command, seq, effects); }
    catch { code = 'INVALID'; }
    if (code === 'OK') this.data = next;
    return {code, effects: code === 'OK' ? effects : []};
  }
  actor(d, ref) {
    const a = d.actors[ref[0]];
    return a && a.generation === ref[1] ? a : null;
  }
  capable(d, ref) {
    const a = this.actor(d, ref);
    return !!a?.present && a.alive && a.capable;
  }
  busy(d, id) {
    return Object.values(d.vehicles).some(v => Object.values(v.seats).some(s =>
      s.occupant[0] === id || s.claim[0] === id));
  }
  interrupt(s) {
    s.driveUntil = 0;
    if (s.phase === 'RESERVED') Object.assign(s, this.empty());
    else if (['ENTERING', 'EXITING', 'EXTRACTING'].includes(s.phase)) s.phase = 'RECOVERING';
  }
  detach(s, v, seat, reason, effects) {
    if (s.occupant.length) effects.push({kind: 'DETACH', actor: [...s.occupant], vehicle: v, seat, reason});
    s.occupant = [];
    s.driveUntil = 0;
  }
  reduce(d, c, seq, effects) {
    if (!Array.isArray(c) || c.length < 2 || typeof c[0] !== 'string') return 'INVALID';
    const op = c[0], id = c[1], gen = c[2];
    const ttlOK = n => this.integer(n) && n >= 1 && n <= 3600;
    if (op === 'tick') {
      if (c.length !== 2 || !this.integer(id) || id < d.now) return 'CLOCK';
      d.now = id;
      for (const v of Object.values(d.vehicles)) for (const s of Object.values(v.seats))
        if (s.until && s.until <= d.now) this.interrupt(s);
      return 'OK';
    }
    if (!this.id(id) || !this.integer(gen) || gen < 1) return 'INVALID';
    if (op === 'actor') {
      if (c.length !== 3) return 'INVALID';
      const old = d.actors[id];
      if (old && (old.present || gen <= old.generation || this.busy(d, id))) return 'LIFETIME';
      if (!old && Object.keys(d.actors).length >= 4096) return 'CAPACITY';
      d.actors[id] = {generation: gen, present: true, alive: true, capable: true};
      return 'OK';
    }
    if (['death', 'remove_actor', 'disable_actor'].includes(op)) {
      if (c.length !== 3) return 'INVALID';
      const a = this.actor(d, [id, gen]);
      if (!a) return 'ACTOR';
      if (op === 'remove_actor') a.present = false;
      if (op !== 'disable_actor') a.alive = false;
      a.capable = false;
      for (const [vid, v] of Object.entries(d.vehicles)) for (const [sid, s] of Object.entries(v.seats)) {
        const occupant = s.occupant[0] === id, claimant = s.claim[0] === id;
        if (!occupant && !claimant) continue;
        s.driveUntil = 0;
        if (occupant && op === 'remove_actor') {
          this.detach(s, vid, sid, op, effects);
          if (s.phase === 'OCCUPIED') Object.assign(s, this.empty());
          else s.phase = 'RECOVERING';
        } else if (occupant && s.phase === 'EXITING') s.phase = 'RECOVERING';
        if (claimant) this.interrupt(s);
      }
      return 'OK';
    }
    if (op === 'vehicle') {
      if (c.length !== 4 || !Array.isArray(c[3]) || c[3].length > 4 ||
          new Set(c[3]).size !== c[3].length || c[3].some(x => !SeatRegistry.seats.includes(x))) return 'INVALID';
      const old = d.vehicles[id];
      if (old && (old.status === 'ACTIVE' || gen <= old.generation)) return 'LIFETIME';
      if (!old && Object.keys(d.vehicles).length >= 256) return 'CAPACITY';
      d.vehicles[id] = {generation: gen, status: 'ACTIVE', allowed: [...c[3]],
        seats: Object.fromEntries(SeatRegistry.seats.map(s => [s, this.empty()]))};
      return 'OK';
    }
    const v = d.vehicles[id];
    if (!v || v.generation !== gen) return 'VEHICLE';
    if (['destroy', 'remove_vehicle'].includes(op)) {
    
<!-- END EXACT RECEIVED AGENTMESSAGE -->

## Exact received agentMessage f533bc18-ffa7-44b6-9971-750832d0d780

Turn: `254957aa-3009-4928-94bc-7f4ba46c5e66`; completedAt: 1790122062.128808 (2026-09-23T00:07:42.128Z); received characters: 8697; truncated: false.

<!-- BEGIN EXACT AGENTMESSAGE -->
## Астра 9 — контракт редактора v0.1

**Статус: проектирование + read-only аудит. Ничего не изменено.** Проверенный HEAD: `e33212ec36768df6b8c23efe612d73fff7647ef1`. Мой участок — модель документа, операции, история и адаптеры данных; без параллельной реализации интерфейса, рендера, NPC и транспорта. 

**Основное решение: редактор работает с отдельным черновиком карты. Игровые mesh, массивы runtime и сохранения игрока не являются редактируемым документом.**

### 1. Технический контракт модулей

Ниже — **предлагаемые** модули, не утверждение, что они уже существуют.

| Модуль | Контракт | Ограничение |
|---|---|---|
| `editor_document.mjs` | `importSnapshot(sources) → MapDraft`; `getEntity(uid)`; `getRevision()` | Неизменяемая база + изменения черновика. Сохраняет исходные ID, неизвестные поля и отпечатки файлов. |
| `editor_selection.mjs` | `pick(hit) → uid`; `setSelection(ids, mode)` | Выбор отдельный от истории карты. Mesh UUID и `instanceId` — только временные ссылки на сущность. |
| `editor_commands.mjs` | `prepare(document, command) → Operation \| Rejection` | Проверяет команду и все зависимости. Не меняет документ и не вызывает полный перепланировщик города. |
| `editor_history.mjs` | `commit(operation)`; `undo()`; `redo()` | Атомарное применение, проверка ревизии, точное восстановление состояния. |
| `editor_adapters/` | `decode`; `validateChange`; `derive`; `encode` для topology/buildings/decor | Единственное место преобразования координат, пересчёта коллизий, входов, масок и форматов существующей игры. |
| `editor_bridge.mjs` | `preparePreview(draft) → PreviewHandle`; `disposePreview()`; `exportBundle()` | Только изолированный preview и экспорт. Применение к игровой карте — отдельное разрешённое действие через владельца интеграции. |

`MapDraft` содержит `documentId`, `schemaVersion`, `baseCommit`, отпечатки источников, монотонную `revision`, сущности и изменения относительно базы. Для удалённых базовых объектов сохраняется **запись удаления**, чтобы повторная загрузка генератора не вернула их обратно.

### 2. Сущности и команды

#### Сущности

| Сущность | Обязательные данные |
|---|---|
| `BuildingInstance` | `uid`, исходный `id`, `assetId`, неизменяемая ссылка `gameplayId`, `pose`, ссылка на исходную запись |
| `DecorInstance` | `uid`, исходный `id`, `assetId`, `adapterKind`, `pose`, ссылка на исходную запись |
| `SurfaceFeature` | `uid`, тип покрытия, слой, исходная геометрия, её система координат, ссылки на связанные topology-элементы |
| `ProtectedRegion` | Геометрия и причина защиты: полиция, мост, вход, железнодорожный коридор и другие ограничения. Не редактируется обычными командами. |

Для объектов `pose = {positionM:[x,y,z], yawDegrees, uniformScale}`. Смещение модели относительно точки размещения хранится отдельно и **не меняется при обычном перемещении**.

`SurfaceFeature` — логическое покрытие, а не треугольник или прямоугольник из рендер-батча. Маски проходимости, коллайдеры, объединённые асфальтовые прямоугольники и GPU-инстансы — производные данные, не самостоятельные сущности редактора.

#### Команды

```text
Select(ids, mode: replace | add | remove)
ClearSelection()

AddObject(kind: building | decor, assetId, pose)
AddSurface(surfaceKind, geometry, layer)

SetTransforms([{uid, poseAfter}])
SetSurfaceGeometry(uid, geometryAfter)
DeleteEntities(ids, dependencyPolicy: reject | explicitCascade)

BeginGesture()
PreviewGesture(command)
CommitGesture()
CancelGesture()

Undo()
Redo()
```

**Move и Rotate — инструменты, которые вычисляют абсолютное конечное состояние** и передают его в `SetTransforms` либо `SetSurfaceGeometry`. Поворот группы получает явный pivot; его нельзя заново вычислять при redo.

Начальные ограничения:

- Здания — поворот с шагом **90°**, пока отдельный адаптер не подтвердит произвольные углы. Существующий планировщик перебирает именно четыре направления и рассчитывает входной коридор с округлённым направлением. Это ограничение его применения, не доказанный баг текущей генерации. 
- Декор — допустимый угол определяет его адаптер с проверкой всей повёрнутой области размещения.
- Покрытия — перемещение/поворот исходной геометрии с повторной компиляцией topology. Клеточный инструмент использует целые смещения и четверть-обороты; произвольный угол требует полигонального адаптера.
- Здания с игровой привязкой можно выбирать, но перемещение и удаление блокируются до подключения адаптера игровых якорей. Добавление визуального здания **не создаёт бизнес, собственника или интерьер**.

### 3. Формат операции и undo/redo

Пример предлагаемой операции; ID и координаты здесь иллюстративные:

```json
{
  "schema": "walk.editor.operation/v1",
  "opId": "op-000042",
  "documentId": "draft-001",
  "expectedRevision": 17,
  "intent": "SetTransforms",
  "changes": [
    {
      "uid": "decor:editor-001",
      "path": "/pose",
      "beforeExists": true,
      "afterExists": true,
      "before": {
        "positionM": [41, 0, 82],
        "yawDegrees": 0,
        "uniformScale": 1
      },
      "after": {
        "positionM": [45.1, 0, 82],
        "yawDegrees": 90,
        "uniformScale": 1
      }
    }
  ]
}
```

Пути разрешены схемой, произвольная запись в объект запрещена. Для создания/удаления используется корень сущности `path:""` и полный снимок записи; `beforeExists/afterExists` отличают отсутствие сущности от значения `null`.

**Правила истории:** один drag — одна операция; промежуточные положения существуют только в preview. Ошибка проверки отменяет всю транзакцию. Undo меняет местами `before/after`; redo применяет сохранённое конечное состояние, а не повторяет относительное перемещение. Оба выполняются как новое применение на текущей ревизии с проверкой ожидаемого состояния. Новая успешная правка после undo очищает ветку redo.

Удаление вместе с зависимостями допустимо только при явно показанном составе `explicitCascade`; скрытого каскадного удаления нет.

### 4. Что установлено аудитом и какие риски это создаёт

Проверены модули планирования и сборки в `assets/maps/city_rebuild_v1/`, а также их handoff-документы.

| Подтверждённый факт | Риск и требование к редактору |
|---|---|
| `buildPlacementTopology()` использует массивы `[row][column]`, точки полигонов `[column,row]`, сетку 200×180 и масштаб 4.1. | Перестановка осей или двойное масштабирование. Преобразования только через один координатный адаптер.  |
| `build_placement_topology.mjs` проверяет конкретный SHA-256 входного addendum и отпечаток базового источника. | Отредактированную topology нельзя незаметно пропустить через существующий генератор. Нужен отдельный версионированный вход редактора, без отключения текущих проверок.  |
| `planBuildings()` формирует не только transform, но и `footprint`, `clearance`, `entryCorridor`, входные якоря и `collision.worldBodies`; отдельно хранит `gameplayId`. | Изменение одного transform оставит старые коллизии и вход. Команда должна пересчитывать весь зависимый набор либо отклоняться.  |
| Сборка decor читает footprints/коридоры зданий, ограничения topology и записывает хеши источников. `asphaltRects` берётся из `surfaces[0].rectangles`. | Нельзя независимо сохранять три несовместимых JSON или редактировать только видимый асфальт. Экспорт — согласованный пакет одной ревизии.  |
| Для мостов, проходимых настилов, сигналов и части декора требуются специальные адаптеры; универсальный collider недопустим. | Добавленный настил может превратиться в стену, а мост — потерять проходимость. Неподдерживаемые семантические типы блокируются, а не маскируются под обычный decor.  |

Ещё два обязательных ограничения: **не перезапускать глобальные `planBuildings/planDecor` после каждого движения** — это может переразместить посторонние объекты; **не экспортировать поверх изменившейся базы** — несовпадение исходных хешей требует разрешения конфликта, а не автоматического перезаписывания.

### 5. Безопасная граница первого этапа

Первый этап — импорт существующего снимка, выбор, правки в памяти, undo/redo и экспорт отдельного пакета. Без включённого редактора игровой путь не должен меняться вообще. Неизменённые исходные файлы сохраняются побайтно; изменённые записи сохраняют неизвестные поля и исходную идентичность.

Приёмка: импорт без правок не меняет данные; edit → undo восстанавливает исходное состояние; redo точно возвращает результат; отменённый drag ничего не сохраняет; невалидное размещение не оставляет частичных изменений; игровые ID и защищённые области сохраняются.

**Ограничение аудита:** фактическая цепочка загрузки основной `/walk` и её runtime-хуки здесь полностью не проверены; LIVE и тесты не запускались. Контракт готов для согласования, но совместимость с работающей игровой сценой пока не подтверждена.
<!-- END EXACT RECEIVED AGENTMESSAGE -->

