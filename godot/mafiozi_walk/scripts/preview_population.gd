extends RefCounted
## Root-owned local session wiring. Native routes never grant source access.
const Residents = preload("res://scripts/npc_visual/preview_resident_host.gd")
const Policy = preload("res://scripts/npc_visual/preview_resident_world_policy.gd")
const Navigation = preload("res://scripts/navigation/preview_navigation_host.gd")
const Queue = preload("res://scripts/navigation/path_job_queue.gd")
const PACKET_SHA := "e9262db60404e538636274565b9a1d6d79de487804af9c7ee99646209b58e096"
const PREPARED_SHA := "3c07e72938a0918fa32de33ca442bf07cb50f21f0916b8b091b552473bd9aac0"
const BLOCK_SHA := "1523f52e2e859c42aec208d4acfffb9714ffb99974823098bb063e31ee61c22e"
const SESSION := "godot-preview-new-session-20260927-01"
const DIRECTORY := "res://assets/npc_visual/session/"
# Explicit new-session preview staging near the starting car. These are not
# original birth coordinates or a full-source population placement receipt.
const PREVIEW_STAGES := {
	"resident_72": Vector2(105.310391309785, 7.73170787532155),
	"resident_169": Vector2(105.310391309785, 9.56097616800448),
	"resident_252": Vector2(104.944537651248, 6.26829324117521),
}
var residents: RefCounted
var navigation: RefCounted
var policy: RefCounted
var owners := {}
var _queue: RefCounted
var status := "not_loaded"
var error := ""
var _disposed := false
var _staged_preview := false

func setup(scene: Node3D, staged_preview: bool = false, walking_preview: bool = true) -> bool:
	if _disposed or status != "not_loaded": return false
	status = "loading"
	var packet_path := DIRECTORY + PACKET_SHA + ".json"
	if FileAccess.get_sha256(packet_path) != PACKET_SHA:
		return _fail("unaccepted_session_packet")
	var packet := FileAccess.get_file_as_bytes(packet_path)
	var parsed: Dictionary = JSON.parse_string(packet.get_string_from_utf8())
	var sources := {}
	for receipt: Dictionary in parsed.source_receipts: sources[receipt.path] = receipt.sha256
	var states := {}
	for row: Dictionary in parsed.rows:
		owners[row.source_id] = Queue.Owner.new(row.source_id, 1)
		states[row.source_id] = "ordinary_outdoor"
	var trust := {"accepted": true, "packet_sha256": PACKET_SHA, "sources": sources,
		"session_id": SESSION, "prepared_sha256": PREPARED_SHA, "block_sha256": BLOCK_SHA}
	policy = Policy.new()
	var accepted: Dictionary = policy.configure(scene, parsed.rows, owners, trust, {"version": 1, "states": states})
	if not accepted.get("ok", false): return _fail("source_policy:" + str(accepted.get("error", "unknown")))
	_queue = Queue.new(); navigation = Navigation.new()
	if not navigation.attach_existing(scene, scene.get("_printshop"), scene.get("_block"), scene.get("_printshop_data"), _queue, SESSION, 1, 1):
		return _fail("navigation:" + str(navigation.diagnostics()))
	residents = Residents.new()
	var result: Dictionary = residents.configure(scene, navigation, packet, trust,
		FileAccess.get_file_as_bytes(DIRECTORY + "prepared/manifest.json"), DIRECTORY + "prepared",
		owners, Callable(policy, "source_admit"), Callable(policy, "support_height"))
	if not result.get("ok", false): return _fail("residents:" + str(result.get("error", "unknown")))
	# Cold asset verification/admission belongs to startup, before gameplay READY.
	if staged_preview:
		for row: Dictionary in parsed.rows:
			var stage: Vector2 = PREVIEW_STAGES[row.source_id]
			residents.admit_preview_stage(row.source_id, stage.y, stage.x)
		_staged_preview = true
		if walking_preview and residents.occupants().size() == parsed.rows.size(): residents.enable_walk_preview()
	else:
		for i in parsed.rows.size(): residents.admit_next()
	status = "ready" if residents.occupants().size() == parsed.rows.size() else "pending_placement"
	return true

func _fail(reason: String) -> bool:
	error = reason
	dispose()
	status = "failed"
	return false

func step(delta: float) -> void:
	if _disposed or residents == null: return
	navigation.pump(Engine.get_physics_frames())
	residents.step(delta)
	if _staged_preview: residents.preview_walk_step(delta)

func door_started(key: String, opening: bool) -> void:
	if not _disposed and navigation != null:
		navigation.door_transition_started(key, 1.0 if opening else 0.0)

func occupants() -> Array[Dictionary]:
	return residents.occupants() if not _disposed and residents != null else []

func request_walk(identity: String, target: Vector3) -> int:
	if _disposed or residents == null or navigation.state() != "READY": return -1
	return residents.request_walk(identity, target)

func snapshot() -> Dictionary:
	return {"status": status, "error": error, "session_id": SESSION,
		"placement_mode": "PREVIEW_STAGE" if _staged_preview else "SOURCE_BIRTH", "original_agenda": false,
		"residents": residents.snapshot() if residents != null else {},
		"navigation": navigation.diagnostics() if navigation != null else {}}

func dispose() -> void:
	if _disposed: return
	_disposed = true
	if residents != null: residents.dispose()
	if navigation != null: navigation.dispose()
	if _queue != null: _queue.dispose()
	if policy != null: policy.dispose()
	owners.clear()
	status = "disposed"
