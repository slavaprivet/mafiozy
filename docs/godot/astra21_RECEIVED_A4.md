# Астра 4 — Интерьеры и камера — exact received prefix

Collection date: 2026-09-26. Thread: `6aaaf0ef-b1a4-83e9-987e-60477590b078`. AgentMessage: `de281538-3d85-4b0a-86d7-f023a9684257`. Turn: `724ddb86-bbe4-4b5a-95b0-860c53ee0ef9`.
CompletedAt: 1790452007.73672 (2026-09-26T19:46:47.736Z); updatedAt: 1790452012.235413.
Received characters: 20000; server truncated: true.

**PARTIAL PACKAGE: 20000-character prefix only.** Statements below about complete files/bundles describe the author's full answer, not what read_thread delivered. Sandbox attachments not downloaded. Claimed PASS counts are not independently repeated. Godot/runtime/GPU/integration not run by collector; no production changed.

Closed file blocks extracted only: `outputs/astra21_a4_review/source_inventory.json`, `outputs/astra21_a4_review/doorway_stockroom.schema.json`, `outputs/astra21_a4_review/service_stockrooms.pending.json`. Remaining schema/test/runtime blocks are unavailable or incomplete. Original claimed hashes and computed local hashes are distinct in review manifest. No final integration acceptance.

<!-- BEGIN EXACT RECEIVED PREFIX -->
**BASE_SHA: `3612fa62f8d3bcb6888c7028ed0791fe0c928085` · TASK_ID: `S00-interiors-doors-stockrooms-3612fa62`**  
**Статус: самостоятельный S00-пакет для приёмки Художником21. JSON/schema: 12/12 PASS. Godot parse/runtime/physics: `NOT_RUN`. Интеграционные gates не открыты.**

Godot **4.7.2-stable** подтверждён официальным архивом; исполняемого Godot в текущей среде нет. Ни проект, ни exporter/player, ни production/LIVE не изменялись. :chatgpt-content-reference{index="0"}

## 1. Что обнаружено в опубликованном source

| Владелец | Что необходимо сохранить при переносе |
|---|---|
| `building_window_integration.mjs → createWindowedBuildingEntry()` | Порядок size transform → окна → entry/storeys → дополнительные оконные вырезы → interior design. Экспортировать **окончательную** геометрию. `roomReveals` — владелец восстановления CSG, а не состояние «комната невидима». |
| `building_storeys.mjs → createBuildingStoreys()` | Собственный inverse-scaled метрический frame, этажи, потолки и отверстия лестниц. Не применять масштаб placement второй раз. |
| `interior_staircase.mjs` и `oriented_staircase.mjs` | Визуальные ступени, `holeRects`, маршруты, сегментированные ограждения и **высотно-зависимый support/ceiling contract**. Простая коллизия по целому AABB лестницы неверна. |
| `building_entry_profiles.mjs` | Реальные pivot/leaf transforms; `fraction/target`; движущиеся прямоугольники коллизии; отдельные пределы высоты. Публичный вход анимируется за `.65 s`. |
| `interior_room_doors.mjs` | Комнатные двери анимируются за `.6 s`; видимые детали уже объединены по материалам, но каждая дверь сохраняет собственные hinge/pivot и collider. |
| `residential_windows.mjs` | Проёмы, стекло, непрозрачные откосы и instance identity. Прозрачное окно нельзя считать доказательством скрытого места появления. |

Основание: прочитанные файлы закреплены за указанным commit. 

### Главный разрыв с новым требованием

**Наличие роли `stockroom` не означает наличия закрытой кладовки.** Планировщик допускает отказ от приватной комнаты и создаёт её doorway с `open:true`; `stockroom` отсутствует в списке ролей, которые `building_storeys` принудительно переводит в закрытое состояние. Следовательно, существующие комнаты нельзя автоматически объявить местами скрытого respawn. 

