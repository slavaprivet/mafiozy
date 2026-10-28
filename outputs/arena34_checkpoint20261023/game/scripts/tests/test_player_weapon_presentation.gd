extends SceneTree
const Player=preload("res://scripts/preview_player.gd")
const Presentation=preload("res://scripts/weapons/player_weapon_presentation.gd")
var checks:=0
var failures:Array[String]=[]
func check(value:bool,label:String)->void:
	checks+=1
	if not value and failures.size()<30: failures.append(label)
func _initialize()->void:call_deferred("run")
func write_pose(player:Node3D,selected:Dictionary)->bool:
	# Isolated compatibility shim for the CURRENT root writer, whose affine
	# route still tests only has("melee"). Root must add has("weapon") itself.
	var accepted:=selected.duplicate();accepted.melee={"test_only_writer_route":true}
	return player._apply_selected_pose(accepted,player._pose_epoch)
func base(player:Node3D,running:bool=false)->Dictionary:
	return player._locomotion.sample(.016,Vector3(0,0,5.8) if running else Vector3.ZERO,true)
func run()->void:
	var player:=Player.new();player.set_meta("actor_id","actualhero-test");player.set_meta("life_generation",1)
	root.add_child(player);player.set_physics_process(false);player.set_process(false)
	check(player._pose_skeleton!=null,"actual player imported hero")
	var presentation:=Presentation.new()
	check(presentation.configure(player).ok,"actual player configure")
	check(not presentation.configure(player).ok,"duplicate bind denied")
	var configured_scale:Vector3=player._pose_skeleton.global_basis.get_scale()
	var cold:Array[int]=[];var costs:Array[int]=[]
	var all_ids:=["nagan","tt_pistol","revolver","deagle","golden_colt","sawn_off","shotgun","uzi","golden_uzi","ak74","m16","tommy_gun","sniper","rpg"]
	for id:String in all_ids:
		var stamp:=Time.get_ticks_usec();var equipped:=presentation.equip(id);cold.append(Time.get_ticks_usec()-stamp)
		check(equipped.ok,"equip original "+id)
		check(not presentation.current_muzzle().ok,"equip has no premature muzzle "+id)
		check(presentation._visual.scale.is_equal_approx(Vector3.ONE),"source scale inherited once")
		var first:Dictionary={}
		for mode:int in 3:
			var initial:=base(player,mode==1)
			var before:Array=[]
			for i:int in 28:before.append(player._pose_skeleton.get_bone_global_pose(i))
			var aim:={"aimYaw":.2+mode*.7,"aimPitch":mode*.24,"reloadProgress":.5 if mode==2 else 0.0,"recoil":.2 if mode==1 else 0.0}
			var selected:=presentation.decorate(initial,aim,{},player._locomotion._phase,player._locomotion._gait,player._pose_epoch)
			check(selected.has("weapon_presentation"),"actual selected weapon pose")
			for i:int in 28:check(before[i]==player._pose_skeleton.get_bone_global_pose(i),"decorate never writes bone")
			check(not presentation.current_muzzle().ok,"decorated but unapplied muzzle denied")
			check(write_pose(player,selected),"actual sole writer accepts")
			var receipt:=presentation.after_pose_applied(selected)
			check(receipt.ok,"applied actual receipt "+id+str(mode))
			if not receipt.ok:continue
			check(receipt.weapon_id==id and receipt.pose_revision==player._pose_revision and receipt.pose_epoch==player._pose_epoch,"receipt source id and pose")
			check(receipt.origin==presentation._visual.get_node("Muzzle").global_position,"receipt actual displayed muzzle")
			check(receipt.direction.is_equal_approx((presentation._visual.global_basis*Vector3.BACK).normalized()),"source +Z direction")
			check(presentation._mount.transform==player._pose_skeleton.get_bone_global_pose(player._pose_skeleton.find_bone("socket_weapon")),"socket refreshed same frame")
			if mode==0:first=receipt
			else:check(receipt.origin.distance_to(first.origin)>.01,"aim/run/reload changes actual muzzle")
			if mode==2:
				for mesh:MeshInstance3D in presentation._visual.geometry_nodes():
					if mesh.get_meta("weapon_animation_slot","")=="magazine":check(absf(mesh.position.y-(mesh.get_meta("weapon_rest") as Transform3D).origin.y+.62)<1e-5,"source magazine extraction")
			var edited:=receipt.duplicate();edited.origin=Vector3.INF
			check(presentation.current_muzzle().origin.is_finite(),"caller receipt mutation isolated")
	check(player._pose_skeleton.global_basis.get_scale()==configured_scale,"no extra skeleton/model scaling")
	for i:int in 200:
		var initial:=base(player,true);var stamp:=Time.get_ticks_usec()
		var selected:=presentation.decorate(initial,{"aimYaw":.4,"aimPitch":.2},{},player._locomotion._phase,player._locomotion._gait,player._pose_epoch)
		write_pose(player,selected);var receipt:=presentation.after_pose_applied(selected);costs.append(Time.get_ticks_usec()-stamp)
		check(receipt.ok,"whole presentation path benchmark current")
	var selected:=presentation.decorate(base(player),{}, {},0,0,player._pose_epoch)
	check(not presentation.after_pose_applied(selected).ok,"unapplied revision denied")
	selected=presentation.decorate(base(player),{}, {},0,0,player._pose_epoch);write_pose(player,selected);write_pose(player,selected)
	check(not presentation.after_pose_applied(selected).ok,"intervening writer revision denied")
	selected=presentation.decorate(base(player),{}, {},0,0,player._pose_epoch);player.position.z+=.2;write_pose(player,selected)
	check(not presentation.after_pose_applied(selected).ok,"actor moved between sample and apply denied")
	selected=presentation.decorate(base(player),{}, {},0,0,player._pose_epoch);write_pose(player,selected);check(presentation.after_pose_applied(selected).ok,"recover accepted next sample")
	player.position.x+=1
	check(not presentation.current_muzzle().ok,"root movement invalidates old muzzle")
	selected=presentation.decorate(base(player),{}, {},0,0,player._pose_epoch);write_pose(player,selected);check(presentation.after_pose_applied(selected).ok,"moving root refreshed")
	player._pose_skeleton.set_bone_pose_rotation(player._pose_skeleton.find_bone("chest"),Quaternion(Vector3.UP,.2))
	player._pose_skeleton.clear_bones_global_pose_override()
	check(not presentation.current_muzzle().ok,"unpublished bone change invalidates muzzle")
	selected=presentation.decorate(base(player),{}, {},0,0,player._pose_epoch);write_pose(player,selected);presentation.after_pose_applied(selected)
	presentation._visual.get_node("Muzzle").position.x+=.1
	check(not presentation.current_muzzle().ok,"changed muzzle anchor invalidates receipt")
	check(presentation.equip("tt_pistol").ok,"different original gun after corrupt anchor")
	selected=presentation.decorate(base(player),{}, {},0,0,player._pose_epoch);write_pose(player,selected);presentation.after_pose_applied(selected)
	presentation._visual.hide();check(not presentation.current_muzzle().ok,"hidden gun invalidates receipt")
	presentation._visual.show();check(not presentation.current_muzzle().ok,"show cannot revive invalidated muzzle")
	selected=presentation.decorate(base(player),{}, {},0,0,player._pose_epoch)
	check(presentation.equip("ak74").ok,"switch after sampled")
	write_pose(player,selected);check(not presentation.after_pose_applied(selected).ok,"old equip selection denied")
	selected=presentation.decorate(base(player),{}, {},0,0,player._pose_epoch)
	var newer:=presentation.decorate(base(player),{}, {},0,0,player._pose_epoch)
	write_pose(player,selected);check(not presentation.after_pose_applied(selected).ok,"older sample denied")
	selected=presentation.decorate(base(player),{}, {},0,0,player._pose_epoch);write_pose(player,selected);presentation.after_pose_applied(selected)
	presentation.invalidate_pose();check(not presentation.current_muzzle().ok and not presentation._visual.visible,"writer failure hides model and receipt")
	check(presentation.equip("none").ok and presentation._visual==null,"none removes model")
	check(presentation.decorate(base(player)).get("weapon_presentation")==null,"none does not decorate")
	check(presentation.equip("ak74").ok,"reequip cached model")
	player.set_preview_pose_authority(&"vehicle")
	presentation.invalidate_pose();check(presentation._visual==null and not presentation.current_muzzle().ok,"authority deny removes visual")
	check(not presentation.equip("ak74").ok,"vehicle equip denied")
	player.set_preview_pose_authority(&"on_foot")
	check(presentation.equip("ak74").ok,"reenter on foot explicit equip")
	selected=presentation.decorate(base(player),{}, {},0,0,player._pose_epoch);player.set_preview_pose_authority(&"on_foot",true)
	write_pose(player,selected);check(not presentation.after_pose_applied(selected).ok,"new lifetime epoch rejects old selection")
	player.set_meta("life_generation",2)
	check(not presentation.current_muzzle().ok and presentation._visual==null,"actor identity lifetime denies old binding")
	presentation.dispose();presentation.dispose()
	check(not presentation.equip("ak74").ok,"disposed equip denied")
	check(presentation.configure(player).ok,"explicit rebind fresh identity")
	check(presentation.equip("tt_pistol").ok,"fresh lifetime equip")
	player._pose_motion.get_node("UniformModelScale").scale*=1.1
	check(not presentation.current_muzzle().ok and presentation._visual==null,"changed bound normalization denies reuse")
	presentation.dispose();player._pose_motion.get_node("UniformModelScale").scale/=1.1
	check(presentation.configure(player).ok and presentation.equip("nagan").ok,"explicit normalization rebind")
	player._pose_motion.get_node("UniformModelScale").queue_free()
	check(not presentation.current_muzzle().ok,"queued intermediate ancestor denied")
	player.queue_free();check(not presentation.current_muzzle().ok,"queued owner rejects immediately")
	presentation.dispose();await process_frame
	costs.sort();cold.sort()
	var report:={"passed":failures.is_empty(),"checks":checks,"failures":failures,"guns":14,"states_per_gun":3,"whole_decorate_writer_after_p50_us":costs[100],"whole_decorate_writer_after_p95_us":costs[190],"cold_equip_min_us":cold[0],"cold_equip_max_us":cold[-1],"scope":"Actual preview_player and imported hero; isolated headless. No GPU or full city FPS claim. Test-only has(melee) shim enables current sole-writer affine branch without production edits."}
	var args:=OS.get_cmdline_user_args();FileAccess.open(args[0],FileAccess.WRITE).store_string(JSON.stringify(report,"\t"));print("PLAYER_WEAPON_PRESENTATION ",JSON.stringify(report));quit(0 if failures.is_empty() else 1)
