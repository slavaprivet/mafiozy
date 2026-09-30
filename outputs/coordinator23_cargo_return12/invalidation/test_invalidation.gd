extends "../test_return_input.gd"
func run()->void:
	root.size=Vector2i(1280,720);root.content_scale_size=Vector2i(1280,720)
	scene=load("res://scenes/main.tscn").instantiate();root.add_child(scene)
	for i in 180:
		await step()
		if scene.preview_ready:break
	check(scene.preview_ready,"actual_main_ready")
	if not scene.preview_ready:finish();return
	p=scene._player;w=scene.preview_weapons;t=scene.preview_transport;c=w.get_node("WeaponCargo")
	p.set_mouse_captured(true);await step(60)
	var access:Dictionary=t.compartments.access_profile("trunk")
	p.global_position=t.body.to_global(access.position_local_m+access.outward_local*.9);p.global_position.y=.01
	await step(5);t.compartments.set_open("trunk",true);await step(100)
	check(c._window_access(),"real_open_trunk_rear_access")
	if not c._window_access():finish();return
	var record:Dictionary=await prepare_item()
	if record.is_empty():finish();return
	var inventory_before:Dictionary=w.inventory.snapshot();var shots:int=w.shots_count
	# Public production pose handoff API, invoked at physics_frame before normal
	# scheduled player processing. No direct advance/_process calls.
	await physics_frame
	p.set_preview_pose_authority(&"qa_external_owner")
	await process_frame;await step(2)
	check(not c.window_open and not w.controls_blocked(),"scheduled_pose_denial_closes_modal")
	check(not p._free_mouse_look and Input.mouse_mode==Input.MOUSE_MODE_VISIBLE,"scheduled_pose_denial_releases_controls")
	check(w.inventory.snapshot()==inventory_before and w.shots_count==shots,"phase_handoff_preserves_inventory_no_shot")
	p.set_preview_pose_authority(&"on_foot");p.set_mouse_captured(true);await step(2)
	send_key(KEY_F,true);await step();send_key(KEY_F,false);await step(3)
	check(c.window_open,"F_reopens_after_valid_control_reacquire")
	send_key(KEY_Q,true);await step();send_key(KEY_Q,false);await step(2)
	check(not c.window_open and not w.menu_open and p._free_mouse_look,"Q_cargo_close_preserves_game_control")
	send_key(KEY_Q,true);await step();send_key(KEY_Q,false);await step(2)
	check(w.menu_open and p._free_mouse_look,"next_Q_opens_arsenal")
	send_key(KEY_Q,true);await step();send_key(KEY_Q,false);await step(2)
	check(not w.menu_open and p._free_mouse_look,"Q_arsenal_close_preserves_control")
	send_key(KEY_F,true);await step();send_key(KEY_F,false);await step(3)
	check(c.window_open,"modal_ready_for_direct_arsenal_handoff")
	# Public menu API used by arsenal UI launcher. This exercises the exact
	# close_window(false) handoff which must NOT be changed to invalidation.
	w.set_menu(true);await step(2)
	check(w.menu_open and not c.window_open and p._free_mouse_look,"arsenal_public_handoff_stays_eligible")
	check(w.equip("nagan").get("ok",false),"arsenal_selection_equips_after_handoff")
	check(not w.menu_open and w.fire_state.weaponId=="nagan" and p._free_mouse_look,"arsenal_equip_returns_to_control")
	finish()
