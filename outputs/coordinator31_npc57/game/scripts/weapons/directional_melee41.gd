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
	var side := -1.0 if relative.x < 0.0 else 1.0
	# Each side spans 120 degrees, from an upward to a downward diagonal.
	var angle := clampf(atan2(-relative.y, absf(relative.x)), -PI / 3.0, PI / 3.0)
	preview = Vector2(side * cos(angle), sin(angle))
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

func windup() -> float: return 0.44 if heavy else 0.26
func release() -> float: return 0.36 if heavy else 0.30
func recovery() -> float: return 0.52 if heavy else 0.28
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
	var arc := 1.16
	var high := (forward * cos(arc) + lateral * sin(arc)).normalized()
	if phase == "windup": return start_dir.slerp(high, smoothstep(0.0, 1.0, p)).normalized()
	var angle := lerpf(arc, -arc, p) if phase == "release" else -arc
	return (forward * cos(angle) + lateral * sin(angle)).normalized()

func description() -> String:
	var side := "справа" if preview.x >= 0.0 else "слева"
	if preview.y > 0.35: side = "сверху " + side
	elif preview.y < -0.35: side = "снизу " + side
	return side
