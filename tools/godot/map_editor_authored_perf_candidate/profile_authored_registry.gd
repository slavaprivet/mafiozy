extends "res://scripts/map_editor/object_registry.gd"
var counters := {"registerUsec":0,"bodyCollectUsec":0,"boundsCollectUsec":0,"bodyVisitedNodes":0,"boundsVisitedNodes":0}
var _body_depth := 0
var _bounds_depth := 0
func _collect_bodies(node: Node,result: Array,seen: Dictionary) -> void:
	var start := Time.get_ticks_usec() if _body_depth==0 else 0
	_body_depth += 1
	counters.bodyVisitedNodes += 1
	super._collect_bodies(node,result,seen)
	_body_depth -= 1
	if _body_depth==0: counters.bodyCollectUsec += Time.get_ticks_usec()-start
func _collect_bounds(node: Node,inverse: Transform3D,bounds: Array) -> void:
	var start := Time.get_ticks_usec() if _bounds_depth==0 else 0
	_bounds_depth += 1
	counters.boundsVisitedNodes += 1
	super._collect_bounds(node,inverse,bounds)
	_bounds_depth -= 1
	if _bounds_depth==0: counters.boundsCollectUsec += Time.get_ticks_usec()-start
func register_object(id: String,root: Node3D,record: Dictionary,dependencies: Array=[],editable: bool=true) -> Dictionary:
	var start := Time.get_ticks_usec()
	var result := super.register_object(id,root,record,dependencies,editable)
	counters.registerUsec += Time.get_ticks_usec()-start
	return result
