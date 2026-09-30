extends SceneTree
var checks:=0
var errors:Array=[]
func check(ok:bool,label:String)->void:
	checks+=1
	if not ok:errors.append(label)
func _initialize()->void:run.call_deferred()
func run()->void:
	var world:=Node3D.new();root.add_child(world)
	var fx:RefCounted=load("C:/Users/Слава/Desktop/Мафиози/outputs/coordinator23_quality_perf23d/surface_preassign_candidate.gd").new()
	check(fx.configure(world),"configure")
	check(fx.stats().total_marks==0 and fx.stats().total_impacts==0,"no fake warmup hits")
	check(fx._marks.size()==72 and fx._impacts.size()==48,"pool caps preserved")
	for i:int in 72:
		var entry:Dictionary=fx._marks[i]
		check(not entry.active and not entry.node.visible,"pooled marks remain hidden")
		check(entry.edge.material_override.vertex_color_use_as_albedo,"normal rim feature preassigned")
		check(entry.node.mesh==fx._art_meshes[i%4].back and entry.edge.mesh==fx._art_meshes[i%4].rim and entry.center.mesh==fx._art_meshes[i%4].core,"intended normal art preassigned")
		check(entry.source_meshes.size()==3 and entry.source_meshes[0]!=entry.node.mesh,"original restoration meshes preserved")
	var collider:=Node3D.new();world.add_child(collider)
	for i:int in 4:
		check(fx.hit({"collider":collider,"point":Vector3.ZERO,"normal":Vector3.BACK}),"real method normal hit accepted")
		check(fx._marks[i].life==5.0 and fx._marks[i].node.mesh==fx._art_meshes[i].back,"normal variant/life preserved")
	collider.set_meta("impactSurface","glass")
	check(fx.hit({"collider":collider,"point":Vector3.ZERO,"normal":Vector3.BACK}),"glass hit")
	check(fx._marks[4].node.mesh==fx._marks[4].source_meshes[0] and not fx._marks[4].edge.material_override.vertex_color_use_as_albedo,"glass original mesh/features restored")
	collider.set_meta("impactSurface","masonry")
	check(fx.hit({"collider":collider,"point":Vector3.ZERO,"normal":Vector3.BACK,"explosive":true}),"explosive hit")
	check(fx._marks[5].node.mesh==fx._marks[5].source_meshes[0] and not fx._marks[5].edge.material_override.vertex_color_use_as_albedo,"explosive original restored")
	var result:Dictionary={"checks":checks,"errors":errors,"headless_only":true,"shader_compile_proven":false,"scope":"pool initialization/restoration contract; no actual physics collision or GPU claim"}
	FileAccess.open("C:/Users/Слава/Desktop/Мафиози/outputs/coordinator23_quality_perf23d/SURFACE_PREASSIGN_TEST.json",FileAccess.WRITE).store_string(JSON.stringify(result,"\t"))
	print("PREASSIGN_TEST ",result);fx.dispose();world.free();quit(0 if errors.is_empty() else 1)
