extends RefCounted
## Exact exported source terrain component, not combined building/rail support,
## Geometry registration, physical admission or source gameplay authority.
const DATA_SHA := "d744b99aa4e4f36c7d5913f9b87cb656ddf4b17cd053f6ad23cc42ebacd2495b"
const SOURCE_SHA := "9f5cc5a1a80db37dbf3136ecab66c4cdba2bd679dbea03aa10800ac16d8a95b5"
const CONTEXT_SHA := "a05ad020429ea8994dba534fe2d6e0886ac02975aadc7db531ea11d93a560f9c"
const SESSION := "godot-preview-new-session-20260927-01"
const PHASE := "OFFLINE_STATIC_NATIVE_REGISTRATION_PREREQUISITES_NO_DYNAMIC_FRAME"
const PROVIDER_ID := "mafiozi.source-landscape-support.component-v1"
const PROVIDER_VERSION := "1"
var _ready := false
var _fault := ""
var _xs := PackedFloat64Array()
var _zs := PackedFloat64Array()
var _heights := PackedFloat32Array()
var _bounds: Dictionary = {}
var _city: Dictionary = {}
var _lakes: Array = []
var _topology: Dictionary = {}
var _proof: Dictionary = {}
var _width := 0
var _height := 0
var _calls := 0

static func _hash(bytes: PackedByteArray) -> String:
	var h := HashingContext.new(); h.start(HashingContext.HASH_SHA256); h.update(bytes)
	return h.finish().hex_encode()

static func _finite(v: Variant) -> bool:
	return (v is int or v is float) and is_finite(float(v))

static func _buffer(spec: Dictionary, dtype: String, count: int, stride: int) -> PackedByteArray:
	if not spec.get("dtype") is String or spec.dtype != dtype or not _finite(spec.get("count")) or spec.count != count or not spec.get("bytes_base64") is String or not spec.get("sha256") is String: return PackedByteArray()
	var bytes := Marshalls.base64_to_raw(spec.bytes_base64)
	return bytes if bytes.size() == count*stride and _hash(bytes) == spec.sha256 else PackedByteArray()

static func _overlay(data: Dictionary, rows: Array) -> bool:
	var seen := {}
	for row: Variant in rows:
		if not row is Dictionary or not row.get("path") is Array or row.path.is_empty() or not row.get("bytes_le") is Array or row.bytes_le.size() != 8: return false
		var key := JSON.stringify(row.path)
		if seen.has(key): return false
		seen[key] = true
		var bytes := PackedByteArray()
		for value: Variant in row.bytes_le:
			if not _finite(value) or float(value) != floor(float(value)) or value < 0 or value > 255: return false
			bytes.append(int(value))
		var decoded := bytes.decode_double(0)
		if not is_finite(decoded): return false
		var cursor: Variant = data
		for i in row.path.size():
			var index: Variant = row.path[i]
			if cursor is Dictionary:
				if not index is String or not cursor.has(index): return false
			elif cursor is Array:
				if not _finite(index) or float(index) != floor(float(index)) or index < 0 or index >= cursor.size(): return false
				index = int(index)
			else: return false
			if i == row.path.size()-1:
				if not _finite(cursor[index]): return false
				cursor[index] = decoded
			else: cursor = cursor[index]
	return true