В пакете **нет ни одного выдуманного production-anchor**. Printshop оставлен `UNRESOLVED`; dirty WIP не подменяет опубликованный source. Полный список сервисов должен поступить от владельца service registry, а не выводиться из числа жилых placements или generated interiors.

## 2. Контракт предложения

**DoorController:** один владелец движения, максимум две створки. Коллайдеры остаются включёнными. Перед движением проверяется общий объём **проёма и всего поворота створок**, а не только две конечные позы. При занятости — удержание текущей доли открытия; после освобождения — продолжение без скачка.

Проверка использует `intersect_shape()` внутри `_physics_process()`. Исключаются только собственные створки; игрок, продавец, другие NPC, трупы, перемещаемые предметы и специальные reservation-объёмы должны попадать в назначенную Root collision mask. `max_results=1` достаточен: любое найденное препятствие останавливает движение. Эти API и ограничение времени доступа к physics space подтверждены документацией Godot. :chatgpt-content-reference{index="3"}

**Продавец:** модель не создаёт NPC самостоятельно. Она выдаёт Root последовательность идемпотентных запросов:

```text
vacancy → 60 s simulation time
→ проверенное скрытое и свободное место
→ SPAWN_IN_STOCKROOM
→ WALK_TO_WAIT
→ CLAIM_HOLD_AND_OPEN
→ подтверждённое полное открытие
→ WALK_TO_DUTY через проём
→ всё тело покинуло guard
→ RELEASE_HOLD
→ прибытие на рабочее место
→ ACTIVATE_SERVICE_LEASE
```

Actor с момента создания должен иметь обычный визуал, **физически закрытый непрозрачной кладовкой**, а не искусственно `visible=false` до выхода. При неизвестной видимости, занятом spawn или отсутствии маршрута появление откладывается. Вторая заявка не создаётся, пока первая не подтверждена или не отменена Root.

**Root сохраняет authority:** проверка доступа/E/замка, service slot, создание actor, движение по пути, `source ID → Godot node` mapping, сохранения и generation lifecycle. Proposal не изменяет эти системы.

---

# 3. Полные файлы

Все новые файлы предназначены для **отдельного harness/proposal**, не для автоматического помещения в основной проект. `project.godot`, exporter и autoload не добавляются.

## Файл 1 — `s00_interiors/source_inventory.json`

