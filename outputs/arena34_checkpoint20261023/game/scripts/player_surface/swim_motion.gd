extends RefCounted
## Exact source swim state and artist-surface world-unit sample. No scene,
## movement, water query, collider, inputs or bone writer is created here.
const SOURCE_SHA256 := "4c1ed3557af7700b74c861a97cbb7abeaf41e374291ba94f280d8d168d9a75d9"
const SURFACE_SOURCE_SHA256 := "30de352fc12723343aafad5c7b04a3a46a40f417a246953f85bc60c48b0af243"
const WALK_SOURCE_SHA256 := "e80ebf4be2d0404ad5b51d4bf28b756a9cba2b486c43c0797de748c37364dd47"
const STEP_FLAGS := ["has_movement","fast","blocked"]
const WORLD_FLAGS := ["in_water","moving","fast","blocked"]
const REACTION_KINDS := ["idle","hit","block","fall","dead"]
var _ready := false
var _unit := 1.0
var _active := false
var _blend := 0.0
var _speed := 0.0
var _lift := 0.0
var _phase := 0.0
var _fast := false
var _moving := false
var _tilt := 0.0

func configure(source_to_world_unit: float) -> Dictionary:
	if not is_finite(source_to_world_unit) or source_to_world_unit<=0.0: return {"ok":false,"error":"ACTUAL_POSITIVE_UNIT_REQUIRED"}
	_unit=source_to_world_unit;_ready=true;reset()
	return {"ok":true}

func reset() -> void:
	_active=false;_blend=0.0;_speed=0.0;_lift=0.0;_phase=0.0;_fast=false;_moving=false;_tilt=0.0

static func _finite(value: Variant) -> bool:
	return typeof(value) in [TYPE_INT,TYPE_FLOAT] and is_finite(float(value))

static func _flags(input: Dictionary,names: Array) -> bool:
	for name: String in names:
		if input.has(name) and typeof(input[name])!=TYPE_BOOL:return false
	return true

func _advance(dt: float,water_level: Variant,chest_height: Variant,moving: bool,fast: bool,blocked: bool) -> void:
	var submerged:=_finite(water_level) and _finite(chest_height)
	if blocked or not submerged:_active=false
	elif _active:
		if float(water_level)<float(chest_height)-.1:_active=false
	elif float(water_level)>float(chest_height):_active=true
	var target:=1.0 if _active else 0.0
	_blend+=(target-_blend)*(1.0-exp(-dt*9.0))
	if absf(_blend-target)<.002:_blend=target
	_fast=fast and moving;_moving=moving
	var cadence:float=(1.5 if _fast else .9) if moving else .55
	_phase=fmod(_phase+dt*PI*2.0*cadence,PI*2.0)
	_speed=(3.4 if _fast else 2.0) if _active and moving else 0.0
	_tilt=(1.32 if moving else .55)*_blend
	var wanted:=maxf(0.0,float(water_level)-float(chest_height)+1.54*(1.0-cos(_tilt))-.12) if submerged else 0.0
	_lift+=(wanted*_blend-_lift)*(1.0-exp(-dt*12.0))
	if not _active and _blend==0.0 and _lift<.002:_lift=0.0

func snapshot() -> Dictionary:
	return {"active":_active,"blend":_blend,"speed":_speed,"lift":_lift,"phase":_phase,"fast":_fast,"moving":_moving,"tilt":_tilt}

## Direct source createSwimMotion.step semantics, author units. Invalid/nonfinite
## dt becomes zero here, but the artist-surface entry below correctly rejects it.
func step(input: Dictionary = {}) -> Dictionary:
	if not _ready:return {"ok":false,"error":"NOT_CONFIGURED"}
	if not _flags(input,STEP_FLAGS):return {"ok":false,"error":"BOOLEAN_FLAGS_REQUIRED"}
	var raw:Variant=input.get("dt",0.0)
	var dt:=minf(.25,maxf(0.0,float(raw))) if _finite(raw) else 0.0
	_advance(dt,input.get("water_level",null),input.get("chest_height",3.0),input.get("has_movement",false),input.get("fast",false),input.get("blocked",false))
	return {"ok":true,"state":snapshot()}

## The numeric slice of hero_artist14_surface.update. Caller passes ACTUAL
## pre-update reaction_kind: a fall expiring this frame still blocks this step.
func sample_world(dt: float,input: Dictionary) -> Dictionary:
	if not _ready:return {"ok":false,"error":"NOT_CONFIGURED"}
	if not is_finite(dt) or dt<0.0:return {"ok":false,"error":"FINITE_NONNEGATIVE_DT_REQUIRED"}
	if not _flags(input,WORLD_FLAGS):return {"ok":false,"error":"BOOLEAN_FLAGS_REQUIRED"}
	var reaction:Variant=input.get("reaction_kind","idle")
	if not reaction is String or reaction not in REACTION_KINDS:return {"ok":false,"error":"ACTUAL_REACTION_KIND_REQUIRED"}
	var ground_value:Variant=input.get("ground_world_y")
	if not _finite(ground_value):ground_value=input.get("object_world_y")
	if not _finite(ground_value):return {"ok":false,"error":"ACTUAL_GROUND_OR_OBJECT_HEIGHT_REQUIRED"}
	var ground:=float(ground_value)
	var chest_value:Variant=input.get("chest_world_y")
	var chest:=float(chest_value) if _finite(chest_value) else ground+3.0*_unit
	var water:Variant=input.get("water_level")
	var author_water:Variant=(float(water)-ground)/_unit if input.get("in_water",false) and _finite(water) else null
	var author_chest:float=(chest-ground)/_unit
	_advance(minf(dt,.25),author_water,author_chest,input.get("moving",false),input.get("fast",false),input.get("blocked",false) or reaction=="dead" or reaction=="fall")
	var sampled:=snapshot()
	sampled["lift_world"]=_lift*_unit;sampled["speed_world"]=_speed*_unit
	return {"ok":true,"swim":sampled}

func dispose() -> void:
	_ready=false;reset()
