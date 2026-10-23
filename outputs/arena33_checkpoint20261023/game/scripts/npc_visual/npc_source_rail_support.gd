extends RefCounted
## Immutable original source rail component. No dynamic advance/registration.
const Landscape=preload("res://scripts/npc_visual/npc_source_landscape_support.gd")
const DATA_SHA="f3c7ab6c3af07f8c3d9f323f09383923d4b7567a4224217a658e66682ffb6087"
const PROVIDER_ID="mafiozi.source-rail-support.component-v1"
const PROVIDER_VERSION="1"
var _ready:=false
var _busy:=false
var _fault:=""
var _ground:=Callable()
var _proof:Dictionary={}
var _points:=PackedFloat64Array()
var _segments:=PackedFloat64Array()
var _stations:Array=[]
var _buckets:Dictionary={}
var _cars:Array=[]
var _length:=0.0
var _calls:=0
var _min_x:=INF
var _max_x:=-INF
var _min_z:=INF
var _max_z:=-INF

func configure(bytes:PackedByteArray,trust:Dictionary,ground_landscape:Callable)->Dictionary:
	if _busy:invalidate("reentrant");return {"ok":false,"error":_fault}
	if not Thread.is_main_thread() or _ready or not _fault.is_empty():return {"ok":false,"error":"state_or_thread"}
	for key in ["data_sha256","source_world_sha256","context_sha256","session_id","phase"]:
		if not trust.get(key) is String or trust[key].is_empty():return {"ok":false,"error":"trust"}
	if trust.data_sha256!=DATA_SHA or trust.source_world_sha256!=Landscape.SOURCE_SHA or trust.context_sha256!=Landscape.CONTEXT_SHA or trust.session_id!=Landscape.SESSION or trust.phase!=Landscape.PHASE or Landscape._hash(bytes)!=DATA_SHA:return {"ok":false,"error":"binding"}
	if not ground_landscape.is_valid():return {"ok":false,"error":"ground_unavailable"}
	var parser:=JSON.new()
	if parser.parse(bytes.get_string_from_utf8())!=OK or not parser.data is Dictionary:return {"ok":false,"error":"json"}
	var packet:Dictionary=parser.data
	if packet.schema!="mafiozi.npc-registered-navigation-rail-static/v1" or packet.source_world_sha256!=Landscape.SOURCE_SHA or packet.context_sha256!=Landscape.CONTEXT_SHA or packet.session_id!=Landscape.SESSION or packet.phase!=Landscape.PHASE:return {"ok":false,"error":"packet_binding"}
	var data:Dictionary=packet.data
	if not Landscape._overlay(data,packet.data_float64):return {"ok":false,"error":"overlay"}
	if data.points.fields!=["x","y","z","distance"]:return {"ok":false,"error":"fields"}
	var pb:=Landscape._buffer(data.points,"float64_le",4084,8)
	if pb.is_empty():return {"ok":false,"error":"points"}
	var points:=pb.to_float64_array()
	for value in points:
		if not is_finite(value):return {"ok":false,"error":"point_finite"}
	_points=points;_length=data.length;_stations=data.stations;_ground=ground_landscape
	_proof={"data_sha256":DATA_SHA,"terrain_sha256":Landscape.DATA_SHA,"source_world_sha256":Landscape.SOURCE_SHA,"context_sha256":Landscape.CONTEXT_SHA,"session_id":Landscape.SESSION,"phase":Landscape.PHASE,"provider_id":PROVIDER_ID,"provider_version":PROVIDER_VERSION}
	# Same segment insertion order and inclusive 32m buckets as the source.
	for i in 1021:
		var j:=(i+1)%1021;var ax:=_p(i,0);var az:=_p(i,2);var bx:=_p(j,0);var bz:=_p(j,2)
		var dx:=bx-ax;var dz:=bz-az
		_segments.append_array(PackedFloat64Array([ax,az,dx,dz,dx*dx+dz*dz,_p(i,3),_v8_hypot2(dx,dz)]))
		var lo_x:=int(floor((minf(ax,bx)-40.)/32.));var hi_x:=int(floor((maxf(ax,bx)+40.)/32.))
		var lo_z:=int(floor((minf(az,bz)-40.)/32.));var hi_z:=int(floor((maxf(az,bz)+40.)/32.))
		_min_x=minf(_min_x,lo_x*32.);_max_x=maxf(_max_x,(hi_x+1)*32.)
		_min_z=minf(_min_z,lo_z*32.);_max_z=maxf(_max_z,(hi_z+1)*32.)
		for x in range(lo_x,hi_x+1):
			for z in range(lo_z,hi_z+1):
				var key:=str(x)+","+str(z)
				if not _buckets.has(key):_buckets[key]=[]
				_buckets[key].append(i)
	var distance:float=_stations[0].progress+18.8
	for i in 3:
		var d:=distance-i*18.8;var a:=_sample(d-5.15);var b:=_sample(d+5.15);var car:=_sample(d)
		var span:=_v8_hypot2(b.x-a.x,b.z-a.z)
		car.merge({"id":"forest-train-car-"+str(i),"tx":(b.x-a.x)/span,"tz":(b.z-a.z)/span,"grade":(b.y-a.y)/span,"length":17.6,"width":2.95},true)
		_cars.append(car)
	_ready=true
	return {"ok":true,"dynamic_advance":false,"physical_admission":false}

