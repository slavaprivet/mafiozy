extends "res://scripts/destruction/modular_buildings/modular_building_site.gd"
## Restaurant "pizza" — modular destructible box, ported from
## outputs/buildings4_restaurant_native_20261003 (profile template:business:pizza,
## 280 authored parts, 2 storeys, 18 rooms, 17 doors, no terrain cutout).
## production_accepted:false in the source package; this class only places it.

func _init() -> void:
	_recipe_path = "res://data/restaurant_pizza_catalog2.json"
