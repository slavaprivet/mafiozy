extends RefCounted
## Source vehicle_damage.mjs contactImpact admission, before its panel raycast.
## Host owns the clock, vehicle lifetime/status, collision event and payload.
## This gate never changes HP, dents, structure, trunk or visual effects.
const COOLDOWN_S:=0.25
const SLIDE_SCRAPE_MPS:=1.5
const NORMAL_MIN_LENGTH_SQUARED:=1e-8
var _authority: RefCounted
var _vehicle_id: String
var _generation:=0
var _clock_revision:=0
var _time_s:=0.0
var _last_crash_s:=-INF
var _last_contact_sequence:=0
var _pending: Dictionary={}
var _disposed:=false

func configure(authority: RefCounted,vehicle_id: String,generation: int) -> bool:
	if _disposed or _authority!=null or authority==null or vehicle_id.is_empty() or generation<1: return false
	_authority=authority; _vehicle_id=vehicle_id; _generation=generation
	return true

## Source update(dt) advances time before subsequent contactImpact calls.
## revision is a host-owned strictly increasing clock receipt, not wall time.
func advance_clock(receipt: Dictionary) -> Dictionary:
	if not _identity(receipt): return {"ok":false,"error":"authority_or_lifetime"}
	if not _pending.is_empty(): return {"ok":false,"error":"raycast_pending"}
	if not receipt.get("clock_revision") is int or receipt.clock_revision!=_clock_revision+1 or not _number(receipt.get("dt")) or float(receipt.dt)<0.0:
		return {"ok":false,"error":"clock_receipt"}
	var next_time: float=_time_s+float(receipt.dt)
	if not is_finite(next_time): return {"ok":false,"error":"clock_overflow"}
	_time_s=next_time; _clock_revision=receipt.clock_revision
	return {"ok":true,"time_s":_time_s,"clock_revision":_clock_revision}

## Receipt fields: authority, vehicle_id, life_generation, clock_revision,
## contact_sequence, status:{disposed,destroying,wrecked}, point_native_m,
## normal_native, center_native_m, impact_speed_mps, slide_speed_mps.
## center is the host's car.localToWorld(0,.75,0), same contact-time pose.
## A successful begin creates a one-use ticket but does NOT consume cooldown:
## source assigns lastCrash only AFTER its geometry raycast completes.
func begin_contact(receipt: Dictionary) -> Dictionary:
	if not _identity(receipt): return {"ok":false,"admitted":false,"error":"authority_or_lifetime"}
	if not _pending.is_empty(): return {"ok":false,"admitted":false,"error":"raycast_pending"}
	if receipt.get("clock_revision")!=_clock_revision or not receipt.get("contact_sequence") is int or receipt.contact_sequence<=_last_contact_sequence:
		return {"ok":false,"admitted":false,"error":"contact_order"}
	var status: Variant=receipt.get("status")
	if not status is Dictionary or not status.get("disposed") is bool or not status.get("destroying") is bool or not status.get("wrecked") is bool:
		return {"ok":false,"admitted":false,"error":"status_receipt"}
	# Source checks lifetime, cooldown and terminal state before payload admission.
	if status.disposed or status.destroying or status.wrecked:
		return {"ok":true,"admitted":false,"reason":"terminal"}
	if _time_s-_last_crash_s<COOLDOWN_S:
		return {"ok":true,"admitted":false,"reason":"cooldown","remaining_s":COOLDOWN_S-(_time_s-_last_crash_s)}
	var point: Variant=receipt.get("point_native_m")
	var normal: Variant=receipt.get("normal_native")
	var center: Variant=receipt.get("center_native_m")
	if not point is Vector3 or not normal is Vector3 or not center is Vector3 or not point.is_finite() or not normal.is_finite() or not center.is_finite():
		return {"ok":false,"admitted":false,"error":"contact_geometry"}
	var impact:=_source_speed(receipt.get("impact_speed_mps"))
	var slide:=_source_speed(receipt.get("slide_speed_mps"))
	if not impact.ok or not slide.ok: return {"ok":false,"admitted":false,"error":"contact_speed"}
	var unit: Vector3=normal
	if unit.length_squared()<NORMAL_MIN_LENGTH_SQUARED: return {"ok":false,"admitted":false,"error":"zero_normal"}
	unit=unit.normalized()
	var damage: int=crash_damage(impact.value)
	if damage==0 and slide.value<SLIDE_SCRAPE_MPS:
		return {"ok":true,"admitted":false,"reason":"below_damage_and_scrape"}
	if unit.dot(point-center)<0.0: unit=-unit
	var ticket:=RefCounted.new()
	_pending={"ticket":ticket,"clock_revision":_clock_revision,"contact_sequence":receipt.contact_sequence,"time_s":_time_s,"damage":damage,"normal":unit,"impact_speed_mps":impact.value,"slide_speed_mps":slide.value}
	return {"ok":true,"prepared":true,"ticket":ticket,"damage":damage,"normalized_outward_native":unit,"raycast_pending":true}

