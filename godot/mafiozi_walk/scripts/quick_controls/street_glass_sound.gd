extends Node
## Original cached glass fracture PCM; no decoding, generation or allocation of
## players on a hit. Owns sound presentation only, never hit/break authority.
const CAPACITY := 4
const MAX_DISTANCE_M := 30.0
const MIX_RATE := 24000
# The original RIFF bytes use a non-imported extension so exports keep the
# exact validated payload; Godot must not replace it with an imported sample.
const WAVE_NAMES := ["street_glass_break_01.bytes", "street_glass_break_02.bytes", "street_glass_break_03.bytes"]
static var _shared_streams: Array[AudioStreamWAV] = []
static var _shared_pcm_bytes := 0
static var _cache_loads := 0
var _world: WeakRef
var _voices: Array[AudioStreamPlayer3D] = []
var _serials: Array[int] = []
var _ready := false
var _retired := false
var _played := 0
var _stolen := 0
var _culled := 0

func _init() -> void:
	set_process(false)
	set_physics_process(false)
	set_process_input(false)
	process_mode = Node.PROCESS_MODE_INHERIT

func configure(parent: Node3D) -> bool:
	if _ready or _retired or not is_inside_tree() or not is_instance_valid(parent) or not parent.is_inside_tree(): return false
	if not _load_shared(): return false
	_world = weakref(parent)
	for i in CAPACITY:
		var voice := AudioStreamPlayer3D.new()
		voice.name = "StreetGlassVoice%d" % i
		voice.top_level = true
		voice.volume_db = -7.0
		voice.max_db = -7.0
		voice.unit_size = 4.0
		voice.max_distance = MAX_DISTANCE_M
		voice.doppler_tracking = AudioStreamPlayer3D.DOPPLER_TRACKING_DISABLED
		add_child(voice)
		_voices.append(voice)
		_serials.append(0)
	parent.tree_exiting.connect(dispose, CONNECT_ONE_SHOT)
	_ready = true
	return true

func _load_shared() -> bool:
	if _shared_streams.size() == WAVE_NAMES.size(): return true
	var streams: Array[AudioStreamWAV] = []
	var total_bytes := 0
	var folder: String = get_script().resource_path.get_base_dir().path_join("../../audio").simplify_path()
	for filename: String in WAVE_NAMES:
		var bytes := FileAccess.get_file_as_bytes(folder.path_join(filename))
		# Our pinned offline writer emits a conventional 44-byte PCM RIFF header.
		# Validate the complete header before exposing any shared stream.
		if bytes.size() < 44 or bytes.slice(0, 4).get_string_from_ascii() != "RIFF" or bytes.slice(8, 12).get_string_from_ascii() != "WAVE": return false
		if bytes.decode_u32(4) + 8 != bytes.size() or bytes.slice(12, 16).get_string_from_ascii() != "fmt " or bytes.decode_u32(16) != 16: return false
		if bytes.decode_u16(20) != 1 or bytes.decode_u16(22) != 1 or bytes.decode_u32(24) != MIX_RATE: return false
		if bytes.decode_u32(28) != MIX_RATE * 2 or bytes.decode_u16(32) != 2 or bytes.decode_u16(34) != 16: return false
		if bytes.slice(36, 40).get_string_from_ascii() != "data" or bytes.decode_u32(40) != bytes.size() - 44 or (bytes.size() - 44) % 2 != 0: return false
		var stream := AudioStreamWAV.new()
		stream.format = AudioStreamWAV.FORMAT_16_BITS
		stream.mix_rate = MIX_RATE
		stream.stereo = false
		stream.loop_mode = AudioStreamWAV.LOOP_DISABLED
		stream.data = bytes.slice(44)
		streams.append(stream)
		total_bytes += bytes.size() - 44
	_shared_streams = streams
	_shared_pcm_bytes = total_bytes
	_cache_loads += 1
	return true

func play_break(point: Vector3) -> bool:
	if not _live() or not point.is_finite() or get_tree().paused: return false
	var camera := get_viewport().get_camera_3d()
	if is_instance_valid(camera) and camera.global_position.distance_squared_to(point) > MAX_DISTANCE_M * MAX_DISTANCE_M:
		_culled += 1
		return false
	var chosen := -1
	var oldest := 0
	for i in _voices.size():
		if not _voices[i].playing:
			chosen = i
			break
		if _serials[i] < _serials[oldest]: oldest = i
	if chosen < 0:
		chosen = oldest
		_stolen += 1
	var voice: AudioStreamPlayer3D = _voices[chosen]
	voice.stop()
	voice.stream = _shared_streams[_played % _shared_streams.size()]
	voice.pitch_scale = 1.0
	voice.global_position = point
	_played += 1
	_serials[chosen] = _played
	voice.play()
	return true

func _live() -> bool:
	if not _ready or _retired or not is_inside_tree() or is_queued_for_deletion() or _world == null: return false
	var world: Variant = _world.get_ref()
	return is_instance_valid(world) and world.is_inside_tree() and not world.is_queued_for_deletion()

func stats() -> Dictionary:
	var active := 0
	for voice: Variant in _voices:
		if is_instance_valid(voice) and voice.playing: active += 1
	return {"ready": _live(), "capacity": CAPACITY, "voices": _voices.size(), "active": active, "played": _played, "stolen": _stolen, "culled": _culled, "shared_streams": _shared_streams.size(), "shared_pcm_bytes": _shared_pcm_bytes, "cache_loads": _cache_loads, "max_distance_m": MAX_DISTANCE_M}

func dispose() -> void:
	if _retired: return
	_ready = false
	_retired = true
	if _world != null:
		var world: Variant = _world.get_ref()
		if is_instance_valid(world) and world.tree_exiting.is_connected(dispose): world.tree_exiting.disconnect(dispose)
	_world = null
	for voice: Variant in _voices:
		if is_instance_valid(voice):
			voice.stop()
			voice.queue_free()
	_voices.clear()
	_serials.clear()

func _exit_tree() -> void:
	dispose()
