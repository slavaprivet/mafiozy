import pathlib,json,hashlib
OUT=pathlib.Path(__file__).resolve().parent;ROOT=OUT.parents[3];GAME=ROOT/'outputs/coordinator31_release57/game'
rel='scripts/hospital/npc_simple_hospital.gd'
s=(GAME/rel).read_text(encoding='utf-8')
s=s.replace('const Swing = preload(', 'const DoorClearance31 = preload("res://scripts/hospital/npc_door_clearance31.gd")\nconst Swing = preload(',1)
s=s.replace('var _door_reason := ""','var _door_reason := ""\nvar _door_clear31: RefCounted',1)
s=s.replace('func begin(goal: Vector3, body: CharacterBody3D, map: RID, id: String, source: String) -> bool:\n', 'func begin(goal: Vector3, body: CharacterBody3D, map: RID, id: String, source: String) -> bool:\n\tif _door_clear31!=null:_door_clear31.cancel()\n\t_door_clear31=DoorClearance31.new() if source=="roam" else null\n',1)
s=s.replace('func cancel() -> void:\n','func cancel() -> void:\n\tif _door_clear31!=null:_door_clear31.cancel()\n',1)
s=s.replace('\t_attention_paused29=true;_phase="attention_paused"','\tvar was_door_backoff31:bool=_door_clear31!=null and _door_clear31.active()\n\tif _door_clear31!=null:_door_clear31.cancel()\n\t_attention_paused29=true;_phase="attention_paused"',1)
s=s.replace('\t_attention_ready29=_route!=null and _route.status=="ready"','\t_attention_ready29=not was_door_backoff31 and _route!=null and _route.status=="ready"',1)
needle='\t_roam_step29_phase="planning"\n\t_door_tick()\n\t_replan_s+=delta'
replacement='''\t_roam_step29_phase="planning"
\t_door_tick()
\tif _door_clear31!=null and (_door_clear31.active() or _door_clear31.poll(_route)):
\t\tvar clearance:String=_door_clear31.step(_route,delta,SPEED_MPS)
\t\t_roam_step29_phase=str(_door_clear31._activity)
\t\tif clearance=="blocked":
\t\t\t_last_reason=str(_door_clear31.snapshot().reason);_active=false;_phase="blocked"
\t\t\t_route.cancel();_guide.cancel()
\t\t\treturn _finish_step(before,delta,"blocked",false)
\t\tif clearance=="resume":
\t\t\t_restart("door_clear_original_goal31")
\t\t\treturn _finish_step(before,delta,"walking",false)
\t\t_phase="door_clear_"+str(_door_clear31._phase)
\t\treturn _finish_step(before,delta,"walking",false)
\t_replan_s+=delta'''
assert needle in s;s=s.replace(needle,replacement,1)
(OUT/'patch'/rel).write_text(s,encoding='utf-8')
rel='scripts/city/runtime/npc_city_clone_door_swing.gd'
s=(GAME/rel).read_text(encoding='utf-8')
s=s.replace('var target := 0.0','var target := 0.0\n## A rejected open still asks the blocking NPC to clear the live leaf arc.\n## A later close request revokes that intent even if target was already closed.\nvar _opening_requested31 := false',1)
s=s.replace('\ttarget = 0.0\n\tset_physics_process(true)','\ttarget = 0.0\n\t_opening_requested31 = false\n\tset_physics_process(true)',1)
s=s.replace('func _request_target(open: bool, trigger: String) -> Dictionary:\n','func opening_requested31() -> bool:\n\treturn _configured and _available() and _opening_requested31\n\n\nfunc _request_target(open: bool, trigger: String) -> Dictionary:\n\t_opening_requested31 = open\n',1)
s=s.replace('\t\t"target": target,','\t\t"target": target,\n\t\t"opening_requested31": _opening_requested31,',1)
p=OUT/'patch'/rel;p.parent.mkdir(parents=True,exist_ok=True);p.write_text(s,encoding='utf-8')
sha=lambda p:hashlib.sha256(p.read_bytes()).hexdigest()
manifest={p.relative_to(OUT/'patch').as_posix():{'base_sha256':sha(GAME/p.relative_to(OUT/'patch')) if (GAME/p.relative_to(OUT/'patch')).exists() else None,'candidate_sha256':sha(p)} for p in (OUT/'patch').rglob('*.gd')}
(OUT/'PATCH.json').write_text(json.dumps(manifest,indent=2)+'\n')
print(json.dumps(manifest))
