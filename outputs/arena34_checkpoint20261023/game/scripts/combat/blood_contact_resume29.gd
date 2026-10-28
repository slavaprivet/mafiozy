extends RefCounted
## Visual-only finite cap spray. The host owns positions and the existing gore
## lifetime/velocity arrays; this helper never searches for or invents a wound.
const MAX_LIVE := 96
const MAX_WINDOW_DROPS := 16
const WINDOW_MS := 100
var mesh: SphereMesh
var material: StandardMaterial3D
var rim_mesh: CylinderMesh
var window_start := -1000
var window_count := 0
var window_wound_count := 0
var serial := 0
var rims: Array[WeakRef] = []

func _warm() -> void:
	if mesh != null:return
	mesh=SphereMesh.new();mesh.radius=0.5;mesh.height=1.0
	mesh.radial_segments=8;mesh.rings=4
	material=StandardMaterial3D.new()
	material.albedo_color=Color(0.46,0.010,0.020)
	material.roughness=0.24;material.metallic_specular=0.35
	rim_mesh=CylinderMesh.new();rim_mesh.top_radius=0.014;rim_mesh.bottom_radius=0.014
	rim_mesh.height=0.0007;rim_mesh.radial_segments=16

func style_spawned(host: Node, first: int, at: Vector3, direction: Vector3, kind: String = "cut") -> int:
	if not at.is_finite():return 0
	_warm()
	var now:=Time.get_ticks_msec()
	if now-window_start>=WINDOW_MS:window_start=now;window_count=0;window_wound_count=0
	var gore:Array=host.get("_npc_gore")
	var velocities:Array=host.get("_blood_velocities")
	var timers:Array=host.get("_blood_timers")
	var count:=gore.size()-first
	if first<0 or count<=0:return 0
	var live_before:=int(host.get("_blood_count"))-count
	var allowed:=mini(mini(count,8),MAX_LIVE-live_before)
	allowed=mini(allowed,MAX_WINDOW_DROPS-window_count)
	# Reserve four slots for real local wounds; sustained cut spray cannot
	# consume their entire budget. Total emission remains sixteen per window.
	allowed=mini(allowed,4-window_wound_count if kind=="wound" else 12-(window_count-window_wound_count))
	allowed=maxi(0,allowed)
	# Remove only new excess drops, keeping the inherited parallel arrays aligned.
	for index in range(gore.size()-1,first+allowed-1,-1):
		var excess:Node=gore[index]
		gore.remove_at(index);velocities.remove_at(index);timers.remove_at(index)
		if is_instance_valid(excess):excess.queue_free()
	host.set("_blood_count",int(host.get("_blood_count"))-(count-allowed))
	var normal:=direction.normalized() if direction.length_squared()>0.000001 else Vector3.UP
	var side:=normal.cross(Vector3.UP if absf(normal.y)<0.9 else Vector3.RIGHT).normalized()
	var up:=normal.cross(side).normalized()
	var made:=0
	for i in allowed:
		serial+=1
		var phase:=float(serial)*2.39996323
		var is_drip:=kind=="wound" or kind=="drip"
		var diameter:=(0.006 if is_drip else 0.009)+0.001*float(serial%4)
		var velocity:=normal*(0.14 if is_drip else 1.15+float(serial%5)*0.24)
		velocity+=Vector3.DOWN*0.18 if is_drip else (side*cos(phase)+up*sin(phase))*0.75
		var drop:MeshInstance3D=gore[first+i]
		drop.mesh=mesh;drop.material_override=material
		drop.cast_shadow=GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
		drop.global_position=at
		var length:=0.018 if is_drip else 0.025+float(serial%3)*0.0075
		var along:=velocity.normalized()
		var right:=along.cross(Vector3.UP if absf(along.y)<0.9 else Vector3.RIGHT).normalized()
		drop.global_basis=Basis(right*diameter,along*length,right.cross(along)*diameter)
		drop.set_meta("cap_blood29",true)
		velocities[first+i]=velocity
		timers[first+i]=0.65 if is_drip else 0.45+float(serial%3)*0.08
		made+=1
	window_count+=made
	if kind=="wound":window_wound_count+=made
	return made

func add_cap_pool(host: Node, body: Node3D, at: Vector3, normal: Vector3) -> bool:
	# A small wet patch on a confirmed detached cap follows its physical owner.
	# Its owner and bounded timer clean it up; it never stains arbitrary world space.
	if not is_instance_valid(body) or not at.is_finite() or normal.length_squared()<0.5:return false
	for i in range(rims.size()-1,-1,-1):
		if rims[i].get_ref()==null:rims.remove_at(i)
	if rims.size()>=8:return false
	_warm()
	var y:=normal.normalized()
	var x:=y.cross(Vector3.UP if absf(y.y)<0.9 else Vector3.RIGHT).normalized()
	var patch:=MeshInstance3D.new();patch.name="CapWetRim29"
	patch.mesh=rim_mesh;patch.material_override=material
	patch.cast_shadow=GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
	body.add_child(patch)
	patch.global_transform=Transform3D(Basis(x,y,x.cross(y)),at+y*0.0008)
	rims.append(weakref(patch))
	var reference:WeakRef=weakref(patch)
	host.get_tree().create_timer(1.8).timeout.connect(func():
		var node:Node=reference.get_ref()
		if is_instance_valid(node):node.queue_free())
	return true

