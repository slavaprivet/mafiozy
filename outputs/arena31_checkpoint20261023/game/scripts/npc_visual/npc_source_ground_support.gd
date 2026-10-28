extends RefCounted
## Original groundHeight composition, approved offline initial source snapshot.
## This component does not register navigation or authorize physical placement.
const BuildingPath := "res://scripts/npc_visual/npc_source_building_support_cache.gd"
const BuildingBasePath := "res://scripts/npc_visual/npc_source_building_support.gd"
const LandscapePath := "res://scripts/npc_visual/npc_source_landscape_support.gd"
const RailPath := "res://scripts/npc_visual/npc_source_rail_support.gd"
const BuildingSHA := "5e2c1df165c97e9824bcbf4ee2aa3ce93e2d7873f27eec794cd18f2c653e227e"
const BuildingBaseSHA := "25fbaa80e9465f907e0768c68efe792867cbc72e48f1cb40dae5a7a2958f11c5"
const LandscapeSHA := "4e22e66258f4b013c5ab0f152e0a4d104f7a61eb7a2cba9f80b8b7799fa907b1"
# Corrected scalar Math.hypot rail, independently exact-reviewed by parent.
const RailSHA := "6259bc1d93720bcbd0861d338cf58b4426d8d43ebbcd38c83d3c984646a99ec1"
const WorldSHA := "9f5cc5a1a80db37dbf3136ecab66c4cdba2bd679dbea03aa10800ac16d8a95b5"
const ContextSHA := "a05ad020429ea8994dba534fe2d6e0886ac02975aadc7db531ea11d93a560f9c"
const Session := "godot-preview-new-session-20260927-01"
const Phase := "OFFLINE_STATIC_NATIVE_REGISTRATION_PREREQUISITES_NO_DYNAMIC_FRAME"
const TerrainDataSHA := "d744b99aa4e4f36c7d5913f9b87cb656ddf4b17cd053f6ad23cc42ebacd2495b"
const RailDataSHA := "f3c7ab6c3af07f8c3d9f323f09383923d4b7567a4224217a658e66682ffb6087"
const BuildingCacheSHA := "b024890f87a7713246aaaace5ba5a903dfb3bff2626fc525e776d354cf9885f3"
var _configured := false
var _busy := false
var _fault := ""
var _proof: Dictionary = {}
var _errors: Dictionary = {}
var _building: RefCounted
var _landscape: RefCounted
var _rail: RefCounted
var _calls := 0

static func _hash(bytes: PackedByteArray) -> String:
	var h := HashingContext.new(); h.start(HashingContext.HASH_SHA256); h.update(bytes)
	return h.finish().hex_encode()
static func _finite(v: Variant) -> bool:
	return (v is float or v is int) and is_finite(float(v))

