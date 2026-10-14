extends SceneTree
## Coordinator-owned sole-window QA. Does not enable production defaults.
const ORDER := [false, true, true, false]
const MAX_READBACK_BYTES := 16 * 1024 * 1024
const READBACK_ENGINE_HASH := "ed1daf0bf001b61586d9930840f2f1394092c079"
var _main: Node3D
var _camera: Camera3D
var _selftest := false
var _out := ""
var _errors: Array[String] = []
var _watching := false
var _input_seen := false
var _focus_lost := false
var _cancelled := false
var _measuring := false
var _settings: Dictionary = {}
var _gpu_pending := false
var _gpu_result: Dictionary = {}
var _views: Array[Dictionary] = []
var _notes_timers_stopped := 0
var _abort_test := false
var _viewport_size: Vector2i

class InputObserver extends Node:
	var qa: SceneTree
	func _input(event: InputEvent) -> void:
		if qa.get("_watching") and (event is InputEventKey or event is InputEventMouseMotion or event is InputEventMouseButton or event is InputEventJoypadButton or event is InputEventJoypadMotion):
			qa.set("_input_seen", true)

func _initialize() -> void:
	call_deferred("run")

func run() -> void:
	for arg in OS.get_cmdline_user_args():
		if arg == "--static-qa-selftest":
			_selftest = true
		elif arg == "--static-qa-selftest-abort":
			_abort_test = true
		elif arg.begins_with("--static-qa-output="):
			_out = arg.trim_prefix("--static-qa-output=")
	if not _out.is_absolute_path() or _selftest != (DisplayServer.get_name() == "headless") or (_abort_test and not _selftest):
		_errors.append("Absolute output and matching native/headless mode required")
	for arg in OS.get_cmdline_args() + OS.get_cmdline_user_args():
		if arg.begins_with("--fixed-fps") or arg.begins_with("--preview-capture") or arg in ["--preview-perf", "--preview-static-batch", "--preview-static-batch-off"]:
			_errors.append("Conflicting measurement argument: " + arg)
	var scene: PackedScene = load("res://scenes/main.tscn")
	if scene == null:
		push_error("Actual main unavailable; cannot restore interactive scene")
		quit(2) # Only unrecoverable startup failure quits a native window.
		return
	var observer := InputObserver.new()
	observer.qa = self
	root.add_child(observer)
	var windows: Array[Dictionary] = []
	var captures: Array[Dictionary] = []
	var readbacks: Array[Dictionary] = []
	var source_receipts := {}
	if _errors.is_empty():
		if DirAccess.make_dir_recursive_absolute(_out) != OK:
			_errors.append("Cannot create output directory")
	if _errors.is_empty():
		_main = scene.instantiate()
		if not _main.has_method("apply_preview_static_batches") or not _main.has_method("restore_preview_static_batches"):
			_errors.append("Actual main lacks the static batch API")
		else:
			_main.set("preview_static_batch_enabled", false)
			root.add_child(_main)
			if not _main.get("preview_ready") or _main.get("static_batch_status") != "disabled":
				_errors.append("Actual main OFF admission failed")
	if _errors.is_empty():
		for path: String in ["res://data/block.json", "res://data/preview_water.json", "res://data/printshop_interior.json", "res://scripts/preview_static_batch.gd", "res://scripts/main.gd"]:
			source_receipts[path] = FileAccess.get_sha256(path) if FileAccess.file_exists(path) else "not_exposed_in_pack"
		_prepare_static_scene()
		_settings = _render_settings()
		_viewport_size = root.size
		await process_frame
		await process_frame # Let mouse release/initial window activation settle.
		_watching = true
		if _views.size() != 4:
			_errors.append("Actual gunshop/pawnshop camera anchors unavailable")
	if _errors.is_empty():
		for index in range(ORDER.size()):
			if _abort_requested() or not _set_batches(ORDER[index]):
				break
			_set_view(0)
			var warmup_us: int = 20000 if _selftest else 5000000
			var until := Time.get_ticks_usec() + warmup_us
			while Time.get_ticks_usec() < until and not _abort_requested():
				await process_frame
			if _abort_requested():
				break
			var frame_count: int = 12 if _selftest else 600
			var wall := PackedInt64Array()
			var calls := PackedInt64Array()
			var primitives := PackedInt64Array()
			wall.resize(frame_count)
			calls.resize(frame_count)
			primitives.resize(frame_count)
			await process_frame
			var previous := Time.get_ticks_usec()
			var count := 0
			_measuring = true
			for frame in range(frame_count):
				await process_frame
				var now := Time.get_ticks_usec()
				if _abort_test and index == 1 and frame == 2:
					_input_seen = true
				if _abort_requested():
					break
				wall[count] = now - previous
				previous = now
				calls[count] = int(Performance.get_monitor(Performance.RENDER_TOTAL_DRAW_CALLS_IN_FRAME))
				primitives[count] = int(Performance.get_monitor(Performance.RENDER_TOTAL_PRIMITIVES_IN_FRAME))
				count += 1
			_measuring = false
			wall.resize(count)
			calls.resize(count)
			primitives.resize(count)
			windows.append({"index":index,"enabled":ORDER[index],"status":_main.get("static_batch_status"),
				"summary":_main.get("static_batch_summary").duplicate(true),"warmup_us":warmup_us,"frames":count,
				"camera":str(_camera.global_transform),"settings":_render_settings(),"wall_us":_stats(wall),
				"draw_calls":_stats(calls),"primitives":_stats(primitives),"raw_wall_us":Array(wall)})
			if _abort_requested():
				break
			if index == 1:
				readbacks.append(await _readback())
			if index < 2 and not _abort_requested():
				captures.append(await _capture_view(0, ORDER[index]))
	# Additional three OFF/ON angles are outside all timing windows.
	if _errors.is_empty() and not _abort_requested():
		for view in range(1, 4):
			var pair: Array[Dictionary] = []
			for enabled in [false, true]:
				if _abort_requested() or not _set_batches(enabled):
					break
				_set_view(view)
				for i in range(3 if _selftest else 30):
					await process_frame
					if _abort_requested():break
				if not _abort_requested():pair.append(await _capture_view(view, enabled))
			captures.append_array(pair)
			if _abort_requested():break
	_watching = false
	_measuring = false
	if _cancelled:
		_errors.append("QA cancelled by input/focus/settings; partial measurements are invalid")
	# Restore control BEFORE image comparison/report disk IO. Fresh main restores
	# its own water clock, notes timer, ordinary controller and printshop spawn.
	if is_instance_valid(_main):
		_main.free()
	_main = scene.instantiate()
	root.add_child(_main)
	var restored: bool = bool(_main.get("preview_ready")) and _main.get("_player") != null
	if not restored:
		_errors.append("Interactive main restore failed")
	var comparisons: Array[Dictionary] = []
	if not _selftest and not _cancelled:
		for view in range(4):
			comparisons.append(_compare_images(view))
	var report := {"passed":_errors.is_empty() and windows.size()==4,"errors":_errors,"headless_selftest":_selftest,
		"native_render_evidence":not _selftest,"input_seen":_input_seen,"focus_lost":_focus_lost,"cancelled":_cancelled,
		"engine":Engine.get_version_info(),"renderer":RenderingServer.get_current_rendering_method(),"executable":OS.get_executable_path(),
		"qualification":"One static small preview quarter, NPC0/vehicles0; wall frame intervals, not GPU timestamps or whole-game FPS. Same scene reused OFF/ON/ON/OFF. Water sample frozen at0, main/player callbacks frozen, notes Timer stopped. No PNG/JSON/readback inside timed windows. Native debug engine with candidate PCK; headless is control-flow-only.",
		"windows":windows,"captures":captures,"image_comparisons":comparisons,"gpu_readbacks":readbacks,
		"notes_timers_stopped":_notes_timers_stopped,"sources":source_receipts,"views":_views,
		"interactive_restored":restored,"restored_spawn":str(_main.get("_spawn")),"visual_review_required":not _selftest}
	if _out.is_absolute_path():
		var file := FileAccess.open(_out.path_join("report.json"),FileAccess.WRITE)
		if file != null:
			file.store_string(JSON.stringify(report))
			file.close()
		else:
			push_error("Static QA report unavailable; interactive scene remains restored")
	print("STATIC_RENDER_QA_COMPLETE passed=",report.passed," interactive_restored=",restored," headless=",_selftest)
	if _selftest:
		quit(0 if (restored and _cancelled if _abort_test else report.passed) else 1)