func invalidate(reason:String="invalidated")->void:
	if _fault.is_empty():_fault=reason if not reason.is_empty() else "invalidated"
func snapshot()->Dictionary:
	return {"ready":_ready,"fault":_fault,"calls":_calls,"provenance":_proof.duplicate(true),"initial_cars":_cars.duplicate(true),"dynamic_advance":false,"physical_admission":false}
func _response(value:Variant,error:String="")->Dictionary:
	_calls+=1
	return {"known":error.is_empty(),"defined":error.is_empty(),"value":value if error.is_empty() else null,"error":error,"provenance":_proof.duplicate(true),"combined_ground":false,"physical_admission":false,"dynamic_advance":false}
func _available(x:float,z:float)->String:
	if _busy:invalidate("reentrant");return _fault
	if not Thread.is_main_thread():return "thread"
	if not _ready:return "unconfigured"
	if not _fault.is_empty():return _fault
	return "" if is_finite(x) and is_finite(z) else "coordinates"
func _p(i:int,field:int)->float:return _points[i*4+field]
static func _v8_hypot2(x:float,z:float)->float:
	# Node v26.1.0 vendored V8 math.tq FastMathHypot, exactly two arguments.
	# Normalize before squaring, preserving its operation order and strict edges.
	var a:=absf(x);var b:=absf(z)
	if is_inf(a) or is_inf(b):return INF
	if is_nan(a) or is_nan(b):return NAN
	var largest:=maxf(a,b)
	if largest==0.0:return 0.0
	var normalized_a:=a/largest;var normalized_b:=b/largest
	var squared_a:=normalized_a*normalized_a;var squared_b:=normalized_b*normalized_b
	return sqrt(squared_a+squared_b)*largest
func _wrap(v:float)->float:return fmod(fmod(v,_length)+_length,_length)
func _sample(distance:float)->Dictionary:
	var s:=_wrap(distance);var lo:=0;var hi:=1021
	while hi-lo>1:
		var m:=(lo+hi)>>1
		if _p(m,3)<=s:lo=m
		else:hi=m
	var j:=(lo+1)%1021;var span:=(_length if lo==1020 else _p(j,3))-_p(lo,3);var t:=(s-_p(lo,3))/span
	return {"x":_p(lo,0)+(_p(j,0)-_p(lo,0))*t,"y":_p(lo,1)+(_p(j,1)-_p(lo,1))*t,"z":_p(lo,2)+(_p(j,2)-_p(lo,2))*t,"tx":(_p(j,0)-_p(lo,0))/span,"tz":(_p(j,2)-_p(lo,2))/span,"grade":(_p(j,1)-_p(lo,1))/span,"distance":s}
func _nearest(x:float,z:float)->Dictionary:
	if x<_min_x or x>=_max_x or z<_min_z or z>=_max_z:return {"distance":INF,"progress":0.}
	var best_distance:=INF;var best_progress:=0.0
	var key:=str(int(floor(x/32.)))+","+str(int(floor(z/32.)))
	for i:int in _buckets.get(key,[]):
		var base:=i*7;var ax:=_segments[base];var az:=_segments[base+1];var dx:=_segments[base+2];var dz:=_segments[base+3]
		var t:=clampf(((x-ax)*dx+(z-az)*dz)/_segments[base+4],0.,1.)
		var off_x:=x-ax-dx*t;var off_z:=z-az-dz*t
		# Finite pinned segments, finite public coordinates and the bounded bucket
		# envelope above make these offsets finite. Inline the SAME V8 operation
		# order; avoid the general helper call/NaN/Infinity checks per segment.
		var absolute_x:=absf(off_x);var absolute_z:=absf(off_z);var largest:=maxf(absolute_x,absolute_z)
		var dist:=0.0
		if largest!=0.0:
			var normalized_x:=absolute_x/largest;var normalized_z:=absolute_z/largest
			dist=sqrt(normalized_x*normalized_x+normalized_z*normalized_z)*largest
		if dist<best_distance:best_distance=dist;best_progress=_wrap(_segments[base+5]+_segments[base+6]*t)
	return {"distance":best_distance,"progress":best_progress}
