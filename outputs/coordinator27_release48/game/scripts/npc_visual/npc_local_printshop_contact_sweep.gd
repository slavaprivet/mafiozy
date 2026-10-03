extends RefCounted
## Source-equivalent static polygon obstruction, NOT complete movement admission.
## Endpoints are [world X metres, world Z metres]; polygon points are unchanged
## absolute source [column,row] cells. floor_at(world_x,world_z) returns metres.
## Preview callers add their source-world origin to endpoints; the callback must
## accept these absolute world coordinates too. The algorithm applies no offset.
## The .738m argument is square HALF-EXTENT (.18 cells), never capsule radius.
## Reuse one instance per caller. No reentry. No provider result survives a call.
const Footprint = preload("res://scripts/navigation/npc_swept_footprint.gd")
const WORLD_SCALE := 4.1
const SOURCE_HALF_EXTENT_M := 0.18 * WORLD_SCALE

var _footprint := Footprint.new()
var _from_rc := {"r": 0.0, "c": 0.0}
var _to_rc := {"r": 0.0, "c": 0.0}
var _floor_at: Callable
var _min_y := NAN
var _max_y := NAN
var _height := 1.9
var _ready := false
var _busy := false
var _fault := false
var contact_count := 0
var last_error := ""

func _finite(value: Variant) -> bool:
	return (value is float or value is int) and is_finite(float(value))

func _point(value: Variant) -> bool:
	return value is Array and value.size() == 2 and _finite(value[0]) and _finite(value[1])

func begin_segment(from_xz: Variant, to_xz: Variant, radius_m: Variant = SOURCE_HALF_EXTENT_M, height_m: Variant = 1.9) -> bool:
	if not Thread.is_main_thread(): return false
	if _busy:
		_fault = true
		last_error = "reentrant-access"
		return false
	_ready = false
	last_error = ""
	contact_count = 0
	if not _point(from_xz) or not _point(to_xz) or not _finite(radius_m) or float(radius_m) <= 0.0 or not _finite(height_m) or float(height_m) <= 0.0:
		last_error = "invalid-segment"
		return false
	_from_rc.c = float(from_xz[0]) / WORLD_SCALE
	_from_rc.r = float(from_xz[1]) / WORLD_SCALE
	_to_rc.c = float(to_xz[0]) / WORLD_SCALE
	_to_rc.r = float(to_xz[1]) / WORLD_SCALE
	_height = float(height_m)
	_ready = _footprint.set_segment(_from_rc, _to_rc, float(radius_m) / WORLD_SCALE)
	if not _ready: last_error = _footprint.last_error
	return _ready

func _solid_at_contact(c: float, r: float) -> bool:
	contact_count += 1
	var floor_y: Variant = _floor_at.call(c * WORLD_SCALE, r * WORLD_SCALE)
	if not _finite(floor_y): return true
	# This is exactly source npc_native_navigation.solidAtContact: floor support
	# is local to the intersection/corner, not the centre of this NPC or segment.
	return not ((is_finite(_max_y) and _max_y <= floor_y + 0.05) or (is_finite(_min_y) and _min_y >= floor_y + _height))

func blocks_polygon(polygon_cr: Variant, floor_at: Callable, min_y: float = NAN, max_y: float = NAN) -> bool:
	if not Thread.is_main_thread(): return true
	if _busy:
		_fault = true
		last_error = "reentrant-access"
		return true
	last_error = ""
	if not _ready:
		last_error = "segment-not-ready"
		return true
	if not floor_at.is_valid():
		last_error = "invalid-floor-provider"
		return true
	_busy = true
	_fault = false
	_floor_at = floor_at
	_min_y = min_y
	_max_y = max_y
	var blocked: bool = _footprint.overlaps(polygon_cr, _solid_at_contact)
	if not _footprint.last_error.is_empty(): last_error = _footprint.last_error
	_floor_at = Callable()
	_busy = false
	return blocked or _fault

func blocks(from_xz: Variant, to_xz: Variant, radius_m: Variant, polygon_cr: Variant, floor_at: Callable, min_y: float = NAN, max_y: float = NAN, height_m: Variant = 1.9) -> bool:
	if not begin_segment(from_xz, to_xz, radius_m, height_m): return true
	return blocks_polygon(polygon_cr, floor_at, min_y, max_y)

func bounds() -> Dictionary:
	var result: Dictionary = _footprint.bounds()
	result.valid = _ready and result.valid
	return result