func configure(data_bytes: PackedByteArray, trust: Dictionary) -> Dictionary:
	if not Thread.is_main_thread() or _ready or not _fault.is_empty(): return {"ok":false,"error":"already_configured_or_thread_or_fault"}
	for key in ["data_sha256","source_world_sha256","context_sha256","session_id","phase","snapshot_id"]:
		if not trust.get(key) is String or trust[key].is_empty(): return {"ok":false,"error":"trust_fields"}
	if not trust.get("revision") is int or trust.revision < 0: return {"ok":false,"error":"revision"}
	if trust.data_sha256 != DATA_SHA or trust.source_world_sha256 != SOURCE_SHA or trust.context_sha256 != CONTEXT_SHA or trust.session_id != SESSION or trust.phase != PHASE or _hash(data_bytes) != DATA_SHA: return {"ok":false,"error":"byte_or_source_binding"}
	var parsed := JSON.new()
	if parsed.parse(data_bytes.get_string_from_utf8()) != OK or not parsed.data is Dictionary: return {"ok":false,"error":"json"}
	var packet: Dictionary = parsed.data
	if packet.get("schema") != "mafiozi.npc-registered-navigation-terrain/v1" or packet.get("source_world_sha256") != SOURCE_SHA or packet.get("context_sha256") != CONTEXT_SHA or packet.get("session_id") != SESSION or packet.get("phase") != PHASE or not packet.get("data") is Dictionary or not packet.get("data_float64") is Array: return {"ok":false,"error":"packet_binding"}
	var data: Dictionary = packet.data
	if not _overlay(data,packet.data_float64): return {"ok":false,"error":"float64_overlay"}
	if not _finite(data.get("world_scale")) or data.world_scale != 4.1: return {"ok":false,"error":"world_scale"}
	var landscape: Dictionary = data.landscape; var grid: Dictionary = landscape.grid
	var width := int(grid.width); var height := int(grid.height)
	if width != 307 or height != 331: return {"ok":false,"error":"grid_shape"}
	var xb := _buffer(grid.xs,"float64_le",width,8); var zb := _buffer(grid.zs,"float64_le",height,8); var hb := _buffer(grid.heights,"float32_le",width*height,4)
	if xb.is_empty() or zb.is_empty() or hb.is_empty(): return {"ok":false,"error":"grid_bytes"}
	var xs := xb.to_float64_array(); var zs := zb.to_float64_array(); var heights := hb.to_float32_array()
	for i in xs.size():
		if not is_finite(xs[i]) or i>0 and xs[i]<=xs[i-1]: return {"ok":false,"error":"grid_axis"}
	for i in zs.size():
		if not is_finite(zs[i]) or i>0 and zs[i]<=zs[i-1]: return {"ok":false,"error":"grid_axis"}
	for value in heights:
		if not is_finite(value): return {"ok":false,"error":"grid_heights"}
	var topology: Dictionary = data.topology
	for key in ["grid","walkableMask","roadMask","protectedMask","policeMask"]:
		if not topology.get(key) is Array or topology[key].size()!=200: return {"ok":false,"error":"topology_rows"}
		for row: Variant in topology[key]:
			if not row is Array or row.size()!=180: return {"ok":false,"error":"topology_columns"}
	_bounds=landscape.bounds;_city=landscape.city_bounds;_lakes=landscape.lakes;_topology=topology
	_xs=xs;_zs=zs;_heights=heights;_width=width;_height=height
	_proof={"data_sha256":DATA_SHA,"source_world_sha256":SOURCE_SHA,"context_sha256":CONTEXT_SHA,"session_id":SESSION,"phase":PHASE,"snapshot_id":trust.snapshot_id,"revision":trust.revision,"provider_id":PROVIDER_ID,"provider_version":PROVIDER_VERSION}
	_ready=true
	return {"ok":true,"combined_ground":false,"physical_admission":false}

func invalidate(reason: String="invalidated") -> void:
	if _fault.is_empty(): _fault=reason if not reason.is_empty() else "invalidated"

func snapshot() -> Dictionary:
	return {"ready":_ready,"fault":_fault,"calls":_calls,"provenance":_proof.duplicate(true),"combined_ground":false,"physical_admission":false}

func _response(value: Variant, known: bool=true, error: String="") -> Dictionary:
	_calls+=1
	return {"known":known,"defined":known,"value":value if known else null,"error":error,"provenance":_proof.duplicate(true),"combined_ground":false,"physical_admission":false}

func _available(x: float, z: float) -> String:
	if not Thread.is_main_thread(): return "thread"
	if not _ready: return "unconfigured"
	if not _fault.is_empty(): return _fault
	if not is_finite(x) or not is_finite(z): return "coordinates"
	return ""

func _in_bounds(x: float, z: float) -> bool:
	return x>=_bounds.minX and x<=_bounds.maxX and z>=_bounds.minZ and z<=_bounds.maxZ

func _inside_city(x: float, z: float) -> bool:
	return x>=_city.minX and x<_city.maxX and z>=_city.minZ and z<_city.maxZ

func _contains(x: float,z: float) -> bool:
	return _in_bounds(x,z) and not _inside_city(x,z)

func _covered(x: float,z: float) -> bool:
	return _in_bounds(x,z) or (x>=0.0 and x<180*4.1 and z>=0.0 and z<200*4.1)

static func _interval(axis: PackedFloat64Array, v: float) -> int:
	var left:=0;var right:=axis.size()-1
	while right-left>1:
		var middle: int=(left+right)>>1
		if axis[middle]<=v:left=middle
		else:right=middle
	return mini(axis.size()-2,left)

func _ground(x: float,z: float) -> float:
	# Exact original internal zero outside plan/city is also used by slopeAt.
	if not _in_bounds(x,z) or _inside_city(x,z): return 0.0
	var i:=_interval(_xs,x);var j:=_interval(_zs,z)
	var u:float=(x-_xs[i])/(_xs[i+1]-_xs[i]);var v:float=(z-_zs[j])/(_zs[j+1]-_zs[j])
	var a:float=_heights[j*_width+i];var b:float=_heights[j*_width+i+1];var c:float=_heights[(j+1)*_width+i];var d:float=_heights[(j+1)*_width+i+1]
	return a+(b-a)*u+(d-b)*v if u>=v else a+(d-c)*u+(c-a)*v