func _local(s:Dictionary,x:float,z:float)->Dictionary:
	return {"along":(x-s.x)*s.tx+(z-s.z)*s.tz,"across":(x-s.x)*s.nx+(z-s.z)*s.nz}
func _width(x:float,z:float)->float:return 3.4 if x>=0. and x<738. and z>=0. and z<820. else 10.
func _ground_value(x:float,z:float)->Variant:
	if not _ground.is_valid():invalidate("ground_unavailable");return null
	var answer:Variant=_ground.call(x,z)
	if not _ground.is_valid():invalidate("ground_unavailable");return null
	if not _fault.is_empty():return null
	if not answer is Dictionary or not answer.get("known") is bool or not answer.known or not answer.get("defined") is bool or not answer.defined or not Landscape._finite(answer.get("value")) or not answer.get("provenance") is Dictionary:invalidate("ground_unknown_or_shape");return null
	var proof:Dictionary=answer.provenance
	for key in ["source_world_sha256","context_sha256","session_id","phase"]:
		if not proof.has(key) or typeof(proof[key])!=typeof(_proof[key]) or proof[key]!=_proof[key]:invalidate("ground_lease");return null
	for key in ["data_sha256","provider_id","provider_version"]:
		if not proof.get(key) is String:invalidate("ground_binding");return null
	if proof.data_sha256!=Landscape.DATA_SHA or proof.provider_id!=Landscape.PROVIDER_ID or proof.provider_version!=Landscape.PROVIDER_VERSION:invalidate("ground_binding");return null
	return float(answer.value)
func _floor(x:float,z:float)->Variant:
	for s:Dictionary in _stations:
		var q:=_local(s,x,z)
		if absf(q.along)<=s.length/2. and absf(q.across)<=s.width/2.:return s.y
		if absf(q.along)<3. and q.across>s.width/2. and q.across<s.width/2.+s.rampLength:
			var t:float=(q.across-s.width/2.)/s.rampLength;var ground:Variant=_ground_value(x,z)
			return s.y*(1.-t)+ground*t if _fault.is_empty() else null
	var q:=_nearest(x,z);var width:=_width(x,z)
	if q.distance<width:
		var t:float=clampf((q.distance-2.)/(width-2.),0.,1.);var fade:=t*t*(3.-2.*t);var ground:Variant=_ground_value(x,z)
		return maxf(ground,(_sample(q.progress).y-.11)*(1.-fade)+ground*fade) if _fault.is_empty() else null
	return null
func sample(distance:float)->Dictionary:
	var error:=_available(distance,0.)
	return _response(_sample(distance)) if error.is_empty() else _response(null,error)
func nearest(x:float,z:float)->Dictionary:
	var error:=_available(x,z)
	return _response(_nearest(x,z)) if error.is_empty() else _response(null,error)
func station_local(station_id:String,x:float,z:float)->Dictionary:
	var error:=_available(x,z)
	if not error.is_empty():return _response(null,error)
	for s:Dictionary in _stations:
		if s.id==station_id:return _response(_local(s,x,z))
	return _response(null,"station_unknown")
func bank_width_at(x:float,z:float)->Dictionary:
	var error:=_available(x,z)
	return _response(_width(x,z)) if error.is_empty() else _response(null,error)
func floor_height(x:float,z:float)->Dictionary:
	var error:=_available(x,z)
	if not error.is_empty():return _response(null,error)
	_busy=true
	var value:Variant=_floor(x,z)
	_busy=false
	if value is float and not is_finite(value):invalidate("floor_overflow")
	return _response(value,_fault)
func initial_train_blocks(x:float,z:float,radius:float=0.0)->Dictionary:
	var error:=_available(x,z)
	if not error.is_empty():return _response(null,error)
	if not is_finite(radius) or radius<0.:return _response(null,"radius")
	for car:Dictionary in _cars:
		var dx:float=x-car.x;var dz:float=z-car.z
		if absf(dx*car.tx+dz*car.tz)<car.length/2.+radius and absf(-dx*car.tz+dz*car.tx)<car.width/2.+radius:return _response(true)
	return _response(false)
