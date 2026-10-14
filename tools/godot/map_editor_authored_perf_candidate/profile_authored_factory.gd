extends "res://scripts/map_editor/catalog_factory.gd"
var counters := {"spawnUsec":0,"cachedSceneUsec":0,"helperHideUsec":0,"helperNodes":0,"cacheCalls":0}
var _helper_depth := 0
func reset_profile() -> void:
	for key in counters: counters[key]=0
func cached_scene(id: String) -> PackedScene:
	var start := Time.get_ticks_usec()
	var scene := super.cached_scene(id)
	counters.cachedSceneUsec += Time.get_ticks_usec()-start
	counters.cacheCalls += 1
	return scene
func spawn(object: Dictionary,options: Dictionary={}) -> Dictionary:
	var start := Time.get_ticks_usec()
	var result := super.spawn(object,options)
	counters.spawnUsec += Time.get_ticks_usec()-start
	return result
func _hide_helpers(node: Node,names: Array) -> void:
	var start := Time.get_ticks_usec() if _helper_depth==0 else 0
	_helper_depth += 1
	counters.helperNodes += 1
	super._hide_helpers(node,names)
	_helper_depth -= 1
	if _helper_depth==0: counters.helperHideUsec += Time.get_ticks_usec()-start
