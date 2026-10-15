extends RefCounted
## Native WALK attack-state slice of world.html. This does not own target HP,
## authenticated permissions, contact geometry or the final damage transaction.
const PORTS := {"state":0,"clock_ms":0,"rng":0,"effect":1,"resolve_contact":2}
const BOOL_STATE := ["walk_active","armed","chat_open","menu_open","dead","arresting","driving","jetski","swimming_deep","in_bus","ws_open"]
const NUMBER_STATE := ["stunned","player_r","player_c","player_angle"]
const DURATION := {"punch":.34,"kick":.62,"heavy":.50,"dropkick":1.25}
const WINDOW := {"punch":[35,190],"kick":[180,340],"heavy":[70,360],"dropkick":[160,380]}
## Native host-service bound, not a new source expiration rule. Correct hosts
## service advance() every frame. Keep unserviced callbacks intact on refusal.
const MAX_PENDING_TIMERS := 8
var _ports:Dictionary={}
var _owner:WeakRef
var _configured:=false
var _busy:=false
var _fault:=""
var _state:Dictionary={}
var _now:=0.0
var _last_clock:=0.0
var _calls:=0
var _begin_context:=false
var _last_punch:=0.0
var _attack_seq:=0
var _hand:=1
var _kick:=1
var _block:=false
var _block_seq:=0
var _charge_at:=0.0
var _charge_seq:=0
var _animation:Dictionary={}
var _pending:Dictionary={}
var _timers:Array[Dictionary]=[]

static func _finite(v:Variant)->bool:return (v is float or v is int) and is_finite(float(v))
static func _truthy(v:Variant)->bool:
	if v==null:return false
	if v is bool:return v
	if v is float or v is int:return v!=0 and not is_nan(float(v))
	if v is String:return not v.is_empty()
	return true
func configure(ports:Dictionary)->Dictionary:
	if _configured or _busy or not Thread.is_main_thread():return {"ok":false,"error":"configuration"}
	var owner:Object=null
	for key:String in PORTS:
		var callback:Variant=ports.get(key)
		if not callback is Callable or not callback.is_valid() or callback.get_argument_count()!=PORTS[key]:return {"ok":false,"error":"port:"+key}
		var current:Object=callback.get_object()
		if not is_instance_valid(current) or current==self or current is Node and current.is_queued_for_deletion():return {"ok":false,"error":"owner"}
		if owner!=null and owner!=current:return {"ok":false,"error":"mixed_owners"}
		owner=current
	_owner=weakref(owner);_ports=ports.duplicate();_configured=true
	return {"ok":true}
func _live()->bool:
	if _owner==null or not is_instance_valid(_owner.get_ref()):return false
	var owner:Object=_owner.get_ref()
	if owner is Node and owner.is_queued_for_deletion():return false
	for key:String in PORTS:
		if not (_ports[key] as Callable).is_valid() or (_ports[key] as Callable).get_object()!=owner:return false
	return true
func _call(key:String,args:Array=[])->Variant:
	if not _fault.is_empty():return null
	if not _live():_fault="owner_lifetime";return null
	_calls+=1
	var reply:Variant=(_ports[key] as Callable).callv(args)
	if not _live():_fault="owner_lifetime"
	return reply
func _enter()->bool:
	if _busy:_fault="reentry";return false
	if not _configured or not _fault.is_empty() or not Thread.is_main_thread():return false
	_busy=true;_calls=0
	var state:Variant=_call("state")
	if not state is Dictionary:_fault="state_ack";_busy=false;return false
	for key:String in BOOL_STATE:
		if not state.get(key) is bool:_fault="state:"+key
	for key:String in NUMBER_STATE:
		if not _finite(state.get(key)):_fault="state:"+key
	for key:String in ["mode","stance"]:
		if not state.get(key) is String:_fault="state:"+key
	if not _fault.is_empty():_busy=false;return false
	_state=state.duplicate()
	var time:Variant=_call("clock_ms")
	if not _fault.is_empty():_busy=false;return false
	if not _finite(time) or float(time)<_last_clock:_fault="clock";_busy=false;return false
	_now=float(time);_last_clock=_now
	return true
func _error()->Dictionary:return {"accepted":false,"valid":false,"error":_fault if not _fault.is_empty() else "unavailable","may_have_dispatched":_calls>0}
func _finish(reply:Dictionary)->Dictionary:
	var result:Dictionary=reply if _fault.is_empty() else _error()
	_busy=false;_begin_context=false
	return result
func _effect(event:Dictionary)->bool:
	var reply:Variant=_call("effect",[event.duplicate(true)])
	if not reply is Dictionary or reply.get("ok")!=true:
		if _fault.is_empty():_fault="effect_ack:"+str(event.get("kind"))
	return _fault.is_empty()
func _tag(field:String,value:String)->bool:return _effect({"kind":"telemetry","field":field,"value":value})
func _locked()->bool:
	return _state.dead or _state.stunned>0 or _state.stance=="prone" or _state.arresting or _state.driving or _state.jetski or _state.swimming_deep or _state.in_bus
