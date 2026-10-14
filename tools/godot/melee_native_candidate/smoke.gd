extends SceneTree
func _initialize():
	var status:=GDExtensionManager.load_extension("res://candidate.gdextension")
	print("EXTENSION_LOAD ",status," class=",ClassDB.class_exists("MeleeNativeGeometry"))
	if not ClassDB.class_exists("MeleeNativeGeometry"):quit(1);return
	var native:Object=ClassDB.instantiate("MeleeNativeGeometry")
	var result:Variant=native.call("run",PackedFloat64Array([0,0,0,1,0,0,-1,.1,-1,-1,0,1,-1,0,0,1,0]))
	print("NATIVE_TRIANGLE ",result);native.free();quit(0 if result is PackedFloat64Array and result[0]==1 and result[1]==1 else 1)
