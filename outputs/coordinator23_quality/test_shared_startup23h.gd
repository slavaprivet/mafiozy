extends "test_shared_startup.gd"

func run()->void:
	for name:String in ["arrow","hand"]:
		var texture:Texture2D=load("res://assets/ui/cursor_"+name+".svg")
		if texture==null or texture.get_size()!=Vector2(36,44):failures.append("cursor_import_"+name)
	await super.run()