## Call after the authoritative panel raycast has completed, before
## crash.contactImpact/trunk.contactImpact/dent/mark. A missing hit still
## consumes cooldown for an admitted zero-damage scrape.
func finish_raycast(receipt: Dictionary) -> Dictionary:
	if not _identity(receipt) or _pending.is_empty(): return {"ok":false,"error":"authority_or_pending"}
	if receipt.get("ticket")!=_pending.ticket or receipt.get("clock_revision")!=_pending.clock_revision or receipt.get("contact_sequence")!=_pending.contact_sequence or receipt.get("raycast_complete")!=true or not receipt.get("hit") is bool or _time_s!=_pending.time_s:
		return {"ok":false,"error":"raycast_receipt"}
	var plan: Dictionary=_pending
	_pending={}
	_last_crash_s=_time_s; _last_contact_sequence=plan.contact_sequence
	return {"ok":true,"admitted":true,"cooldown_consumed":true,"damage":plan.damage,"time_s":_time_s,"normalized_outward_native":plan.normal,"impact_speed_mps":plan.impact_speed_mps,"slide_speed_mps":plan.slide_speed_mps,"source_return":plan.damage>0 or receipt.hit,"hit":receipt.hit,"callbacks_pending":true}

## If the host raycast aborts before source's lastCrash assignment, release its
## ticket without consuming cooldown; a new host contact sequence may retry.
func cancel_pending(ticket: RefCounted) -> bool:
	if _pending.is_empty() or _pending.ticket!=ticket: return false
	_pending={}
	return true

static func crash_damage(impact_mps: float) -> int:
	if not is_finite(impact_mps) or impact_mps<=0.0: return 0
	return mini(80,int(floor(pow(impact_mps/4.1,2.0)*1.4+0.5)))

func stats() -> Dictionary:
	return {"time_s":_time_s,"last_crash_s":_last_crash_s,"clock_revision":_clock_revision,"last_contact_sequence":_last_contact_sequence,"raycast_pending":not _pending.is_empty(),"disposed":_disposed}

func dispose() -> void:
	_authority=null; _pending={}; _disposed=true

func _identity(receipt: Dictionary) -> bool:
	return not _disposed and _authority!=null and receipt.get("authority")==_authority and receipt.get("vehicle_id")==_vehicle_id and receipt.get("life_generation")==_generation

static func _number(value: Variant) -> bool:
	return (value is float or value is int) and is_finite(float(value))

static func _source_speed(value: Variant) -> Dictionary:
	# The trusted native host must supply finite numeric payloads. Source JS
	# Number(x)||0 also accepts strings/booleans; that coercion is deliberately
	# outside this native authority boundary.
	if value==null: return {"ok":true,"value":0.0}
	if not _number(value): return {"ok":false}
	return {"ok":true,"value":maxf(0.0,float(value))}
