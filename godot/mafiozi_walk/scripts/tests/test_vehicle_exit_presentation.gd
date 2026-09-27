extends SceneTree
const Presentation = preload("res://scripts/vehicle_visual/vehicle_exit_presentation.gd")
var checks := 0
var failures := []
func check(ok: bool, label: String) -> void:
	checks += 1
	if not ok: failures.append(label)
func smooth(t: float) -> float:
	t=clampf(t,0,1); return t*t*(3-2*t)
func _initialize() -> void:
	var matrix := []
	for speed: float in [0.0,2.4,2.903,4.8,14.0]:
		var start := Presentation.sample(0,1.7,speed)
		check(start.valid and start.visual_progress == 0.0,"first pose zero")
		var stop: float = start.roll_window_s
		check(stop >= .25 and stop <= 1.19,"bounded roll window")
		check(is_equal_approx(float(Presentation.sample(stop,1.7,speed).visual_progress),.70),"full canonical roll by planned stop")
		var previous := 0.0
		var max_step := 0.0
		var previous_angle := 0.0
		for i in 103:
			var t := minf(i/60.0,1.7)
			var result := Presentation.sample(t,1.7,speed,previous,i>=6 and i<=12)
			check(result.valid and result.visual_progress >= previous and result.visual_progress <= 1.0,"monotonic including temporary blocked interval")
			var angle := TAU*smooth((float(result.visual_progress)-.06)/.64)*float(result.rolls_scale)
			max_step=maxf(max_step,angle-previous_angle); previous_angle=angle
			previous=result.visual_progress
		check(previous == 1.0,"exact final upright")
		check(Presentation.sample(.1,1.7,speed,.8).visual_progress == .8,"stale clock does not reverse pose")
		matrix.append({"speed":speed,"stop_s":stop,"max_60hz_rotation_step_rad":max_step,"zero_speed_rolls_scale":start.rolls_scale})
	check(Presentation.sample(1.0/60.0,1.7,2.903).visual_progress > .06,"current native initial motion already rotates on first tick")
	check(not Presentation.sample(NAN,1.7,3).valid,"NaN reject")
	check(not Presentation.sample(.1,0,3).valid,"duration reject")
	check(not Presentation.sample(.1,1.7,-3).valid,"negative speed reject")
	check(not Presentation.sample(.1,1.7,3,1.1).valid,"foreign invalid progress reject")
	var costs: Array[int] = []
	for i in 544:
		var before := Time.get_ticks_usec()
		Presentation.sample(float(i%102)/60.0,1.7,2.903)
		if i>=32: costs.append(Time.get_ticks_usec()-before)
	costs.sort()
	print("VEHICLE_EXIT_PRESENTATION_TEST ",JSON.stringify({"checks":checks,"failures":failures,"matrix":matrix,
		"isolated_cpu_us":{"p50":costs[255],"p95":costs[486],"samples":costs.size()},
		"qualification":"Pure timing/canonical curve only; microsecond CPU timer resolution, no geometry, body motion, loaded-scene FPS or LIVE acceptance."}))
	quit(0 if failures.is_empty() else 1)
