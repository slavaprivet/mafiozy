extends RefCounted
## One click commits one directional attack. Durations are our tuning, not Mordhau data.
var phase := "idle"
var elapsed := 0.0
var heavy := false
var chosen := Vector2.RIGHT
var preview := Vector2.RIGHT
var mouse_age := 10.0
var serial := 0
var hits := {}
var start_dir := Vector3.FORWARD
var frame := Basis.IDENTITY
var interrupted := false

func reset() -> void:
	phase = "idle"
	elapsed = 0.0
	hits.clear()
	interrupted = false

func mouse(relative: Vector2) -> void:
	if relative.length() < 2.0: return
	# Preserve vertical, horizontal and diagonal origins exactly.
	preview = Vector2(relative.x, -relative.y).normalized()
	mouse_age = 0.0

func begin(is_heavy: bool, current: Vector3, camera: Basis) -> bool:
	if phase != "idle": return false
	heavy = is_heavy
	chosen = preview
	start_dir = current
	frame = camera.orthonormalized()
	phase = "windup"
	elapsed = 0.0
	serial += 1
	hits.clear()
	interrupted = false
	return true

func windup() -> float: return 0.62 if heavy else 0.36
func release() -> float: return 0.54 if heavy else 0.40
func recovery() -> float: return 0.72 if heavy else 0.46
func active() -> bool: return phase != "idle"
func damaging() -> bool: return phase == "release"
func progress() -> float:
	var duration := windup() if phase == "windup" else (release() if phase == "release" else recovery())
	return clampf(elapsed / duration, 0.0, 1.0)

func stop() -> void:
	if phase not in ["windup", "release"]: return
	phase = "recover"
	elapsed = 0.0
	interrupted = true

func advance(delta: float, camera: Basis) -> void:
	mouse_age += delta
	if not active(): return
	elapsed += delta
	# Bound only the attacking frame; camera remains usable for looking around.
	var from := frame.get_rotation_quaternion()
	var to := camera.orthonormalized().get_rotation_quaternion()
	var angle := from.angle_to(to)
	frame = Basis(from.slerp(to, minf(1.0, (1.5 if heavy else 2.3) * delta / maxf(angle, 0.00001))))
	if phase == "windup" and elapsed >= windup():
		elapsed -= windup()
		phase = "release"
	elif phase == "release" and elapsed >= release():
		elapsed -= release()
		phase = "recover"
	elif phase == "recover" and elapsed >= recovery(): reset()

func target() -> Vector3:
	var lateral := (frame.x * chosen.x + frame.y * chosen.y).normalized()
	var forward := -frame.z
	var p := progress()
	var arc := 0.72 if chosen.y < -0.35 else 1.16
	var high := (forward * cos(arc) + lateral * sin(arc)).normalized()
	if phase == "windup":
		# Reposition through the open front space, avoiding a shortcut across the torso.
		if p < 0.45: return start_dir.slerp(forward, smoothstep(0.0, 0.45, p)).normalized()
		return forward.slerp(high, smoothstep(0.45, 0.90, p)).normalized()
	if phase == "recover":
		var end := (forward * cos(-arc) + lateral * sin(-arc)).normalized()
		return end.slerp((forward - frame.y * 0.20).normalized(), smoothstep(0.0, 1.0, p)).normalized()
	var angle := lerpf(arc, -arc, smoothstep(0.0, 1.0, p))
	return (forward * cos(angle) + lateral * sin(angle)).normalized()

func description() -> String:
	if absf(preview.x) < 0.20: return "сверху" if preview.y > 0.0 else "снизу"
	var side := "справа" if preview.x >= 0.0 else "слева"
	if preview.y > 0.35: side = "сверху " + side
	elif preview.y < -0.35: side = "снизу " + side
	return side