```json
{
  "task_id": "S00-interiors-doors-stockrooms-3612fa62",
  "base_sha": "3612fa62f8d3bcb6888c7028ed0791fe0c928085",
  "stage": "S00_PROPOSAL_ONLY",
  "owner": "Astra4",
  "reviewer": "Artist21",
  "integration_owner": "Coordinator20",
  "godot_target": "4.7.2-stable",
  "godot_runtime": "NOT_RUN",
  "production_exports_built": false,
  "package_approved_stockroom_anchors": 0,
  "service_inventory_complete": false,
  "source_prefix": "assets/maps/city_rebuild_v1/",
  "read_sources": [
    {"path": "building_entry_profiles.mjs", "git_blob": "b6422f23468781c186ed492608cf4d39cab2f2c4", "symbols": ["ADDITIONAL_ENTRY_PROFILES", "createAdditionalBuildingEntry"], "export": ["final door leaves and pivots", "fraction and target", "getCollisionBodies polygons and height limits", "floor and ceiling references"]},
    {"path": "building_window_integration.mjs", "git_blob": "011750e2e09196a46300660a010eaa9f9256dc0f", "symbols": ["createWindowedBuildingEntry"], "export": ["post-size/post-CSG geometry", "windows and entry/storeys/design owners", "roomReveals is a disposal owner, not reveal state"]},
    {"path": "building_storeys.mjs", "git_blob": "850037103e5befd7961042377f3c4c8eeef61966", "symbols": ["createBuildingStoreys"], "export": ["inverse-scaled metric frame", "floor plates with stair holes", "rooms and floorPlans", "storey collision bodies", "closed-room role override"]},
    {"path": "interior_staircase.mjs", "git_blob": "342a81727cc711cb4d4ca37f28fd26ee66809756", "symbols": ["planInteriorStaircase", "createInteriorStaircase"], "export": ["boxes and rails", "holeRects and route", "height-aware support and ceiling samples", "segmented rail obstacles"]},
    {"path": "oriented_staircase.mjs", "git_blob": "13b042bef59db3e4ee1537f0bf58d40c2b563d95", "symbols": ["createFittedStaircase"], "export": ["rotated mapping (x,z) to (z,-x)", "compact/noncompact result", "final mapped route and obstacles"]},
    {"path": "interior_spacious_layout.mjs", "git_blob": "c1e64a6eb6bb866cfaa78174a430109181863aae", "symbols": ["rolesFor", "planSpaciousFloor"], "export": ["accepted room IDs/rectangles", "partitions", "door opening state", "reservedPaths and unreachable"]},
    {"path": "interior_room_doors.mjs", "git_blob": "0b2269a454afd0c55a6c07a7bbe452d41873b8a7", "symbols": ["createInteriorRoomDoors"], "export": ["door-to-instanced-part ownership", "hinge/pivot transforms", "moving collider polygons", "fraction/target", "sweepContains behavior"]},
    {"path": "residential_windows.mjs", "git_blob": "d35162f511b309b3ced8152a3fac6291fbb03dcf", "symbols": ["applyResidentialWindows"], "export": ["final panes and normal/origin", "window cuts", "glass instance identity and fracture/reset ownership"]},
    {"path": "building_interior_design.mjs", "git_blob": "82888ae6d1b095872e8a9858962fe5f9d0fd8743", "symbols": ["createBuildingInteriorDesign"], "export": ["actual created room doors", "combined furniture/door/safe collision ownership", "dispose chain"]}
  ],
  "required_capture_dependencies": [
    "building_entry.mjs; building_room_profiles.mjs; building_storey_profiles.mjs",
    "residential_windows.mjs: final panes, cuts, glass and instance ownership",
    "building_size_policy.mjs; building_site_collision.mjs; building_floor_surface.mjs",
    "interior_functional_furnishing.mjs and interior_interactive_safe.mjs: final occupied volumes",
    "Root service registry, accepted GLB/placement bytes and runtime source snapshot",
    "Dirty service WIP manifest, only after separate explicit acceptance"
  ],
  "confirmed_contracts": [
    "Room role stockroom is not guaranteed for every purpose or successful layout",
    "Private-room openings start open:true; stockroom is not in the forced-closed role list",
    "InteriorRoomDoors uses a passed point, vertical span 1.9 and radius .36 in sweep checking",
    "Interior room door motion is .6s with smoothstep; public entry motion is .65s",
    "Collision polygonCR must be multiplied by captured metresPerCell exactly once",
    "Stair visual treads do not replace the height-conditioned support oracle"
  ],
  "proposal_limits": {
    "door_leaves": 2,
    "box_shapes_per_leaf": 4,
    "physics_queries_per_moving_door_tick": 1,
    "query_max_results": 1,
    "door_query_margin_m": 0,
    "guard_extra_margin_m": 0.02,
    "maximum_motion_step_s": 0.1,
    "respawn_delay_simulation_us": 60000000,
    "concurrent_seller_slots_per_service": 1,
    "maximum_route_points": 64
  },
  "integration_gates": [
    "Exact service registry coverage, including missing-stockroom services",
    "Approved metric frame, geometry and collision source IDs for each service",
    "All six anchors and complete routes physically checked for the selected actor capsule",
    "Spawn/wait are outside the full door guard; no window or other opening exposes spawn volume",
    "Root atomically reserves service slot and rechecks same-tick spawn proof before creation",
    "Headless Godot 4.7.2 tests, then separately approved actual-build capture acceptance",
    "Artist21 review and Coordinator20 explicit integration approval; no later stage implied"
  ]
}
```

