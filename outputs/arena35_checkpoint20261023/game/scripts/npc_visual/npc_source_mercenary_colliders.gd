extends RefCounted
## Original parameterized source constructor output; never actor admission.
const Navigation=preload("res://scripts/navigation/npc_native_navigation.gd")
const Ground=preload("res://scripts/npc_visual/npc_source_ground_support.gd")
# Set only after the independent exporter/schema freeze, before acceptance.
const EXPORTER_SHA="76ba432338ff2673062d88b3695af4a424afaddd7d12bff8cd6dd7f0c80e1d8d"
const WALK_SHA="e80ebf4be2d0404ad5b51d4bf28b756a9cba2b486c43c0797de748c37364dd47"
const FENCE_SHA="6c657e4dc141bcb2489af0e3f60437e2af12741f33f495f7e47f7a46eb2432f2"
const POWER_SHA="5bc7b10ee69cfb601d8b62c72946f79a89db3d97e6cc3a2058c91a39441318db"
const STATIC_BINDINGS={"topology_sha256":"11f256f20ea5f8f5387fa4829173e84cf688aa2ba554aa5b6aacdb85301d67b6","building_data_sha256":"dd304db781ee18da12cb3111a3f8126b89658a2562dee38ccd9c2567c9a3ca15","building_values_sha256":"1a05e2bd1d05ffb48634991c1047fc4c1e7fff873f4a0c1fa08d3cb4792a6b88","building_cache_sha256":"b024890f87a7713246aaaace5ba5a903dfb3bff2626fc525e776d354cf9885f3","ground_helper_sha256":"f0ece358320676f158416900770b43e64df12e68fcde2d80264058d7bee5a3b8"}
var _ready:=false
var _fault:=""
var _busy:=false
var _fixture:=false
var _decode_error:=false
var _lease:=Callable()
var _proof:Dictionary={}
var _bodies:Array=[]
var _descriptors:Array=[]

static func _hex(value:Variant)->bool:
	if not value is String or value.length()!=64:return false
	for i in value.length():
		if value.substr(i,1) not in "0123456789abcdef":return false
	return true
func _decode(value:Variant,scalars:PackedByteArray,depth:int=0)->Variant:
	if depth>48:_decode_error=true;return null
	if value is Dictionary:
		if value.has("$f64"):
			var at:Variant=value["$f64"]
			if value.size()!=1 or not Ground._finite(at) or at<0 or at!=floor(float(at)) or at>=scalars.size()/8:_decode_error=true;return null
			var number:=scalars.decode_double(int(at)*8)
			if not is_finite(number):_decode_error=true
			return number
		var result:Dictionary={}
		for key:String in value:result[key]=_decode(value[key],scalars,depth+1)
		return result
	if value is Array:
		var result:Array=[]
		for item:Variant in value:result.append(_decode(item,scalars,depth+1))
		return result
	return value
