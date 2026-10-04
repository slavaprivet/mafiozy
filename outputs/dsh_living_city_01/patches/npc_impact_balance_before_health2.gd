extends RefCounted
## Constant-memory presentation/physical reaction state. Owns no HP or death.
## Revision is the already consumed ordinary-hit adapter revision, never shot id.
const LIMIT := 3.2
const FALL_THRESHOLD := 1.85
const DECAY_PER_SECOND := .70
const QUIET_RECOVERY_SECONDS := 1.5
var load := 0.0
var revision := -1
var reaction_generation := 0
var quiet := QUIET_RECOVERY_SECONDS
var down := false
var final_dead := false
var medical_held := false

func accept(next_revision: int, impulse_ns: float, dead: bool, medical: bool, attack_type: String = "bullet") -> Dictionary:
	if next_revision <= revision or not is_finite(impulse_ns) or impulse_ns < 0.0 or impulse_ns > 300.0:
		return {"ok":false,"reason":"duplicate_or_invalid"}
	revision = next_revision
	reaction_generation += 1
	quiet = 0.0
	final_dead = final_dead or dead
	medical_held = medical
	if final_dead:
		return {"ok":true,"knockdown":false,"recoverable":false}
	if medical_held:
		down = true
		return {"ok":true,"knockdown":false,"recoverable":true,"medical_release_required":true}
	# Even the largest admitted single round cannot cross the fall threshold.
	# Rapid subsequent real contacts accumulate; quiet spacing restores balance.
	var contribution := clampf(impulse_ns / 95.0,.24,1.10)
	if attack_type in ["punch","kick"]: contribution = .85
	elif attack_type == "heavy": contribution = 1.05
	elif attack_type == "dropkick": contribution = 1.95
	load = minf(LIMIT,load + contribution)
	var begin: bool = not down and load >= FALL_THRESHOLD
	if begin: down = true
	return {"ok":true,"knockdown":begin,"recoverable":true,"load":load,"burst_scale":1.0 + .28 * clampf(load - 1.0,0.0,2.0)}

func step(delta: float) -> void:
	if not is_finite(delta) or delta <= 0.0 or delta > .05: return
	quiet = minf(60.0,quiet + delta)
	load = maxf(0.0,load - DECAY_PER_SECOND * delta)

# DSH_HEALTH: true when step(delta) provably cannot change any value that is ever
# read: load already sits on its floor (it can only decrease) and quiet has already
# crossed the only threshold allows_release() compares it against. down is part of
# the test so a downed/dead owner always keeps the exact existing cadence.
func settled() -> bool:
	return not down and load <= 0.0 and quiet >= QUIET_RECOVERY_SECONDS

func allows_release() -> bool:
	# Medical survivors are candidates under the explicit NEW local user rule.
	# This grants only a physical clearance attempt, never medical state mutation.
	return down and not final_dead and quiet >= QUIET_RECOVERY_SECONDS

func recovered() -> void:
	# Called only after native recovery commits the original standing capsule.
	if final_dead: return
	medical_held = false
	down = false
	load = 0.0
