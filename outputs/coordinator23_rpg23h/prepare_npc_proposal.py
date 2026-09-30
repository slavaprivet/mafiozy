"""Exact current23g recipient overlay, output only. No engine or Git actions."""
from pathlib import Path
import hashlib,json,difflib
ROOT=Path(__file__).resolve().parents[2];OUT=Path(__file__).resolve().parent
BASE=ROOT/'godot/mafiozi_walk/scripts/npc_visual';DST=OUT/'npc_proposal';DST.mkdir(parents=True,exist_ok=True)
def sha(b):return hashlib.sha256(b).hexdigest()
owner_name='npc_local_preview_hit_owner.gd';life_name='npc_ordinary_hit_lifecycle.gd'
original=(BASE/owner_name).read_bytes(); s=original.decode('utf8').replace('\r\n','\n')
assert sha(original)=='0a3e311dd08bb463088f3afb1499d74032e8e7528af8aaadda1aa9e47025f225'
assert 'func accept_native_rpg_blast' not in s
s=s.replace('var _binding: Dictionary={}','var _binding: Dictionary={}\nvar _rpg_blast_gate: RefCounted\nvar _rpg_blast_busy:=false',1)
s=s.replace('func dispose() -> void:\n','func dispose() -> void:\n\t_rpg_blast_gate=null\n',1)
# Blast pressure has no single bullet contact. Keep every ordinary point-share
# path exact; only this owner-created matching-event context bypasses the share.
old_point='var point_impulse:=impulse.normalized()*minf(POINT_MAX_NS,impulse.length()*POINT_SHARE)'
new_point='var point_impulse:=Vector3.ZERO if _native_impulse_context.get("event_id")==id and _native_impulse_context.get("uniform_only",false) else impulse.normalized()*minf(POINT_MAX_NS,impulse.length()*POINT_SHARE)'
assert s.count(old_point)==1;s=s.replace(old_point,new_point)
old_call='if not _point_consumed.has(id) and _adapter.receipt(id)==last_result'
assert s.count(old_call)==1
s=s.replace(old_call,'if point_impulse!=Vector3.ZERO and not _point_consumed.has(id) and _adapter.receipt(id)==last_result')
s+='''
## Proposed local RPG seam; the gate owns the actual ammo/Flight/native proof.
## No cosmetics, arbitrary damage dictionary or explosion proximity admits HP.
func bind_native_rpg_gate(gate: RefCounted) -> bool:
	if not is_instance_valid(gate) or _rpg_blast_gate!=null or _rpg_blast_busy or _current(_binding).is_empty(): return false
	if gate._disposed or gate._resident_host!=_host or gate._weapons.get_ref()!=_weapons or not gate._owners.has(self): return false
	_rpg_blast_gate=gate
	return true

func accept_native_rpg_blast(gate: RefCounted, ticket: RefCounted) -> Dictionary:
	if _rpg_blast_busy or not _admitting.is_empty() or not is_instance_valid(gate) or gate!=_rpg_blast_gate or _current(_binding).is_empty(): return {"ok":false,"reason":"owner_life_or_gateway"}
	var binding:Dictionary=_binding.duplicate(true)
	var token:Dictionary=_token.duplicate()
	_rpg_blast_busy=true
	var accepted:Dictionary=gate.take_target(self,ticket)
	# Opaque ticket is consumed before callbacks; recheck this same owner after
	# its issuer calls live-owner services. Never apply a retired returned ticket.
	if not accepted.get("ok",false) or not _ready or _rpg_blast_gate!=gate or _binding!=binding or _token!=token or accepted.get("binding")!=binding or accepted.get("token")!=token or gate._disposed or not gate._busy or _current(binding).is_empty():
		_rpg_blast_busy=false; return {"ok":false,"reason":"blast_capability"}
	var position:Variant=accepted.get("target_position")
	var origin:Variant=accepted.get("point")
	if not position is Vector3 or not position.is_finite() or not origin is Vector3 or not origin.is_finite() or accepted.get("admission_kind")!="owner_proved_native_rpg" or not accepted.get("hit") is Dictionary or accepted.hit.get("weapon_id")!="rpg":
		_rpg_blast_busy=false; return {"ok":false,"reason":"blast_shape"}
	_row.r=(position.z+45.1)/4.1; _row.c=(position.x+395.65)/4.1
	_last_player=_weapons.player.global_position
	_admitting={"event_id":accepted.event_id,"binding":binding,"hit":accepted.hit.duplicate(true),"admission_kind":"owner_proved_native_rpg"}
	var before:=Time.get_ticks_usec()
	last_result=_adapter.hit(accepted.event_id,_admitting.hit)
	_admitting={}
	var blast_physical:Dictionary={"status":"no_applied_transition","applied":false}
	if last_result.get("ok",false) and last_result.get("applied",false) and _ready and _rpg_blast_gate==gate and not gate._disposed and not _current(binding).is_empty():
		# The opaque target ticket owns this actual current target/epicentre pair.
		# Existing user-tuned blast J is horizontal; no invented impact skin point.
		var radial:Vector3=position-origin
		var distance_m:=Vector2(radial.x,radial.z).length()
		var direction:=Vector3(float(accepted.hit.dir_c),0,float(accepted.hit.dir_r))
		var proposal:Dictionary=HitImpulse.blast(distance_m,direction,_row.get("_invulnerable",false))
		_native_impulse_context={"event_id":accepted.event_id,"value":proposal,"uniform_only":true}
		_publish_physical(accepted.event_id,last_result.reason,position)
		_native_impulse_context={}
		if last_impulse.get("event_id")==accepted.event_id:
			blast_physical={"status":"initial_uniform_applied","applied":true,"receipt":last_impulse.duplicate(true)}
		elif last_result.reason in ["medical_downed","final_death"]:
			blast_physical={"status":"HOLD_active_uniform_port_or_activation_rejected","applied":false,"physical":last_physical.duplicate(true)}
		else:
			blast_physical={"status":"standing_survivor_no_ragdoll_transition","applied":false}
	_last_hit_us=Time.get_ticks_usec()-before
	_rpg_blast_busy=false
	var reply:=last_result.duplicate(true)
	reply["blast_physical"]=blast_physical
	return reply
'''
(DST/owner_name).write_text(s,encoding='utf8',newline='\n')
raw=(BASE/life_name).read_bytes();t=raw.decode('utf8').replace('\r\n','\n')
assert sha(raw)=='80f7a0cb8eb36d26912abbedac7c9ed25597c28ceeca1ac72ad47c5546c1f309'
old='if h.damage<=0 or not h.get("weapon_id") is String or Rules.balance_id(h.weapon_id) in ["","rpg"]: return _stop("ordinary_bullet_required")'
new='if h.damage<=0 or not h.get("weapon_id") is String or Rules.balance_id(h.weapon_id)=="" or (Rules.balance_id(h.weapon_id)=="rpg" and admitted.get("admission_kind")!="owner_proved_native_rpg"): return _stop("admitted_ordinary_hit_required")'
assert t.count(old)==1;t=t.replace(old,new)
(DST/life_name).write_text(t,encoding='utf8',newline='\n')
rows=[];patch=[]
for name in [owner_name,life_name]:
    before=(BASE/name).read_bytes();after=(DST/name).read_bytes()
    rows.append({'path':'scripts/npc_visual/'+name,'before_sha256':sha(before),'after_sha256':sha(after)})
    patch.extend(difflib.unified_diff(before.decode('utf8').replace('\r\n','\n').splitlines(True),after.decode('utf8').splitlines(True),fromfile='a/scripts/npc_visual/'+name,tofile='b/scripts/npc_visual/'+name))
(DST/'PROPOSAL.patch').write_text(''.join(patch),encoding='utf8')
(DST/'RECEIPT.json').write_text(json.dumps({'status':'OUTPUTS_ONLY_UNRUN_23G_COMPATIBLE_HP_AND_INITIAL_UNIFORM_J','base_user_checkpoint':'27ee4b39','gate_reused_without_changes':'outputs/artist23_rpg_damage/npc_rpg_blast_gate.gd','gate_sha256':sha((ROOT/'outputs/artist23_rpg_damage/npc_rpg_blast_gate.gd').read_bytes()),'files':rows,'limits':['No engine, parse or integration test run. Prior445/88/18 belong to earlier component fixture, not this overlay.','Initial IDLE uses existing HitImpulse.blast uniform-only J; medical75Ns retained. ACTIVE additional pressure remains explicit HOLD.','No fake bullet surface contact or bullet blood/mark at epicentre.','Preserves exact23g anatomical-head logic, marks, ordinary/pellet methods, current_damage_context; only publish point-share gains trusted matching-event uniform-only branch.']},ensure_ascii=False,indent=2),encoding='utf8')
print(json.dumps(rows))
