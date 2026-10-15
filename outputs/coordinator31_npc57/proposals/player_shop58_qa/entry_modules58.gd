extends "res://scripts/shop/tests/test_player_shop.gd"
func _initialize() -> void:
	_delayed58.call_deferred()
func _delayed58() -> void:
	await create_timer(3.0).timeout
	run()
