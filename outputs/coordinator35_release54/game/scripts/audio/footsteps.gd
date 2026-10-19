class_name Footsteps
extends Node3D
## DSH_STEPS: footfalls that know what they are standing on.
##
## Four voices - stone, wood, dirt, grass - chosen by what is under the man, not by where
## he is: a raycast from the boots finds the collider, and a collider may say what it is by
## carrying `surface` metadata. Nothing plays when he is airborne, or standing still, and
## the stride is measured in metres walked rather than in seconds, so a walk and a run have
## the same length of step and the cadence follows the speed on its own.
##
## Generated at build time by tools/make_steps.py: four variants per surface, so a long walk
## never repeats itself.

const STRIDE_WALK := 1.85
const STRIDE_RUN := 2.35
const SURFACES := ["stone", "wood", "dirt", "grass"]
const VARIANTS := 4

var _player: CharacterBody3D
var _players: Dictionary = {}
var _accum: float = 0.0
var _last_position := Vector3.ZERO
var _have_last := false
var _muted := false

func install(player: CharacterBody3D) -> void:
	_player = player
	for surface: String in SURFACES:
		var pool: Array[AudioStreamPlayer3D] = []
		for variant: int in range(1, VARIANTS + 1):
			var path := "res://audio/steps/%s_%d.wav" % [surface, variant]
			var stream: AudioStream = _load_stream(path)
			if stream == null: continue
			var player_node := AudioStreamPlayer3D.new()
			player_node.stream = stream
			player_node.unit_size = 4.0
			player_node.max_distance = 24.0
			player_node.volume_db = -6.0
			add_child(player_node)
			pool.append(player_node)
		_players[surface] = pool

## A WAV that Godot has not imported (a run without the editor) still has to make a sound.
## The file is parsed here rather than trusted to an importer: it is PCM 16-bit mono, and
## reading the chunks is a dozen lines that work the same in every build.
func _load_stream(path: String) -> AudioStream:
	var imported: AudioStream = load(path)
	if imported != null: return imported
	if not FileAccess.file_exists(path): return null
	var file := FileAccess.open(path, FileAccess.READ)
	if file == null: return null
	var bytes := file.get_buffer(file.get_length())
	file.close()
	if bytes.size() < 44: return null
	if bytes.slice(0, 4).get_string_from_ascii() != "RIFF": return null
	if bytes.slice(8, 12).get_string_from_ascii() != "WAVE": return null
	var offset := 12
	var rate := 44100
	var channels := 1
	var bits := 16
	var data := PackedByteArray()
	while offset + 8 <= bytes.size():
		var chunk_id := bytes.slice(offset, offset + 4).get_string_from_ascii()
		var chunk_size := bytes.decode_u32(offset + 4)
		var body := offset + 8
		if body + chunk_size > bytes.size(): break
		if chunk_id == "fmt ":
			channels = bytes.decode_u16(body + 2)
			rate = bytes.decode_u32(body + 4)
			bits = bytes.decode_u16(body + 14)
		elif chunk_id == "data":
			data = bytes.slice(body, body + chunk_size)
		offset = body + chunk_size + (chunk_size % 2)
	if data.is_empty(): return null
	var wav := AudioStreamWAV.new()
	wav.format = AudioStreamWAV.FORMAT_16_BITS
	wav.mix_rate = rate
	wav.stereo = channels == 2
	wav.data = data
	return wav
## What is he standing on? A collider may answer directly through `surface` metadata; the
## castle tags its masonry, its gates and its ground, so the answer is exact there. Failing
## that, the name is a good guide, and failing that it is stone.
func surface_under_feet() -> String:
	if not is_instance_valid(_player): return "stone"
	var space: PhysicsDirectSpaceState3D = _player.get_world_3d().direct_space_state
	if space == null: return "stone"
	var from: Vector3 = _player.global_position + Vector3.UP * 0.4
	var query := PhysicsRayQueryParameters3D.create(from, from - Vector3.UP * 1.6, 1)
	query.exclude = [_player.get_rid()]
	var hit: Dictionary = space.intersect_ray(query)
	if hit.is_empty(): return "stone"
	var collider: Object = hit.get("collider")
	if not is_instance_valid(collider): return "stone"
	if collider.has_meta("surface"): return str(collider.get_meta("surface"))
	var name_lower := String((collider as Node).name).to_lower()
	if name_lower.contains("gate") or name_lower.contains("wood") or name_lower.contains("plank"):
		return "wood"
	if name_lower.contains("ground") or name_lower.contains("grass") or name_lower.contains("dirt"):
		return "dirt"
	return "stone"

func _physics_process(_delta: float) -> void:
	if _muted or not is_instance_valid(_player): return
	var position := _player.global_position
	if not _have_last:
		_last_position = position
		_have_last = true
		return
	var travelled := Vector2(position.x - _last_position.x, position.z - _last_position.z).length()
	_last_position = position
	if not _player.is_on_floor():
		return
	var speed := Vector2(_player.velocity.x, _player.velocity.z).length()
	if speed < 0.35:
		_accum = 0.0
		return
	_accum += travelled
	var stride := STRIDE_RUN if speed > 4.2 else STRIDE_WALK
	if _accum < stride: return
	_accum = 0.0
	_play(surface_under_feet())

func _play(surface: String) -> void:
	var pool: Array = _players.get(surface, [])
	if pool.is_empty(): return
	var candidates: Array = pool.filter(func(node: AudioStreamPlayer3D) -> bool: return not node.playing)
	if candidates.is_empty(): candidates = pool
	var chosen: AudioStreamPlayer3D = candidates[randi() % candidates.size()]
	chosen.pitch_scale = randf_range(0.92, 1.08)
	chosen.play()

func set_muted(muted: bool) -> void:
	_muted = muted
