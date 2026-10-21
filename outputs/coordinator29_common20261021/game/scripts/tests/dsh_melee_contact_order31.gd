extends SceneTree

const SEGMENTS := 9
var out_dir := ""
var failures: Array[String] = []
var report: Dictionary = {"scope":"controlled collision-order regression; not natural-input acceptance"}

func _initialize() -> void:
 for argument: String in OS.get_cmdline_user_args():
  if argument.begins_with("--qa-out="): out_dir=argument.trim_prefix("--qa-out=")
  if argument.begins_with("--qa-source="): report["source_ref"]=argument.trim_prefix("--qa-source=")
 if out_dir.is_empty():out_dir=ProjectSettings.globalize_path("user://dsh_melee_contact_order31")
 _run.call_deferred()

func _frames(count: int) -> void:
 for i in count: await physics_frame

func _key(code: int) -> void:
 for down: bool in [true,false]:
  var event:=InputEventKey.new()
  event.keycode=code;event.physical_keycode=code;event.pressed=down
  Input.parse_input_event(event)
  await _frames(2)

func _run() -> void:
 DirAccess.make_dir_recursive_absolute(out_dir)
 var scene: Node3D=load("res://scenes/castle.tscn").instantiate()
 scene.set("preview_residents_enabled",false)
 scene.set_meta("npc_home_registry58",RefCounted.new())
 root.add_child(scene);current_scene=scene
 var deadline:=Time.get_ticks_msec()+90000
 while scene.get("preview_ready")!=true and Time.get_ticks_msec()<deadline:await process_frame
 if scene.get("preview_ready")!=true:failures.append("castle_ready");_finish();return
 await _frames(30)
 var player: CharacterBody3D=scene.get("_player")
 player.set_mouse_captured(true)
 await _key(KEY_Q);await _key(KEY_1);await _frames(10)
 var sword: Node=scene.get("preview_sword_prototype")
 if not is_instance_valid(sword):failures.append("sword_host");_finish();return
 var knight: CharacterBody3D=sword.get("_npc_body")
 var npc_sword: Node3D=sword.get("_npc_sword")
 for i in 300:
  if is_instance_valid(knight) and is_instance_valid(npc_sword):break
  await _frames(1)
  knight=sword.get("_npc_body");npc_sword=sword.get("_npc_sword")
 if not is_instance_valid(knight) or not is_instance_valid(npc_sword):failures.append("npc_sword");_finish();return
 sword.set_physics_process(false)
 var anchor: Vector3=knight.global_position+Vector3(0,5,0)
 var body:=AnimatableBody3D.new()
 body.sync_to_physics=false;body.collision_layer=1;body.collision_mask=0
 body.set_meta("sword_npc_part","forearm_l")
 var shape:=CollisionShape3D.new()
 var box:=BoxShape3D.new();box.size=Vector3(0.12,0.28,0.24)
 shape.shape=box;body.add_child(shape);scene.add_child(body)
 var cases: Array[Dictionary]=[
  {"name":"body_only","body_x":-0.25,"steel_x":0.25,"steel":false},
  {"name":"steel_first","body_x":0.25,"steel_x":-0.25,"steel":true},
  {"name":"body_first","body_x":-0.25,"steel_x":0.25,"steel":true},
  {"name":"tight_steel_first","body_x":-0.25,"steel_x":-0.34,"steel":true},
 ]
 var outcomes: Dictionary={}
 for item: Dictionary in cases:
  body.global_position=anchor+Vector3(float(item.body_x),0,-0.64)
  npc_sword.global_transform=Transform3D(Basis.IDENTITY,anchor+Vector3(float(item.steel_x),0,-0.64))
  npc_sword.visible=bool(item.steel)
  await _frames(2)
  sword.set("_held",true);sword.set("_hold_left",true)
  sword.set("_blocking",false)
  sword.set("_npc_part_hp",{})
  sword.set("_contact_prev",{})
  sword.set("_contact_gap",{})
  sword.set("_last_clash_ms",-1000)
  var from_origin: Vector3=anchor+Vector3(-0.5,0,0)
  var to_origin: Vector3=anchor+Vector3(0.5,0,0)
  sword.set("_sword_origin",to_origin)
  sword.set("_dir",Vector3.FORWARD)
  var weapon_length: float=sword.get("_weapon_length")
  var previous:=PackedVector3Array()
  for index in SEGMENTS+1:
   previous.append(from_origin+Vector3.FORWARD*(0.06+weapon_length*float(index)/SEGMENTS))
  sword.set("_prev_points",previous)
  var query:=PhysicsRayQueryParameters3D.create(previous[5],to_origin+Vector3.FORWARD*(0.06+weapon_length*5.0/SEGMENTS),1,[player.get_rid(),knight.get_rid()])
  var pre_ray: Dictionary=player.get_world_3d().direct_space_state.intersect_ray(query)
  var before: Dictionary=sword.snapshot()
  sword._sweep(0.1)
  var after: Dictionary=sword.snapshot()
  outcomes[str(item.name)]={
   "pre_ray_tag":str(pre_ray.get("collider").get_meta("sword_npc_part","")) if not pre_ray.is_empty() else "none",
   "pre_ray_normal":pre_ray.get("normal",Vector3.ZERO),
   "part_hp":after.get("npc_part_hp",{}),
   "blocks_delta":int(after.get("player_blocks",0))-int(before.get("player_blocks",0)),
   "sparks_delta":int(after.get("sparks_total",0))-int(before.get("sparks_total",0)),
   "sweep_rays_delta":int(after.get("sweep_rays",0))-int(before.get("sweep_rays",0)),
   "sweep_hits_delta":int(after.get("sweep_hits",0))-int(before.get("sweep_hits",0)),
  }
 report["cases"]=outcomes
 var body_only: Dictionary=outcomes.get("body_only",{})
 var steel_first: Dictionary=outcomes.get("steel_first",{})
 var body_first: Dictionary=outcomes.get("body_first",{})
 var tight_steel_first: Dictionary=outcomes.get("tight_steel_first",{})
 if not body_only.get("part_hp",{}).has("forearm_l") or int(body_only.get("blocks_delta",0))!=0:
  failures.append("body_only_must_wound")
 if not steel_first.get("part_hp",{}).is_empty() or int(steel_first.get("blocks_delta",0))!=1:
  failures.append("steel_first_must_block")
 if not body_first.get("part_hp",{}).has("forearm_l") or int(body_first.get("blocks_delta",0))!=0:
  failures.append("body_first_must_wound")
 if not tight_steel_first.get("part_hp",{}).is_empty() or int(tight_steel_first.get("blocks_delta",0))!=1:
  failures.append("tight_steel_first_must_block")
 _finish()

func _finish() -> void:
 report["fixture_passed"]=failures.is_empty()
 report["failures"]=failures
 FileAccess.open(out_dir.path_join("result.json"),FileAccess.WRITE).store_string(JSON.stringify(report,"\t"))
 print("SWEEP_ORDER4D83_RESULT ",JSON.stringify(report))
 quit(0 if failures.is_empty() else 1)
