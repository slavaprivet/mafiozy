extends "strong_input.gd"
func key(code:int):
 var e:=InputEventKey.new();e.physical_keycode=code;e.keycode=code;e.pressed=true;Input.parse_input_event(e);Input.flush_buffered_events()
 e=InputEventKey.new();e.physical_keycode=code;e.keycode=code;e.pressed=false;Input.parse_input_event(e);Input.flush_buffered_events()
func air():
 await start(1.3)
 button(true)
 for i in 16:motion(Vector2(-8,0));await physics_frame
func run():
 await air()
 checks["actual_free_air_path"]=solid._free_swing34.size()>0
 var reverse_seen:=false;var reverse_cleared:=false
 var prior:Vector3=solid._free_swing34.back().step if not solid._free_swing34.is_empty() else Vector3.ZERO
 for i in 45:
  motion(Vector2(16,0));await physics_frame
  var ledger:Array=solid._free_swing34
  if not ledger.is_empty():
   var step:Vector3=ledger.back().step
   if step.dot(prior)<0:reverse_seen=true;reverse_cleared=ledger.size()==1
   prior=step
 checks["real_reversal_observed"]=reverse_seen
 checks["reversal_starts_new_epoch"]=reverse_cleared
 button(false);await frames(45)
 checks["released_air_path_cleared"]=solid._free_swing34.is_empty()
 await air()
 key(KEY_F6);await frames(2)
 checks["native_reset_drops_old_generation"]=solid._free_swing34.size()<=2
 await air()
 key(KEY_3);await frames(3)
 checks["native_equipment_drops_sword_credit"]=solid._free_swing34.is_empty() and host._weapon_id!="sword"
 await air()
 var pos:Vector3=host._sword.global_position
 # Supplemental API test: the production clash callback must consume credit
 # even when its sound/effect cooldown suppresses a second call. This is not
 # presented as an actual steel collision or a cut acceptance test.
 host._register_clash(pos)
 checks["clash_hook_consumes_existing_path"]=solid._free_swing34.is_empty()
 var frame:int=Engine.get_physics_frames()
 host._register_clash(pos)
 checks["clash_hook_cooldown_still_blocks_epoch"]=solid._free_block_frame34==frame
 checks["air_no_damage_or_cuts"]=host.clay_cuts==0 and host.clay_local_wounds28==0
 var passed:=true
 for value in checks.values():passed=passed and bool(value)
 FileAccess.open(out.path_join("RESULT.json"),FileAccess.WRITE).store_string(JSON.stringify({"passed":passed,"checks":checks,"scope":"Actual mouse air path/reversal/release, native F6 and equipment keys. Supplemental direct clash callback verifies cooldown invalidation only; no contact or damage acceptance claimed."},"\t"))
 button(false)
 if is_instance_valid(current_scene):
  var old:=current_scene;current_scene=null;old.queue_free()
 await frames(5);quit(0 if passed else 1)
