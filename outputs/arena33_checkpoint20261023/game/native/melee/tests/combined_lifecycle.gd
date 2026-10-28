extends SceneTree
var checks:=0
var failures:Array[String]=[]
const EXT="res://melee_kernels.gdextension"
func check(value:bool,label:String)->void:
	checks+=1
	if not value:failures.append(label)
func _initialize()->void:run.call_deferred()
func run()->void:
	for cycle in 3:
		check(GDExtensionManager.load_extension(EXT)==OK,"combined load "+str(cycle))
		check(ClassDB.class_exists("MeleeNativeGeometry") and ClassDB.class_exists("MeleeNativeSkin"),"both classes registered")
		var geometry:Object=ClassDB.instantiate("MeleeNativeGeometry")
		var skin:Object=ClassDB.instantiate("MeleeNativeSkin")
		var vertices:=PackedVector3Array([Vector3.ZERO,Vector3.RIGHT,Vector3.UP])
		var joints:=PackedInt32Array([0,0,0,0,0,0,0,0,0,0,0,0])
		var weights:=PackedFloat32Array([1,0,0,0,1,0,0,0,1,0,0,0])
		var frames:=PackedVector3Array([Vector3.RIGHT,Vector3.UP,Vector3.BACK,Vector3.ZERO])
		var deformed:PackedVector3Array=skin.call("skin",vertices,joints,weights,frames)
		check(deformed.to_byte_array()==vertices.to_byte_array(),"combined exact identity skin")
		var mesh:=PackedFloat64Array([1,0,3,1,0,0,0,1,0,0,0,1,0,0,1,2])
		check(geometry.call("run",mesh)[0]==1,"combined geometry setup")
		frames[3]=Vector3(0,0,2)
		deformed=skin.call("skin",vertices,joints,weights,frames)
		check(geometry.call("refit_vertices",deformed,1)[0]==1,"skin output feeds exact geometry refit")
		var result:PackedFloat64Array=geometry.call("run",PackedFloat64Array([3,1,1,1,.2,.2,3,.2,.2,1,.1]))
		check(result[0]==1 and result[3]==1 and result[11]==2,"combined contact at deformed plane")
		check(geometry.call("refit_vertices",null,null)[0]==-1,"geometry failure isolated")
		check((skin.call("skin",vertices,joints,weights,frames) as PackedVector3Array).to_byte_array()==deformed.to_byte_array(),"skin unaffected by geometry fault")
		geometry.free();skin.free()
		check(GDExtensionManager.unload_extension(EXT)==OK,"combined unload")
		check(not ClassDB.class_exists("MeleeNativeGeometry") and not ClassDB.class_exists("MeleeNativeSkin"),"both classes retired")
	var report:={"passed":failures.is_empty(),"checks":checks,"failures":failures,"cycles":3,"dll_sha":FileAccess.get_sha256("res://melee_kernels.dll")}
	var f:=FileAccess.open("res://../lifecycle_report.json",FileAccess.WRITE);f.store_string(JSON.stringify(report,"\t"));f.close()
	print(JSON.stringify(report));quit(0 if failures.is_empty() else 1)
