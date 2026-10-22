extends SceneTree

const Snapshot = preload("res://scripts/transport/candidates/transport_vehicle_debris_material_snapshot.gd")

var checks := 0
var failures: Array[String] = []

func _initialize() -> void:
	_run.call_deferred()

func _check(condition: bool, label: String) -> void:
	checks += 1
	if not condition:
		failures.append(label)

func _run() -> void:
	var world := Node3D.new()
	root.add_child(world)

	var pending := _setup(world, "pending")
	_check(pending.ok, "pending fixture configured")
	var staged: Dictionary = pending.helper.stage_material_snapshot(0, 1)
	_check(staged.ok, "nested-resource snapshot staged")
	(pending.gradient as Gradient).set_color(0, Color.RED)
	_check(pending.helper.commit_material_snapshot(staged.stage_token).error == "material_content_changed", "same-frame nested source mutation rejects commit")
	_check(pending.helper.abort_material_snapshot(staged.stage_token).ok, "nested mutation transaction aborts")
	pending.helper.dispose()
	pending.vehicle.free()

	var committed := _setup(world, "committed")
	_check(committed.ok, "committed fixture configured")
	staged = committed.helper.stage_material_snapshot(0, 1)
	_check(staged.ok and committed.helper.commit_material_snapshot(staged.stage_token).ok, "nested-resource snapshot committed")
	var private: MeshInstance3D = committed.helper._entries[0].template
	var private_material := private.get_active_material(0) as StandardMaterial3D
	var private_texture := private_material.albedo_texture as GradientTexture1D
	_check(private_texture != null and private_texture.gradient != null, "private nested resource duplicated")
	private_texture.gradient.set_color(0, Color.BLUE)
	var launch: Dictionary = committed.helper.launch_with_visual_revision([{"linear_velocity": Vector3.ZERO, "angular_velocity": Vector3.ZERO}], 1)
	_check(launch.error == "private_material_changed", "same-frame nested private mutation invalidates receipt")
	committed.helper.dispose()
	committed.vehicle.free()

	print("TRANSPORT_DEBRIS_MATERIAL_SNAPSHOT_REVIEW " + JSON.stringify({"passed": failures.is_empty(), "checks": checks, "failures": failures, "scope": "same-frame nested resource transaction fences"}))
	quit(0 if failures.is_empty() else 1)

func _setup(world: Node3D, label: String) -> Dictionary:
	var vehicle := Node3D.new()
	vehicle.name = "Vehicle_" + label
	world.add_child(vehicle)
	var source := MeshInstance3D.new()
	source.name = "Door_" + label
	vehicle.add_child(source)
	var gradient := Gradient.new()
	gradient.colors = PackedColorArray([Color.WHITE, Color.BLACK])
	var texture := GradientTexture1D.new()
	texture.gradient = gradient
	var material := StandardMaterial3D.new()
	material.albedo_texture = texture
	var arrays := []
	arrays.resize(Mesh.ARRAY_MAX)
	arrays[Mesh.ARRAY_VERTEX] = PackedVector3Array([
		Vector3(-1, 0, 0), Vector3(1, 0, 0), Vector3(0, 1, 0),
		Vector3(-1, 0, 0), Vector3(0, 1, 0), Vector3(0, 0, 1),
	])
	var mesh := ArrayMesh.new()
	mesh.add_surface_from_arrays(Mesh.PRIMITIVE_TRIANGLES, arrays)
	mesh.surface_set_material(0, material)
	source.mesh = mesh
	var helper := Snapshot.new()
	var configured: Dictionary = helper.configure(vehicle, world, [{"source": source, "mass_kg": 12.0, "collision_layer": 8, "collision_mask": 1, "linear_damp": 0.2, "angular_damp": 1.0, "friction": 0.7, "bounce": 0.05}], null, 0, 0)
	return {"ok": configured.get("ok", false), "helper": helper, "vehicle": vehicle, "source": source, "gradient": gradient}