func configure(json_bytes:PackedByteArray,scalar_bytes:PackedByteArray,trust:Dictionary,current_lease:Callable,fixture_mode:bool=false)->Dictionary:
	if not Thread.is_main_thread() or _ready or not _fault.is_empty() or _busy:return {"ok":false,"error":"state_or_thread"}
	if EXPORTER_SHA.is_empty():return {"ok":false,"error":"exporter_freeze_pending"}
	for key in ["packet_sha256","scalars_sha256","exporter_sha256"]:
		if not _hex(trust.get(key)):return {"ok":false,"error":"trust_hash"}
	if trust.exporter_sha256!=EXPORTER_SHA or Ground._hash(json_bytes)!=trust.packet_sha256 or Ground._hash(scalar_bytes)!=trust.scalars_sha256:return {"ok":false,"error":"bytes_or_producer"}
	if json_bytes.size()>1048576 or scalar_bytes.size()>1048576 or scalar_bytes.size()%8!=0:return {"ok":false,"error":"size"}
	var parser:=JSON.new()
	if parser.parse(json_bytes.get_string_from_utf8())!=OK or not parser.data is Dictionary:return {"ok":false,"error":"json"}
	_decode_error=false
	var packet:Variant=_decode(parser.data,scalar_bytes)
	if _decode_error or not packet is Dictionary:return {"ok":false,"error":"float64"}
	if packet.get("schema")!="mafiozi.npc-mercenary-colliders/v1" or not packet.get("known") is bool or packet.known!=true or not packet.get("colliders") is Array:return {"ok":false,"error":"source_capture_hold"}
	if not _hex(packet.get("input_sha256")):return {"ok":false,"error":"input_hash"}
	if packet.get("source_world_sha256")!=Ground.WorldSHA or packet.get("context_sha256")!=Ground.ContextSHA or packet.get("static_component_context_sha256")!=Ground.ContextSHA:return {"ok":false,"error":"source_binding"}
	if not packet.get("source_static_bindings") is Dictionary:return {"ok":false,"error":"static_binding"}
	for key in STATIC_BINDINGS:
		if packet.source_static_bindings.get(key)!=STATIC_BINDINGS[key]:return {"ok":false,"error":"static_binding"}
	var pins:Variant=packet.get("source_pins")
	if not pins is Dictionary or pins.get("assets/maps/city_rebuild_v1/walk_preview.mjs")!=WALK_SHA or pins.get("assets/maps/city_rebuild_v1/mercenary_fences.mjs")!=FENCE_SHA or pins.get("assets/maps/city_rebuild_v1/mercenary_power_panel.mjs")!=POWER_SHA:return {"ok":false,"error":"constructor_binding"}
	if fixture_mode:
		if packet.get("kind")!="TEST_ONLY_PARAMETERIZED_ORIGINAL_CONSTRUCTORS" or packet.get("input_fixture_only")!=true:return {"ok":false,"error":"fixture_kind"}
	else:
		if packet.get("kind")!="SOURCE_CAPTURE" or packet.get("input_fixture_only")!=false or not _hex(packet.get("capture_context_sha256")) or packet.capture_context_sha256==Ground.ContextSHA or not current_lease.is_valid():return {"ok":false,"error":"capture_proof"}
		if not packet.get("snapshot_id") is String or packet.snapshot_id.is_empty() or not Ground._finite(packet.get("revision")) or packet.revision<0 or packet.revision!=floor(float(packet.revision)) or packet.revision>9007199254740991.0:return {"ok":false,"error":"capture_identity"}
		if packet.get("session_id")==Ground.Session or not packet.get("frame") is String or packet.frame.is_empty() or not packet.get("input_proof_receipts") is Array or packet.input_proof_receipts.is_empty():return {"ok":false,"error":"capture_receipts"}
		for receipt:Variant in packet.input_proof_receipts:
			if not receipt is Dictionary or not receipt.get("path") is String or receipt.path.is_empty() or not _hex(receipt.get("sha256")):return {"ok":false,"error":"capture_receipts"}
	for key in ["session_id","phase"]:
		if not packet.get(key) is String or packet[key].is_empty():return {"ok":false,"error":"identity"}
	if not packet.get("gate_enabled") is bool:return {"ok":false,"error":"gate"}
	if (not packet.gate_enabled and not packet.colliders.is_empty()) or (packet.gate_enabled and packet.colliders.size() not in [7,8]):return {"ok":false,"error":"source_count"}
	var bodies:Array=[];var descriptors:Array=[];var ids:Dictionary={}
	for record:Variant in packet.colliders:
		if not record is Dictionary or not record.get("id") is String or record.id.is_empty() or ids.has(record.id) or not record.get("polygonCR") is Array or record.polygonCR.size()!=4 or not Ground._finite(record.get("minYM")) or not Ground._finite(record.get("maxYM")) or record.minYM>record.maxYM:return {"ok":false,"error":"source_body"}
		for point:Variant in record.polygonCR:
			if not point is Array or point.size()!=2 or not Ground._finite(point[0]) or not Ground._finite(point[1]):return {"ok":false,"error":"source_polygon"}
		ids[record.id]=true
		bodies.append(Navigation.Body.new(record.polygonCR,record.minYM,record.maxYM));descriptors.append(record.duplicate(true))
	_proof={"source_world_sha256":Ground.WorldSHA,"static_component_context_sha256":Ground.ContextSHA,"capture_context_sha256":packet.get("capture_context_sha256"),"session_id":packet.session_id,"phase":packet.phase,"snapshot_id":packet.get("snapshot_id"),"revision":packet.get("revision"),"frame":packet.get("frame"),"input_sha256":packet.get("input_sha256"),"input_proof_receipts":packet.get("input_proof_receipts",[]).duplicate(true),"source_static_bindings":packet.source_static_bindings.duplicate(true),"packet_sha256":trust.packet_sha256,"scalars_sha256":trust.scalars_sha256,"exporter_sha256":EXPORTER_SHA,"fixture_only":fixture_mode}
	if not fixture_mode:_proof.revision=int(packet.revision)
	_bodies=bodies;_descriptors=descriptors;_lease=current_lease;_fixture=fixture_mode;_ready=true
	if not fixture_mode and not _current():invalidate("capture_lease");return {"ok":false,"error":_fault}
	return {"ok":true,"bodies":bodies.size(),"fixture_only":_fixture,"registered_frame_known":false,"physical_admission":false}
func _current()->bool:
	if _fixture:return true
	if not _lease.is_valid():return false
	var owner:Variant=_lease.get_object()
	if not is_instance_valid(owner) or (owner is Node and owner.is_queued_for_deletion()):return false
	_busy=true
	var answer:Variant=_lease.call()
	_busy=false
	if not _lease.is_valid() or not is_instance_valid(owner) or (owner is Node and owner.is_queued_for_deletion()) or not _fault.is_empty() or not answer is Dictionary or not answer.get("known") is bool or answer.known!=true:return false
	for key in ["source_world_sha256","capture_context_sha256","session_id","phase","snapshot_id","revision","frame","input_sha256"]:
		if not answer.has(key) or typeof(answer[key])!=typeof(_proof[key]) or answer[key]!=_proof[key]:return false
	return true
func collections()->Dictionary:
	if not Thread.is_main_thread():return {"known":false,"error":"thread","physical_admission":false}
	if _busy:invalidate("reentrant")
	if not _ready or not _fault.is_empty():return {"known":false,"error":_fault if _ready else "unconfigured","physical_admission":false}
	if not _current():invalidate("capture_lease");return {"known":false,"error":_fault,"physical_admission":false}
	for i in _bodies.size():
		var body:Variant=_bodies[i];var record:Dictionary=_descriptors[i]
		if not is_instance_valid(body) or body.polygon_cr!=record.polygonCR or body.min_y!=record.minYM or body.max_y!=record.maxYM:invalidate("body_changed");return {"known":false,"error":_fault,"physical_admission":false}
	return {"known":true,"bodies":_bodies.duplicate(),"descriptors":_descriptors.duplicate(true),"provenance":_proof.duplicate(true),"fixture_only":_fixture,"registered_frame_known":false,"physical_admission":false}
func invalidate(reason:String="invalidated")->void:
	if Thread.is_main_thread() and _fault.is_empty():_fault=reason if not reason.is_empty() else "invalidated"