func _prepare_static_scene() -> void:
	_main.set_process(false)
	_main.set_physics_process(false)
	var player: Node = _main.get("_player")
	player.call("set_mouse_captured",false)
	player.set_physics_process(false)
	player.set_process_unhandled_input(false)
	var water: RefCounted = _main.get("_water_host")
	if water != null:water.call("advance",0.0)
	for timer: Node in _main.find_children("NotesPoll","Timer",true,false):
		timer.call("stop")
		_notes_timers_stopped += 1
	var anchors := {}
	for record: Dictionary in _main.get("_block").buildings:
		if record.assetId in ["gun_shop","pawnshop"]:
			var position: Array = record.positionLocalM
			anchors[record.assetId] = Vector3(position[0],position[1],position[2])
	if anchors.size()!=2:return
	var gun: Vector3 = anchors.gun_shop
	var pawn: Vector3 = anchors.pawnshop
	var center := (gun+pawn)*.5 + Vector3.UP*4.0
	var distance := maxf(45.0,gun.distance_to(pawn)*1.25)
	_views = [
		{"name":"both-east","position":center+Vector3(distance,distance*.45,0),"target":center},
		{"name":"gunshop-oblique","position":gun+Vector3(24,9,18),"target":gun+Vector3.UP*4},
		{"name":"pawnshop-oblique","position":pawn+Vector3(24,9,-18),"target":pawn+Vector3.UP*4},
		{"name":"both-west-culling","position":center+Vector3(-distance,distance*.4,distance*.6),"target":center}]
	_camera = Camera3D.new()
	_camera.fov=65.0
	_camera.near=.08
	_camera.far=1600.0
	_main.add_child(_camera)
	_camera.make_current()
	_set_view(0)