func _set_block(active:bool)->bool:
	var next:bool=active and not _state.armed and not _locked()
	if next==_block:return next
	_block=next
	if not _tag("meleeBlock","held:90-percent-melee-reduction" if next else "released"):return false
	if _state.ws_open:
		_block_seq+=1
		if not _effect({"kind":"packet","type":"melee_block","data":{"active":next,"seq":_block_seq}}):return false
	return next
func _set_charge(active:bool)->bool:
	var next:bool=active and not _state.armed and not _locked() and not _block
	if next and _charge_at==0:_charge_at=_now
	if not next:_charge_at=0
	if not _tag("meleeCharge","charging:1200ms" if next else "released"):return false
	if _state.ws_open:
		_charge_seq+=1
		if not _effect({"kind":"packet","type":"melee_charge","data":{"active":next,"seq":_charge_seq}}):return false
	return next

# Names match melee_input.gd's exact bridge ports. A bool false is ordinary
# refusal; null means an acknowledged host fault, stopping that input adapter.
func setWalkMeleeBlock(active:Variant)->Variant:
	if not _enter():return null
	var result:=false
	if _state.walk_active:result=_set_block(_truthy(active) and not _state.chat_open and not _state.menu_open)
	var valid:=_fault.is_empty();_finish({})
	return result if valid else null
func setWalkMeleeCharge(active:Variant)->Variant:
	if not _enter():return null
	var result:=false
	if _state.walk_active and not (not _truthy(active) and _pending.get("chargeHeld",false) and not _state.armed and not _locked()):
		result=_set_charge(_truthy(active) and not _state.chat_open and not _state.menu_open)
	var valid:=_fault.is_empty();_finish({})
	return result if valid else null
func beginWalkMelee(request:Dictionary)->Dictionary:
	if not _enter():return _error()
	if not _state.walk_active or _begin_context or _state.armed or _state.chat_open or _state.menu_open or _block or not _finite(request.get("angle")):return _finish({"accepted":false,"reason":"locked"})
	if _truthy(request.get("heavy")) and not _truthy(request.get("airborne")) and (_charge_at==0 or _now-_charge_at<1200):return _finish({"accepted":false,"reason":"charge"})
	# Reserve the entire attack before heading, RNG, UI/network effects or any
	# source-state mutation. Ground heavy owns two callbacks, all others one.
	var timer_slots:=2 if _truthy(request.get("heavy")) and request.get("airborne")!=true else 1
	if _timers.size()+timer_slots>MAX_PENDING_TIMERS:return _finish({"accepted":false,"reason":"timer-backlog"})
	_begin_context=true
	var ctx:Dictionary={"melee":true,"airborne":request.get("airborne")==true,"at":_now,"confirmed":false,"contact":null,"ref":null}
	if not _punch(request,ctx):return _finish({"accepted":false,"reason":"admission"})
	var type:String=ctx.animation.type
	ctx.window=WINDOW[type].duplicate();ctx.shotId="walk-melee:"+str(ctx.animation.seq);ctx.weapon="fists"
	_animation.duration=float(DURATION[type])*1000;_animation.impactAt=float(ctx.at)+float(ctx.window[0]);_pending=ctx
	if _truthy(request.get("heavy")) and not ctx.airborne:
		ctx.chargeHeld=true;_charge_at=0
		_timers.append({"kind":"charge_release","at":_now+float(ctx.window[1])+80,"context":ctx})
	return _finish({"accepted":true,"seq":ctx.animation.seq,"type":type,"side":-1 if ctx.animation.hand=="left" else 1,"startAt":ctx.at,"duration":DURATION[type],"contactWindow":ctx.window.duplicate()})
