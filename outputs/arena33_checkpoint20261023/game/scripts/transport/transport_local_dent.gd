extends RefCounted
## Pure cumulative local-dent buffer. The caller owns mesh transforms,
## subdivision, normals/bounds recomputation, rendering and event authority.

const MAX_VERTICES:=90000
const MAX_POSITION_VALUES:=MAX_VERTICES*3
const BULLET_MAX_DEPTH:=.18
const COLLISION_MAX_DEPTH:=.40
const UNIT_NORMAL_TOLERANCE_SQUARED:=1.0e-8
class DentStageToken extends RefCounted: pass

var _configured:=false
var _disposed:=false
var _generation:=0
var _base:=PackedFloat32Array()
var _offset:=PackedFloat32Array()
var _max_depth:=0.0
var _pending: Dictionary={}

func configure(initial_positions: Variant,generation_value: Variant) -> Dictionary:
	if _configured or _disposed: return _error("lifetime")
	var positions_check:=_positions_contract(initial_positions)
	if not positions_check.ok: return positions_check
	if not generation_value is int or int(generation_value)<1: return _error("generation")
	_base=(initial_positions as PackedFloat32Array).duplicate()
	_offset.resize(_base.size()); _offset.fill(0.0)
	_generation=int(generation_value); _configured=true
	return {"ok":true,"generation":_generation,"vertex_count":int(_base.size()/3),"max_depth":_max_depth}

## collision is {} for a bullet or exactly {impactSpeed: finite >= 0}.
## Point and normal are already in mesh-local space. The normal must be unit.
func apply(current_positions: Variant,local_point_f64: Variant,local_normal_f64: Variant,damage_value: Variant,collision_value: Variant,expected_generation: Variant) -> Dictionary:
	var state:=_state_contract(expected_generation)
	if not state.ok: return state
	if not _pending.is_empty(): return _error("pending_commit")
	var positions_check:=_positions_contract(current_positions)
	if not positions_check.ok: return positions_check
	var current: PackedFloat32Array=current_positions
	if current.size()!=_base.size(): return _error("topology")
	if not _f64_vec3(local_point_f64): return _error("point")
	if not _f64_vec3(local_normal_f64): return _error("normal")
	var normal: PackedFloat64Array=local_normal_f64
	var normal_length_squared:=normal[0]*normal[0]+normal[1]*normal[1]+normal[2]*normal[2]
	if not is_finite(normal_length_squared) or absf(normal_length_squared-1.0)>UNIT_NORMAL_TOLERANCE_SQUARED: return _error("normal")
	if not (damage_value is float or damage_value is int) or not is_finite(float(damage_value)) or float(damage_value)<0.0: return _error("damage")
	if not collision_value is Dictionary: return _error("collision")
	var collision: Dictionary=collision_value; var is_collision:=not collision.is_empty(); var impact_speed:=0.0
	if is_collision:
		if collision.size()!=1 or not collision.has("impactSpeed") or not (collision.impactSpeed is float or collision.impactSpeed is int) or not is_finite(float(collision.impactSpeed)) or float(collision.impactSpeed)<0.0: return _error("collision")
		impact_speed=float(collision.impactSpeed)
	var point: PackedFloat64Array=local_point_f64
	var damage:=float(damage_value)
	var radius:=minf(1.10,.30+impact_speed*.035) if is_collision else .10+minf(.20,sqrt(damage)*.014)
	var depth:=minf(.30,.012+impact_speed*impact_speed*.0028) if is_collision else minf(.10,.008+damage*.00055)
	var next_max_depth:=maxf(_max_depth,COLLISION_MAX_DEPTH if is_collision else BULLET_MAX_DEPTH)
	var next_base:=PackedFloat32Array(); next_base.resize(current.size())
	var next_positions:=current.duplicate(); var next_offset:=_offset.duplicate()
	# Assignment to PackedFloat32Array preserves the source's rebase rounding.
	for i in current.size(): next_base[i]=current[i]-_offset[i]
	var radius_inverse:=1.0/radius; var affected:=0; var changed:=0
	for vertex in current.size()/3:
		var at:=vertex*3
		var ox:=float(next_base[at]); var oy:=float(next_base[at+1]); var oz:=float(next_base[at+2])
		var dx:=ox-point[0]; var dy:=oy-point[1]; var dz:=oz-point[2]
		var distance:=sqrt(dx*dx+dy*dy+dz*dz)
		if distance>=radius: continue
		affected+=1
		var falloff:=1.0-distance*radius_inverse; falloff*=falloff
		var amount:=depth*falloff
		var x:=float(current[at])-normal[0]*amount
		var y:=float(current[at+1])-normal[1]*amount
		var z:=float(current[at+2])-normal[2]*amount
		var sx:=x-ox; var sy:=y-oy; var sz:=z-oz; var shift:=sqrt(sx*sx+sy*sy+sz*sz)
		if shift>next_max_depth:
			var scale:=next_max_depth/shift
			x=ox+sx*scale; y=oy+sy*scale; z=oz+sz*scale
		# The position and offset writes round separately, exactly like setXYZ()
		# followed by Float32Array offset assignments in the source.
		next_positions[at]=x; next_positions[at+1]=y; next_positions[at+2]=z
		next_offset[at]=x-ox; next_offset[at+1]=y-oy; next_offset[at+2]=z-oz
		if next_positions[at]!=current[at] or next_positions[at+1]!=current[at+1] or next_positions[at+2]!=current[at+2]: changed+=1
	if not _finite_positions(next_base) or not _finite_positions(next_positions) or not _finite_positions(next_offset): return _error("nonfinite_result")
	var token:=DentStageToken.new()
	_pending={"token":token,"generation":_generation,"base":next_base,"offset":next_offset,"max_depth":next_max_depth}
	return {"ok":true,"generation":_generation,"stage_token":token,"positions":next_positions.duplicate(),"base":next_base.duplicate(),"offset":next_offset.duplicate(),"max_depth":next_max_depth,"affected":affected,"changed":changed,"requires_geometry_refresh":true}