## Файл 2 — `s00_interiors/doorway_stockroom.schema.json`

`xform` — 12 чисел: **три столбца Basis, затем origin**. Все позиции якорей и маршрутов — в проверенном метрическом frame здания; `frame_to_building` переводит frame двери в него. Автоматического отражения Z нет: направление камеры Godot `−Z` не требует зеркалить мировые данные. :chatgpt-content-reference{index="4"}

Schema проверяет структуру. Она **не подменяет** проверку геометрии, скрытости и проходимости.

```json
{
  "$schema": "https://json-schema.org/draft/2020-12/schema",
  "title": "S00 doorway and stockroom proposal, not an exporter",
  "type": "object",
  "additionalProperties": false,
  "required": ["schema_version", "source_commit", "service_inventory_complete", "expected_service_ids", "records"],
  "properties": {
    "schema_version": {"const": 1},
    "source_commit": {"const": "3612fa62f8d3bcb6888c7028ed0791fe0c928085"},
    "service_inventory_complete": {"type": "boolean"},
    "expected_service_ids": {"type": "array", "uniqueItems": true, "items": {"$ref": "#/$defs/id"}},
    "records": {"type": "array", "maxItems": 1024, "items": {"$ref": "#/$defs/record"}}
  },
  "$defs": {
    "id": {"type": "string", "minLength": 1, "maxLength": 256},
    "hash": {"type": "string", "pattern": "^[0-9a-f]{64}$"},
    "vec3": {"type": "array", "minItems": 3, "maxItems": 3, "items": {"type": "number"}},
    "vec2": {"type": "array", "minItems": 2, "maxItems": 2, "items": {"type": "number"}},
    "xform": {"type": "array", "minItems": 12, "maxItems": 12, "items": {"type": "number"}},
    "path": {"type": "array", "minItems": 2, "maxItems": 64, "items": {"$ref": "#/$defs/vec3"}},
    "box": {
      "type": "object", "additionalProperties": false, "required": ["min", "size"],
      "properties": {"min": {"$ref": "#/$defs/vec3"}, "size": {"$ref": "#/$defs/vec3"}}
    },
    "leaf": {
      "type": "object", "additionalProperties": false,
      "required": ["source_node_id", "body_id", "closed_xform", "open_angle_rad", "collider_ids"],
      "properties": {
        "source_node_id": {"$ref": "#/$defs/id"},
        "body_id": {"$ref": "#/$defs/id"},
        "closed_xform": {"$ref": "#/$defs/xform"},
        "open_angle_rad": {"type": "number", "minimum": -1.5707963267948966, "maximum": 1.5707963267948966, "not": {"const": 0}},
        "collider_ids": {"type": "array", "minItems": 1, "maxItems": 4, "uniqueItems": true, "items": {"$ref": "#/$defs/id"}}
      }
    },
    "doorway": {
      "type": "object", "additionalProperties": false,
      "required": ["frame_to_building", "portal", "guard", "leaves", "seconds", "initial_fraction", "initial_target_open", "blocker_mask_role"],
      "properties": {
        "frame_to_building": {"$ref": "#/$defs/xform"},
        "portal": {"$ref": "#/$defs/box"}, "guard": {"$ref": "#/$defs/box"},
        "leaves": {"type": "array", "minItems": 1, "maxItems": 2, "items": {"$ref": "#/$defs/leaf"}},
        "seconds": {"type": "number", "minimum": 0.05, "maximum": 5},
        "initial_fraction": {"type": "number", "minimum": 0, "maximum": 1},
        "initial_target_open": {"type": "boolean"},
        "blocker_mask_role": {"const": "actors_corpses_pushables_reserved_areas"}
      }
    },
    "anchors": {
      "type": "object", "additionalProperties": false,
      "required": ["spawn", "wait_inside", "portal_inside", "portal_outside", "clear_outside", "duty"],
      "properties": {
        "spawn": {"$ref": "#/$defs/vec3"}, "wait_inside": {"$ref": "#/$defs/vec3"},
        "portal_inside": {"$ref": "#/$defs/vec3"}, "portal_outside": {"$ref": "#/$defs/vec3"},
        "clear_outside": {"$ref": "#/$defs/vec3"}, "duty": {"$ref": "#/$defs/vec3"}
      }
    },
    "stockroom": {
      "type": "object", "additionalProperties": false,
      "required": ["room_id", "polygon_xz", "floor_y", "ceiling_y", "anchors", "to_wait", "exit_to_duty", "capsule_radius_m", "capsule_height_m", "spawn_visual_bounds", "occluder_ids", "all_opening_ids", "respawn_delay_us", "slot_capacity"],
      "properties": {
        "room_id": {"$ref": "#/$defs/id"},
        "polygon_xz": {"type": "array", "minItems": 3, "maxItems": 64, "items": {"$ref": "#/$defs/vec2"}},
        "floor_y": {"type": "number"}, "ceiling_y": {"type": "number"},
        "anchors": {"$ref": "#/$defs/anchors"},
        "to_wait": {"$ref": "#/$defs/path"}, "exit_to_duty": {"$ref": "#/$defs/path"},
        "capsule_radius_m": {"type": "number", "exclusiveMinimum": 0},
        "capsule_height_m": {"type": "number", "exclusiveMinimum": 0},
        "spawn_visual_bounds": {"$ref": "#/$defs/box"},
        "occluder_ids": {"type": "array", "minItems": 1, "uniqueItems": true, "items": {"$ref": "#/$defs/id"}},
        "all_opening_ids": {"type": "array", "minItems": 1, "uniqueItems": true, "items": {"$ref": "#/$defs/id"}},
        "respawn_delay_us": {"const": 60000000},
        "slot_capacity": {"const": 1}
      }
    },
    "record": {
      "type": "object", "additionalProperties": false, "required": ["state", "asset_id"],
      "properties": {
        "state": {"enum": ["UNRESOLVED", "VERIFIED"]}, "asset_id": {"$ref": "#/$defs/id"},
        "service_id": {"$ref": "#/$defs/id"}, "building_id": {"$ref": "#/$defs/id"},
        "stockroom_id": {"$ref": "#/$defs/id"}, "doorway_id": {"$ref": "#/$defs/id"},
        "generation": {"type": "integer", "minimum": 0, "maximum": 2147483647},
        "scene_snapshot_sha256": {"$ref": "#/$defs/hash"},
        "geometry_manifest_sha256": {"$ref": "#/$defs/hash"},
        "root_approval_id": {"$ref": "#/$defs/id"},
        "building_to_world": {"$ref": "#/$defs/xform"},
        "space": {"const": "BUILDING_METRIC_RIGHT_HANDED_Y_UP"},
        "doorway": {"$ref": "#/$defs/doorway"}, "stockroom": {"$ref": "#/$defs/stockroom"},
        "missing": {"type": "array", "minItems": 1, "items": {"$ref": "#/$defs/id"}}
      },
      "allOf": [
        {"if": {"properties": {"state": {"const": "UNRESOLVED"}}}, "then": {"required": ["missing"], "not": {"anyOf": [{"required": ["doorway"]}, {"required": ["stockroom"]}]}}},
        {"if": {"properties": {"state": {"const": "VERIFIED"}}}, "then": {
          "required": ["service_id", "building_id", "stockroom_id", "doorway_id", "generation", "scene_snapshot_sha256", "geometry_manifest_sha256", "root_approval_id", "building_to_world", "space", "doorway", "stockroom"],
          "not": {"required": ["missing"]}
        }}
      ]
    }
  }
}
```

