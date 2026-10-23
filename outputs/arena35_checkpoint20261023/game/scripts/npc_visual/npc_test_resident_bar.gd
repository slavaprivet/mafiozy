extends Label3D
## DSH_RESBAR: zhivaya podpis' nad golovoj podopytnogo - imya, HP i energiya.
## Zhivet na samom Label3D (u nego est' _process), poetomu ne trebuet nikakih
## pravok hosta i rabotaet dazhe kogda host ne imeet pokadrovogo shaga.
## Chitaet znacheniya iz zapisi zhizni hosta po source_id; chego net - pokazyvaet "-".

var _host: Object
var _id := ""
var _base := ""
var _t := 0.0
var _last := ""
var _dumped := false

func setup(host: Object, id: String, base_text: String) -> void:
	_host = host
	_id = id
	_base = base_text
	_last = ""

func _num(d: Dictionary, key: String, def_value: float) -> float:
	var v: Variant = d.get(key, null)
	if v is float or v is int: return float(v)
	return def_value

func _row() -> Dictionary:
	if _host == null or _id == "": return {}
	var records: Variant = _host.get("_records")
	if not (records is Dictionary) or not (records as Dictionary).has(_id): return {}
	var rec: Variant = (records as Dictionary)[_id]
	# The record layout is not ours to assume: look for the vitals on the record itself and one
	# level down (row / life / state), so the bar shows real numbers instead of "-".
	var dsh := _find_vitals(rec, 0)
	if not _dumped:
		_dumped = true
		print("DSH_RESBAR_DUMP id=", _id, " found_hp=", dsh.has("hp"), " found_max=", dsh.has("max_hp"), " found_energy=", dsh.has("energy"), " keys=", ",".join(PackedStringArray(dsh.keys().map(func(k): return str(k)))))
	return dsh

func _find_vitals(source: Variant, depth: int) -> Dictionary:
	var out: Dictionary = {}
	if source == null or depth > 2: return out
	if source is Dictionary:
		var d := source as Dictionary
		for key: String in ["hp", "max_hp", "energy"]:
			if d.has(key): out[key] = d[key]
		if out.has("hp"): return out
		for nested: String in ["row", "life", "state", "health"]:
			if d.has(nested):
				var inner := _find_vitals(d[nested], depth + 1)
				if not inner.is_empty(): return inner
		return out
	if source is Object:
		for key2: String in ["hp", "max_hp", "energy"]:
			var v: Variant = (source as Object).get(key2)
			if v is float or v is int: out[key2] = v
		if out.has("hp"): return out
		for nested2: String in ["row", "life", "state", "health"]:
			var t: Variant = (source as Object).get(nested2)
			if t != null:
				var inner2 := _find_vitals(t, depth + 1)
				if not inner2.is_empty(): return inner2
	return out

func _compose() -> String:
	var text := _base
	var row := _row()
	if row.is_empty():
		text += "\nHP -"
		return text
	var maximum := _num(row, "max_hp", 0.0)
	if maximum > 0.0:
		text += "\nHP %.0f%%" % clampf(_num(row, "hp", maximum) / maximum * 100.0, 0.0, 100.0)
	else:
		text += "\nHP -"
	var energy := _num(row, "energy", -1.0)
	if energy >= 0.0: text += "  EN %.0f%%" % clampf(energy, 0.0, 100.0)
	return text

func _process(delta: float) -> void:
	_t += delta
	if _t < 0.25: return
	_t = 0.0
	var value := _compose()
	if value == _last: return
	_last = value
	text = value
	print("DSH_RESBAR id=", _id, " text=\"", value.replace("\n", " | "), "\"")