func _set_view(index: int) -> void:
	_camera.global_position = _views[index].position
	_camera.look_at(_views[index].target)

func _set_batches(enabled: bool) -> bool:
	if enabled:
		if not bool(_main.call("apply_preview_static_batches")) or _main.get("static_batch_status") != "ready":
			_errors.append("Static batching failed admission")
			return false
	else:
		_main.call("restore_preview_static_batches","render_qa_off")
		if _main.get("_static_batch_lease") != null:
			_errors.append("Static batching restore left an active lease")
			return false
	return true

func _render_settings() -> Dictionary:
	return {"viewport":str(root.size),"msaa":root.msaa_3d,"render_scale":root.scaling_3d_scale,
		"vsync":DisplayServer.window_get_vsync_mode(),"max_fps":Engine.max_fps,"physics_hz":Engine.physics_ticks_per_second,
		"time_scale":Engine.time_scale,"paused":paused,"renderer":RenderingServer.get_current_rendering_method()}

func _abort_requested() -> bool:
	if not _watching:return _cancelled
	_focus_lost = _focus_lost or (not _selftest and not DisplayServer.window_is_focused())
	# No per-frame Dictionary/string allocation in the measurement observer.
	if _input_seen or _focus_lost or root.size!=_viewport_size or root.msaa_3d!=_settings.msaa or root.scaling_3d_scale!=_settings.render_scale or DisplayServer.window_get_vsync_mode()!=_settings.vsync or Engine.max_fps!=_settings.max_fps or Engine.physics_ticks_per_second!=_settings.physics_hz or Engine.time_scale!=_settings.time_scale or paused!=_settings.paused:
		_cancelled=true
	return _cancelled

func _stats(values: PackedInt64Array) -> Dictionary:
	if values.is_empty():return {"count":0}
	var sorted:=values.duplicate()
	sorted.sort()
	return {"count":sorted.size(),"p50":sorted[int(ceil(sorted.size()*.5))-1],"p95":sorted[int(ceil(sorted.size()*.95))-1],"max":sorted[-1]}

func _capture_view(view: int, enabled: bool) -> Dictionary:
	var path := _out.path_join("view-%d-%s.png" % [view,"on" if enabled else "off"])
	var result := {"view":view,"enabled":enabled,"camera":str(_camera.global_transform),"fov":_camera.fov,"path":path,"headless_skipped":_selftest}
	if not _selftest:
		await RenderingServer.frame_post_draw
		if _abort_requested():return result
		var error := root.get_texture().get_image().save_png(path)
		result["save_error"]=error
		if error != OK:_errors.append("Viewport capture failed: "+path)
	return result

func _compare_images(view: int) -> Dictionary:
	var off_path := _out.path_join("view-%d-off.png" % view)
	var on_path := _out.path_join("view-%d-on.png" % view)
	if not FileAccess.file_exists(off_path) or not FileAccess.file_exists(on_path):return {"view":view,"available":false}
	var off:=Image.load_from_file(off_path)
	var on:=Image.load_from_file(on_path)
	if off==null or on==null or off.get_size()!=on.get_size():return {"view":view,"available":false}
	var result := {"view":view,"available":true,"off":off_path,"on":on_path,"exact_pixels_equal":off.get_data()==on.get_data(),"review":"Compare facade materials, normals/light direction, cast shadows and silhouette/culling. Pixel differences require human review, not automatic rejection."}
	if off.has_method("compute_image_metrics"):
		result["metrics"]=off.call("compute_image_metrics",on,false)
	return result