## Call only after the host successfully committed positions, normals, bounds,
## sphere and its mesh/resource revision. Returned arrays never alias this state.
func commit(token_value: Variant) -> Dictionary:
	if not _configured or _disposed: return _error("lifetime")
	if _pending.is_empty() or not token_value is DentStageToken or token_value!=_pending.token or _pending.generation!=_generation: return _error("stale_stage")
	_base=(_pending.base as PackedFloat32Array).duplicate()
	_offset=(_pending.offset as PackedFloat32Array).duplicate()
	_max_depth=float(_pending.max_depth); _pending.clear()
	return {"ok":true,"generation":_generation,"max_depth":_max_depth}

## Host-side commit failure discards staged state without advancing rebasing.
func abort(token_value: Variant) -> Dictionary:
	if not _configured or _disposed: return _error("lifetime")
	if _pending.is_empty() or not token_value is DentStageToken or token_value!=_pending.token or _pending.generation!=_generation: return _error("stale_stage")
	_pending.clear()
	return {"ok":true,"generation":_generation}

## Geometry replacement clears local dent offsets. The persistent cap survives,
## matching source geometry replacement; full_reset clears it for vehicle reset.
func reset(initial_positions: Variant,new_generation: Variant,full_reset_value: Variant=false) -> Dictionary:
	if not _configured or _disposed: return _error("lifetime")
	var positions_check:=_positions_contract(initial_positions)
	if not positions_check.ok: return positions_check
	if not new_generation is int or int(new_generation)<=_generation: return _error("generation")
	if not full_reset_value is bool: return _error("reset")
	var next_base: PackedFloat32Array=(initial_positions as PackedFloat32Array).duplicate()
	var next_offset:=PackedFloat32Array(); next_offset.resize(next_base.size()); next_offset.fill(0.0)
	_pending.clear(); _base=next_base; _offset=next_offset; _generation=int(new_generation)
	if full_reset_value: _max_depth=0.0
	return {"ok":true,"generation":_generation,"vertex_count":int(_base.size()/3),"max_depth":_max_depth,"full_reset":full_reset_value}

func snapshot() -> Dictionary:
	if not _configured or _disposed: return _error("lifetime")
	return {"ok":true,"generation":_generation,"base":_base.duplicate(),"offset":_offset.duplicate(),"max_depth":_max_depth,"vertex_count":int(_base.size()/3),"pending":not _pending.is_empty()}

func dispose() -> void:
	if _disposed: return
	_pending.clear(); _base=PackedFloat32Array(); _offset=PackedFloat32Array(); _disposed=true

func _state_contract(expected_generation: Variant) -> Dictionary:
	if not _configured or _disposed: return _error("lifetime")
	if not expected_generation is int or int(expected_generation)!=_generation: return _error("generation")
	return {"ok":true}

static func _positions_contract(value: Variant) -> Dictionary:
	if not value is PackedFloat32Array: return _error("positions")
	var positions: PackedFloat32Array=value
	if positions.is_empty() or positions.size()%3!=0 or positions.size()>MAX_POSITION_VALUES: return _error("positions")
	if not _finite_positions(positions): return _error("nonfinite_positions")
	return {"ok":true}

static func _f64_vec3(value: Variant) -> bool:
	if not value is PackedFloat64Array or value.size()!=3: return false
	return is_finite(value[0]) and is_finite(value[1]) and is_finite(value[2])

static func _finite_positions(values: PackedFloat32Array) -> bool:
	for value in values:
		if not is_finite(value): return false
	return true

static func _error(code: String) -> Dictionary: return {"ok":false,"error":code}
