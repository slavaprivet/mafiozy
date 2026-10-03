extends Node
## One cached PCM loop, played only by the local seated driver.
const SAMPLE_RATE := 22050
const LOOP_SAMPLES := 2205
static var _shared_wave: AudioStreamWAV
var _world: Node
var _player: Node
var _transport: Node
var _audio: AudioStreamPlayer3D
var _requested := false

func configure(world: Node, player: Node, transport: Node) -> void:
	stop()
	_world = world
	_player = player
	_transport = transport
	# Inherit pause: the parent's update stops while paused, so audio must pause too.
	process_mode = Node.PROCESS_MODE_INHERIT
	if not is_instance_valid(_audio):
		_audio = AudioStreamPlayer3D.new()
		_audio.name = "LocalCarHorn"
		_audio.stream = wave()
		_audio.volume_db = -10.0
		_audio.max_db = -10.0
		_audio.unit_size = 8.0
		_audio.max_distance = 70.0
		add_child(_audio)

static func wave() -> AudioStreamWAV:
	if _shared_wave != null:
		return _shared_wave
	var pcm := PackedByteArray()
	pcm.resize(LOOP_SAMPLES * 2)
	# Integer periods of both tones make a seamless loop without streaming work.
	for index in range(LOOP_SAMPLES):
		var time := float(index) / SAMPLE_RATE
		var sample := 0.17 * (sin(TAU * 400.0 * time) + sin(TAU * 500.0 * time))
		sample += 0.018 * (sin(TAU * 800.0 * time) + sin(TAU * 1000.0 * time))
		pcm.encode_u16(index * 2, int(round(sample * 32767.0)) & 0xffff)
	_shared_wave = AudioStreamWAV.new()
	_shared_wave.format = AudioStreamWAV.FORMAT_16_BITS
	_shared_wave.mix_rate = SAMPLE_RATE
	_shared_wave.stereo = false
	_shared_wave.data = pcm
	_shared_wave.loop_mode = AudioStreamWAV.LOOP_FORWARD
	_shared_wave.loop_begin = 0
	_shared_wave.loop_end = LOOP_SAMPLES
	return _shared_wave

func request(held: bool) -> void:
	_requested = held
	update_allowed()

func set_held(held: bool) -> void:
	request(held)

func allowed() -> bool:
	if not is_inside_tree() or get_tree().paused:
		return false
	if not is_instance_valid(_world) or not is_instance_valid(_player) or not is_instance_valid(_transport):
		return false
	if _world.preview_dead or _world.preview_physics_fault:
		return false
	if not _transport.ready_for_play or _transport.phase != "SEATED" or _transport.active_seat != "front_left":
		return false
	if not is_instance_valid(_transport.body) or not _transport.body.is_inside_tree():
		return false
	if not _player._free_mouse_look:
		return false
	if DisplayServer.get_name() != "headless" and (Input.mouse_mode != Input.MOUSE_MODE_CAPTURED or not get_window().has_focus()):
		return false
	if _player.has_method("_text_control_focused") and _player._text_control_focused():
		return false
	var weapons: Node = _player._weapon_host
	if is_instance_valid(weapons) and weapons.has_method("controls_blocked") and weapons.controls_blocked():
		return false
	return true

func update_allowed() -> void:
	if not _requested or not allowed():
		stop()
		return
	if not is_instance_valid(_audio):
		return
	_audio.global_position = _transport.body.global_position + Vector3.UP * 0.6
	if not _audio.playing:
		_audio.play()

func stop() -> void:
	_requested = false
	if is_instance_valid(_audio):
		_audio.stop()

func _notification(what: int) -> void:
	if what == NOTIFICATION_APPLICATION_FOCUS_OUT or what == NOTIFICATION_WM_WINDOW_FOCUS_OUT or what == NOTIFICATION_PAUSED:
		stop()

func _exit_tree() -> void:
	stop()
