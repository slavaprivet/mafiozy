extends RefCounted
## Temporary, non-physical handheld visuals. No skeleton or actor transform writes.
var _attachment: BoneAttachment3D
var _root: Node3D

func clear() -> void:
	if is_instance_valid(_attachment):
		_attachment.visible = false
		_attachment.queue_free()
	_attachment = null; _root = null

func _box(parent: Node3D, size: Vector3, at: Vector3, color: Color) -> void:
	var mesh := MeshInstance3D.new()
	var box := BoxMesh.new(); box.size = size
	var material := StandardMaterial3D.new(); material.albedo_color = color; material.roughness = .85
	box.material = material; mesh.mesh = box; mesh.position = at
	mesh.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
	parent.add_child(mesh)

func begin(rig: Skeleton3D, kind: String) -> bool:
	clear()
	if kind not in ["book", "newspaper", "camera"]: return true
	if not is_instance_valid(rig) or rig.find_bone("hand_l") < 0: return false
	_attachment = BoneAttachment3D.new(); _attachment.name = "AmbientProp28"; _attachment.bone_name = "hand_l"
	_attachment.set_meta("ambient_prop28", true)
	rig.add_child(_attachment)
	_root = Node3D.new(); _attachment.add_child(_root)
	# The host aligns this mount after its one final pose commit; attachment then
	# follows that same hand. It is hidden until a fresh current pose was committed.
	_attachment.visible = false
	match kind:
		"book":
			_box(_root, Vector3(.29, .015, .21), Vector3.ZERO, Color("573b27"))
			_box(_root, Vector3(.135, .025, .19), Vector3(-.07,.018,0), Color("e9dfc7"))
			_box(_root, Vector3(.135, .025, .19), Vector3(.07,.018,0), Color("e9dfc7"))
		"newspaper":
			_box(_root, Vector3(.43,.006,.32), Vector3.ZERO, Color("d9d4bd"))
			for column: int in 3:
				for line: int in 5:
					_box(_root, Vector3(.105,.002,.008), Vector3((column-1)*.13,.005,-.11+line*.045), Color("5c5b55"))
		"camera":
			_box(_root, Vector3(.19,.12,.075), Vector3.ZERO, Color("262726"))
			_box(_root, Vector3(.09,.045,.06), Vector3(0,.075,0), Color("464947"))
			var lens := MeshInstance3D.new(); var cylinder := CylinderMesh.new()
			cylinder.top_radius = .043; cylinder.bottom_radius = .043; cylinder.height = .065
			var material := StandardMaterial3D.new(); material.albedo_color = Color("5b7379"); material.metallic = .6; material.roughness = .25
			cylinder.material = material; lens.mesh = cylinder; lens.rotation.x = PI*.5; lens.position.z = .057
			_root.add_child(lens)
	return true

func hide() -> void:
	if is_instance_valid(_attachment): _attachment.visible = false

func sync_after_pose(rig: Skeleton3D, kind: String) -> void:
	if not is_instance_valid(_attachment) or not is_instance_valid(_root) or not is_instance_valid(rig): return
	var left: int = rig.find_bone("hand_l"); var right: int = rig.find_bone("hand_r")
	var chest: int = rig.find_bone("chest"); var head: int = rig.find_bone("head")
	if left < 0 or right < 0 or chest < 0 or head < 0: hide(); return
	var a: Vector3 = rig.to_global(rig.get_bone_global_pose(left).origin)
	var b: Vector3 = rig.to_global(rig.get_bone_global_pose(right).origin)
	var side: Vector3 = b-a
	var up: Vector3 = rig.global_basis * Vector3.UP
	if side.length_squared() < .0001: hide(); return
	side = side.normalized(); up = up.normalized()
	var forward: Vector3 = side.cross(up).normalized()
	var basis := Basis(side, up, forward).orthonormalized()
	if kind in ["book", "newspaper"]: basis = basis * Basis(Vector3.RIGHT, -.35)
	_root.global_transform = Transform3D(basis, (a+b)*.5)
	_attachment.visible = true
