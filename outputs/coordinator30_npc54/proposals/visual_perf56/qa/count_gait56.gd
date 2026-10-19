extends "res://scripts/preview_locomotion.gd"
var samples56 := 0
var commits56 := 0
var advances56 := 0
var last_sample56: Dictionary = {}
func sample(delta: float, velocity56: Vector3, grounded: bool) -> Dictionary:
    samples56 += 1
    last_sample56 = super.sample(delta,velocity56,grounded)
    return last_sample56
func update_pose(delta: float, velocity56: Vector3, grounded: bool) -> void:
    commits56 += 1
    super.update_pose(delta,velocity56,grounded)
func advance_distance(metres: float, grounded: bool, speed_hint: float=-1.0) -> void:
    advances56 += 1
    super.advance_distance(metres,grounded,speed_hint)
