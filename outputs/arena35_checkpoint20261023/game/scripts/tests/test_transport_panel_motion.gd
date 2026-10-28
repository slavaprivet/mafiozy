extends SceneTree

const Motion = preload("res://scripts/transport/transport_panel_motion.gd")
var checks := 0
var failures: Array[String] = []

func check(ok: bool, label: String) -> void:
	checks += 1
	if not ok: failures.append(label)

func _initialize() -> void:
	# Numbers independently produced by the actual tracked JavaScript helper.
	var vectors := [
		[0.0, 0.0, 1.0, 1.0/60.0, .03693631311376677, 4.0004183916812766],
		[.7, 2.0, 0.0, .1, .35704559855862694, -4.013457006020121],
		[.2, -3.0, 1.0, .8, .8830544679255878, 1.6295868067565282],
		[1.0, 0.0, 1.0, .1, 1.0, 0.0],
	]
	for v in vectors:
		var result := Motion.step(v[0], v[1], v[2], v[3])
		check(result.code == "OK" and absf(result.amount-v[4]) < 1e-12 and absf(result.velocity-v[5]) < 1e-12, "actual source numeric vector")
	for fps in [20, 30, 60, 120, 144]:
		var amount := 0.0; var velocity := 0.0
		for i in fps:
			var result := Motion.step(amount, velocity, 1.0, 1.0/fps)
			amount = result.amount; velocity = result.velocity
		check(amount == 1.0 and velocity == 0.0, "open settles across frame rates")
	var opening := Motion.step(0.0, 0.0, 1.0, .08)
	var reversal := Motion.step(opening.amount, opening.velocity, 0.0, .001)
	check(reversal.amount > opening.amount and reversal.velocity > 0.0, "immediate reversal preserves positive momentum without snapping")
	check(Motion.step(0, 0, 1, -.1).code == "INVALID_MOTION", "negative delta fails closed")
	check(Motion.step(0, NAN, 1, .1).code == "INVALID_MOTION", "nonfinite input fails closed")
	check(Motion.step(0, 0, .5, .1).code == "INVALID_MOTION", "only source binary target accepted")
	check(is_equal_approx(Motion.hinge_angle(.5, -1.4), -.7), "smooth hinge preserves signed authored angle")
	var start := Time.get_ticks_usec()
	for i in 10000: Motion.step(.3, 1.0, 1.0, 1.0/60.0)
	print(JSON.stringify({"checks":checks,"failures":failures,"ten_thousand_steps_us":Time.get_ticks_usec()-start,"scope":"source numeric panel motion; no visual or LIVE claim"}))
	quit(0 if failures.is_empty() else 1)
