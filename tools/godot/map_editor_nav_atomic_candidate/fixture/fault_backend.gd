extends "res://scripts/navigation/atomic_backend.gd"

var callback_effects := 0

func _start_bake() -> void:
	callback_effects += 1
	# This callback arrives while the first completion is being replayed.
	_finish_query(1001, 8, 0, NavigationPathQueryResult3D.new())
	# A foreign write during replay faults the lease after the side effect.
	request_path(null, Vector3.ZERO, Vector3.RIGHT, Callable())