static func _hypot(x:float,z:float)->float:
	# Original Math.hypot uses V8's normalized two-argument arithmetic.
	# Preserve strict lake/slope/water boundaries without widening thresholds.
	var a:=absf(x);var b:=absf(z)
	if is_inf(a) or is_inf(b):return INF
	if is_nan(a) or is_nan(b):return NAN
	var largest:=maxf(a,b)
	if largest==0.0:return 0.0
	var normalized_a:=a/largest;var normalized_b:=b/largest
	var squared_a:=normalized_a*normalized_a;var squared_b:=normalized_b*normalized_b
	return sqrt(squared_a+squared_b)*largest

func _lake_radius(lake:Dictionary,x:float,z:float)->float:
	var dx:float=(x-lake.x)/lake.rx;var dz:float=(z-lake.z)/lake.rz;var angle:=atan2(dz,dx)
	return _hypot(dx,dz)/(1.0+.065*sin(3.0*angle)+.035*cos(5.0*angle))

func _landscape_water(x:float,z:float)->Variant:
	if not _contains(x,z):return null
	for lake:Dictionary in _lakes:
		if _lake_radius(lake,x,z)>1.12:continue
		var floor_y:=_ground(x,z);var depth:float=lake.level-floor_y
		if depth>.015:return {"id":lake.id,"level":lake.level,"floor":floor_y,"depth":depth}
	return null

func _tile(row:int,col:int)->Variant:
	return _topology.grid[row][col] if row>=0 and row<200 and col>=0 and col<180 else null

func _water(x:float,z:float)->Variant:
	if _contains(x,z):return _landscape_water(x,z)
	var r:=int(floor(z/4.1));var c:=int(floor(x/4.1))
	if _tile(r,c)!=16 or bool(_topology.protectedMask[r][c]):return null
	var shore:=3.5
	for rr in range(r-1,r+2):
		for cc in range(c-1,c+2):
			if _tile(rr,cc)==16:continue
			var dx:=maxf(maxf(cc*4.1-x,0.0),x-(cc+1)*4.1);var dz:=maxf(maxf(rr*4.1-z,0.0),z-(rr+1)*4.1)
			shore=minf(shore,_hypot(dx,dz))
	var floor_y:float=-minf(2.4,shore*.9)
	return {"level":-.18,"depth":maxf(0.0,-.18-floor_y),"floor":floor_y}

func _can_walk(x:float,z:float)->bool:
	if not _contains(x,z):return false
	if _landscape_water(x,z)!=null:return true
	return _hypot(_ground(x+.5,z)-_ground(x-.5,z),_ground(x,z+.5)-_ground(x,z-.5))<.78

func ground_landscape(x:float,z:float)->Dictionary:
	var error:=_available(x,z)
	if not error.is_empty():return _response(null,false,error)
	if not _in_bounds(x,z):return _response(null,false,"outside_landscape_coverage")
	return _response(_ground(x,z))

func water_at(x:float,z:float)->Dictionary:
	var error:=_available(x,z)
	if not error.is_empty():return _response(null,false,error)
	if not _covered(x,z):return _response(null,false,"outside_coverage")
	return _response(_water(x,z))

func contains(x:float,z:float)->Dictionary:
	var error:=_available(x,z)
	return _response(_contains(x,z)) if error.is_empty() else _response(null,false,error)

func can_walk(x:float,z:float)->Dictionary:
	var error:=_available(x,z)
	if not error.is_empty():return _response(null,false,error)
	if not _covered(x,z):return _response(null,false,"outside_coverage")
	return _response(_can_walk(x,z))

func terrain_allows(x:float,z:float)->Dictionary:
	var error:=_available(x,z)
	if not error.is_empty():return _response(null,false,error)
	if not _covered(x,z):return _response(null,false,"outside_coverage")
	if _contains(x,z):return _response(_can_walk(x,z))
	var r:=int(floor(z/4.1));var c:=int(floor(x/4.1));var tile:Variant=_tile(r,c)
	var native:=false
	if tile!=null:native=bool(_topology.walkableMask[r][c]) or (tile==9 and (_topology.policeMask[r][c] is float or _topology.policeMask[r][c] is int) and _topology.policeMask[r][c]==1)
	return _response(native or _water(x,z)!=null)

func surface_at(x:float,z:float,r:float,c:float)->Dictionary:
	var error:=_available(x,z)
	if not error.is_empty():return _response(null,false,error)
	if not is_finite(r) or not is_finite(c):return _response(null,false,"coordinates")
	if not _covered(x,z):return _response(null,false,"outside_coverage")
	# Use literal query r/c. Recomputing after multiply/divide loses source ULPs.
	var rr:=int(floor(r));var cc:=int(floor(c))
	var road:=rr>=0 and rr<200 and cc>=0 and cc<180 and bool(_topology.roadMask[rr][cc])
	return _response("road" if road else "land")
