extends RefCounted
## User-requested physical tuning, NOT source ballistic momentum or authority.
## Caller must already own a current accepted native hit and applied HP result.
const Rules=preload("res://scripts/weapons/weapon_hit_rules.gd")
const NEAR_NS={"pistol":55.0,"pistol_gold":65.0,"pistol_heavy":100.0,"revolver":110.0,"nagan":90.0,"smg":45.0,"tommy_gun":60.0,"rifle":95.0,"sniper":135.0,"shotgun":225.0}
static func bullet(weapon: String,distance_m: float,damage: float,direction: Vector3,invulnerable: bool=false) -> Dictionary:
	var key:=Rules.balance_id(weapon)
	if invulnerable or not NEAR_NS.has(key) or not is_finite(distance_m) or distance_m<0 or distance_m>float(Rules.damage_profile(key).range)*4.1+.205 or not is_finite(damage) or damage<=0 or not direction.is_finite() or direction.length_squared()<.000001:return {"ok":false,"impulse_ns":Vector3.ZERO}
	var radial:=Vector3(direction.x,0,direction.z)
	if radial.length_squared()<.000001:return {"ok":false,"impulse_ns":Vector3.ZERO}
	# Strongest within 1.5 native metres, taper to 25% by 12m. Actual admitted
	# pellet damage scales partial hits; critical cannot exceed the tested peak.
	var distance_scale:=lerpf(1.0,.25,clampf((distance_m-1.5)/10.5,0,1))
	var hit_scale:=clampf(damage/float(Rules.damage_profile(key).dmg),.18,1.0)
	return {"ok":true,"impulse_ns":radial.normalized()*float(NEAR_NS[key])*distance_scale*hit_scale,"scope":"user_requested_physical_tuning","source_exact":false}
static func blast(distance_from_blast_m: float,direction: Vector3,invulnerable: bool=false) -> Dictionary:
	if invulnerable or not is_finite(distance_from_blast_m) or distance_from_blast_m<0 or distance_from_blast_m>11.07 or not direction.is_finite():return {"ok":false,"impulse_ns":Vector3.ZERO}
	var radial:=Vector3(direction.x,0,direction.z)
	if radial.length_squared()<.000001:radial=Vector3.RIGHT
	# Upward .3 variant failed NPC169 getup; keep the tested horizontal impulse.
	return {"ok":true,"impulse_ns":radial.normalized()*450.0*(1.0-.72*distance_from_blast_m/11.07),"scope":"user_requested_blast_tuning_separate_native_RPG_gate_required","source_exact":false}
