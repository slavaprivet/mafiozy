extends "res://scripts/vehicle_physics/vehicle_mesh_spike_no_bumper_fixture.gd"
## TEST_ONLY counterfactual: preserve eight-shape geometry but make explicit
## compound inertia match production box's measured centre-of-mass inertia.

func _rebuild_physical_body() -> void:
	super._rebuild_physical_body()
	if profile == null or not profile.is_valid() or profile.profile_id != &"compact_sedan":
		return
	var delta: Vector3 = profile.chassis_center_local_m() - profile.center_of_mass_local_m
	inertia += profile.mass_kg * Vector3(
		delta.y * delta.y + delta.z * delta.z,
		delta.x * delta.x + delta.z * delta.z,
		delta.x * delta.x + delta.y * delta.y)
