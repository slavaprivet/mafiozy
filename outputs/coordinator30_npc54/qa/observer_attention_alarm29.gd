extends "observer_attention29.gd"
const Focus = preload("res://scripts/npc_visual/npc_resident_focus29.gd")
var _alarm_test := false
var _alarm_frame := 0
var _alarm_seen := false
var _alarm_focused_frames := 0
var _alarm_held_frames := 0
var _hp_before := 0.0

func _done(reason: String) -> void:
	if reason == "complete" and not _alarm_test:
		_alarm_test=true; _phase="alarm_prepare"; _alarm_frame=Engine.get_physics_frames()
		_deadline_ms=Time.get_ticks_msec()+15000; _hp_before=float(_health.get("_row").hp)
		_weapons.equip("tt_pistol"); _look(true)
		return
	super._done(reason)

func _physics_process(delta: float) -> void:
	if not _alarm_test: super._physics_process(delta); return
	var frame: int=Engine.get_physics_frames()
	if Time.get_ticks_msec()>_deadline_ms: _done("alarm_timeout:"+_phase); return
	if _phase=="alarm_prepare" and frame-_alarm_frame>12:
		_button(MOUSE_BUTTON_LEFT,true); _phase="alarm_shot"; _alarm_frame=frame
	elif _phase=="alarm_shot":
		_button(MOUSE_BUTTON_LEFT,false); _look(); _phase="alarm_observe"
	elif _phase=="alarm_observe":
		_look()
		var alarm: bool=_life._phase=="INCIDENT_REACTING" or _health.should_pause_walk()
		if alarm: _alarm_seen=true
		if alarm and Focus.focused(_body):
			_alarm_focused_frames+=1
			if _life._attention29.active: _alarm_held_frames+=1
		if _alarm_seen and not alarm and _life._attention29.active:
			_attention_checks["actual_shot_event"]=_shots.size()==1
			_attention_checks["alarm_observed_while_focused"]=_alarm_focused_frames>3
			_attention_checks["alarm_blocks_attention"]=_alarm_held_frames==0
			_attention_checks["no_hp_edit_or_hit"]=is_equal_approx(float(_health.get("_row").hp),_hp_before)
			_attention_checks["attention_returns_after_alarm"]=true
			_done("complete")
