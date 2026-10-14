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
	if rec is Dictionary: return (rec as Dictionary).get("row", {})
	if rec is Object:
		var r: Variant = (rec as Object).get("row")
		if r is Dictionary: return r
	return {}

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
