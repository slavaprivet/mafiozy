extends "res://scripts/destruction/modular_buildings/modular_building_site.gd"
## Small bank — modular destructible box, ported from
## outputs/buildings4_bank_small_catalog2_20261003 (profile modular:REBUILD-bank:small,
## 422 authored parts, 2 storeys, 34 rooms, 31 interior doors, 47 glass panes).
##
## STATUS OF THE SOURCE: SOURCE_ONLY / CPU_SOURCE_GEOMETRY_PASS (560 checks).
## native_collision_and_support, 32-door, both stair routes and basement cutouts
## are NOT_RUN in the source package, and city_placement is
## BLOCKED_PENDING_FULL_REVALIDATION. This class therefore places the authored
## geometry and its external soil ring ONLY; it makes no claim about doors,
## stairs, basement access or destruction being accepted.
##
## The recipe carries one terrain_cutout ("basement_excavation"), so the shared
## instantiator builds the soil as a ring and this site stays in
## "awaiting_native_basement_clearance" until verify_terrain_clearance() proves
## the authored basement volume is really empty.

const BASEMENT_NOTE := "source_only_basement_cutout_requires_host_clearance"

func _init() -> void:
	_recipe_path = "res://data/small_bank_catalog2.json"

func basement_note() -> String:
	return BASEMENT_NOTE

## Convenience wrapper so a host can report the cutout without re-reading the
## recipe: returns the authored cutout rows exactly as the site computes them.
func terrain_cutouts() -> Array:
	if _node != null and is_instance_valid(_node) and _node.has_method("runtime_ground_cutout"):
		return _node.runtime_ground_cutout()
	return []
