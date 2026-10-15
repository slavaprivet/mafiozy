extends "observer_injury30.gd"
## Final integration keeps the original actual-hit regression unchanged and adds
## ordinary healthy attention plus the complete enabled venue/staff content.
var _healthy_held_frames := 0
var _healthy_focused_frames := 0
var _healthy_started_ms := 0
var _healthy_held_origin := Vector3.INF
var _healthy_hold_max_distance := 0.0
var _content_before: Dictionary={}

func _content(scene: Node) -> Dictionary:
	var total := 0
	var added := 0
	for child: Node in scene.get_children():
		if child.get_meta("dsh_town_extra",false) and child.get_node_or_null("TownCloneSign") is Label3D:total+=1
		if str(child.name).begins_with("CompactService29_"):added+=1
	var staff_count := 0
	var staff_live := 0
	var host: Node=scene.get("preview_venue_staff29") as Node
	if is_instance_valid(host):
		var entries: Dictionary=host.get("_rows")
		staff_count=entries.size()
		for row: Dictionary in entries.values():
			if is_instance_valid(row.get("actor")):staff_live+=1
	return {"venues":total,"new_venues":added,"staff_rows":staff_count,"staff_live":staff_live}

func _content_ok(content: Dictionary) -> bool:
	return int(content.get("venues",0))==12 and int(content.get("new_venues",0))==8 and int(content.get("staff_rows",0))==12 and int(content.get("staff_live",0))==12

func _bind(scene: Node3D) -> bool:
	if not super._bind(scene):return false
	_content_before=_content(scene)
	_checks["full_final_content_before"]=_content_ok(_content_before)
	if not _checks.full_final_content_before:_finish("final_content_missing");return false
	_phase="healthy_attention"
	_healthy_started_ms=Time.get_ticks_msec()
	return true

func _physics_process(delta: float) -> void:
	if _phase!="healthy_attention":
		super._physics_process(delta)
		return
	_torso_aim()
	var full: bool=float(_health._row.hp)==float(_health._row.max_hp)
	var focused: bool=Focus30.focused(_body)
	var held: bool=_life._attention29.active
	if not full or _fired!=0 or not _shots.is_empty():_finish("healthy_phase_was_damaged");return
	if focused:_healthy_focused_frames+=1
	if focused and held and Vector2(_body.velocity.x,_body.velocity.z).length()<.03:
		if not _healthy_held_origin.is_finite():_healthy_held_origin=_body.global_position
		_healthy_hold_max_distance=maxf(_healthy_hold_max_distance,_body.global_position.distance_to(_healthy_held_origin))
		_healthy_held_frames+=1
	if _healthy_held_frames>=30:
		_checks["healthy_gaze_pauses_before_hit"]=_healthy_focused_frames>=30 and _healthy_hold_max_distance<.05
		_rows.append({"phase":"healthy_attention_complete","hp":_health._row.hp,"focused_frames":_healthy_focused_frames,"held_frames":_healthy_held_frames,"max_hold_distance_m":_healthy_hold_max_distance,"shots_before_injury":_shots.size(),"content":_content_before})
		_phase="aim_and_wound"
	elif Time.get_ticks_msec()-_healthy_started_ms>12000:_finish("healthy_attention_not_observed")

func _finish(reason: String) -> void:
	if _phase=="finished":return
	var scene: Node=get_tree().current_scene
	var content_after: Dictionary=_content(scene) if is_instance_valid(scene) else {}
	_checks["full_final_content_after"]=_content_ok(content_after)
	if not _out.is_empty():
		var file:=FileAccess.open(_out.path_join("FINAL_CONTENT30.json"),FileAccess.WRITE)
		if file!=null:
			file.store_string(JSON.stringify({"before":_content_before,"after":content_after,"healthy_focused_frames":_healthy_focused_frames,"healthy_held_frames":_healthy_held_frames,"healthy_hold_max_distance_m":_healthy_hold_max_distance,"npc_relocated":false,"synthetic_damage":false},"\t"));file.close()
	super._finish(reason)
