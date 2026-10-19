extends RefCounted
## Exact local /walk damage calculator, never server authority.
## Host validates vehicle lifetime, event origin and cooldown before apply.
static func create(max_hp: float = 240, armor: float = 1) -> Dictionary:
	if not is_finite(max_hp) or max_hp < 120 or not is_finite(armor) or armor < 1: return {}
	return {"maxHp":max_hp,"hp":max_hp,"armor":armor,"smoking":false,"burning":false,"destroying":false,"wrecked":false,"destroyRemaining":0.0,"wreckAge":0.0,"explosions":0,"recentHits":[],"lastDamage":0.0}

static func apply(state: Dictionary, damage: float, event_id: Variant = null, kind: String = "gun") -> Dictionary:
	if state.is_empty() or not is_finite(damage) or damage <= 0 or state.destroying or state.wrecked or (event_id != null and state.recentHits.has(event_id)): return state
	var amount: float = state.hp if kind == "rpg" else clampf(floor(damage+.5),0,100) if kind == "collision" else maxf(4,floor(damage/float(state.armor)+.5))
	if amount == 0: return state
	var out := state.duplicate(true)
	out.hp=maxf(0,float(state.hp)-amount)
	var ratio: float=out.hp/float(state.maxHp)
	out.lastDamage=amount
	if event_id != null:
		out.recentHits.append(event_id)
		if out.recentHits.size()>64: out.recentHits.pop_front()
	out.smoking=state.smoking or ratio<=.55
	out.burning=state.burning or (out.hp!=0 and ratio<=.24)
	out.destroying=out.hp==0
	out.destroyRemaining=(0.0 if kind in ["collision","rpg"] else 1.55) if out.destroying else 0.0
	out.externalBlast=kind=="rpg"
	return out

## Actual source contact handler prevents mechanical failure becoming explosion.
static func collision(state: Dictionary, impact_mps: float) -> Dictionary:
	if not is_finite(impact_mps) or impact_mps<=0 or state.is_empty() or state.destroying or state.wrecked: return state
	var amount := minf(80,floor(pow(impact_mps/4.1,2)*1.4+.5))
	if amount == 0: return state
	var out := apply(state,amount,null,"collision")
	out.hp=maxf(1,float(out.hp))
	out.destroying=false
	out.destroyRemaining=0.0
	out.burning=state.burning
	return out

static func step(state: Dictionary, dt: float) -> Dictionary:
	# Native fail-closed equivalent of source's exception: keep the valid state.
	if state.is_empty() or not is_finite(dt) or dt<0: return state
	if state.wrecked:
		var out:=state.duplicate(true); out.wreckAge+=dt; return out
	if not state.destroying: return state
	var out:=state.duplicate(true)
	out.destroyRemaining=maxf(0,float(state.destroyRemaining)-dt)
	if out.destroyRemaining==0:
		out.destroying=false; out.wrecked=true
		out.wreckAge=maxf(0,dt-float(state.destroyRemaining))
		out.smoking=true; out.burning=true; out.explosions+=1
	return out