func configure(building_cache: PackedByteArray, terrain_data: PackedByteArray, rail_data: PackedByteArray, trust: Dictionary) -> Dictionary:
	if not Thread.is_main_thread() or _busy or _configured or not _fault.is_empty(): return {"ok":false,"error":"state_or_thread"}
	for key in ["source_world_sha256","context_sha256","session_id","phase","snapshot_id"]:
		if not trust.get(key) is String or trust[key].is_empty(): return {"ok":false,"error":"trust_fields"}
	if trust.source_world_sha256 != WorldSHA or trust.context_sha256 != ContextSHA or trust.session_id != Session or trust.phase != Phase or not trust.get("revision") is int or trust.revision < 0: return {"ok":false,"error":"source_lease"}
	if not trust.get("components") is Dictionary: return {"ok":false,"error":"components"}
	var expected := {"building":BuildingSHA,"building_base":BuildingBaseSHA,"landscape":LandscapeSHA,"rail":RailSHA}
	for key in expected:
		if trust.components.get(key) != expected[key]: return {"ok":false,"error":"component_binding"}
	_proof={"source_world_sha256":WorldSHA,"context_sha256":ContextSHA,"session_id":Session,"phase":Phase,"snapshot_id":trust.snapshot_id,"revision":trust.revision,"provider_id":"mafiozi.source-ground-support.component-v1","provider_version":"1","components":expected.duplicate(true),"data":{"building_cache":BuildingCacheSHA,"terrain":TerrainDataSHA,"rail":RailDataSHA},"building_phase":"OFFLINE_NEW_SESSION_SOURCE_REFRESH_INITIAL_DOORS_UPDATE_ZERO_BEFORE_NATIVE_REGISTRATION"}
	_errors={}
	if FileAccess.get_sha256(BuildingPath) != BuildingSHA or FileAccess.get_sha256(BuildingBasePath) != BuildingBaseSHA:
		_errors.building="helper_binding"
	elif building_cache.is_empty(): _errors.building="missing_bytes"
	else:
		var script: GDScript=load(BuildingPath)
		var candidate: RefCounted=script.new()
		var result: Dictionary=candidate.configure_cached(building_cache)
		if result.get("ok") == true: _building=candidate
		else: _errors.building=str(result.get("error","setup"))
	if FileAccess.get_sha256(LandscapePath) != LandscapeSHA: _errors.landscape="helper_binding"
	elif terrain_data.is_empty(): _errors.landscape="missing_bytes"
	else:
		var script: GDScript=load(LandscapePath)
		var candidate: RefCounted=script.new()
		var lease: Dictionary=trust.duplicate(true); lease.data_sha256=TerrainDataSHA
		var result: Dictionary=candidate.configure(terrain_data,lease)
		if result.get("ok") == true: _landscape=candidate
		else: _errors.landscape=str(result.get("error","setup"))
	if RailSHA.is_empty(): _errors.rail="rail_peer_review_hold"
	elif FileAccess.get_sha256(RailPath) != RailSHA: _errors.rail="helper_binding"
	elif rail_data.is_empty(): _errors.rail="missing_bytes"
	elif not is_instance_valid(_landscape): _errors.rail="landscape_setup_unavailable"
	else:
		var script: GDScript=load(RailPath)
		var candidate: RefCounted=script.new()
		var lease: Dictionary=trust.duplicate(true); lease.data_sha256=RailDataSHA
		# Rail owns a callable to our private landscape, never a back-reference to
		# this compositor. This avoids a RefCounted ground→rail→ground cycle.
		var result: Dictionary=candidate.configure(rail_data,lease,Callable(_landscape,"ground_landscape"))
		if result.get("ok") == true: _rail=candidate
		else: _errors.rail=str(result.get("error","setup"))
	if not _errors.is_empty():
		_building=null; _landscape=null; _rail=null
		return {"ok":false,"error":"incomplete_source_components","component_errors":_errors.duplicate(true),"combined_ground":false,"physical_admission":false}
	_configured=true
	return {"ok":true,"component_errors":_errors.duplicate(true),"provenance":_proof.duplicate(true),"combined_ground":false,"physical_admission":false}

func _component(name:String,answer:Variant,allow_null:bool)->Dictionary:
	if not answer is Dictionary: return {"error":name+"_response"}
	var captured: Dictionary=answer.duplicate(true)
	if not captured.get("known") is bool or not captured.known: return {"error":name+"_unknown:"+str(captured.get("error","unknown"))}
	if not captured.has("value") or (captured.value == null and not allow_null): return {"error":name+"_value"}
	if name != "building":
		if captured.get("defined") != true or not captured.get("provenance") is Dictionary: return {"error":name+"_proof"}
		var p: Dictionary=captured.provenance
		for key in ["source_world_sha256","context_sha256","session_id","phase"]:
			if not p.has(key) or typeof(p[key]) != typeof(_proof[key]) or p[key] != _proof[key]: return {"error":name+"_lease"}
		if name == "landscape" or name == "water":
			if p.get("data_sha256") != TerrainDataSHA or p.get("snapshot_id") != _proof.snapshot_id or p.get("revision") != _proof.revision or p.get("provider_id") != "mafiozi.source-landscape-support.component-v1" or p.get("provider_version") != "1": return {"error":name+"_binding"}
		else:
			if p.get("data_sha256") != RailDataSHA or p.get("terrain_sha256") != TerrainDataSHA or p.get("provider_id") != "mafiozi.source-rail-support.component-v1" or p.get("provider_version") != "1": return {"error":"rail_binding"}
	return {"error":"","value":captured.value}

