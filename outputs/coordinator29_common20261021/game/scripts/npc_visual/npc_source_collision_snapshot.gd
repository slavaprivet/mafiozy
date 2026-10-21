extends RefCounted
## Exact STATIC subset +78 verified initial entries. NOT full registered frame.
const Navigation=preload("res://scripts/navigation/npc_native_navigation.gd")
const Building=preload("res://scripts/npc_visual/npc_source_building_support_cache.gd")
const Landscape=preload("res://scripts/npc_visual/npc_source_landscape_support.gd")
const DATA_SHA="bce46bc70bd2b4526f1e860ad5d95ae85d093ff4a678b10716879b871f98f839"
const BUILDING_SCRIPT_SHA="5e2c1df165c97e9824bcbf4ee2aa3ce93e2d7873f27eec794cd18f2c653e227e"
const BUILDING_COLLECTIONS_SHA="b9f665cd243a15dd93e335e1761e9208b044d97254b2545f4f59b06694271273"
const ENGINE="4.7.2-stable (official)"
const PHASE="OFFLINE_DETERMINISTIC_CURRENT_SOURCE_STATIC_GEOMETRY_NO_DYNAMIC_FRAME"
const COVERAGE="PARTIAL_STATIC_AND_VERIFIED_78_ENTRIES_NOT_FULL_REGISTERED_FRAME"
const PROVIDER_ID="mafiozi.source-static-entry-collision.component-v1"
const PROVIDER_VERSION="1"
const MISSING=["Mercenary fence/power panel branch state and original collider additions","Current dynamic fleet/logical/train frame","Actual resolver registration lease"]
var _ready:=false
var _busy:=false
var _fault:=""
var _building:RefCounted
var _index:RefCounted
var _revision:=-1
var _proof:Dictionary={}
var _records:Dictionary={}
var _calls:=0
var _setup_cpu:Dictionary={}
var _source_bounds:Dictionary={}

func invalidate(reason:String="invalidated")->void:
	if _fault.is_empty():_fault=reason if not reason.is_empty() else "invalidated"
func _error(error:String)->Dictionary:
	_source_bounds.clear()
	return {"ok":false,"error":error,"registered_frame_known":false,"physical_admission":false}
static func _scalar(base64_value:Variant)->float:
	if not base64_value is String:return NAN
	var bytes:=Marshalls.base64_to_raw(base64_value)
	return bytes.decode_double(0) if bytes.size()==8 else NAN
func _body(polygon:Variant,bottom:Variant,top:Variant)->Variant:
	if not polygon is Array or polygon.is_empty() or polygon.size()>4096 or not (bottom is float or bottom is int) or not (top is float or top is int) or not is_finite(float(bottom)) or not is_finite(float(top)):return null
	var min_c:=INF;var max_c:=-INF;var min_r:=INF;var max_r:=-INF
	for point:Variant in polygon:
		if not point is Array or point.size()!=2 or not (point[0] is float or point[0] is int) or not (point[1] is float or point[1] is int):return null
		var c:float=point[0];var r:float=point[1]
		if not is_finite(c) or not is_finite(r) or absf(c)>1e6 or absf(r)>1e6:return null
		min_c=minf(min_c,c);max_c=maxf(max_c,c);min_r=minf(min_r,r);max_r=maxf(max_r,r)
	var body:=Navigation.Body.new(polygon,float(bottom),float(top))
	_source_bounds[body]=[int(floor(min_r/4.)),int(floor(max_r/4.)),int(floor(min_c/4.)),int(floor(max_c/4.))]
	return body
