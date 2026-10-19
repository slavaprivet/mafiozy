extends SceneTree
func _initialize() -> void: call_deferred("run")
func run() -> void:
	await create_timer(1.2).timeout
	var errors: Array[String] = []
	var result := []
	for heavy: bool in [false,true]:
		for motion: Vector2 in [Vector2(20,0),Vector2(-20,0),Vector2(20,-30),Vector2(-20,-30),Vector2(20,30),Vector2(-20,30)]:
			var c = load("res://scripts/weapons/directional_melee41.gd").new()
			c.mouse(motion)
			if not c.begin(heavy,Vector3.FORWARD,Basis.IDENTITY): errors.append("start")
			var chosen: Vector2 = c.chosen
			if c.begin(heavy,Vector3.FORWARD,Basis.IDENTITY): errors.append("double_start")
			var phases := {}
			var first := Vector3.ZERO
			var last := Vector3.ZERO
			for tick in 100:
				c.advance(1.0/60.0,Basis.IDENTITY)
				phases[c.phase]=int(phases.get(c.phase,0))+1
				if c.damaging():
					if first==Vector3.ZERO:first=c.target()
					last=c.target()
				elif c.phase!="idle" and c.damaging():errors.append("damage_outside_release")
				c.mouse(-motion)
				if c.chosen!=chosen:errors.append("direction_changed_mid_attack")
			if c.phase!="idle" or not phases.has("release") or not phases.has("recover"):errors.append("incomplete")
			if first.angle_to(last)<1.9:errors.append("no_full_arc")
			result.append({"heavy":heavy,"motion":str(motion),"chosen":str(chosen),"phases":phases,"arc":first.angle_to(last)})
	var p = load("res://scripts/weapons/directional_melee41.gd").new()
	p.begin(false,Vector3.FORWARD,Basis.IDENTITY);p.stop()
	if p.damaging() or p.phase!="recover":errors.append("cancel")
	var report={"passed":errors.is_empty(),"errors":errors,"cases":result}
	FileAccess.open("D:/MafioziCombat31/directional41/PHASES.json",FileAccess.WRITE).store_string(JSON.stringify(report,"\t"))
	print(JSON.stringify(report))
	quit(0 if errors.is_empty() else 1)