## Файл 3 — `s00_interiors/service_stockrooms.pending.json`

Это **не полный service manifest**. Он намеренно не содержит фиктивного `building_id`, координат кладовки или принятого printshop-пилота.

```json
{
  "schema_version": 1,
  "source_commit": "3612fa62f8d3bcb6888c7028ed0791fe0c928085",
  "service_inventory_complete": false,
  "expected_service_ids": [],
  "records": [
    {
      "state": "UNRESOLVED",
      "asset_id": "print_shop",
      "missing": [
        "Root authoritative service_id and placed building_id",
        "Accepted generated stockroom geometry and actual moving door",
        "Six measured anchors and continuous capsule-tested paths",
        "Whole spawn visual-volume occlusion through every opening",
        "Scene generation, geometry manifest hash and Root approval",
        "Dirty printshop WIP is not an accepted canonical or LIVE snapshot"
      ]
    }
  ]
}
```

## Файл 4 — `s00_interiors/door_controller.gd`

Важные границы этого controller:

- Поддерживает только вертикальные створки с **1–4 BoxShape3D на створку**, без scale/shear в управляющем frame. Иная геометрия требует отдельного адаптера, не аппроксимации здесь.
- `guard` должен охватывать проём, полный collision sweep и дополнительный отступ 2 см. Экстремумы вращающихся углов проверяются аналитически.
- Root передаёт **уже существующие** `AnimatableBody3D`; controller не создаёт и не удаляет их коллизии.
- Root назначает `sync_to_physics=false`, поскольку перемещение выполняется непосредственно в physics callback; с `move_and_collide()` этот controller не смешивается. Семантика AnimatableBody3D подтверждена документацией, но конкретный proposal ещё не выполнялся движком. :chatgpt-content-reference{index="5"}

