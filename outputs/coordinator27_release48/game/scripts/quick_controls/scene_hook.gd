extends Node
const Controls = preload("quick_controls.gd")
var controls: Node
var status := "waiting"
func _ready() -> void: _attach.call_deferred()
func _attach() -> void:
	var world := get_parent() as Node3D
	if not is_instance_valid(world): return
	for frame in 1200:
		if not is_inside_tree() or not is_instance_valid(world): return
		if world.get("preview_ready") == true: break
		await get_tree().process_frame
	if world.get("preview_ready") != true: return
	controls = Controls.new()
	controls.name = "LookBackAndHorn"
	add_child(controls)
	if not controls.configure(world):
		controls.queue_free()
		status = "unavailable"
		return
	status = "ready"
	print("QUICK_CONTROLS_READY B=look_back H=driver_horn F=driver_headlights lights=", controls.headlights.lights.size())
	print("REAR_LIGHTS_READY ", controls.rear_lights.ready_for_play)
	print("STREET_LAMPS_STATUS ", controls.street_lamps_status)
	print("DAY_NIGHT_READY N=day_night T=pause day_sec_per_hour=300 night_sec_per_hour=150 hour=", controls.day_clock.hour, " lighting=", controls.day_night.enabled)
