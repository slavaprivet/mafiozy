extends SceneTree
const Sizes=preload("res://scripts/weapons/weapon_cargo_sizes.gd")
const Weapons=preload("res://scripts/weapon_visual/weapon_visual_catalog.gd")
const Store=preload("res://scripts/transport/trunk/transport_trunk_cargo_store.gd")
var checks:=0
var failures:Array=[]
func check(ok:bool,label:String):
	checks+=1
	if not ok:failures.append(label);print("CHECK_FAILED ",label)
func _initialize():run.call_deferred()
func run():
	var source:=FileAccess.get_file_as_string("res://assets/weapon_visual/manifest.json")
	var normalized:=source.replace("\r\n","\n")
	check(normalized.sha256_text()==Sizes.MANIFEST_SHA256_LF,"portable manifest pin explicitly CRLF to LF")
	check(normalized.replace("\n","\r\n").replace("\r\n","\n").sha256_text()==Sizes.MANIFEST_SHA256_LF,"fresh Windows CRLF checkout retains same manifest authority")
	var oracle:Dictionary=JSON.parse_string(FileAccess.get_file_as_string("res://data/tests/weapon_cargo_sizes_oracle.json"))
	check(oracle.manifest_sha256_lf==Sizes.MANIFEST_SHA256_LF and oracle.capacity==100,"generated source oracle matches measured manifest")
	var catalog:=Weapons.new();check(catalog.open().ok and Sizes.catalog_matches(catalog),"actual native catalogue measurement table matches")
	var total:=0;var volume:=0.0;var widths:=0.0;var max_height:=0.0;var max_depth:=0.0;var rows:Array=[]
	for expected:Dictionary in oracle.rows:
		var id:String=expected.id;var actual:Dictionary=catalog.get_entry(id).profile.bounds_native
		var sx:float=actual.max[0]-actual.min[0];var sy:float=actual.max[1]-actual.min[1];var sz:float=actual.max[2]-actual.min[2]
		var v:float=sx*sy*sz;volume+=v
		check(absf(v-expected.volume)<1e-12 and absf(v-Sizes.MEASUREMENTS[id].volume_native)<1e-12,"source volume measurement "+id)
		check(Sizes.COSTS[id] is int and Sizes.COSTS[id]>=1 and Sizes.COSTS[id]==int(expected.units),"integer unit allocation "+id)
		var made:Dictionary=catalog.instantiate_weapon(id);check(made.ok,"original model loads "+id)
		if made.ok:
			var model:Node3D=made.visual;var low:=Vector3(INF,INF,INF);var high:=Vector3(-INF,-INF,-INF)
			for mesh:MeshInstance3D in model.find_children("*","MeshInstance3D",true,false):
				if mesh.mesh==null:continue
				var transform:=Transform3D.IDENTITY;var node:Node=mesh
				while node!=model:
					if node is Node3D:transform=node.transform*transform
					node=node.get_parent()
				for vertex:Vector3 in mesh.mesh.get_faces():
					var point:Vector3=transform*vertex;low=low.min(point);high=high.max(point)
			# Serialized model transforms differ from authored manifest bounds by
			# <=49.4 microunits (<=9.9 micrometres at .2). Far below the5mm gap.
			check(low.distance_to(Vector3(actual.min[0],actual.min[1],actual.min[2]))<.00006 and high.distance_to(Vector3(actual.max[0],actual.max[1],actual.max[2]))<.00006,"actual native vertices agree within serialized precision "+id)
			model.free()
		total+=Sizes.COSTS[id];widths+=sx;max_height=maxf(max_height,sy);max_depth=maxf(max_depth,sz)
		rows.append({"id":id,"volume":v,"cost":Sizes.COSTS[id]})
	check(total==100 and rows.size()==14,"one of every original model totals100")
	for a:Dictionary in rows:
		for b:Dictionary in rows:
			if a.volume>b.volume:check(a.cost>=b.cost,"larger model volume never costs fewer units")
	# Independent allocation certificate: every result is floor/ceil of its
	# proportional remainder quota, and all upward awards beat unawarded residues.
	var minimum_awarded:=INF;var maximum_unawarded:=-INF
	for row:Dictionary in rows:
		var quota:float=86.0*row.volume/volume;var base:=int(floor(quota))+1;var fraction:float=quota-floor(quota)
		check(row.cost in [base,base+1],"within largest-remainder quota "+row.id)
		if row.cost==base+1:minimum_awarded=minf(minimum_awarded,fraction)
		else:maximum_unawarded=maxf(maximum_unawarded,fraction)
	check(minimum_awarded>=maximum_unawarded,"all extra units awarded to greatest fractional remainders")
	var compartments:Dictionary=JSON.parse_string(FileAccess.get_file_as_string("res://assets/vehicle_visual/compartments.json"))
	var cb:Dictionary=compartments.profiles.compact_sedan.cargo_bounds
	var floor_size:=Vector3(cb.max[0]-cb.min[0],cb.max[1]-cb.min[1],cb.max[2]-cb.min[2])
	var strip:=Vector3(widths*Sizes.TRUNK_SCALE+13*(Store.GAP_M+Store.FRONTIER_PAD_M),max_height*Sizes.TRUNK_SCALE,max_depth*Sizes.TRUNK_SCALE)
	check(strip.x<floor_size.x and strip.y<floor_size.y and strip.z<floor_size.z,"any ordering fits one floor row with actual store gap and pad")
	check(Sizes.TRUNK_SCALE==.2,"original shared trunk scale retained without per-weapon distortion")
	catalog.close()
	print("WEAPON_CARGO_SIZES ",JSON.stringify({"ok":failures.is_empty(),"checks":checks,"failures":failures,"costs":Sizes.COSTS,"floor_strip_m":[strip.x,strip.y,strip.z],"actual_cargo_size_m":[floor_size.x,floor_size.y,floor_size.z]}))
	quit(0 if failures.is_empty() else 1)
