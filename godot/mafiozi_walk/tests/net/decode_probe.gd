extends SceneTree
## Зонд кадрирования: проверяет decode при срезанном первом байте, без среза и
## при лишнем байте. Запуск:
##   godot --headless --path . --script res://tests/net/decode_probe.gd

const Protocol = preload("res://scripts/net/net_protocol.gd")


func _initialize() -> void:
	var message := {"kind": "state", "v": 1, "s": {"p": Vector3(1, 2, 3), "n": "guest"}}
	var framed: PackedByteArray = Protocol.encode(message)
	print("PROBE framed=", framed.size(), " head=", framed.slice(0, 6).hex_encode())
	print("PROBE full   -> ", Protocol.decode(framed).get("kind", "FAIL"))
	print("PROBE minus1 -> ", Protocol.decode(framed.slice(1)).get("kind", "FAIL"))
	print("PROBE minus2 -> ", Protocol.decode(framed.slice(2)).get("kind", "FAIL"))
	var plain: PackedByteArray = var_to_bytes(message)
	print("PROBE plain  -> ", Protocol.decode(plain).get("kind", "FAIL"))
	var extra := PackedByteArray([7])
	extra.append_array(framed)
	print("PROBE plus1  -> ", Protocol.decode(extra).get("kind", "FAIL"))
	quit(0)
