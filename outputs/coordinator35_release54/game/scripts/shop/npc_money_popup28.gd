extends Label3D
## One two-second visual of an actual local-account debit. No simulated money.
var _elapsed := 0.0

static func clear(body: Node3D) -> void:
	if not is_instance_valid(body): return
	var old: Node = body.get_node_or_null("NpcMoneySpend28")
	if old != null:
		if old is Node3D: old.visible = false
		body.remove_child(old)
		if not old.is_queued_for_deletion(): old.queue_free()

static func show_debit(body: Node3D, receipt: Dictionary) -> void:
	if not is_instance_valid(body) or not body.is_inside_tree(): return
	var key: String = str(receipt.get("event_id", ""))
	var amount: int = int(receipt.get("amount", 0))
	if key.is_empty() or amount < 5 or amount > 50 or receipt.get("kind") not in ["local_shop_purchase28", "local_restaurant_purchase28"]: return
	if str(body.get_meta("npc_money28_last_event", "")) == key: return
	clear(body)
	body.set_meta("npc_money28_last_event", key)
	var popup := load("res://scripts/shop/npc_money_popup28.gd").new() as Label3D
	popup.name = "NpcMoneySpend28"
	popup.text = "−%d $" % amount
	popup.position = Vector3(.42, 2.50, 0)
	popup.pixel_size = .0045; popup.font_size = 56
	popup.billboard = BaseMaterial3D.BILLBOARD_ENABLED
	popup.no_depth_test = true; popup.double_sided = true
	popup.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
	popup.modulate = Color("ff5367"); popup.outline_modulate = Color.BLACK; popup.outline_size = 8
	popup.render_priority = 1
	body.add_child(popup)
	print("NPC_MONEY28 event=", key, " amount=", amount, " duration_s=2 frame=", Engine.get_physics_frames())

func _process(delta: float) -> void:
	_elapsed += delta
	position.y = 2.50 + .38 * smoothstep(0.0, 2.0, _elapsed)
	var alpha: float = 1.0 - smoothstep(1.15, 2.0, _elapsed)
	modulate.a = alpha
	outline_modulate.a = alpha
	if _elapsed >= 2.0: queue_free()