```gdscript
extends Node3D
# Proposal only. Root imports approved, metre-space bodies; this is NOT an importer.
# Attach each leaf as a direct AnimatableBody3D child with sync_to_physics=false.
signal pose_changed(fraction: float, blocked: bool)

class Motion extends RefCounted:
	var fraction := 0.0
	var target := 0.0
	var seconds := 0.6
	var blocked := false
	var hold_token := ""
	var last_tick := -1

	func open(token: String = "") -> bool:
		if not token.is_empty():
			if not hold_token.is_empty() and hold_token != token:
				return false
			hold_token = token
		target = 1.0
		return true

	func close() -> bool:
		if not hold_token.is_empty():
			return false
		target = 0.0
		return true

	func release(token: String) -> bool:
		if token.is_empty() or token != hold_token:
			return false
		hold_token = ""
		return true

	func advance(dt: float, tick: int, clear: bool) -> bool:
		if tick <= last_tick or not is_finite(dt) or dt < 0.0 or not is_finite(seconds) or seconds <= 0.0:
			return false
		last_tick = tick
		blocked = fraction != target and not clear
		if blocked or dt == 0.0:
			return false
		var previous := fraction
		fraction = move_toward(fraction, target, minf(dt, 0.1) / seconds)
		return fraction != previous

	func angle(open_angle: float) -> float:
		return open_angle * fraction * fraction * (3.0 - 2.0 * fraction)

@export var enabled := false
var motion := Motion.new()
var queries := 0
var fault := "UNBOUND"
var generation := -1
var _bound := false
var _leaves: Array[AnimatableBody3D] = []
var _closed: Array[Transform3D] = []
var _angles: Array[float] = []
var _shape_rows: Array[Dictionary] = []
var _body_flags: Array[Vector2i] = []
var _root_pose := Transform3D.IDENTITY
var _query := PhysicsShapeQueryParameters3D.new()
var _query_local := Transform3D.IDENTITY

static func _rigid(t: Transform3D) -> bool:
	return t.origin.is_finite() and t.basis.is_finite() and is_equal_approx(t.basis.determinant(), 1.0) and t.basis.is_equal_approx(t.basis.orthonormalized())

static func _leaf_pose(closed: Transform3D, angle: float) -> Transform3D:
	return closed * Transform3D(Basis(Vector3.UP, angle), Vector3.ZERO
<!-- END EXACT RECEIVED PREFIX -->

