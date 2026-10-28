extends Node3D
## Recorded CC0 foley; observes gait support without driving animation/movement.
const SURFACES := ["stone", "wood", "dirt", "grass"]
const VARIANTS := 5
const STRIDE_WALK := PI/2.3
const STRIDE_RUN := STRIDE_WALK
var _player: CharacterBody3D
var _players: Dictionary = {}
var _voices: Array[AudioStreamPlayer3D] = []
var _bags: Dictionary = {}
var _last_variant: Dictionary = {}
var _rng := RandomNumberGenerator.new()
var _accum := 0.0
var _last_position := Vector3.ZERO
var _have_last := false
var _muted := false
var _support := -1
var _last_play_time := -100.0
var _clock := 0.0
var _side := 0
var _rig: Skeleton3D
var _foot_bones: Array[int] = []
var events30: Array[Dictionary] = []
var suppressed_warps30 := 0
var _last_ground_point := Vector3.ZERO

func install(player: CharacterBody3D) -> void:
	_player=player
	process_priority=80
	_rng.randomize()
	_rig=player.get("_pose_skeleton") as Skeleton3D
	if is_instance_valid(_rig): _foot_bones=[_rig.find_bone("foot_l"),_rig.find_bone("foot_r")]
	for surface: String in SURFACES:
		var bank: Array[AudioStream]=[]
		for variant in range(1,VARIANTS+1):
			var stream:=_load_stream("res://audio/steps30/%s_%d.wav"%[surface,variant])
			if stream!=null:bank.append(stream)
		_players[surface]=bank
	for index in 8:
		var voice:=AudioStreamPlayer3D.new()
		voice.name="Footfall%d"%index
		voice.unit_size=3.0;voice.max_distance=22.0;voice.max_db=-5.0
		add_child(voice);_voices.append(voice)

func _load_stream(path: String) -> AudioStream:
	if not FileAccess.file_exists(path):return null
	var bytes:=FileAccess.get_file_as_bytes(path)
	if bytes.size()<44 or bytes.slice(0,4).get_string_from_ascii()!="RIFF" or bytes.slice(8,12).get_string_from_ascii()!="WAVE":return null
	var offset:=12
	var rate:=0
	var pcm:=false
	var data:=PackedByteArray()
	while offset+8<=bytes.size():
		var key:=bytes.slice(offset,offset+4).get_string_from_ascii()
		var size:=bytes.decode_u32(offset+4)
		var body:=offset+8
		if body+size>bytes.size():return null
		if key=="fmt " and size>=16:
			pcm=bytes.decode_u16(body)==1 and bytes.decode_u16(body+2)==1 and bytes.decode_u16(body+14)==16
			rate=bytes.decode_u32(body+4)
		elif key=="data":data=bytes.slice(body,body+size)
		offset=body+size+(size%2)
	if not pcm or rate<=0 or data.is_empty():return null
	var stream:=AudioStreamWAV.new()
	stream.format=AudioStreamWAV.FORMAT_16_BITS;stream.mix_rate=rate;stream.data=data
	return stream

func _foot_position(side: int) -> Vector3:
	if is_instance_valid(_rig) and side<_foot_bones.size() and _foot_bones[side]>=0:return _rig.global_transform*_rig.get_bone_global_pose(_foot_bones[side]).origin
	return _player.global_position

func surface_under_feet() -> String:
	if not is_instance_valid(_player):return "stone"
	var foot:=_foot_position(_side)
	var query:=PhysicsRayQueryParameters3D.create(foot+Vector3.UP*.35,foot-Vector3.UP*1.1,1,[_player.get_rid()])
	var hit:=_player.get_world_3d().direct_space_state.intersect_ray(query)
	_last_ground_point=hit.get("position",foot)
	var node: Node=hit.get("collider") as Node
	while is_instance_valid(node):
		var surface:=str(node.get_meta("surface","")).to_lower()
		if surface in ["concrete","rock","masonry"]:surface="stone"
		if surface in ["soil","earth","sand"]:surface="dirt"
		if SURFACES.has(surface):return surface
		var low:=String(node.name).to_lower()
		if "wood" in low or "plank" in low or "gate" in low:return "wood"
		if "grass" in low:return "grass"
		if "dirt" in low or "ground" in low or "soil" in low:return "dirt"
		node=node.get_parent()
	return "stone"

func _process(delta: float) -> void:
	_clock+=delta
	if not is_instance_valid(_player):return
	var at:=_player.global_position
	if not _have_last:_last_position=at;_have_last=true;return
	var displacement:=at-_last_position
	_last_position=at
	var travel:=Vector2(displacement.x,displacement.z).length()
	var velocity:=_player.get_real_velocity()
	var speed:=Vector2(velocity.x,velocity.z).length()
	var pose: Variant=_player.get("_locomotion")
	var support:=int(pose.get("_dsh_support_side")) if pose!=null else -1
	var unavailable:=_muted or not _player.is_on_floor() or bool(_player.get("_swimming")) or bool(_player.get("_mount_mode")) or bool(_player.get("_vehicle_hold"))
	var warp:=displacement.length()>maxf(.65,speed*minf(delta,.1)*1.8+.15)
	if warp:suppressed_warps30+=1
	if unavailable or warp or delta>.25 or speed<.25:
		_accum=0.0;_support=support;return
	_accum+=travel
	if support>=0:
		if _support<0:_support=support;return
		if support==_support:return
		_support=support
		if _accum<.12 or _clock-_last_play_time<.16:return
		_side=support
	else:
		if _accum<STRIDE_WALK or _clock-_last_play_time<.16:return
		_side=1-_side
	_accum=0.0
	_play(surface_under_feet(),speed)

func _play(surface: String,speed: float=3.2) -> void:
	var bank: Array=_players.get(surface,[])
	if bank.is_empty() or _voices.is_empty():return
	var bag: Array=_bags.get(surface,[])
	if bag.is_empty():
		for index in bank.size():bag.append(index)
		for i in range(bag.size()-1,0,-1):
			var j:=_rng.randi_range(0,i)
			var swap: int=bag[i];bag[i]=bag[j];bag[j]=swap
		if bag.size()>1 and bag.back()==_last_variant.get(surface,-1):
			var swap: int=bag[0];bag[0]=bag[-1];bag[-1]=swap
	var variant: int=bag.pop_back()
	_bags[surface]=bag;_last_variant[surface]=variant
	var voice: AudioStreamPlayer3D=null
	for candidate: AudioStreamPlayer3D in _voices:
		if not candidate.playing:voice=candidate;break
	if voice==null:return
	voice.stream=bank[variant]
	voice.global_position=_last_ground_point+Vector3.UP*.035
	voice.pitch_scale=_rng.randf_range(.965,1.035)
	voice.volume_db=lerpf(-10.5,-7.0,clampf(speed/5.8,0,1))+_rng.randf_range(-.5,.5)
	voice.play();_last_play_time=_clock
	events30.append({"surface":surface,"variant":variant,"side":_side,"time":_clock,"at":voice.global_position,"speed":speed,"support":_support,"volume_db":voice.volume_db})
	if events30.size()>200:events30.pop_front()

func set_muted(muted: bool) -> void:
	_muted=muted;_accum=0.0
	if muted:
		for voice: AudioStreamPlayer3D in _voices:voice.stop()
