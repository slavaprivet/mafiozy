extends "res://scripts/vehicle_physics/vehicle_runover_mesh_envelope_variant.gd"
## TEST_ONLY: real narrow rounded bumper bars within the exterior nose extent.
## Checks whether a curved front contact sheds a ragdoll instead of dragging it.

func _rebuild_physical_body() -> void:
	super._rebuild_physical_body()
	if profile == null or not profile.is_valid() or profile.profile_id != &"compact_sedan":
		return
	for spec in [
		["NativeFrontBumper", -2.205, 1.476],
		["NativeRearBumper", 2.237, 1.440],
	]:
		var bumper := get_node(spec[0]) as CollisionShape3D
		var bar := CylinderShape3D.new()
		bar.height = spec[2]
		bar.radius = 0.085
		bumper.shape = bar
		bumper.position = Vector3(0.0, 0.245, spec[1])
		bumper.rotation.z = PI * 0.5 # Cylinder length follows the full-width X axis.
