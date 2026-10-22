extends SceneTree
const Visual=preload("res://scripts/vehicle_visual/vehicle_visual.gd")
const Bindings=preload("res://scripts/transport/transport_vehicle_damage_bindings.gd")
var checks:=0
var failures: Array[String]=[]
func check(ok: bool,label: String) -> void:
	checks+=1
	if not ok: failures.append(label)
func _initialize() -> void:
	run.call_deferred()
func run() -> void:
	var world:=Node3D.new(); root.add_child(world)
	var oracle: Dictionary=Bindings.load_oracle()
	check(not oracle.is_empty(),"exact pinned source oracle admission")
	if oracle.is_empty(): quit(1); return
	var catalog:=Visual.load_catalogue("res://assets/vehicle_visual/manifest.json")
	for row: Dictionary in oracle.rows:
		var loaded:=Visual.instantiate_visual(catalog.entries[row.profile_id],catalog.base_path)
		check(loaded.ok,"actual GLB "+row.profile_id)
		if not loaded.ok: continue
		var visual=loaded.visual; world.add_child(visual.root)
		var bound:=Bindings.bind(visual,row)
		check(bound.ok,"actual source node identity "+row.profile_id+" "+str(bound.get("error")))
		if bound.ok:
			check(bound.explosion.size()==row.explosion.size() and bound.structural.size()==12,"source assembly counts")
			for i in row.explosion.size():
				check(bound.explosion[i].source==visual.nodes[row.explosion[i].key] and bound.explosion[i].source_index==i,"source exact order/index")
			for part: Dictionary in row.structural:
				check(bound.structural[part.id]==visual.nodes.get(part.key),"source structural mounts")
			check(bound.crash_profile_source==row.profile_source_metadata.vehicleProfile,"exact postfactory source profile")
		var wrong:=row.duplicate(true); wrong.native_visual.sha256="wrong"
		check(not Bindings.bind(visual,wrong).ok,"wrong visual SHA rejected")
		wrong=row.duplicate(true); wrong.explosion[0].source_name="wrong"
		check(not Bindings.bind(visual,wrong).ok,"wrong authored assembly rejected")
		for mutation in ["profile","base","input","part","index","eligible","rng","missing"]:
			wrong=row.duplicate(true)
			match mutation:
				"profile": wrong.profile_source_metadata.vehicleProfile.massKg+=1
				"base": wrong.source_profile_id="forged"
				"input": wrong.input_glb.sha256="forged"
				"part": wrong.structural[0].id="forged"
				"index": wrong.explosion[0].source_index=.5
				"eligible": wrong.explosion[0].copy_eligible=1
				"rng": wrong.explosion[0].rng_draw_indices=[1]
				"missing": wrong.missing_structural_ids=["forged"]
			check(not Bindings.bind(visual,wrong).ok,"forged receipt rejected "+mutation)
		wrong=row.duplicate(true)
		wrong.explosion.pop_back(); wrong.explosion_rng_draw_count=_renumber_draws(wrong.explosion)
		check(not Bindings.bind(visual,wrong).ok,"coherent final assembly removal rejected")
		wrong=row.duplicate(true)
		var first: Variant=wrong.explosion[0]; wrong.explosion[0]=wrong.explosion[1]; wrong.explosion[1]=first
		wrong.explosion_rng_draw_count=_renumber_draws(wrong.explosion)
		check(not Bindings.bind(visual,wrong).ok,"coherent assembly reorder rejected")
		wrong=row.duplicate(true)
		wrong.explosion[0].copy_eligible=false; wrong.explosion_rng_draw_count=_renumber_draws(wrong.explosion)
		check(not Bindings.bind(visual,wrong).ok,"coherent eligibility rewrite rejected")
		visual.dispose()
	var tampered:=FileAccess.open("user://transport_damage_oracle_tampered.json",FileAccess.WRITE)
	tampered.store_string(JSON.stringify(oracle)); tampered.close()
	check(Bindings.load_oracle("user://transport_damage_oracle_tampered.json").is_empty(),"coherent rewritten oracle rejected by exact byte SHA")
	world.free()
	print("TRANSPORT_DAMAGE_BINDINGS ",JSON.stringify({"checks":checks,"failures":failures,"passed":failures.is_empty(),"scope":"actual 13 GLBs+source factory assembly oracle; no runtime damage authority"}))
	quit(0 if failures.is_empty() else 1)

func _renumber_draws(explosion: Array) -> int:
	var draw:=0
	for index in explosion.size():
		var part: Dictionary=explosion[index]
		part.source_index=index
		part.rng_draw_indices=[]
		if part.copy_eligible:
			for slot in 7:
				draw+=1; part.rng_draw_indices.append(draw)
	return draw