func _punch(request:Dictionary,ctx:Dictionary)->bool:
	if _state.mode=="pve":
		if _tag("meleeInputDecision","rejected:pve-observer"):_effect({"kind":"toast","id":"pve_observer_melee","duration_ms":2600})
		return false
	if _locked():return false
	var heavy:bool=ctx.airborne or request.get("heavy")==true
	if heavy and not ctx.airborne and (_charge_at==0 or _now-_charge_at<1165):return false
	if _now-_last_punch<300:return false
	var angle:float=request.angle
	var target_r:float=_state.player_r+sin(angle)*1.7*.78
	var target_c:float=_state.player_c+cos(angle)*1.7*.78
	_last_punch=_now;angle=atan2(target_r-float(_state.player_r),target_c-float(_state.player_c))
	if not _effect({"kind":"heading","angle":angle}):return false
	var kick:=false
	if not heavy:
		var roll:Variant=_call("rng")
		if not _fault.is_empty():return false
		if not _finite(roll) or float(roll)<0 or float(roll)>=1:
			if _fault.is_empty():_fault="rng"
			return false
		kick=float(roll)<.20
	var damage:=18 if heavy else 21 if kick else 12
	var leg:=""
	if kick:_kick*=-1;leg="right" if _kick>0 else "left"
	_hand*=-1;_attack_seq+=1
	_animation={"seq":_attack_seq,"startAt":_now,"ang":angle,"type":"dropkick" if ctx.airborne else "heavy" if heavy else "kick" if kick else "punch","hand":leg if kick else "right" if _hand>0 else "left","leg":leg,"dmg":damage,"critical":kick,"heavy":heavy,"blockPiercing":heavy,"proneTarget":false,"hit":false,"impactAt":_now+(330 if heavy else 165 if kick else 175),"duration":650 if heavy else 470 if kick else 430}
	if not _tag("meleeInputDecision","accepted:"+str(_animation.type)):return false
	if not _tag("meleeAttack","%s:%s:%s:miss:%s"%[_attack_seq,_animation.type,_animation.hand,damage]):return false
	if not _effect({"kind":"camera_kick","angle":angle,"power":.6}):return false
	if not _effect({"kind":"cooldown","active":true,"duration_ms":300}):return false
	_timers.append({"kind":"cooldown_release","at":_now+300})
	if not _effect({"kind":"renew_locks"}):return false
	ctx.animation=_animation.duplicate(true)
	return true

func resolveWalkMelee(request:Dictionary)->Dictionary:
	if not _enter():return _error()
	var ctx:=_pending
	if not _state.walk_active or ctx.is_empty() or ctx.animation.seq!=request.get("seq"):return _finish({"accepted":false,"reason":"sequence"})
	var age:float=_now-float(ctx.at)
	if age<float(ctx.window[0]):return _finish({"accepted":false,"reason":"early"})
	_pending={}
	var result:=_resolve(ctx,request,age)
	if ctx.get("chargeHeld",false):
		ctx.chargeHeld=false
		# An effect callback fault forbids additional dispatch; it is not caught
		# and silently reported as a successful source transaction.
		if _fault.is_empty():_set_charge(false)
	return _finish(result)
func _resolve(ctx:Dictionary,request:Dictionary,age:float)->Dictionary:
	if age>float(ctx.window[1])+250 or _state.armed or _locked() or _state.chat_open or _state.menu_open:return {"accepted":false,"reason":"expired-or-locked"}
	if not _truthy(request.get("contact")):return {"accepted":true,"hit":false}
	var contact_age:Variant=request.get("contactAge",age)
	if contact_age==null:contact_age=age
	if not _finite(contact_age) or float(contact_age)<float(ctx.window[0]) or float(contact_age)>float(ctx.window[1]) or float(contact_age)>age:return {"accepted":false,"reason":"contact-time"}
	# Mandatory source owner executes the remaining world.html resolve body:
	# current ref/view, finite point+normal, ranges, exact collection dispatch,
	# local impact or real server send. It may explicitly reject unavailable.
	var envelope:=ctx.duplicate(true);envelope.age=age;envelope.contactAge=contact_age
	var reply:Variant=_call("resolve_contact",[envelope,request.duplicate(true)])
	if not reply is Dictionary or not reply.get("accepted") is bool:
		if _fault.is_empty():_fault="resolve_ack"
		return {}
	if reply.accepted:
		if not reply.get("hit") is bool:_fault="resolve_hit_ack";return {}
		if reply.get("hit") and reply.get("confirmed")!=true:_fault="resolve_confirmation";return {}
	elif not reply.get("reason") is String:_fault="resolve_rejection_ack";return {}
	return reply.duplicate(true)

func advance()->Dictionary:
	if not _enter():return _error()
	var remaining:Array[Dictionary]=[]
	for timer:Dictionary in _timers:
		if timer.at>_now:remaining.append(timer);continue
		if not _fault.is_empty():break
		if timer.kind=="cooldown_release":_effect({"kind":"cooldown","active":false,"duration_ms":300})
		elif timer.context.get("chargeHeld",false):timer.context.chargeHeld=false;_set_charge(false)
	_timers=remaining
	return _finish({"ok":true})
func reset(reason:String="neutral")->Dictionary:
	if not _enter():return _error()
	_block=false;_charge_at=0;_animation={};_pending={}
	if _tag("meleeBlock","released:reconnect" if reason=="reconnect-open" else "released:"+reason):_tag("meleeCharge","released:"+reason)
	# Source timers retain their captured context even after reset. Counters,
	# cadence and alternating hands are likewise not reset by this function.
	return _finish({"ok":true})
func snapshot()->Dictionary:
	return {"fault":_fault,"begin_context":_begin_context,"lastPunchClientT":_last_punch,"attackSeq":_attack_seq,"handSide":_hand,"kickSide":_kick,"block":_block,"blockSeq":_block_seq,"chargeStartedAt":_charge_at,"chargeSeq":_charge_seq,"animation":_animation.duplicate(true),"pending":_pending.duplicate(true),"timers":_timers.size()}