func _response(value:Variant,error:String,branch:String,visited:Array)->Dictionary:
	_calls+=1
	var complete: bool=_configured and _fault.is_empty() and is_instance_valid(_building) and is_instance_valid(_landscape) and is_instance_valid(_rail)
	if complete:
		complete=_building.get("_fault").is_empty() and _landscape.get("_fault").is_empty() and _rail.get("_fault").is_empty()
	return {"known":error.is_empty(),"defined":error.is_empty(),"value":value if error.is_empty() else null,"error":error,"source_branch":branch,"visited":visited.duplicate(true),"provenance":_proof.duplicate(true),"combined_ground":error.is_empty() and complete,"coverage":"full_source_composition" if complete else "component_only_hold","physical_admission":false,"dynamic_advance":false}

func ground_height(x:float,z:float)->Dictionary:
	if not Thread.is_main_thread(): return {"known":false,"defined":false,"value":null,"error":"thread","combined_ground":false,"physical_admission":false}
	if _busy: invalidate("reentrant"); return _response(null,_fault,"",[])
	if not _configured or not _fault.is_empty(): return _response(null,_fault if _configured else "unconfigured","",[])
	if not is_finite(x) or not is_finite(z): return _response(null,"coordinates","",[])
	_busy=true
	var result: Dictionary=_evaluate(x,z)
	_busy=false
	return result

func _evaluate(x:float,z:float)->Dictionary:
	var visited: Array=["building"]
	if not is_instance_valid(_building): return _response(null,"building_unavailable:"+str(_errors.get("building","missing")),"building",visited)
	var result: Dictionary=_component("building",_building.floor_at(x,z,0.0),true)
	if not result.error.is_empty(): return _response(null,result.error,"building",visited)
	if result.value != null:
		return _response(result.value,"" if _finite(result.value) else "building_nonfinite","building",visited)
	visited.append("rail")
	if not is_instance_valid(_rail): return _response(null,"rail_unavailable:"+str(_errors.get("rail","missing")),"rail",visited)
	result=_component("rail",_rail.floor_height(x,z),true)
	if not result.error.is_empty(): return _response(null,result.error,"rail",visited)
	if result.value != null: return _response(result.value,"" if _finite(result.value) else "rail_nonfinite","rail",visited)
	visited.append("water")
	if not is_instance_valid(_landscape): return _response(null,"water_unavailable:"+str(_errors.get("landscape","missing")),"water",visited)
	result=_component("water",_landscape.water_at(x,z),true)
	if not result.error.is_empty(): return _response(null,result.error,"water",visited)
	if result.value != null:
		if not result.value is Dictionary or not _finite(result.value.get("floor")): return _response(null,"water_floor","water",visited)
		return _response(float(result.value.floor),"","water",visited)
	visited.append("landscape")
	result=_component("landscape",_landscape.ground_landscape(x,z),false)
	if not result.error.is_empty(): return _response(null,result.error,"landscape",visited)
	return _response(result.value,"" if _finite(result.value) else "landscape_nonfinite","landscape",visited)

func invalidate(reason:String="invalidated")->void:
	if not Thread.is_main_thread(): return
	if _fault.is_empty(): _fault=reason if not reason.is_empty() else "invalidated"
func snapshot()->Dictionary:
	if not Thread.is_main_thread(): return {"known":false,"error":"thread"}
	return {"configured":_configured,"fault":_fault,"calls":_calls,"component_errors":_errors.duplicate(true),"provenance":_proof.duplicate(true),"combined_ground":false,"physical_admission":false}
