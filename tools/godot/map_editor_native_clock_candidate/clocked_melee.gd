extends "res://scripts/combat/preview_melee.gd"
## Exact preview_melee.gd configure seam (SHA 5098c2a1...), with the optional
## InputPort clock supplied by this same host. Source/Input implementations stay raw.
var gameplay_clock: RefCounted

func bind_gameplay_clock(clock: RefCounted) -> bool:
	if gameplay_clock != null or clock == null: return false
	gameplay_clock = clock
	return true

func clock_ms() -> float:
	return gameplay_clock.now_ms() if gameplay_clock != null else NAN

func clock_seconds() -> float: return clock_ms() / 1000.0

func configure(scene: Node3D, player: CharacterBody3D, physical_pose: RefCounted) -> bool:
	if _bound or not is_instance_valid(scene) or not is_instance_valid(player) or physical_pose == null: return false
	if player._locomotion == null or not is_instance_valid(player._pose_skeleton): return false
	_scene = scene; _player = player; _physical_pose = physical_pose
	_pose = Pose.new()
	if not _pose.configure(player._pose_skeleton, player._pose_motion, player._locomotion._rest_poses, player._model_scale, player._visual): return false
	_source = SourcePort.new()
	if not _source.configure({"state":source_state,"clock_ms":clock_ms,"rng":random_draw,"effect":effect,"resolve_contact":resolve_contact}).get("ok", false): return false
	_input = InputPort.new()
	if not _input.configure({"beginWalkMelee":Callable(_source,"beginWalkMelee"),"setWalkMeleeCharge":Callable(_source,"setWalkMeleeCharge"),"setWalkMeleeBlock":Callable(_source,"setWalkMeleeBlock")},clock_seconds).get("ok",false): return false
	_rng.randomize()
	_camera_home = Vector2(player._camera.h_offset, player._camera.v_offset)
	_epoch = player._pose_epoch; _bound = true
	return true
