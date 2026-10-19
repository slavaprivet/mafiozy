extends "res://scripts/main.gd"
## Only the inherited factory seam changes; pose/owner setup is identical.
const Clock = preload("res://diagnostic/gameplay_clock.gd")
const ClockedMelee = preload("res://diagnostic/clocked_melee.gd")

func _install_preview_melee_practice() -> bool:
	if is_instance_valid(preview_melee) or not is_instance_valid(_player): return false
	var adapter_script: Script = load("res://scripts/combat/melee_physical_pose.gd")
	if adapter_script == null:
		melee_status = "physical_pose_unavailable"; return false
	var adapter: RefCounted = adapter_script.new()
	if not adapter.configure(_player._pose_skeleton, _player._locomotion._rest_poses):
		melee_status = "physical_pose_binding"; return false
	var host := ClockedMelee.new()
	host.name = "MeleePractice"
	add_child(host)
	var generation := int(get_meta("gameplay_clock_generation", 0)) + 1
	set_meta("gameplay_clock_generation", generation)
	var clock: RefCounted = Clock.new()
	if not clock.bind(self, host, generation) or not host.bind_gameplay_clock(clock):
		host.queue_free(); melee_status = "clock_binding"; return false
	if not host.configure(self, _player, adapter):
		host.queue_free(); melee_status = "host_binding"; return false
	preview_melee = host; _player._melee_practice = host
	melee_status = "ground_practice_no_combat_targets"
	return true
