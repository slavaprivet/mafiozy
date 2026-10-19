extends "res://test_full_registry.gd"
## Actual full source factories/registries inherited from the validated assembly.
## No SyntheticSourceIndex and no mutated source catalog or forged admissions.
const CatalogUI = preload("res://scripts/map_editor/catalog_ui.gd")
func run() -> void:
	catalog = JSON.parse_string(FileAccess.get_file_as_string("res://data/catalog.json"))
	assets = authored_factory_class().new()
	check(assets.configure(catalog),"actual authored GLB source SHA admission")
	var session := make_session()
	if not session.ok:
		for error in failures: push_error(error)
		quit(1); return
	var ui := CatalogUI.build(catalog,session.composite)
	check(ui.ok,"actual CatalogUI built")
	if not ui.ok:
		dispose_extras(session); session.world.free(); quit(1); return
	var doc_ids := {}
	for record: Dictionary in session.controller.document.to_dictionary().objects: doc_ids[record.id]=true
	check(doc_ids.size()==9901,"actual full controller document 9901")
	check(ui.total==catalog.objects.size() and ui.items.size()==9901,"actual catalog all9901 represented")
	var source_by_key := {}
	for row: Dictionary in catalog.objects: source_by_key[row.key]=row
	var asset_by_id := {}
	for asset: Dictionary in catalog.assets: asset_by_id[asset.assetId]=asset
	var seen := {}
	var unmatched: Array = []
	var protected: Array = []
	var parking: Array = []
	var parking_counts := {}
	var mapped: Array = []
	var categories := {}
	var admitted := 0
	var availability_mismatches: Array = []
	var document_mismatches: Array = []
	var reason_mismatches: Array = []
	var start := Time.get_ticks_usec()
	for item: Dictionary in ui.items:
		var row: Dictionary = source_by_key[item.semantic_key]
		var present: bool = session.composite.has_object(item.id)
		var expected_available: bool = present and session.composite.is_editable(item.id)
		check(not seen.has(item.id),"unique resolved catalog ID "+item.id)
		seen[item.id]=true
		check(source_by_key.has(item.semantic_key),"source semantic key preserved "+item.semantic_key)
		check(item.available==expected_available,"real owner availability "+item.id)
		check(not str(item.label).strip_edges().is_empty() and item.label.length()<=300,"nonempty bounded label "+item.id)
		check(item.category in CatalogUI.CATEGORIES.values(),"Russian category recognized "+item.id)
		var asset: Dictionary = asset_by_id.get(row.get("assetId",""),{})
		var raw_label: Variant = row.get("label",asset.get("label"))
		var expected_label := "Объект "+str(row.id)
		if raw_label is String:
			var clean := ""
			for character: String in raw_label.left(300):
				if character.unicode_at(0)>31: clean+=character
			clean=clean.strip_edges()
			if not clean.is_empty(): expected_label=clean
		check(item.label==expected_label,"exact sanitized source label "+item.id)
		var category_key: String = str(row.get("category",asset.get("category","decor")))
		if row.dataset in ["buildings","detention"]: category_key="buildings"
		check(item.category==CatalogUI.CATEGORIES.get(category_key,"Городские объекты"),"source category mapping "+item.id)
		if item.available!=expected_available: availability_mismatches.append(item)
		if present and not doc_ids.has(item.id): document_mismatches.append(item)
		var reason_ok: bool = item.reason=="" if expected_available else not str(item.reason).strip_edges().is_empty()
		check(reason_ok,"availability/protected reason "+item.id)
		if not reason_ok: reason_mismatches.append(item)
		if not present: unmatched.append({"source_key":row.key,"source_id":row.id,"resolved_id":item.id,"reason":item.reason})
		if not expected_available and present: protected.append({"id":item.id,"category":item.category,"reason":item.reason})
		if expected_available: admitted+=1
		if item.id!=row.key: mapped.append({"source_key":row.key,"source_id":row.id,"resolved_id":item.id})
		if str(row.dataset).begins_with("parking"):
			parking.append({"source_key":row.key,"source_id":row.id,"resolved_id":item.id,"registry":present,"document":doc_ids.has(item.id),"available":item.available})
			parking_counts[row.dataset]=parking_counts.get(row.dataset,0)+1
		categories[item.category]=categories.get(item.category,0)+1
	check(ui.admitted==admitted,"UI admitted count equals real owners")
	check(availability_mismatches.is_empty() and document_mismatches.is_empty() and reason_mismatches.is_empty(),"actual owner/document/reason parity")
	var missing_registry_ui: Array = []
	for id: String in session.composite.ids():
		if not seen.has(id): missing_registry_ui.append(id)
	check(unmatched.is_empty(),"every catalog item resolves actual live owner")
	check(missing_registry_ui.is_empty(),"every actual owner ID represented in catalog")
	check(parking.size()==233 and protected.size()==38,"all233 parking items and38 protected objects retained")
	var elapsed := Time.get_ticks_usec()-start
	var report := {"suite":"actual-full-catalog-admission","checks":checks,"failures":failures,"catalog_items":ui.total,"registry_objects":session.composite.ids().size(),"document_objects":doc_ids.size(),"matched_items":ui.total-unmatched.size(),"admitted":admitted,"protected_present":protected.size(),"unmatched":unmatched,"registry_missing_ui":missing_registry_ui,"mapped_source_key_count":mapped.size(),"mapped_source_key_samples":mapped.slice(0,4),"parking_count":parking.size(),"parking_dataset_counts":parking_counts,"parking_samples":parking.slice(0,4),"protected":protected,"categories":categories,"availability_mismatches":availability_mismatches,"document_mismatches":document_mismatches,"reason_mismatches":reason_mismatches,"verification_cpu_usec":elapsed,"synthetic_index":false,"gpu":false,"production_wired":false,"owner_admissions":"test-only native geometry callbacks; real protected resources remain locked"}
	dispose_extras(session); session.world.free()
	for error in failures: push_error(error)
	print(JSON.stringify(report))
	quit(0 if failures.is_empty() else 1)
