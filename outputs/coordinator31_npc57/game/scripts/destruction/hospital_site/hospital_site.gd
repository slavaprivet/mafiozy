extends "res://scripts/destruction/modular_buildings/modular_building_site.gd"
## Hospital structural01 — modular destructible box, ported from
## outputs/buildings4_hospital_native_20261003 (profile modular:REBUILD-VISUAL-hospital-001,
## 403 authored parts, 2 storeys, 26 rooms, 25 doors, no terrain cutout).
## production_accepted:false in the source package; this class only places it.

func _init() -> void:
	_recipe_path = "res://data/hospital_catalog2.json"
