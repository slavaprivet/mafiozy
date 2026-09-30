extends RefCounted
## Bounded printshop entry/ramp source floor. Uses scalar binary64 arithmetic;
## Godot Vector3/Transform3D are deliberately absent from source calculations.
## Requires exporter-provided inverseEntryToPreview and documented dry domain.
## No authority, global ground replacement, static centre-floor shortcut or cache.
## Exported bounds use (preview_endpoint - .738); actual source corners use
## (source_cell - .18) * 4.1 - origin and differ by up to 5.69e-14m. Preserve
## those identical boundary points with binary64-only slack, never game clearance.
const DOMAIN_NUMERIC_EPS := 1e-12

var _inverse: Array = []
var _room: Array = []
var _corridor: Array = []
var _domain: Array = []
var _origin: Array = []
var _base_y := 0.0
var _half_width := 0.0
var _ramp_length := 0.0
var _epsilon := 0.0
var _ready := false
var _terrain_at: Callable
var last_error := "unconfigured"

func _finite(value: Variant) -> bool:
	return (value is float or value is int) and is_finite(float(value))

func _numbers(value: Variant, count: int) -> bool:
	if not value is Array or value.size() != count: return false
	for item: Variant in value:
		if not _finite(item): return false
	return true

func configure(parameters: Dictionary, origin_m: Array, validated_terrain_at: Callable = Callable()) -> bool:
	_ready = false
	last_error = "invalid-parameters"
	if parameters.get("schema") != "mafiozi.printshop-bounded-source-floor/v1": return false
	if not _numbers(parameters.get("inverseEntryToPreview"),16) or not _numbers(parameters.get("roomRect"),4) or not _numbers(parameters.get("corridorRect"),4) or not _numbers(parameters.get("domainPreviewXZ"),4) or not _numbers(origin_m,3): return false
	for key: String in ["baseWorldY","halfWidth","rampLength","epsilon"]:
		if not _finite(parameters.get(key)): return false
	if parameters.halfWidth <= 0.0 or parameters.rampLength <= 0.0 or parameters.epsilon < 0.0: return false
	var domain: Array = parameters.domainPreviewXZ
	if domain[0] > domain[2] or domain[1] > domain[3]: return false
	_inverse = parameters.inverseEntryToPreview.duplicate()
	_room = parameters.roomRect.duplicate()
	_corridor = parameters.corridorRect.duplicate()
	_domain = domain.duplicate()
	_origin = origin_m.duplicate()
	_base_y = parameters.baseWorldY
	_half_width = parameters.halfWidth
	_ramp_length = parameters.rampLength
	_epsilon = parameters.epsilon
	_terrain_at = validated_terrain_at
	_ready = true
	last_error = ""
	return true

func in_domain_preview(x: float, z: float) -> bool:
	return _ready and is_finite(x) and is_finite(z) and x >= _domain[0] - DOMAIN_NUMERIC_EPS and x <= _domain[2] + DOMAIN_NUMERIC_EPS and z >= _domain[1] - DOMAIN_NUMERIC_EPS and z <= _domain[3] + DOMAIN_NUMERIC_EPS

func entry_floor_preview(x: float, z: float) -> Variant:
	if not in_domain_preview(x,z): return null
	# Exact expression order of THREE.Vector3.applyMatrix4 at referenceY=0.
	var e := _inverse
	var w: float = 1.0 / (e[3] * x + e[7] * 0.0 + e[11] * z + e[15])
	var local_x: float = (e[0] * x + e[4] * 0.0 + e[8] * z + e[12]) * w
	var local_z: float = (e[2] * x + e[6] * 0.0 + e[10] * z + e[14]) * w
	var inside_room: bool = local_x >= _room[0] - _epsilon and local_x <= _room[2] + _epsilon and local_z >= _room[1] - _epsilon and local_z <= _room[3] + _epsilon
	var inside_corridor: bool = absf(local_x) <= _half_width + _epsilon and local_z >= _corridor[1] - _epsilon and local_z <= _epsilon
	if inside_room or inside_corridor: return _base_y
	if absf(local_x) <= _half_width + _epsilon and local_z >= -_epsilon and local_z <= _ramp_length + _epsilon:
		return _base_y * clampf(1.0 - local_z / _ramp_length,0.0,1.0)
	return null

func entry_floor_world(x: float, z: float) -> Variant:
	if not _ready: return null
	return entry_floor_preview(x - _origin[0],z - _origin[2])

func floor_world(x: float, z: float) -> float:
	if not _ready or not in_domain_preview(x - _origin[0],z - _origin[2]): return NAN
	var entry_floor: Variant = entry_floor_world(x,z)
	if _finite(entry_floor): return float(entry_floor)
	# The host must prove dry walkable land/current support before returning a
	# terrain height. Unknown support remains blocked; there is no implicit 0.
	if not _terrain_at.is_valid(): return NAN
	var terrain_floor: Variant = _terrain_at.call(x,z)
	return float(terrain_floor) if _finite(terrain_floor) else NAN