func _readback() -> Dictionary:
	var lease: RefCounted = _main.get("_static_batch_lease")
	if lease==null:
		_errors.append("No active lease for readback")
		return {"passed":false}
	var receipts: Array = lease.call("batch_receipts")
	var requests: Array[Dictionary] = []
	var byte_count := 0
	var metadata: Array[Dictionary] = []
	for receipt: Dictionary in receipts:
		var batch: MultiMeshInstance3D = receipt.batch.get_ref()
		if not is_instance_valid(batch):
			_errors.append("Receipt batch no longer exists")
			return {"passed":false}
		if batch.multimesh.transform_format!=MultiMesh.TRANSFORM_3D or batch.multimesh.use_colors or batch.multimesh.use_custom_data or batch.multimesh.instance_count!=receipt.instance_transforms.size():
			_errors.append("Unsupported MultiMesh layout; refusing inferred GPU stride")
			return {"passed":false,"status":"unsupported_layout"}
		var expected := PackedFloat32Array()
		for transform: Transform3D in receipt.instance_transforms:
			var b:=transform.basis
			var p:=transform.origin
			expected.append_array(PackedFloat32Array([b.x.x,b.y.x,b.z.x,p.x,b.x.y,b.y.y,b.z.y,p.y,b.x.z,b.y.z,b.z.z,p.z]))
		byte_count += expected.size()*4
		requests.append({"rid":batch.multimesh.get_rid(),"expected":expected})
		metadata.append({"source_ids":receipt.source_ids,"instances":receipt.instance_transforms.size(),"mesh_sha256":receipt.mesh_payload_sha256,"material_sha256":receipt.material_payload_sha256,"custom_aabb":str(receipt.custom_aabb)})
	if receipts.is_empty() or byte_count*2>MAX_READBACK_BYTES:
		_errors.append("Empty/oversized GPU readback request")
		return {"passed":false}
	if _selftest:
		return {"status":"HEADLESS_NOT_GPU_READBACK","passed":false,"skipped":true,"cpu_receipts":metadata,"expected_bytes":byte_count}
	if str(Engine.get_version_info().hash)!=READBACK_ENGINE_HASH:
		_errors.append("GPU layout not audited for this engine hash")
		return {"passed":false,"status":"unreviewed_engine_layout"}
	# Wait until uploads have rendered, then explicitly read the actual RD GPU
	# buffer. get_instance_transform / CPU receipts alone are not this evidence.
	await RenderingServer.frame_post_draw
	_gpu_pending=true
	RenderingServer.call_on_render_thread(_read_gpu.bind(requests))
	var deadline:=Time.get_ticks_usec()+10000000
	while _gpu_pending and Time.get_ticks_usec()<deadline:
		await process_frame
		_abort_requested()
	if _gpu_pending:
		_errors.append("Native GPU readback timed out")
		return {"passed":false,"status":"timeout"}
	var result:=_gpu_result.duplicate(true)
	result["cpu_receipts"]=metadata
	if not result.get("passed",false):_errors.append("Native GPU transform buffer readback failed")
	return result

func _read_gpu(requests: Array[Dictionary]) -> void:
	var rd:=RenderingServer.get_rendering_device()
	var result: Dictionary = {"passed":true,"status":"native_rendering_device_buffer_get_data","engine_layout_hash":READBACK_ENGINE_HASH,"batches":requests.size(),"floats":0,"single_bank_batches":0,"double_bank_batches":0,"max_abs_error":0.0}
	if rd==null:
		result={"passed":false,"status":"RenderingDevice unavailable; no GPU readback proof"}
	else:
		for request: Dictionary in requests:
			var buffer:=RenderingServer.multimesh_get_buffer_rd_rid(request.rid)
			var expected: PackedFloat32Array=request.expected
			if not buffer.is_valid():
				result.passed=false
				result.status="Invalid GPU MultiMesh buffer RID"
				break
			# Pinned renderer_rd/storage_rd/mesh_storage.cpp allocation uses 12
			# floats per admitted transform. Motion vectors may allocate two banks;
			# never guess their current offset. Both must match for static batches.
			var bytes:=rd.buffer_get_data(buffer)
			var actual:=bytes.to_float32_array()
			if actual.size()!=expected.size() and actual.size()!=expected.size()*2:
				result.passed=false
				result.status="Unexpected GPU allocation size; no stride/offset inference"
				break
			if actual.size()==expected.size():result.single_bank_batches+=1
			else:result.double_bank_batches+=1
			for i in range(actual.size()):
				var error:=absf(actual[i]-expected[i % expected.size()])
				if not is_finite(actual[i]) or error>.00001:result.passed=false
				result.max_abs_error=maxf(result.max_abs_error,error)
			result.floats += actual.size()
	call_deferred("_receive_gpu",result)

func _receive_gpu(result: Dictionary) -> void:
	_gpu_result=result
	_gpu_pending=false
