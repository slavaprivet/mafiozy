extends "test_pressure_control.gd"
## Original28 actual TT death and owner impulse, strengthened receipt observation.
## The inherited setup moves the player once; no corpse, shape or velocity edits.
var capsule_identity: Dictionary = {}
var verified_pressure_frames := 0
var verified_dead_contacts := 0
var previous_move: Dictionary = {}

func _initialize() -> void:
	force_enabled = true
	super._initialize()

func place_player() -> bool:
	var capsule: CollisionShape3D = player.get_node("PlayerCapsule")
	capsule_identity = {"node":capsule.get_instance_id(), "shape":capsule.shape.get_instance_id(), "local":capsule.transform, "radius":capsule.shape.radius, "height":capsule.shape.height, "mask":player.collision_mask, "layer":player.collision_layer}
	return super.place_player()

func observe_pressure(delta: float) -> void:
	super.observe_pressure(delta)
	if done or phase not in ["pressure", "released"]: return
	var capsule: CollisionShape3D = player.get_node("PlayerCapsule")
	check(capsule.get_instance_id()==capsule_identity.node and capsule.shape.get_instance_id()==capsule_identity.shape and capsule.transform==capsule_identity.local and not capsule.disabled, "step33 original player capsule identity and local pose")
	check(capsule.shape.radius==capsule_identity.radius and capsule.shape.height==capsule_identity.height and is_equal_approx(capsule.shape.radius,.3) and is_equal_approx(capsule.shape.height,1.9) and player.collision_mask==capsule_identity.mask and player.collision_layer==capsule_identity.layer, "step33 full player capsule and filters retained beside actual corpse")
	check(player._jump.is_empty() and not Input.is_action_pressed(player.ACTION_JUMP), "step33 pressure remains ordinary walking")
	var move: Dictionary = player.completed_ground_pressure_receipt()
	check(not move.is_empty(), "step33 public same-frame corpse pressure receipt exists")
	if move.is_empty(): return
	verified_pressure_frames += 1
	check(move.frame==Engine.get_physics_frames() and move.end==player.global_position and player.get_position_delta().is_equal_approx(move.end-move.start), "step33 corpse receipt equals entire single native move")
	if not previous_move.is_empty():
		check(move.serial==previous_move.serial+1 and move.start.is_equal_approx(previous_move.end), "step33 native corpse-contact movement continuity")
	previous_move = move.duplicate(true)
	for i: int in player.get_slide_collision_count():
		var hit := player.get_slide_collision(i)
		for j: int in hit.get_collision_count():
			if not owns(hit.get_collider(j)): continue
			var contact: Dictionary = player.completed_ground_slide_contact(i,j)
			check(not contact.is_empty(), "step33 actual dead-part native public contact")
			if contact.is_empty(): continue
			verified_dead_contacts += 1
			check(contact.serial==move.serial and contact.frame==move.frame and contact.collider_rid==hit.get_collider_rid(j) and contact.point==hit.get_position(j) and contact.normal==hit.get_normal(j) and contact.capsule_shape_id==capsule_identity.shape, "step33 exact dead-part contact and capsule receipt identity")

func finish() -> void:
	if done: return
	check(verified_pressure_frames>0 and verified_dead_contacts>0, "step33 real corpse contact receipt observed")
	FileAccess.open(out.path_join("RECEIPTS.json"), FileAccess.WRITE).store_string(JSON.stringify({"verified_pressure_frames":verified_pressure_frames, "verified_dead_contacts":verified_dead_contacts, "force_enabled":force_enabled, "errors":errors, "scope":"actual original resident72 TT death and original owner impulse; original28 inherited checks plus step33 whole-capsule native public receipt checks", "performance_acceptance":false}, "  "))
	super.finish()