func configure(bytes:PackedByteArray,building_source_provider:Variant,trust:Dictionary)->Dictionary:
	var setup_started:=Time.get_ticks_usec()
	if _busy:invalidate("reentrant");return _error(_fault)
	if not Thread.is_main_thread() or _ready or not _fault.is_empty():return _error("state_or_thread")
	if Engine.get_version_info().string!=ENGINE:return _error("engine")
	for key in ["data_sha256","source_world_sha256","context_sha256","session_id","phase"]:
		if not trust.get(key) is String or trust[key].is_empty():return _error("trust")
	if trust.data_sha256!=DATA_SHA or trust.source_world_sha256!=Landscape.SOURCE_SHA or trust.context_sha256!=Landscape.CONTEXT_SHA or trust.session_id!=Landscape.SESSION or trust.phase!=PHASE or Landscape._hash(bytes)!=DATA_SHA:return _error("binding")
	if typeof(building_source_provider)!=TYPE_OBJECT or not is_instance_valid(building_source_provider) or not building_source_provider is RefCounted or building_source_provider.get_script()!=Building:return _error("building_class")
	if Landscape._hash(FileAccess.get_file_as_bytes("res://scripts/npc_visual/npc_source_building_support_cache.gd"))!=BUILDING_SCRIPT_SHA or Landscape._hash(FileAccess.get_file_as_bytes("res://scripts/npc_visual/npc_source_building_support.gd"))!=Building.SOURCE_HELPER_SHA:return _error("building_code_binding")
	_building=building_source_provider
	if not _building._configured or not _building._fault.is_empty():return _error("building_unavailable")
	_busy=true
	var entry_packet:Variant=_building.collision_collections()
	_busy=false
	if not is_instance_valid(_building) or not _fault.is_empty() or not _building._fault.is_empty():return _error("building_lifetime_or_reentry")
	if not entry_packet is Dictionary or not entry_packet.get("known") is bool or not entry_packet.known or entry_packet.get("phase")!=Building.PHASE or not entry_packet.get("collections") is Array or entry_packet.collections.size()!=78:return _error("building_shape")
	if Landscape._hash(var_to_bytes(entry_packet.collections))!=BUILDING_COLLECTIONS_SHA:return _error("building_collections_changed")
	var entries_captured:=Time.get_ticks_usec()
	var ids:Dictionary={}
	for entry:Variant in entry_packet.collections:
		if not entry is Dictionary or not entry.get("entry_id") is String or entry.entry_id.is_empty() or ids.has(entry.entry_id) or not entry.get("bodies") is Array:return _error("entry_shape")
		ids[entry.entry_id]=true
	var parser:=JSON.new()
	if parser.parse(bytes.get_string_from_utf8())!=OK or not parser.data is Dictionary:return _error("json")
	var packet:Dictionary=parser.data
	if packet.schema!="mafiozi.npc-registered-navigation-packed-static/v1" or packet.source_world_sha256!=Landscape.SOURCE_SHA or packet.context_sha256!=Landscape.CONTEXT_SHA or packet.phase!=PHASE:return _error("packet_binding")
	var data:Dictionary=packet.data
	if _scalar(data.world_scale_f64_le_b64)!=4.1 or data.building_exclusion!="EXCLUDE_AUTHORED_INSTANCE_ONLY_IF_EXACT_ENTRY_ID_PRESENT_IN_VERIFIED_ENTRY_PACKET":return _error("scale_or_exclusion")
	var pool_bytes:=Landscape._buffer(data.polygon_pool,"float64_le",66824,8)
	if pool_bytes.is_empty() or data.polygon_pool.fields!=["c","r"]:return _error("pool")
	var pool:=pool_bytes.to_float64_array()
	var data_decoded:=Time.get_ticks_usec()
	var bodies:Array=[];var metadata:Array=[]
	for record:Dictionary in data.bodies:
		if record.group_id=="authored-nonentry-items" and ids.has(record.instance_id):continue
		var polygon:Array=[]
		var offset:=int(record.polygon_offset);var count:=int(record.polygon_count)
		if count<1 or count>4096 or offset<0 or (offset+count)*2>pool.size():return _error("pool_span")
		for i in count:polygon.append([pool[(offset+i)*2],pool[(offset+i)*2+1]])
		var body:Variant=_body(polygon,_scalar(record.minYM_f64_le_b64),_scalar(record.maxYM_f64_le_b64))
		if body==null:return _error("static_body")
		metadata.append({"group_id":"world-static","local_ordinal":bodies.size(),"global_ordinal":bodies.size(),"source":record})
		bodies.append(body)
	if bodies.size()!=3062:return _error("static_count")
	var entry_count:=0
	for entry:Dictionary in entry_packet.collections:
		var local:=0
		for record:Variant in entry.bodies:
			if not record is Dictionary:return _error("entry_body")
			var body:Variant=_body(record.get("polygonCR"),record.get("minYM"),record.get("maxYM"))
			if body==null:return _error("entry_body_fields")
			metadata.append({"group_id":"entry:"+entry.entry_id,"local_ordinal":local,"global_ordinal":bodies.size(),"source":record})
			bodies.append(body);local+=1;entry_count+=1
	if entry_count!=17086 or bodies.size()!=20148:return _error("entry_count")
	var bodies_created:=Time.get_ticks_usec()
	var index:=Navigation.SpatialIndex.new(4.0)
	if not index.publish([bodies],PROVIDER_ID,1,0):return _error("index_publish")
	var index_published:=Time.get_ticks_usec()
	# Locate the cloned Body via original source-order bucket offsets. Identical
	# polygons remain distinct identities; equality/hash dedup would be wrong.
	var counters:Dictionary={};var records:Dictionary={}
	for i in bodies.size():
		var source:RefCounted=bodies[i]
		var bounds:Array=_source_bounds[source]
		var r0:int=bounds[0];var r1:int=bounds[1];var c0:int=bounds[2];var c1:int=bounds[3]
		var row:Dictionary=counters.get(r0,{});var bucket:Array=index.query(c0*4.,r0*4.)
		var ordinal:int=row.get(c0,0)
		if ordinal>=bucket.size():return _error("clone_mapping")
		var clone:RefCounted=bucket[ordinal]
		if records.has(clone) or clone.polygon_cr!=source.polygon_cr or clone.min_y!=source.min_y or clone.max_y!=source.max_y:return _error("clone_mapping")
		records[clone]={"polygon":clone.polygon_cr,"bottom":clone.min_y,"top":clone.max_y,"descriptor":metadata[i]}
		for r in range(r0,r1+1):
			if not counters.has(r):counters[r]={}
			row=counters[r]
			for c in range(c0,c1+1):
				row[c]=int(row.get(c,0))+1
	_source_bounds.clear()
	_index=index;_revision=index.revision;_records=records
	_proof={"data_sha256":DATA_SHA,"source_world_sha256":Landscape.SOURCE_SHA,"context_sha256":Landscape.CONTEXT_SHA,"session_id":Landscape.SESSION,"phase":PHASE,"building_phase":Building.PHASE,"building_data_sha256":Building.DATA_SHA,"building_values_sha256":Building.VALUES_SHA,"building_cache_sha256":Building.CACHE_SHA,"building_collections_sha256":BUILDING_COLLECTIONS_SHA,"engine":ENGINE,"provider_id":PROVIDER_ID,"provider_version":PROVIDER_VERSION,"coverage_status":COVERAGE}
	_ready=true
	_setup_cpu={"capture_entries_us":entries_captured-setup_started,"decode_static_us":data_decoded-entries_captured,"create_bodies_us":bodies_created-data_decoded,"publish_native_index_us":index_published-bodies_created,"map_clones_us":Time.get_ticks_usec()-index_published,"total_us":Time.get_ticks_usec()-setup_started}
	return {"ok":true,"bodies":20148,"groups":79,"coverage_status":COVERAGE,"registered_frame_known":false,"physical_admission":false}
