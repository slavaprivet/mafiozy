extends RefCounted
const ORACLE_SHA="8643b11808f5834445e34be6d1c2930a9cc2f5a930042dfb7edfcf4ce6d78279"
const PART_IDS=["hood","trunk","door_front_left","door_front_right","door_rear_left","door_rear_right","bumper_front","bumper_rear","wheel_front_left","wheel_front_right","wheel_rear_left","wheel_rear_right"]
const RNG_SLOTS=["angle","strength","vertical_velocity","landing_yaw","spin_x","spin_y","spin_z"]
static func load_oracle(path: String="res://data/transport/damage_assemblies.json") -> Dictionary:
	var file:=FileAccess.open(path,FileAccess.READ)
	if file==null or file.get_length()>1048576: return {}
	var bytes:=file.get_buffer(file.get_length()); var hash:=HashingContext.new(); hash.start(HashingContext.HASH_SHA256); hash.update(bytes)
	if hash.finish().hex_encode()!=ORACLE_SHA: return {}
	var data: Variant=JSON.parse_string(bytes.get_string_from_utf8())
	if not data is Dictionary or data.get("schema")!="mafiozi.transport-damage-source-assemblies.v1" or not data.get("rows") is Array or data.rows.size()!=13: return {}
	return data
## Bind already-verified source oracle to the exact SHA-bound imported visual.
## Caller loads/verifies oracle bytes; this helper creates no entities/resources.
static func bind(visual: RefCounted, row: Dictionary) -> Dictionary:
	var canonical:=load_oracle()
	if canonical.is_empty(): return {"ok":false,"error":"oracle_receipt"}
	var matched:=false
	for original: Dictionary in canonical.rows:
		if original.get("profile_id")==row.get("profile_id"):
			matched=original==row; break
	if not matched: return {"ok":false,"error":"assembly_row_receipt"}
	if visual == null or not is_instance_valid(visual.get("root")): return {"ok":false,"error":"visual_missing"}
	var entry: Dictionary=visual.get("entry")
	var nodes: Dictionary=visual.get("nodes")
	if row.get("profile_id")!=visual.get("profile_id") or not row.get("native_visual") is Dictionary or row.native_visual.get("sha256")!=entry.get("sha256"):
		return {"ok":false,"error":"visual_identity"}
	if not row.get("explosion") is Array or not row.get("structural") is Array or row.explosion.size()>10 or row.structural.size()!=12:
		return {"ok":false,"error":"assembly_contract"}
	var structural: Dictionary={}
	var missing: Array=[]
	for part: Variant in row.structural:
		if not part is Dictionary or not part.get("id") is String or structural.has(part.id) or part.id not in PART_IDS: return {"ok":false,"error":"part_identity"}
		# An authored missing part remains absent; never manufacture replacement.
		if part.get("key")==null:
			structural[part.id]=null
			missing.append(part.id)
			continue
		var node: Node3D=nodes.get(part.key) as Node3D
		if node==null or node.get_meta("source_name","")!=part.get("source_name") or not (visual.get("root") as Node3D).is_ancestor_of(node):
			return {"ok":false,"error":"part_binding"}
		structural[part.id]=node
	var explosion: Array=[]
	var seen: Dictionary={}
	var draws:=0
	for part: Variant in row.explosion:
		if not part is Dictionary: return {"ok":false,"error":"explosion_row"}
		var index: Variant=part.get("source_index")
		if not (index is int or index is float) or index!=explosion.size() or not part.get("copy_eligible") is bool: return {"ok":false,"error":"explosion_index"}
		if part.get("rng_slots")!=RNG_SLOTS: return {"ok":false,"error":"rng_slots"}
		var expected_draws: Array=[]
		if part.copy_eligible:
			for slot in 7: draws+=1; expected_draws.append(draws)
		var actual_draws: Variant=part.get("rng_draw_indices")
		if not actual_draws is Array or actual_draws.size()!=expected_draws.size(): return {"ok":false,"error":"rng_indices"}
		for draw_index in expected_draws.size():
			var draw: Variant=actual_draws[draw_index]
			if not (draw is int or draw is float) or draw!=expected_draws[draw_index]: return {"ok":false,"error":"rng_indices"}
		var node: Node3D=nodes.get(part.get("key")) as Node3D
		if node==null or seen.has(node) or node.get_meta("source_name","")!=part.get("source_name") or not (visual.get("root") as Node3D).is_ancestor_of(node):
			return {"ok":false,"error":"explosion_binding"}
		seen[node]=true
		explosion.append({"source":node,"source_index":part.get("source_index"),"source_key":part.key,"copy_eligible_at_export":part.get("copy_eligible",false)})
	if row.get("missing_structural_ids")!=missing or row.get("explosion_rng_draw_count")!=draws: return {"ok":false,"error":"assembly_receipt"}
	var metadata: Variant=row.get("profile_source_metadata")
	if not metadata is Dictionary or not metadata.get("vehicleProfile") is Dictionary: return {"ok":false,"error":"crash_profile"}
	var profile: Dictionary=metadata.vehicleProfile
	if profile.get("id")!=row.get("profile_id"): return {"ok":false,"error":"crash_profile_identity"}
	var exact_profile: Dictionary={}
	for descriptor: Dictionary in entry.get("nodes",[]):
		var source_meta: Dictionary=descriptor.get("source_metadata",{})
		if source_meta.has("vehicleProfile"): exact_profile=source_meta.vehicleProfile
	if exact_profile!=profile or not row.get("input_glb") is Dictionary or row.input_glb.get("sha256")!=entry.get("source_glb_sha256"): return {"ok":false,"error":"crash_profile_receipt"}
	var expected_source: String="compact_sedan" if row.profile_id=="city_taxi" else row.profile_id
	if row.get("source_profile_id")!=expected_source: return {"ok":false,"error":"source_profile_receipt"}
	return {"ok":true,"explosion":explosion,"structural":structural,"crash_profile_source":profile.duplicate(true)}


