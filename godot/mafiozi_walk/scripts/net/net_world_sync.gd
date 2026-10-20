extends Node
## DSH_NET — игровая сторона сети: чужие игроки как настоящие тела и общая шина
## событий для остальных систем (разрушения, снаряды, транспорт, NPC).
##
## Этот узел создаёт `main.gd` один раз после появления локального игрока.
## Он НЕ владеет ни одной игровой системой: он только
##   1) публикует состояние своего игрока в `Net`,
##   2) держит по аватару на каждого чужого игрока и кормит их снапшотами,
##   3) логирует события, которые приходят по сети (задел для следующих этапов).
##
## Аватар — это тот же `WalkPreviewPlayer`, что и у локального игрока, но с
## `net_avatar = true`: без камеры, без чтения Input, позиция и поза берутся из
## сети. Именно поэтому чужая ходьба/бег/прыжок выглядят как у себя: поза
## процедурная и считается из скорости, а не гоняется по проводу.

const PlayerScript = preload("res://scripts/preview_player.gd")
const HudScript = preload("res://scripts/net/net_hud.gd")
const Protocol = preload("res://scripts/net/net_protocol.gd")

## Флаги состояния игрока в снапшоте.
const FLAG_GROUNDED := 1
const FLAG_SWIMMING := 2
const FLAG_MOUNTED := 4
const FLAG_CROUCH := 8
const FLAG_DEAD := 16

var world: Node3D = null
var local_player: CharacterBody3D = null
var avatar_root: Node3D = null
## peer id -> CharacterBody3D
var avatars: Dictionary = {}
## Сколько последних сетевых событий держим для отладки/тестов.
var event_log: Array[Dictionary] = []

var _hud: Node = null
var _publish_clock: float = 0.0
var _applied_frames: int = 0


func install(world_root: Node3D, player: CharacterBody3D) -> void:
	world = world_root
	local_player = player
	avatar_root = Node3D.new()
	avatar_root.name = "NetAvatars"
	world.add_child(avatar_root)
	Net.peer_joined.connect(_on_peer_joined)
	Net.peer_left.connect(_on_peer_left)
	Net.role_changed.connect(_on_role_changed)
	Net.event_received.connect(_on_event)
	if Net.online():
		_on_role_changed(Net.role)
	set_physics_process(true)
	print("DSH_NET_SYNC_INSTALLED role=", Net.status_line())


func avatar_for(id: int) -> CharacterBody3D:
	var body: Variant = avatars.get(id)
	return body as CharacterBody3D


func avatar_count() -> int:
	return avatars.size()


## Отправка игрового события. Если сеть выключена — тихо ничего не делает,
## поэтому вызывать можно из любого места без проверок (одиночная игра цела).
func send_event(kind: String, data: Dictionary = {}) -> void:
	Net.send_event(kind, data)


# ------------------------------------------------------------------ кадры

func _physics_process(_delta: float) -> void:
	if not Net.online() or not is_instance_valid(local_player):
		return
	Net.publish_state(_local_state())
	_sync_avatars()


func _local_state() -> Dictionary:
	var flags: int = 0
	if local_player.is_on_floor():
		flags |= FLAG_GROUNDED
	if bool(local_player.get("_swimming")):
		flags |= FLAG_SWIMMING
	if bool(local_player.get("_mount_mode")):
		flags |= FLAG_MOUNTED
	var heading: float = float(local_player.get("_heading"))
	var aim: float = float(local_player.get("_camera_yaw"))
	return {
		"p": local_player.global_position,
		"v": local_player.velocity,
		"y": heading,
		"a": aim,
		"f": flags,
		"n": Net.player_name,
	}


func _sync_avatars() -> void:
	var seen: Dictionary = {}
	for id: Variant in Net.states:
		var peer_id: int = int(id)
		if peer_id == Net.local_id:
			continue
		var state: Variant = Net.states[id]
		if not (state is Dictionary):
			continue
		seen[peer_id] = true
		var body: CharacterBody3D = avatar_for(peer_id)
		if body == null:
			body = _spawn_avatar(peer_id)
			if body == null:
				continue
		_apply_state(body, state)
	_applied_frames += 1
	# Игрок ушёл, а состояние осталось (потерянный BYE): убираем аватар.
	for id: Variant in avatars.keys():
		if not seen.has(int(id)) and not Net.players.has(int(id)):
			_remove_avatar(int(id))


func _spawn_avatar(peer_id: int) -> CharacterBody3D:
	if avatar_root == null or not is_instance_valid(local_player):
		return null
	var body: Node = PlayerScript.new()
	body.name = "NetAvatar_%d" % peer_id
	body.set("net_avatar", true)
	body.set("hero_scene_path", str(local_player.get("hero_scene_path")))
	body.set("model_target_height", float(local_player.get("model_target_height")))
	# Позицию ставим только после add_child: до входа в дерево global_position
	# читается как Transform3D() и в лог летит ошибка.
	avatar_root.add_child(body)
	body.global_position = local_player.global_position
	avatars[peer_id] = body
	print("DSH_NET_AVATAR_SPAWN id=", peer_id, " name=", Net.peer_name(peer_id),
		" total=", avatars.size())
	return body as CharacterBody3D


func _apply_state(body: CharacterBody3D, state: Dictionary) -> void:
	var position: Variant = state.get("p", Vector3.ZERO)
	if not (position is Vector3) or not (position as Vector3).is_finite():
		return
	var yaw: float = float(state.get("y", 0.0))
	var aim: float = float(state.get("a", yaw))
	var velocity: Variant = state.get("v", Vector3.ZERO)
	if not (velocity is Vector3):
		velocity = Vector3.ZERO
	var flags: int = int(state.get("f", 0))
	body.call("net_apply_state", position, yaw, aim, velocity, (flags & FLAG_GROUNDED) != 0)


func _remove_avatar(peer_id: int) -> void:
	var body: Variant = avatars.get(peer_id)
	avatars.erase(peer_id)
	if is_instance_valid(body):
		print("DSH_NET_AVATAR_REMOVE id=", peer_id)
		(body as Node).queue_free()


# ------------------------------------------------------------------ сигналы

func _on_peer_joined(id: int, info: Dictionary) -> void:
	print("DSH_NET_SYNC_PEER_JOINED id=", id, " name=", info.get("name", "player"),
		" players=", Net.players.size())


func _on_peer_left(id: int) -> void:
	_remove_avatar(id)


func _on_role_changed(role: int) -> void:
	print("DSH_NET_SYNC_ROLE role=", Net.status_line())
	_ensure_hud(Net.online())


func _ensure_hud(wanted: bool) -> void:
	if wanted and _hud == null:
		_hud = HudScript.new()
		_hud.name = "NetHud"
		add_child(_hud)
	elif not wanted and _hud != null:
		_hud.queue_free()
		_hud = null


func _on_event(kind: String, data: Dictionary, from_id: int) -> void:
	event_log.append({"k": kind, "f": from_id, "t": Time.get_ticks_msec()})
	if event_log.size() > 64:
		event_log.pop_front()
	# Следующие этапы подключаются здесь: разрушения, снаряды, бросок, транспорт.
	# Пока печатаем, чтобы тест и лог подтверждали, что шина живая.
	match kind:
		Protocol.EV_DESTRUCTION, Protocol.EV_PROJECTILE, Protocol.EV_THROW, Protocol.EV_MELEE:
			print("DSH_NET_EVENT kind=", kind, " from=", from_id, " data=", data)