func _available()->String:
	if _busy:invalidate("reentrant");return _fault
	if not Thread.is_main_thread():return "thread"
	if not _ready:return "unconfigured"
	if not _fault.is_empty():return _fault
	if not is_instance_valid(_building) or not _building._configured or not _building._fault.is_empty():invalidate("building_unavailable");return _fault
	if not _index.valid() or _index.revision!=_revision:invalidate("index_changed");return _fault
	return ""
func _answer(value:Variant,error:String="")->Dictionary:
	_calls+=1
	return {"known":error.is_empty(),"defined":error.is_empty(),"value":value if error.is_empty() else null,"error":error,"provenance":_proof.duplicate(true),"coverage_status":COVERAGE,"missing":MISSING.duplicate(),"registered_frame_known":false,"physical_admission":false}
func _checked(bodies:Array)->String:
	for body:Variant in bodies:
		if typeof(body)!=TYPE_OBJECT or not is_instance_valid(body) or not body is Navigation.Body or not _records.has(body):invalidate("foreign_body");return _fault
		var record:Dictionary=_records[body]
		if not is_same(body.polygon_cr,record.polygon) or body.min_y!=record.bottom or body.max_y!=record.top:invalidate("body_mutated");return _fault
	return ""
func bodies_at(c:float,r:float)->Dictionary:
	var error:=_available()
	if not error.is_empty():return _answer(null,error)
	var bodies:Array=_index.query(c,r)
	if not _index.last_error.is_empty():return _answer(null,_index.last_error)
	return _answer(bodies,_checked(bodies))
func bodies_in_bounds(min_c:float,min_r:float,max_c:float,max_r:float)->Dictionary:
	var error:=_available()
	if not error.is_empty():return _answer(null,error)
	var bodies:Array=_index.query_bounds(min_c,min_r,max_c,max_r)
	if not _index.last_error.is_empty():return _answer(null,_index.last_error)
	bodies.make_read_only()
	return _answer(bodies,_checked(bodies))
func body_descriptor(body:Variant)->Dictionary:
	var error:=_available()
	if not error.is_empty():return _answer(null,error)
	error=_checked([body])
	return _answer(_records[body].descriptor.duplicate(true)) if error.is_empty() else _answer(null,error)
func snapshot()->Dictionary:
	return {"ready":_ready,"fault":_fault,"calls":_calls,"index":_index.stats() if _ready else {},"setup_cpu":_setup_cpu.duplicate(),"provenance":_proof.duplicate(true),"coverage_status":COVERAGE,"missing":MISSING.duplicate(),"registered_frame_known":false,"physical_admission":false}
