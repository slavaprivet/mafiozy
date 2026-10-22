extends SceneTree
const Damage=preload("res://scripts/transport/transport_vehicle_damage_state.gd")
func _initialize() -> void:
	var fixture: Dictionary=JSON.parse_string(FileAccess.get_file_as_string("res://data/transport/damage_state_oracle.json"))
	var checks:=0
	var failures: Array[String]=[]
	checks+=1
	if fixture.get("source_sha256")!="e029cb4a03dcd23bbdd0fb2f73b7780db92f24f761cf83b030991acb3c403f92": failures.append("source SHA mismatch")
	var hash:=HashingContext.new(); hash.start(HashingContext.HASH_SHA256); hash.update(FileAccess.get_file_as_bytes("res://data/transport/damage_state_oracle.json"))
	checks+=1
	if hash.finish().hex_encode()!="55ee489bae495b3815dfec11a14a6da943f00645a09805613219ab22cc88101f": failures.append("oracle byte SHA mismatch")
	for row: Dictionary in fixture.rows:
		var state:=Damage.create(row.maxHp,row.armor)
		var applied:=Damage.apply(state,row.damage,"actual-event",row.kind)
		for pair in [[state,row.initial],[applied,row.applied],[Damage.step(applied,row.dt),row.stepped],[Damage.apply(applied,row.damage,"actual-event",row.kind),row.duplicate]]:
			for key in pair[1]:
				checks+=1
				var actual: Variant=pair[0].get(key)
				var expected: Variant=pair[1][key]
				var same: bool=absf(float(actual)-float(expected))<1e-12 if (actual is float or actual is int) and (expected is float or expected is int) else actual==expected
				if not same: failures.append("oracle mismatch "+key+" "+str(row.kind))
	var state:=Damage.create()
	for i in range(70): state=Damage.apply(state,.1,str(i))
	checks+=1
	if state.recentHits.size()!=60: failures.append("terminal stops later events")
	state=Damage.create(10000)
	for i in range(70): state=Damage.apply(state,4,str(i))
	checks+=1
	if state.recentHits.size()!=64 or state.recentHits[0]!="6": failures.append("64 event ring")
	state=Damage.create()
	for i in range(100): state=Damage.collision(state,50)
	checks+=1
	if state.hp!=1 or state.destroying or state.wrecked or state.burning: failures.append("collision never fuel explosion")
	state=Damage.step(Damage.apply(Damage.create(),1,"blast","rpg"),0)
	for i in range(100): state=Damage.step(state,.1)
	checks+=1
	if state.explosions!=1 or not state.wrecked: failures.append("one explosion edge")
	for invalid in [NAN,INF,-1.0]:
		checks+=1
		if Damage.step(state,invalid)!=state: failures.append("invalid clock must retain valid state")
	state=Damage.create()
	var start:=Time.get_ticks_usec()
	for i in range(10000): Damage.step(state,.016)
	print("TRANSPORT_DAMAGE_STATE ",JSON.stringify({"checks":checks,"failures":failures,"passed":failures.is_empty(),"idle_10000_us":Time.get_ticks_usec()-start,"source_rows":fixture.rows.size(),"scope":"pure actual JS state oracle, no authority/rendering"}))
	quit(0 if failures.is_empty() else 1)

