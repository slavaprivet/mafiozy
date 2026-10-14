extends RefCounted
## Isolated candidate: source contact gate -> local DamageState orchestrator.
## Host owns raycast and must run crash/trunk/dent callbacks after finish_raycast.
const Damage=preload("res://scripts/transport/transport_vehicle_damage_state.gd")
const Gate=preload("res://scripts/transport/transport_vehicle_contact_admission.gd")
var _authority: RefCounted
var _vehicle_id: String
var _generation:=0
var _gate: RefCounted
var _orchestrator: RefCounted
var _pending: Dictionary={}

func configure(authority: RefCounted,vehicle_id: String,generation: int,gate: RefCounted,orchestrator: RefCounted) -> bool:
	if _authority!=null or authority==null or vehicle_id.is_empty() or generation<1 or gate==null or orchestrator==null: return false
	_authority=authority; _vehicle_id=vehicle_id; _generation=generation; _gate=gate; _orchestrator=orchestrator
	return true

func advance_clock(receipt: Dictionary) -> Dictionary:
	if not _identity(receipt) or not _pending.is_empty(): return {"ok":false,"error":"authority_or_pending"}
	return _gate.advance_clock(receipt)

## Host supplies a unique event_id, exact current status and prior HP/revision.
## The gate's ticket ensures no time or other contact interleaves its raycast.
func begin_contact(receipt: Dictionary) -> Dictionary:
	if not _identity(receipt) or not _pending.is_empty(): return {"ok":false,"error":"authority_or_pending"}
	if not receipt.get("event_id") is String or receipt.event_id.is_empty(): return {"ok":false,"error":"event_identity"}
	var state: Dictionary=_orchestrator.state()
	var revision: int=_orchestrator.revision()
	var status: Variant=receipt.get("status")
	if state.is_empty() or not status is Dictionary or status.get("destroying")!=state.get("destroying") or status.get("wrecked")!=state.get("wrecked") or status.get("disposed")!=false or receipt.get("prior_hp")!=state.get("hp") or receipt.get("prior_explosions")!=state.get("explosions") or receipt.get("prior_revision")!=revision:
		return {"ok":false,"error":"state_authority"}
	var impact: Variant=receipt.get("impact_speed_mps")
	if not (impact is float or impact is int) or not is_finite(float(impact)):
		return {"ok":false,"error":"collision_payload"}
	var damage: int=Gate.crash_damage(maxf(0.0,float(impact)))
	# At the mechanical HP floor, a valid source contact still consumes cooldown
	# and runs callbacks even if the frozen orchestrator would reject an equal
	# state. Preserve that path without inventing a native HP revision.
	var hp_noop: bool=damage>0 and Damage.collision(state,maxf(0.0,float(impact)))==state
	var result: Dictionary=_gate.begin_contact(receipt)
	if not result.get("prepared",false): return result
	_pending={"ticket":result.ticket,"event_id":receipt.event_id,"state":state,"revision":revision,"contact_sequence":receipt.contact_sequence,"impact_speed_mps":maxf(0.0,float(impact)),"hp_noop":hp_noop}
	return result

## After the host's panel raycast, commit source cooldown first, then HP iff
## damage>0. Return the source callback order as a required host continuation.
func finish_raycast(receipt: Dictionary) -> Dictionary:
	if not _identity(receipt) or _pending.is_empty() or receipt.get("ticket")!=_pending.ticket or receipt.get("contact_sequence")!=_pending.contact_sequence:
		return {"ok":false,"error":"authority_or_ticket"}
	if _orchestrator.revision()!=_pending.revision or _orchestrator.state()!=_pending.state:
		_gate.cancel_pending(_pending.ticket); _pending={}
		return {"ok":false,"error":"state_changed_during_raycast"}
	var admitted: Dictionary=_gate.finish_raycast(receipt)
	if not admitted.get("ok",false): return admitted
	var pending: Dictionary=_pending; _pending={}
	var state_before: Dictionary=pending.state
	var revision_before: int=pending.revision
	if admitted.damage==0 or pending.hp_noop:
		if _orchestrator.revision()!=revision_before or _orchestrator.state()!=state_before:
			return {"ok":false,"error":"unchanged_hp_state_mismatch","cooldown_consumed":true}
		return {"ok":true,"admitted":true,"cooldown_consumed":true,"damage":admitted.damage,"hp_committed":false,"revision":revision_before,"state":state_before,"source_return":admitted.source_return,"callbacks_pending":true,"normalized_outward_native":admitted.normalized_outward_native,"hp_floor_noop":pending.hp_noop}
	var damage_receipt: Dictionary={"authority":_authority,"vehicle_id":_vehicle_id,"life_generation":_generation,"revision":revision_before+1,"kind":"collision","event_id":pending.event_id,"impact_mps":pending.impact_speed_mps,"prior_hp":state_before.hp,"prior_explosions":state_before.explosions}
	var committed: Dictionary=_orchestrator.accept(damage_receipt)
	if not committed.get("ok",false):
		return {"ok":false,"error":"hp_commit_failed","cause":committed.get("error","unknown"),"cooldown_consumed":true,"callbacks_pending":false}
	return {"ok":true,"admitted":true,"cooldown_consumed":true,"damage":admitted.damage,"hp_committed":true,"revision":committed.revision,"state":committed.state,"source_return":admitted.source_return,"callbacks_pending":true,"normalized_outward_native":admitted.normalized_outward_native}

func cancel_pending(ticket: RefCounted) -> bool:
	if _pending.is_empty() or _pending.ticket!=ticket: return false
	var canceled: bool=_gate.cancel_pending(ticket)
	if canceled: _pending={}
	return canceled

func dispose() -> void:
	if not _pending.is_empty(): _gate.cancel_pending(_pending.ticket)
	_pending={}; _authority=null; _gate=null; _orchestrator=null

func _identity(receipt: Dictionary) -> bool:
	return _authority!=null and receipt.get("authority")==_authority and receipt.get("vehicle_id")==_vehicle_id and receipt.get("life_generation")==_generation
