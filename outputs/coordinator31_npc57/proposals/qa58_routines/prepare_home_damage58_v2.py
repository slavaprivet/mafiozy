from pathlib import Path
H=Path(__file__).resolve().parent
def save(name,text):
    p=H/name
    assert not p.exists(),p
    p.write_text(text,encoding='utf-8')
base=(H/'entry_c4_home_damage58.gd').read_text(encoding='utf-8')
base=base.replace('target58=wall.to_global', 'evidence.allowed_before_aim58=allowed_snapshot58(scene,equipment,weapons)\n\ttarget58=wall.to_global')
base=base.replace('"diagnostic":equipment._target_query45.snapshot()', '"diagnostic":equipment._target_query45.snapshot(),"allowed":allowed_snapshot58(scene,equipment,weapons)')
base+='''
func allowed_snapshot58(scene: Node3D,equipment: Node,weapons: Node) -> Dictionary:
	var window: Window=player58.get_window()
	return {"allowed":equipment._allowed(),"current":equipment._current(),"owner_killed":equipment._owner_killed,"dead":scene.preview_dead,"physics_fault":scene.preview_physics_fault,"interaction":weapons._interaction_allowed(),"ground_controls":player58._ground_pressure_controls_allowed(),"free_mouse":player58._free_mouse_look,"pose_authority":str(player58._pose_authority),"jump_active":not player58._jump.is_empty(),"text_focus":player58._text_control_focused(),"controls_blocked":weapons.controls_blocked(),"on_floor":player58.is_on_floor(),"display":DisplayServer.get_name(),"window_visible":window.visible,"window_focus":window.has_focus(),"window_mode":window.mode,"mouse_mode":Input.mouse_mode}
'''
save('entry_c4_home_damage58_v2.gd',base)
entry=(H/'entry_home_damage58.gd').read_text(encoding='utf-8')
entry=entry.replace('entry_c4_home_damage58.gd','entry_c4_home_damage58_v2.gd').replace('home_damage_driver58.gd','home_damage_driver58_v2.gd')
entry=entry.replace('evidence.sleep_before_damage=component.home.snapshot()', 'check(Engine.physics_ticks_per_second==60,"native physics60",Engine.physics_ticks_per_second)\n\tevidence.sleep_before_damage=component.home.snapshot()')
entry=entry.replace('await capture_bed58(scene)', 'evidence.visual_companion="runs/home_damage01/sleep_resident3_native.png; exact stage05 rendered native pose; this test is headless"')
entry=entry.replace('component.sleep_cancel_frame>=component.damage_trigger_frame and', 'component.damage_trigger_frame>=0 and component.sleep_cancel_frame>=component.damage_trigger_frame and')
entry=entry.replace('component.exit_frame>=component.sleep_cancel_frame,', 'component.damage_trigger_frame>=0 and component.sleep_cancel_frame>=0 and component.exit_frame>=component.sleep_cancel_frame,')
save('entry_home_damage58_v2.gd',entry)
driver=(H/'home_damage_driver58.gd').read_text(encoding='utf-8')
driver=driver.replace('or life._health.should_pause_walk():', 'or life._health.should_pause_walk() or life._attention29.active:')
save('home_damage_driver58_v2.gd',driver)
run=(H/'run_home_damage58.py').read_text(encoding='utf-8')
run=run.replace('entry_c4_home_damage58.gd','entry_c4_home_damage58_v2.gd').replace('entry_home_damage58.gd','entry_home_damage58_v2.gd').replace('home_damage_driver58.gd','home_damage_driver58_v2.gd')
run=run.replace("[str(engine),'--path'", "[str(engine),'--headless','--path'").replace("probe('graphical'", "probe('headless'").replace("Lease('graphical'", "Lease('headless'")
save('run_home_damage58_v2.py',run)
