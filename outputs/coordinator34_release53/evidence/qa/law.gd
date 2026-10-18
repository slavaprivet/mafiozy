extends SceneTree
func _initialize()->void:call_deferred("run")
func run()->void:
	await create_timer(1.3).timeout
	var host=load("res://scripts/weapons/sword_prototype.gd").new()
	host._weapon_id="sword";host._weapon_mass=1.0;host._carry_side=&"right"
	host._npc_swing_start43=Vector3.UP;host._npc_dir=Vector3.FORWARD;host._npc_timer=.4
	var angle:float=host._npc_swing_start43.angle_to(host._npc_dir)
	var decisive:float=clampf((angle/.4)/host.WINDUP_RATE_IDEAL,host.WINDUP_DECISION_FLOOR,1.0)
	var prepared:float=clampf(host.SWING_STRENGTH_MIN+angle*host.SWING_STRENGTH_GAIN*decisive,host.SWING_STRENGTH_MIN,host.SWING_STRENGTH_MAX)
	var rows=[];var errors=[]
	for kind:String in ["slice","stab","flat"]:
		for speed:float in [0.0,1.0,3.2,7.0,12.0]:
			var player:float=host._impact_damage31(speed*.6,prepared,kind)
			var enemy:float=host._npc_contact_damage31(speed,.5,"forearm_l",kind=="stab",false,kind)
			rows.append({"kind":kind,"speed":speed,"player":player,"enemy":enemy})
			if absf(player-enemy)>.0001:errors.append("law_mismatch")
	var steel:=Node3D.new();root.add_child(steel);host._npc_sword=steel
	var points:PackedVector3Array=host._npc_blade_points()
	if points.size()!=host.SWEEP_SEGMENTS+1 or absf(points[0].x-.06)>.0001 or absf(points[-1].x-1.21)>.0001:errors.append("sampling_geometry")
	var result={"passed":errors.is_empty(),"errors":errors,"rows":rows,"sweep_samples":points.size(),"scope":"Native same sword mass/one-hand grip/preparation/speed/kind law and sample geometry; armor uses shared resolver, separate real-contact scene required."}
	FileAccess.open("D:/MafioziCombat31/coordinator34_merged53/law/result.json",FileAccess.WRITE).store_string(JSON.stringify(result,"\t"));host.free();quit(0 if errors.is_empty() else 1)
