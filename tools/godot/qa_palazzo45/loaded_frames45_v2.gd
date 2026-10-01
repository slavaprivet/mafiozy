extends "loaded_frames45.gd"
## Fix only the QA observation lifetime. The native owner runs before this
## observer and may synchronously retire the very pane struck by the rocket.
## Post-terminal owns_collider=false stays visible in diagnostics; it is not
## rewritten to true and is never used as the pre-shot ownership witness.

func source_receipt45() -> void:
	super.source_receipt45()
	var directory: String = get_script().resource_path.get_base_dir()
	var base_sha: String = FileAccess.get_sha256(directory.path_join("loaded_frames45.gd"))
	var helper_sha: String = FileAccess.get_sha256(directory.path_join("frozen/weapon_observer40.gd"))
	check(base_sha == "0c6ab1b164a25c90903f2d0ef0413977dc0317b05e5b2cbea202c8464c953e37", "v2 retains exact original45 focused fixture")
	check(helper_sha == "21982c211896ebd73762ec42fc14aa9f98c1ed300c1e9ca840eac5aff9f2dee1", "v2 retains exact frozen40 observer helper")
	evidence.observer_revision = "frames45_terminal_v2_prefire_identity"
	evidence.fixture_sha256 = {"loaded_frames45.gd":base_sha, "frozen/weapon_observer40.gd":helper_sha, "loaded_frames45_v2.gd":FileAccess.get_sha256(get_script().resource_path)}

func on_terminal(receipt: Dictionary) -> void:
	# Keep the original instantaneous post-handler ownership fields honestly.
	super.on_terminal(receipt)
	if terminals.is_empty(): return
	var observed: Dictionary = terminals[-1]
	observed.native_rpg_impact = receipt.get("native_rpg_impact", false)
	observed.cosmetic_only = receipt.get("cosmetic_only", false)
	observed.native_hit = receipt.get("hit", {}).get("hit", false)
	observed.scene_token = receipt.get("scene_token", "")
	observed.actor_id = receipt.get("actor_id")
	observed.life_generation = receipt.get("life_generation")
	observed.sequence = receipt.get("sequence")
	observed.site_generation_at_observer = int(host.site.rebuild_generation)
	var pane_row: Dictionary = host.site._glazing._panes.get(int(observed.collider_id), {})
	observed.pane_support_lost_at_observer = pane_row.get("support_lost", false)
	observed.pane_broken_at_observer = pane_row.get("broken", false)
	observed.pane_visual_retired_at_observer = pane_row.get("visual_retired", false)

