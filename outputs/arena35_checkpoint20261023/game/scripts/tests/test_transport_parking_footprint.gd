extends SceneTree

const Catalog = preload("res://scripts/transport/transport_descriptor_catalog.gd")
const Footprint = preload("res://scripts/transport/transport_parking_footprint.gd")
const ORACLE = "res://data/transport/parking_footprint_oracle.v1.json"
var checks := 0
var failures: Array[String] = []

func check(ok: bool, label: String) -> void:
	checks += 1
	if not ok: failures.append(label)

func _initialize() -> void:
	var data: Variant = JSON.parse_string(FileAccess.get_file_as_string(ORACLE))
	check(data is Dictionary and data.get("schema") == "mafiozi.transport.parking-footprint-oracle.v1", "executed source oracle loads")
	var catalog := Catalog.new()
	check(catalog.load_file(), "source descriptor catalog loads")
	var provider := Footprint.new()
	var slots_ok := true
	for source_slot in data.slots:
		var bay: Dictionary = catalog.parking_bay(source_slot.id)
		var native_slot: Dictionary = provider.source_slot_from_bay(bay)
		if native_slot.is_empty() or native_slot.id != source_slot.id or native_slot.lotId != source_slot.lotId or absf(float(native_slot.r) - float(source_slot.r)) > .00000001 or absf(float(native_slot.c) - float(source_slot.c)) > .00000001 or absf(wrapf(float(native_slot.angle) - float(source_slot.angle), -PI, PI)) > .00000001 or absf(float(native_slot.widthM) - float(source_slot.widthM)) > .00000001 or absf(float(native_slot.lengthM) - float(source_slot.lengthM)) > .00000001:
			slots_ok = false; break
	check(slots_ok and data.slots.size() == 59, "all 59 source parking bay IDs, origins, angles and dimensions match Godot catalog")
	var overlaps_ok := true
	var overlap_count := 0
	for row in data.boxes:
		var actual: Dictionary = provider.source_boxes_overlap(row.a, row.b)
		if actual.code != "OK" or actual.overlap != row.overlap:
			overlaps_ok = false; break
		if actual.overlap: overlap_count += 1
	check(overlaps_ok and data.boxes.size() == 1024 and overlap_count == 420, "1024 executed Walk source oriented-box overlap results match")
	var fits_ok := true
	var fitting := 0
	for row in data.fits:
		var slot: Dictionary = provider.source_slot_from_bay(catalog.parking_bay(row.slotId))
		var actual: bool = provider.source_bay_fits(float(row.halfLength), float(row.halfWidth), slot)
		if actual != row.fits:
			fits_ok = false; break
		if actual: fitting += 1
	check(fits_ok and data.fits.size() == 1024 and fitting == 284, "1024 source 8.2-factor bay fit cases match")
	check(provider.source_boxes_overlap({"r": NAN}, {}).code == "INVALID" and provider.source_boxes_overlap({"r": NAN}, {}).overlap, "invalid box conservatively blocks overlap admission")
	check(not provider.source_bay_fits(NAN, .2, data.slots[0]) and provider.source_slot_from_bay({}).is_empty(), "invalid dimensions and bay fail closed")
	var first: Dictionary = data.boxes[0]
	var started := Time.get_ticks_usec()
	for i in 10000:
		provider.source_boxes_overlap(first.a, first.b)
	var query_10000_us := Time.get_ticks_usec() - started
	print("TRANSPORT_PARKING_FOOTPRINT ", JSON.stringify({"checks": checks, "failures": failures, "passed": failures.is_empty(), "query_10000_us": query_10000_us, "scope": "source geometry prefilter only; navigation and live occupancy remain host-owned"}))
	quit(0 if failures.is_empty() else 1)
