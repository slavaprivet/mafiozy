extends "res://scripts/vehicle_physics/vehicle_runover_mesh_envelope_variant.gd"
## TEST_ONLY: preserve real full-width bumpers and wheel/cabin geometry, but
## test whether low car-body surface friction prevents long ragdoll dragging.

func _rebuild_physical_body() -> void:
	super._rebuild_physical_body()
	if profile == null or not profile.is_valid() or profile.profile_id != &"compact_sedan":
		return
	var surface := PhysicsMaterial.new()
	surface.friction = 0.0
	surface.bounce = 0.0
	physics_material_override = surface
