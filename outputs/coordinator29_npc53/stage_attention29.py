import pathlib, sys, shutil, json, hashlib
OUT = pathlib.Path(__file__).resolve().parent
ROOT = OUT.parents[1]
GAME = OUT/'game'
sys.path.insert(0, str(ROOT))
from tools.godot.test_scheduler import Lease

def edit(rel, replacements):
    path = GAME/rel
    content = path.read_text(encoding='utf-8')
    for old, new in replacements:
        assert content.count(old) == 1, (rel, old[:150], content.count(old))
        content = content.replace(old, new, 1)
    path.write_text(content, encoding='utf-8')

with Lease(mode='headless', project=GAME, access='write', wait_seconds=30):
    shutil.copy2(OUT/'proposals/root_attention29/npc_attention29.gd', GAME/'scripts/npc_visual/npc_attention29.gd')
    focus=GAME/'scripts/npc_visual/npc_resident_focus29.gd'
    source=focus.read_text(encoding='utf-8')
    first=source.index('static func focused('); end=source.index('\nstatic func prepare(',first)
    old=source[first:end]
    refresh=old[old.index('\tvar frame:'):old.index('\tif not _player_position.is_finite()')]
    refresh=refresh.replace('body.get_viewport()', 'scene.get_viewport()').replace('body.get_world_3d()', '(scene as Node3D).get_world_3d()')
    refresh=refresh.replace('return false', 'return')
    replacement='''static func _refresh(scene: Node) -> void:
	if scene == null: return
'''+refresh+'''
static func focused(body: Node3D) -> bool:
	if not is_instance_valid(body) or not body.is_inside_tree(): return false
	_refresh(body.get_tree().current_scene)
'''+old[old.index('\tif not _player_position.is_finite()'):]+'''
static func target_source(scene: Node) -> String:
	_refresh(scene)
	var collider: Node = _hit.get_ref() as Node if _hit != null else null
	for _depth in 12:
		if not is_instance_valid(collider): return ""
		if collider is CharacterBody3D and focused(collider): return str(collider.get_meta("source_id", ""))
		collider = collider.get_parent()
	return ""
'''
    source=source[:first]+replacement+source[end:]
    focus.write_text(source,encoding='utf-8')
    edit('scripts/npc_city_daily.gd', [
        ('const Life =', 'const Focus29 = preload("res://scripts/npc_visual/npc_resident_focus29.gd")\nvar _focused29 := ""\nconst Life ='),
        ('\tvar started:=Time.get_ticks_usec()\n\t# The walk', '''	var started:=Time.get_ticks_usec()
	# At most two direct life polls: the newly looked-at resident and the previous
	# one on release. No population scan or wait for the rotating daily slice.
	var focused: String = Focus29.target_source(_scene.get_ref())
	var urgent: Array[String] = []
	if not _focused29.is_empty() and _focused29 != focused: urgent.append(_focused29)
	if not focused.is_empty(): urgent.append(focused)
	_focused29 = focused
	for id: String in urgent:
		if not _lives.has(id): continue
		var current: RefCounted = _lives[id]
		current._dsh_elapsed = 0.0; current._dsh_last_ms = Time.get_ticks_msec()
		if _track_single28: _step_calls28 += 1
		current.step(delta)
	# The walk''')
    ])
    edit('scripts/npc_daily_life.gd', [
        ('const ResDiag =', 'const Attention29 = preload("res://scripts/npc_visual/npc_attention29.gd")\nvar _attention29: RefCounted = Attention29.new()\nconst ResDiag ='),
        ('\t_now=_health._now()\n\tif _ambient29 != null', '\t_now=_health._now()\n\tif _attention29.step(self, delta, row):\n\t\t_dsh_energy_drain(); _dsh_resdiag_step(row); _busy=false; return\n\tif _ambient29 != null'),
        ('func _start_incident_hold() -> void:\n', 'func _start_incident_hold() -> void:\n\t_attention29.clear()\n\tif _roam51_active and _roam51 != null: _roam51.cancel(); _roam51_active=false\n'),
        ('func dsh_notice_damage() -> Dictionary:\n', 'func dsh_notice_damage() -> Dictionary:\n\t_attention29.clear()\n'),
        ('func _end_life() -> void:\n', 'func _end_life() -> void:\n\t_attention29.clear(false)\n'),
        ('func dispose() -> void:\n', 'func dispose() -> void:\n\t_attention29.clear(false)\n'),
        ('return {"source_id":_token.get("source_id",""),"phase":_phase', 'return {"attention29":_attention29.active,"source_id":_token.get("source_id",""),"phase":_phase'),
    ])
    # Service pause retains the reservation and the physical leg; it cannot accrue a purchase/heal dwell.
    edit('scripts/hospital/npc_restaurant_visit28.gd', [
        ('func stand(delta: float) -> void:\n', '''func attention_pause29() -> bool:
	if not is_instance_valid(_body) or _drive == null or _phase in ["CANCELLED", "OUTSIDE", "IDLE"]: return false
	if _phase == "INSIDE" or (_phase in ["WAITING", "PORTAL_WAIT_IN", "PORTAL_WAIT_OUT"] and not _waiting_move): return true
	return _drive.attention_pause29()

func attention_hold29(delta: float) -> void:
	stand(delta)
	var now: int = Time.get_ticks_msec()
	if _registry != null and now >= _next_touch:
		_next_touch = now + 1000; _registry.ledger.touch(_key, now, _entered)
	_progress_at = now; _progress_position = _body.global_position
	_door_tick()

func attention_resume29() -> bool:
	_progress_at = Time.get_ticks_msec(); _progress_position = _body.global_position
	_next_poll = 0
	return _drive.attention_resume29() if _drive != null else false

func stand(delta: float) -> void:
''')
    ])
print('Attention staged: original goal, same-frame release, alarm/health priority.')
