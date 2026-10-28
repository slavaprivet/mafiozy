extends "res://scripts/vehicle_physics/vehicle_runover_sedan_visual_variant.gd"
## TEST_ONLY exclusive GDScript integrator timing, not native collision cost.
var integrator_us := 0
func _integrate_forces(state: PhysicsDirectBodyState3D) -> void:
	var start := Time.get_ticks_usec()
	super._integrate_forces(state)
	integrator_us = Time.get_ticks_usec() - start
