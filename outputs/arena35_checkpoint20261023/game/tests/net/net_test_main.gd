extends Node3D
## DSH_NET — тестовая сцена для проверки сети двумя процессами.
##
## Поднимает плоский пол, одного игрока и сетевой слой. Ни замка, ни NPC, ни
## оружия: проверяется ровно труба (подключение, состав, снапшоты, события),
## поэтому тест идёт секунды, а не минуты.
##
## Запуск (см. tests/net/net_pair_test.ps1):
##   godot --headless --path . res://tests/net/net_test.tscn -- \
##       --net-host --net-port=7821 --net-hold=8
##   godot --headless --path . res://tests/net/net_test.tscn -- \
##       --net-join=127.0.0.1:7821 --net-hold=8

const PlayerScript = preload("res://scripts/preview_player.gd")
const SyncScript = preload("res://scripts/net/net_world_sync.gd")

var player: CharacterBody3D = null
var sync: Node = null
var hold_seconds: float = 8.0
var move_speed: float = 2.4

var _elapsed: float = 0.0
var _reported: bool = false
var _events_sent: int = 0
var _events_seen: int = 0
var _test_event_sent: bool = false
var _ticks: int = 0


func _ready() -> void:
	for argument: String in OS.get_cmdline_user_args():
		if argument.begins_with("--net-hold="):
			hold_seconds = maxf(1.0, float(argument.substr("--net-hold=".length())))
		elif argument.begins_with("--net-move="):
			move_speed = maxf(0.0, float(argument.substr("--net-move=".length())))
	_build_floor()
	player = PlayerScript.new()
	player.name = "TestPlayer"
	player.position = Vector3(0.0, 1.1, 0.0)
	add_child(player)
	player.set_physics_process(false)
	sync = SyncScript.new()
	sync.name = "NetWorldSync"
	add_child(sync)
	sync.call("install", self, player)
	Net.event_received.connect(_on_event)
	Net.role_changed.connect(_on_role_changed)
	print("NET_TEST_READY role=", Net.status_line(), " hold=", hold_seconds,
		" move=", move_speed)
	_on_role_changed(Net.role)


func _build_floor() -> void:
	var floor_body := StaticBody3D.new()
	floor_body.name = "Floor"
	var collider := CollisionShape3D.new()
	var shape := BoxShape3D.new()
	shape.size = Vector3(60.0, 1.0, 60.0)
	collider.shape = shape
	collider.position.y = -0.5
	floor_body.add_child(collider)
	add_child(floor_body)
	var light := DirectionalLight3D.new()
	light.rotation_degrees = Vector3(-50.0, -35.0, 0.0)
	add_child(light)


func _physics_process(delta: float) -> void:
	_elapsed += delta
	_ticks += 1
	if is_instance_valid(player):
		var radius: float = 2.0
		player.global_position = Vector3(cos(_elapsed * 0.6) * radius, 1.1,
			sin(_elapsed * 0.6) * radius)
		player.velocity = Vector3(-sin(_elapsed * 0.6), 0.0, cos(_elapsed * 0.6)) * move_speed
	if not _test_event_sent and _elapsed > 1.5 and Net.online():
		_test_event_sent = true
		Net.send_event("chat", {"text": "ping-" + Net.role_name()})
		_events_sent += 1
	if _elapsed >= hold_seconds and not _reported:
		_reported = true
		_report()


func _report() -> void:
	var avatars: int = 0
	if sync != null and sync.has_method("avatar_count"):
		avatars = int(sync.call("avatar_count"))
	var events_seen: int = Net.events_received
	print("NET_TEST_SUMMARY role=", Net.role_name(),
		" id=", Net.local_id,
		" players=", Net.players.size(),
		" avatars=", avatars,
		" snapshots_in=", Net.snapshots_received,
		" snapshots_out=", Net.snapshots_sent,
		" events_in=", events_seen,
		" events_sent=", Net.events_sent,
		" err=", Net.last_error)
	get_tree().quit(0)


func _on_event(kind: String, data: Dictionary, from_id: int) -> void:
	_events_seen += 1
	print("NET_TEST_EVENT kind=", kind, " from=", from_id, " data=", data)


func _on_role_changed(role: int) -> void:
	print("NET_TEST_ROLE role=", Net.role_name(), " id=", Net.local_id)
