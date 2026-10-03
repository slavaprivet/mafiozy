extends "../palazzo_site.gd"
## Reuse the accepted house/destruction. Variants change only palette and rooms.
@export_enum("brick", "sage", "ivory") var color_scheme: String = "brick"
@export_enum("two_rooms", "corridor", "front_hall") var room_layout: String = "two_rooms"
var interior_panels: Array[RigidBody3D] = []
var _palette: Array = []

func mat(color: Color, metallic: float = 0.0) -> StandardMaterial3D:
	if _palette.is_empty():
		match color_scheme:
			"sage": _palette=[Color("899889"),Color("d9d3bd"),Color("344347"),Color("4f6461")]
			"ivory": _palette=[Color("d0c7af"),Color("e5dfce"),Color("354554"),Color("435973")]
			_: _palette=[Color("ab7562"),Color("d6c5a3"),Color("3d4941"),Color("46584b")]
	var selected: Color=color
	if color==STONE: selected=_palette[0]
	elif color==TRIM: selected=_palette[1]
	elif color==DARK: selected=_palette[2]
	elif color==WINE: selected=_palette[3]
	return super.mat(selected,metallic)

func _build_building() -> void:
	# Assemble and batch once, after adding the interior to the same body lists.
	var use_batches: bool=batched
	batched=false
	super._build_building()
	interior_panels.clear()
	for floor_index: int in 2:
		var base: float=.30+floor_index*2.70
		match room_layout:
			"corridor":
				_partition_with_door(Vector3(.15,base,-.46),4.62,-.3+.46,PI*.5)
				_partition_with_door(Vector3(1.85,base,-.46),4.62,-.3+.46,PI*.5)
			"front_hall":
				_partition_with_door(Vector3(0,base,-.65),7.56,1.0,0.0)
			_:
				_partition_with_door(Vector3(-.7,base,0),5.54,-.8,PI*.5)
	for body: RigidBody3D in pieces:
		if str(body.name).begins_with("LobbyTable"):
			body.position=Vector3(-2.2,.95,1.1) if room_layout!="front_hall" else Vector3(-1.2,.95,-1.8)
			initial_transforms[body.get_instance_id()]=body.global_transform
	for wall: RigidBody3D in interior_panels:
		_prepare_wall_fragments(wall)
		_pool_wall_fragments(wall)
		wall_panels.append(wall)
	batched=use_batches
	if batched: _build_batches()

func _partition_with_door(origin: Vector3, length: float, doorway_x: float, yaw_angle: float) -> void:
	# A real 1.4m wide, 2.1m high passage: two solid sides and a lintel above it.
	var width: float=1.4
	var low: float=-length*.5
	var high: float=length*.5
	var left_end: float=doorway_x-width*.5
	var right_start: float=doorway_x+width*.5
	var basis:=Basis(Vector3.UP,yaw_angle)
	for interval: Vector2 in [Vector2(low,left_end),Vector2(right_start,high)]:
		var segment_length: float=interval.y-interval.x
		# Keep the original roughly 2m wall-module size; a longer room wall is a
		# row of those modules, so its local blast does not become coarse or weak.
		var segments: int=ceili(segment_length/1.98)
		var module_width: float=segment_length/segments
		for index: int in segments:
			var at: Vector3=origin+basis*Vector3(interval.x+module_width*(index+.5),1.24,0)
			var wall:=piece("InteriorPartition",Vector3(module_width,2.48,.16),at,STONE,yaw_angle)
			interior_panels.append(wall)
	var lintel:=piece("InteriorLintel",Vector3(width,.38,.16),origin+basis*Vector3(doorway_x,2.29,0),TRIM,yaw_angle)
	interior_panels.append(lintel)

func get_stats() -> Dictionary:
	var result: Dictionary=super.get_stats()
	result.color_scheme=color_scheme
	result.room_layout=room_layout
	result.interior_panels=interior_panels.size()
	result.native_body_cap=_owned_bodies.size()
	return result
