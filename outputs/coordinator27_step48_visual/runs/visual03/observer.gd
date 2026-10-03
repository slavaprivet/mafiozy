extends Node
var sample: Callable
func _physics_process(_delta: float) -> void:
	if sample.is_valid(): sample.call()
