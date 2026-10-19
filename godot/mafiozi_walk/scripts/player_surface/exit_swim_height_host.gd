extends RefCounted
## Numeric-height portion of walk finishExit/heroSwimHeight only. The Root must
## pass actual actor lease, existing ground/water facts and actual artist lift.
## No movement writes, controls, scene calls, authority receipts or swim guesses.
const Handoff = preload("res://scripts/player_surface/exit_swim_handoff.gd")
const WALK_SOURCE_SHA256 := "e80ebf4be2d0404ad5b51d4bf28b756a9cba2b486c43c0797de748c37364dd47"
var _exit_ground: Callable
var _ground: Callable
var _water: Callable
var _binding_current: Callable
var _handoff: RefCounted
var _ready := false
var _begun := false

func configure(exit_ground_height: Callable, ground_height: Callable, water_at: Callable, binding_current: Callable) -> Dictionary:
	if not exit_ground_height.is_valid() or not ground_height.is_valid() or not water_at.is_valid() or not binding_current.is_valid(): return {"ok":false,"error":"REAL_CALLBACKS_REQUIRED"}
	_exit_ground=exit_ground_height; _ground=ground_height; _water=water_at; _binding_current=binding_current
	_handoff=null; _begun=false; _ready=true
	return {"ok":true}

func _valid_binding() -> bool:
	if not _ready or not _binding_current.is_valid(): return false
	var current: Variant = _binding_current.call()
	return typeof(current)==TYPE_BOOL and current

static func _number(value: Variant) -> bool:
	return typeof(value) in [TYPE_INT,TYPE_FLOAT] and is_finite(float(value))

func begin(x: float,z: float,from_y: float,current_swim_lift_world: float) -> Dictionary:
	if not _valid_binding(): return {"ok":false,"error":"BINDING_NOT_CURRENT"}
	if not is_finite(x) or not is_finite(z) or not is_finite(from_y) or not is_finite(current_swim_lift_world): return {"ok":false,"error":"FINITE_INPUT_REQUIRED"}
	# Exact source order: heroGroundHeight then waterAt, before height handoff.
	var floor_value: Variant = _exit_ground.call(x,z)
	if not _number(floor_value): return {"ok":false,"error":"FINITE_EXIT_GROUND_REQUIRED"}
	var water: Variant = _water.call(x,z)
	if water != null and not water is Dictionary: return {"ok":false,"error":"WATER_VALUE_REQUIRED"}
	var candidate: RefCounted = null
	var y := float(floor_value)
	if water != null:
		if not _number(water.get("level")): return {"ok":false,"error":"FINITE_WATER_LEVEL_REQUIRED"}
		candidate=Handoff.new()
		var configured:Dictionary=candidate.configure(from_y,float(water.level))
		if not configured.ok: return configured
		var first:Dictionary=candidate.update(float(floor_value)+current_swim_lift_world,0.0)
		if not first.ok: return first
		y=first.y
	if not _valid_binding(): return {"ok":false,"error":"BINDING_CHANGED_DURING_SAMPLE"}
	_handoff=candidate; _begun=true
	return {"ok":true,"y":y,"surface_motion_reset_floor_y":float(floor_value),"handoff_active":_handoff!=null,"height_producer":"exit_swim_handoff" if _handoff!=null else "exit_floor","requires_swim_owner":water!=null,"actor_authority_committed":false}

func update(x: float,z: float,swim_lift_world: float,dt: float) -> Dictionary:
	if not _valid_binding() or not _begun: return {"ok":false,"error":"BINDING_OR_BEGIN_REQUIRED"}
	if not is_finite(x) or not is_finite(z) or not is_finite(swim_lift_world) or not is_finite(dt) or dt<0.0: return {"ok":false,"error":"FINITE_INPUT_NONNEGATIVE_DT_REQUIRED"}
	# Source heroSwimHeight calls groundHeight (not heroGroundHeight) each frame.
	var floor_value:Variant=_ground.call(x,z)
	if not _number(floor_value): return {"ok":false,"error":"FINITE_GROUND_REQUIRED"}
	var water:Variant=_water.call(x,z)
	if water!=null and not water is Dictionary: return {"ok":false,"error":"WATER_VALUE_REQUIRED"}
	if water!=null and not _number(water.get("level")): return {"ok":false,"error":"FINITE_WATER_LEVEL_REQUIRED"}
	if not _valid_binding(): return {"ok":false,"error":"BINDING_CHANGED_DURING_SAMPLE"}
	var target:=float(floor_value)+swim_lift_world
	if not is_finite(target): return {"ok":false,"error":"FINITE_TARGET_REQUIRED"}
	if water==null: _handoff=null
	var y:=target
	if _handoff!=null:
		var step:Dictionary=_handoff.update(target,dt)
		if not step.ok: return step
		y=step.y
		if step.done: _handoff=null
	return {"ok":true,"y":y,"target_y":target,"handoff_active":_handoff!=null,"height_producer":"exit_swim_handoff" if _handoff!=null else "source_swim_sample","requires_swim_owner":water!=null,"actor_authority_committed":false}

func state() -> Dictionary:
	return {"ready":_ready,"begun":_begun,"handoff_active":_handoff!=null,"handoff":_handoff.state() if _handoff!=null else {}}

func dispose() -> void:
	if _handoff!=null: _handoff.dispose()
	_handoff=null; _ready=false; _begun=false
	_exit_ground=Callable(); _ground=Callable(); _water=Callable(); _binding_current=Callable()