func fire_rpg(wanted: CollisionObject3D, at: Vector3, label: String) -> Dictionary:
	target = at
	mouse(MOUSE_BUTTON_RIGHT, true)
	var settled: bool = await settle_aim(wanted, label)
	if not check(settled and native_sight(wanted), label + ": real camera and mounted muzzle remain settled on exact target before fire"):
		tracking = false
		mouse(MOUSE_BUTTON_RIGHT, false)
		return {}
	# Capture fresh, current, enabled pane ownership immediately before the
	# native button press. This read-only validation never applies any damage.
	var glazing: Node = host.site._glazing
	var contact: Dictionary = glazing.validate_pane_contact(wanted, at)
	var wall: RigidBody3D = contact.get("wall") as RigidBody3D
	var generation: int = int(host.site.rebuild_generation)
	var expected_id: int = wanted.get_instance_id()
	var valid: bool = bool(contact.get("ok", false)) and bool(glazing.owns_collider(wanted)) and int(contact.get("pane_id", 0)) == expected_id and int(contact.get("generation", -1)) == generation and is_instance_valid(wall)
	if not check(valid, label + ": fresh pre-shot native pane geometry, identity and generation are owned"):
		mouse(MOUSE_BUTTON_RIGHT, false)
		return {}
	var prefire: Dictionary = {"pane_id":expected_id, "wall_id":wall.get_instance_id(), "generation":generation, "scene_token":"preview-scene:" + str(game.get_instance_id()), "actor_id":player.get_meta("actor_id"), "life_generation":player.get_meta("life_generation"), "target":at, "pane_transform":wanted.global_transform, "layer":wanted.collision_layer, "owned_pane":true, "validated_pane_contact":true, "both_native_rays":true, "physics_frame":Engine.get_physics_frames()}
	evidence.get_or_add("prefire_identity", {})[label] = prefire
	var ammo: int = weapons.fire_state.magazine
	var shots: int = weapons.shots_count
	var before: int = owned_events("blast").size()
	var admitted: int = host.snapshot().damage.stats.admitted_blast_events
	var terminal_count: int = terminals.size()
	var launch_count: int = emitted_shots.size()
	mouse(MOUSE_BUTTON_LEFT, true)
	await step(2)
	mouse(MOUSE_BUTTON_LEFT, false)
	evidence.aim[label].after_fire = aim_sample(wanted)
	for i: int in 240:
		await step()
		if owned_events("blast").size() > before: break
	tracking = false
	mouse(MOUSE_BUTTON_RIGHT, false)
	check(weapons.shots_count == shots + 1 and weapons.fire_state.magazine == ammo - 1, label + ": native RPG consumes exactly one existing round")
	var one_terminal: bool = terminals.size() == terminal_count + 1
	var one_launch: bool = emitted_shots.size() == launch_count + 1
	check(one_terminal and one_launch, label + ": exactly one native committed launch and one terminal observed")
	check(host.snapshot().damage.stats.admitted_blast_events == admitted + 1, label + ": authenticated bridge admits exactly one terminal")
	var events: Array = owned_events("blast")
	if not check(events.size() == before + 1, label + ": exactly one blast reaches integrated owner"): return {}
	var event: Dictionary = events[-1]
	var result: Dictionary = event.get("result", {})
	check(bool(result.get("committed", false)) and result.get("detached") == 4, label + ": exactly four original tiles released")
	if not one_terminal or not one_launch: return event
	var terminal: Dictionary = terminals[-1]
	var launch: Dictionary = emitted_shots[-1]
	var shot_id: String = str(launch.get("shot_id", ""))
	var event_id: String = str(prefire.scene_token) + ":" + shot_id
	check(not shot_id.is_empty() and launch.get("weapon_id") == "rpg" and terminal.get("shot_id") == shot_id and bool(terminal.get("native_rpg_impact", false)) and bool(terminal.get("native_hit", false)) and not bool(terminal.get("cosmetic_only", false)), label + ": native hit and committed RPG launch carry the same real shot identity")
	check(int(terminal.get("collider_id", 0)) == expected_id and int(result.get("contact_collider_id", 0)) == expected_id and int(result.get("area_target_id", 0)) == int(prefire.wall_id), label + ": terminal and authoritative damage preserve exact pre-shot glass collider and source wall")
	check(terminal.get("scene_token") == prefire.scene_token and terminal.get("actor_id") == prefire.actor_id and terminal.get("life_generation") == prefire.life_generation and int(terminal.get("site_generation_at_observer", -1)) == generation and int(result.get("generation", -1)) == generation and int(host.site.rebuild_generation) == generation, label + ": scene actor lifetime and building generation remain current through impact")
	check(event.get("event_id") == event_id and result.get("event_id") == event_id and result.get("original_position") is Vector3 and terminal.get("position") is Vector3 and result.original_position.is_equal_approx(terminal.position) and is_equal_approx(float(result.get("original_radius", -1.0)), .8), label + ": owner event matches exact committed shot and unmodified native contact/radius")
	evidence.get_or_add("terminal_identity_validation", {})[label] = {"prefire":prefire, "terminal":terminal.duplicate(true), "launch":launch.duplicate(true), "event":event.duplicate(true), "post_terminal_ownership_used_as_prefire_proof":false, "authoritative_event_identity":event_id}
	return event
