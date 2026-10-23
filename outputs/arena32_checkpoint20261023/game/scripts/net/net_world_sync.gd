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
## Сколько снапшотов подряд сервер считает нас в другом месте.
var _correction_streak: int = 0
# DSH_NET: клиент сообщает, что его замок построен; хост ждёт этого перед
# собственным выстрелом, иначе взрыв случится до готовности клиента и потеряется.
var _client_ready_sent := false
var _clients_ready := 0
## До какого момента (мс) публикуем поддельную позицию в тесте авторитета.
var _forge_until_ms: int = 0

## Самопроверка разрушений (tests/net/net_destruction_test.ps1):
## `--net-blast-at=СЕК` — через столько секунд клиент просит хост взорвать
## участок стены; `--net-castle-stats=СЕК` — как часто печатать счётчики кладки.
var _blast_after: float = -1.0
var _stats_every: float = 0.0
var _selftest_clock: float = 0.0
var _next_stats_at: float = 0.0
var _blast_sent: bool = false
## `--net-shot-at=СЕК` — через столько секунд выстрелить из корабельной пушки,
## чтобы вторая сторона подняла снаряд-дубль (tests/net/net_projectile_test.ps1).
var _shot_after: float = -1.0
var _shot_sent: bool = false
## `--net-melee-at=СЕК` — ударить мечом по кладке, чтобы проверить сетевой удар.
var _melee_after: float = -1.0
var _melee_sent: bool = false
## `--net-inject-at=СЕК` — отрицательный тест авторитета: клиент шлёт поддельное
## событие `destruction`, которого не имеет права отправлять. Хост обязан его
## отклонить и НЕ пересылать другим (tests/net/net_authority_test.ps1).
var _inject_after: float = -1.0
var _inject_sent: bool = false
## `--net-heartbeat=СЕК` — периодическая строка «я жив» с ролью и числом игроков.
## Тест по ней доказывает, что клиент остался в сети к концу прогона.
var _heartbeat_every: float = 0.0
var _next_heartbeat_at: float = 0.0
## `--net-gate-at=СЕК` — взрыв у ворот: проверяет перенос состояния створок.
var _gate_after: float = -1.0
var _gate_sent: bool = false
## `--net-catapult-at=СЕК` — выстрел из катапульты (камень-дубль у второй стороны).
var _catapult_after: float = -1.0
var _catapult_sent: bool = false
var _catapult_wait_logged: bool = false
## `--net-ship-at=СЕК` — хост открывает паруса; клиент проверяет получение
## трансформа корабля.
var _ship_after: float = -1.0
var _ship_sent: bool = false
var _ship_stats_every: float = 0.0
var _next_ship_stats_at: float = 0.0
## `--net-throw-at=СЕК` — бросок меча/копья (видимый дубль у второй стороны).
var _throw_after: float = -1.0
var _throw_sent: bool = false
## `--net-quit-at=СЕК` — корректно выйти по таймеру (чтобы stdout успел сброситься).
var _quit_after: float = -1.0
## `--net-teleport-at=СЕК` — клиент пытается телепортироваться на 500 м:
## проверка, что хост отклоняет скачок, а клиент возвращается на место.
var _teleport_after: float = -1.0
var _teleport_sent: bool = false
## `--net-player-stats=СЕК` — печатать свою позицию (для этого же теста).
var _player_stats_every: float = 0.0
var _next_player_stats_at: float = 0.0


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
	_read_test_args()
	if Net.online():
		_on_role_changed(Net.role)
	set_physics_process(true)
	print("DSH_NET_SYNC_INSTALLED role=", Net.status_line())


func _read_test_args() -> void:
	for argument: String in OS.get_cmdline_user_args():
		if argument.begins_with("--net-blast-at="):
			_blast_after = float(argument.substr("--net-blast-at=".length()))
		elif argument.begins_with("--net-castle-stats="):
			_stats_every = maxf(0.5, float(argument.substr("--net-castle-stats=".length())))
		elif argument.begins_with("--net-shot-at="):
			_shot_after = float(argument.substr("--net-shot-at=".length()))
		elif argument.begins_with("--net-melee-at="):
			_melee_after = float(argument.substr("--net-melee-at=".length()))
		elif argument.begins_with("--net-inject-at="):
			_inject_after = float(argument.substr("--net-inject-at=".length()))
		elif argument.begins_with("--net-heartbeat="):
			_heartbeat_every = maxf(0.5, float(argument.substr("--net-heartbeat=".length())))
		elif argument.begins_with("--net-gate-at="):
			_gate_after = float(argument.substr("--net-gate-at=".length()))
		elif argument.begins_with("--net-catapult-at="):
			_catapult_after = float(argument.substr("--net-catapult-at=".length()))
		elif argument.begins_with("--net-teleport-at="):
			_teleport_after = float(argument.substr("--net-teleport-at=".length()))
		elif argument.begins_with("--net-player-stats="):
			_player_stats_every = maxf(0.5, float(argument.substr("--net-player-stats=".length())))
		elif argument.begins_with("--net-ship-at="):
			_ship_after = float(argument.substr("--net-ship-at=".length()))
		elif argument.begins_with("--net-ship-stats="):
			_ship_stats_every = maxf(0.5, float(argument.substr("--net-ship-stats=".length())))
		elif argument.begins_with("--net-throw-at="):
			_throw_after = float(argument.substr("--net-throw-at=".length()))
		elif argument.begins_with("--net-quit-at="):
			_quit_after = float(argument.substr("--net-quit-at=".length()))


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

func _physics_process(delta: float) -> void:
	if not Net.online() or not is_instance_valid(local_player):
		return
	_selftest(delta)
	if Time.get_ticks_msec() < _forge_until_ms:
		# Тест авторитета: держим поддельную позицию несколько кадров, иначе она
		# живёт один кадр и до отправки по сети (20 Гц) не доживает.
		var forged: Dictionary = _local_state()
		forged["p"] = Vector3(500.0, 30.0, 500.0)
		Net.publish_state(forged)
	else:
		Net.publish_state(_local_state())
	_sync_avatars()
	if Net.is_client() and not _client_ready_sent and castle_node() != null:
		# `Net.online()` истинно уже на старте соединения, когда пира-хоста ещё
		# нет: первый `client_ready` уходил в пустоту, а флаг запрещал повтор, и
		# хост навсегда оставался с `_clients_ready = 0`. Ждём появления хоста
		# в составе, как это делает обычная отправка состояния.
		if Net.players.has(1):
			_client_ready_sent = true
			Net.send_event_to_host("client_ready", {})
			print("DSH_NET_CLIENT_READY")
	if Net.is_client():
		_apply_own_correction()


## Клиент ведёт своё тело сам, но если хост считает его позицию совсем другой
## (например, отклонил телепорт), принимаем серверную: иначе подделка остаётся
## без последствий. Порог 3 м — чтобы обычный лаг не дёргал игрока.
func _apply_own_correction() -> void:
	var state: Dictionary = Net.authoritative_self
	if state.is_empty():
		return
	var target: Variant = state.get("p")
	if not (target is Vector3) or not (target as Vector3).is_finite():
		return
	var aim: Vector3 = target
	if aim.length() < 1.0:
		return
	if local_player.global_position.distance_to(aim) <= 3.0:
		_correction_streak = 0
		return
	# Одна «старая» посылка снапшота не должна дёргать игрока: правим только если
	# расхождение держится несколько снапшотов подряд (это уже решение хоста).
	_correction_streak += 1
	if _correction_streak < 3:
		return
	_correction_streak = 0
	local_player.global_position = aim
	local_player.velocity = Vector3.ZERO
	print("NET_CORRECTION to=", aim)


# ------------------------------------------------------------------ самопроверка

## Тестовый сценарий разрушения: клиент просит хост взорвать стену, оба печатают
## счётчики кладки. Нужен, чтобы этап 3 проверялся без ручного участия.
func _selftest(delta: float) -> void:
	if _blast_after < 0.0 and _stats_every <= 0.0 and _shot_after < 0.0 \
			and _melee_after < 0.0 and _inject_after < 0.0 and _heartbeat_every <= 0.0 \
			and _gate_after < 0.0 and _catapult_after < 0.0 and _ship_after < 0.0 \
			and _ship_stats_every <= 0.0 and _teleport_after < 0.0 \
			and _player_stats_every <= 0.0 and _throw_after < 0.0 and _quit_after < 0.0:
		return
	_selftest_clock += delta
	# DSH_NET: корректный выход по таймеру. Нужен тестам: убитый процесс теряет
	# буферизованный stdout, и проверка «в логе пусто» врёт.
	if _quit_after >= 0.0 and _selftest_clock >= _quit_after:
		print("NET_QUIT role=", Net.role_name(), " t=", int(_selftest_clock))
		Net.leave("selftest_done")
		get_tree().quit(0)
		return
	if _heartbeat_every > 0.0 and _selftest_clock >= _next_heartbeat_at:
		_next_heartbeat_at = _selftest_clock + _heartbeat_every
		print("NET_HEARTBEAT role=", Net.role_name(), " t=", int(_selftest_clock),
			" players=", Net.players.size(), " rtt=", Net.rtt_ms)
	if _blast_after >= 0.0 and not _blast_sent and _selftest_clock >= _blast_after:
		_blast_sent = true
		_blast_wall()
	if _gate_after >= 0.0 and not _gate_sent and _selftest_clock >= _gate_after:
		_gate_sent = true
		_gate_test()
	# Раньше здесь был только таймер: хост стрелял, не зная, поднялась ли сцена у
	# гостя, и тест «камень-дубль» мог пройти на выстреле в пустоту. Теперь ждём
	# `client_ready`; если его нет — выстрела нет, и проверка честно падает.
	if _catapult_after >= 0.0 and not _catapult_sent and _selftest_clock >= _catapult_after:
		# Ждём готовности гостя только на хосте: у самого клиента счётчик всегда
		# нулевой, и общее условие гасило его собственный выстрел.
		if Net.is_host() and _clients_ready <= 0:
			if not _catapult_wait_logged:
				_catapult_wait_logged = true
				print("DSH_NET_CATAPULT waiting=client_ready")
		else:
			_catapult_sent = true
			_catapult_test()
	if _ship_after >= 0.0 and not _ship_sent and _selftest_clock >= _ship_after:
		_ship_sent = true
		_ship_test()
	if _ship_stats_every > 0.0 and _selftest_clock >= _next_ship_stats_at:
		_next_ship_stats_at = _selftest_clock + _ship_stats_every
		_ship_stats()
	if _teleport_after >= 0.0 and not _teleport_sent and _selftest_clock >= _teleport_after:
		_teleport_sent = true
		_teleport_test()
	if _throw_after >= 0.0 and not _throw_sent and _selftest_clock >= _throw_after:
		_throw_sent = true
		_throw_test()
	if _player_stats_every > 0.0 and _selftest_clock >= _next_player_stats_at:
		_next_player_stats_at = _selftest_clock + _player_stats_every
		_player_stats()
		_peer_stats()
	if _shot_after >= 0.0 and not _shot_sent and _selftest_clock >= _shot_after:
		_shot_sent = true
		_fire_test_shot()
	if _melee_after >= 0.0 and not _melee_sent and _selftest_clock >= _melee_after:
		_melee_sent = true
		_melee_test()
	if _inject_after >= 0.0 and not _inject_sent and _selftest_clock >= _inject_after:
		_inject_sent = true
		_inject_cheat_event()
	if _stats_every > 0.0 and _selftest_clock >= _next_stats_at:
		_next_stats_at = _selftest_clock + _stats_every
		_print_castle_stats()


func _blast_wall() -> void:
	var castle: Node = castle_node()
	if castle == null:
		print("NET_BLAST skipped=no_castle")
		return
	var half: float = float(castle.call("wall_half")) if castle.has_method("wall_half") else 68.0
	# Точка СБОКУ от ворот: по центру стены (x = 0) находится проём, там кирпичей
	# нет, и взрыв не выбивает ничего.
	var point: Vector3 = (castle as Node3D).to_global(Vector3(12.0, 5.0, half))
	var event: Dictionary = {"position": point, "radius": 3.0, "power": 120.0,
		"direction": Vector3(0.0, 0.4, -1.0), "kind": "net_test"}
	if Net.is_client():
		print("NET_BLAST request point=", point)
		Net.send_event_to_host("destruction_request", {"site": "castle", "e": event})
	else:
		print("NET_BLAST host point=", point, " result=", castle.call("apply_explosion", event))


## Выстрел из корабельной пушки для проверки снарядов-дублей. `debug_fire_at`
## сам наводит, заряжает и стреляет — участие игрока не нужно.
## Взрыв у ворот: доски створок считаются отдельно от кирпичей, поэтому их
## состояние хост присылает списком (gate_state / apply_gate_state).
func _gate_test() -> void:
	var castle: Node = castle_node()
	if castle == null:
		print("NET_GATE skipped=no_castle")
		return
	var half: float = float(castle.call("wall_half")) if castle.has_method("wall_half") else 68.0
	var point: Vector3 = (castle as Node3D).to_global(Vector3(0.0, 4.0, half + 2.75))
	# Целимся в настоящую доску створки: геометрия ворот зависит от сборки, и
	# «примерно в центр» давало ноль попаданий.
	var boards: Array = castle.call("gate_board_points")
	if not boards.is_empty():
		point = boards[0] as Vector3
		print("NET_GATE boards=", boards.size(), " aim=", point)
	var event: Dictionary = {"position": point, "radius": 2.0, "power": 90.0,
		"direction": Vector3(0.0, 0.0, -1.0), "kind": "net_gate_test"}
	if Net.is_client():
		print("NET_GATE request point=", point)
		Net.send_event_to_host("destruction_request", {"site": "castle", "e": event})
	else:
		castle.call("apply_explosion", event)
		print("NET_GATE host point=", point)


## Выстрел из катапульты: камень — RigidBody3D, поэтому вторая сторона ведёт
## кинематический дубль по событию запуска (проверка tests/net/net_catapult_test.ps1).
## Бросок меча/копья (проверка tests/net/net_throw_test.ps1). Работает в сцене,
## где установлен sword_prototype (город с --sword-proto=1).
func _throw_test() -> void:
	if world == null:
		return
	var sword: Variant = world.get("preview_sword_prototype")
	if sword == null or not (sword is Object) or not is_instance_valid(sword as Object):
		print("NET_THROW skipped=no_sword")
		return
	var result: Variant = sword.call("debug_throw")
	print("NET_THROW role=", Net.role_name(), " result=", result)


func _catapult_test() -> void:
	if world == null:
		return
	var catapult: Variant = world.get("preview_catapult")
	if catapult == null or not (catapult is Object) or not is_instance_valid(catapult as Object):
		print("NET_CATAPULT skipped=no_machine")
		return
	var result: Variant = catapult.call("debug_launch")
	print("NET_CATAPULT role=", Net.role_name(), " result=", result)


## Отрицательный тест авторитета движения: клиент публикует поддельную позицию
## в 500 м (так поступил бы модифицированный клиент). Хост обязан отклонить
## скачок и оставить прежнюю точку.
func _teleport_test() -> void:
	if not Net.is_client():
		print("NET_TELEPORT skipped=", Net.role_name())
		return
	var forged: Dictionary = _local_state()
	var forged_target := Vector3(500.0, 30.0, 500.0)
	forged["p"] = forged_target
	_forge_until_ms = Time.get_ticks_msec() + 900
	print("NET_TELEPORT forged=", forged_target, " real=", local_player.global_position)


func _player_stats() -> void:
	var position: Vector3 = local_player.global_position if is_instance_valid(local_player) else Vector3.ZERO
	print("NET_PLAYER t=", int(_selftest_clock), " role=", Net.role_name(), " pos=", position)


## Позиция, которую хост принял от удалённого игрока (для проверки отклонения).
func _peer_stats() -> void:
	if not Net.is_host():
		return
	for id: Variant in Net.states:
		if int(id) == Net.local_id:
			continue
		var state: Variant = Net.states[id]
		if not (state is Dictionary):
			continue
		print("NET_PEER_STATE id=", int(id), " pos=", (state as Dictionary).get("p", Vector3.ZERO))
		return


func _ship_node() -> Node3D:
	if world == null:
		return null
	var host: Variant = world.get("preview_ship")
	if host != null and host is Object and is_instance_valid(host as Object):
		var boat: Variant = (host as Object).get("preview_boat")
		if boat != null and boat is Object and is_instance_valid(boat as Object):
			return boat as Node3D
	# Хост корабля мог быть пересобран — ищем узел по имени.
	var found: Node = world.find_child("ShipBoat", true, false)
	return found as Node3D


## Хост сдвигает корабль: клиент обязан повторить трансформ из снапшота.
func _ship_test() -> void:
	var boat: Node3D = _ship_node()
	if boat == null:
		print("NET_SHIP skipped=no_boat")
		return
	var before: Vector3 = boat.global_position
	# Открываем паруса: корабль стоит на стоянке и сам возвращается туда, поэтому
	# телепорт симуляция отменяет. Паруса дают настоящее движение, которое и
	# должен повторить клиент.
	if boat.has_method("set_sails"):
		boat.call("set_sails", true)
	print("NET_SHIP start pos=", before, " sails=", boat.call("sails_open") if boat.has_method("sails_open") else "?")


func _ship_stats() -> void:
	var boat: Node3D = _ship_node()
	var position: Vector3 = boat.global_position if boat != null else Vector3.ZERO
	print("NET_SHIP t=", int(_selftest_clock), " role=", Net.role_name(), " pos=", position,
		" keys=", Net.world_states.keys(), " online=", Net.online(),
		" boat=", boat != null,
		" ship_host=", world.get("preview_ship") != null if world != null else false,
		" state_pos=", (Net.world_state("ship").get("p") if not Net.world_state("ship").is_empty() else "none"))


func _fire_test_shot() -> void:
	if world == null:
		return
	var ship: Variant = world.get("preview_ship")
	if ship == null or not (ship is Object) or not is_instance_valid(ship as Object):
		print("NET_SHOT skipped=no_ship")
		return
	var aim: Vector3 = Vector3.ZERO
	var castle: Node = castle_node()
	if castle != null:
		var half: float = float(castle.call("wall_half")) if castle.has_method("wall_half") else 68.0
		# Стреляем в БОКОВУЮ стену: она ближе корабельной стоянки и попадает в
		# дальность ядра. Разные z у хоста и гостя — чтобы траектории отличались и
		# сравнение «свой выстрел против дубля» было осмысленным.
		var z_offset: float = 12.0 if Net.is_host() else 40.0
		aim = (castle as Node3D).to_global(Vector3(half, 5.0, z_offset))
	else:
		aim = (ship as Node3D).global_position + Vector3(0.0, 0.0, -40.0)
	var result: Variant = ship.call("debug_fire_at", aim)
	print("NET_SHOT role=", Net.role_name(), " aim=", aim, " result=", result)


## Удар мечом по кладке: клиент бьёт "у себя", но настоящий урон считает хост и
## рассылает его. Проверяется равенством числа живых секций кладки с двух сторон.
func _melee_test() -> void:
	var castle: Node = castle_node()
	if castle == null:
		print("NET_MELEE skipped=no_castle")
		return
	var before: int = int(castle_stats().get("wall_collision_active", -1))
	var points: Array = castle.call("wall_section_points")
	if points.is_empty():
		print("NET_MELEE skipped=no_sections")
		return
	var key: Vector3 = points[0] as Vector3
	var collider: Node = castle.call("section_collider_at", key)
	if collider == null:
		print("NET_MELEE skipped=no_collider")
		return
	var impulse := Vector3(0.0, 0.3, -1.0)
	for hit: int in 3:
		castle.call("apply_melee_hit", collider, key, 8.0, impulse)
	var after: int = int(castle_stats().get("wall_collision_active", -1))
	print("NET_MELEE role=", Net.role_name(), " before=", before, " after=", after)


## Отрицательный тест авторитета: клиент шлёт `destruction` напрямую, как это
## сделал бы модифицированный клиент. Хост обязан отклонить событие и не
## пересылать его другим; у гостя не должно появиться ни одной новой пробоины.
func _inject_cheat_event() -> void:
	var castle: Node = castle_node()
	if castle == null:
		print("NET_INJECT skipped=no_castle")
		return
	var half: float = float(castle.call("wall_half")) if castle.has_method("wall_half") else 68.0
	var point: Vector3 = (castle as Node3D).to_global(Vector3(-12.0, 5.0, half))
	var event: Dictionary = {"position": point, "radius": 3.0, "power": 120.0,
		"direction": Vector3(0.0, 0.4, -1.0), "kind": "net_cheat"}
	Net.send_event("destruction", {"site": "castle", "e": event})
	print("NET_INJECT kind=destruction role=", Net.role_name(), " at=", point)


func _print_castle_stats() -> void:
	var stats: Dictionary = castle_stats()
	print("NET_CASTLE t=", int(_selftest_clock), " role=", Net.role_name(),
		" detached=", stats.get("detached", -1), " bricks=", stats.get("bricks", -1),
		" falling=", stats.get("falling", -1), " gates=", stats.get("gate_boards_broken", -1),
		" explosions=", stats.get("explosions", -1))


func castle_node() -> Node:
	if world == null:
		return null
	var castle: Variant = world.get("preview_castle")
	if castle == null or not (castle is Object) or not is_instance_valid(castle as Object):
		return null
	return castle as Node


func castle_stats() -> Dictionary:
	var castle: Node = castle_node()
	if castle == null or not castle.has_method("get_stats"):
		return {}
	return castle.call("get_stats")


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
	match kind:
		"client_ready":
			if Net.is_host():
				_clients_ready += 1
				print("DSH_NET_CLIENT_READY from=", from_id, " total=", _clients_ready)
		"destruction":
			# Хост уже применил удар у себя и разослал его. Клиент повторяет тот
			# же удар с флагом from_network, чтобы не отправить запрос по кругу.
			if Net.is_client():
				_apply_network_explosion(data, true)
		"destruction_request":
			# Запрос клиента: применяет хост, после чего рассылает результат.
			# `apply_explosion` сам разошлёт `destruction` (см. castle_site.gd).
			if Net.is_host():
				_apply_network_explosion(data, false)
		"melee_hit":
			if Net.is_client():
				_apply_network_melee_hit(data, true)
		"melee_hit_request":
			if Net.is_host():
				_apply_network_melee_hit(data, false)
		Protocol.EV_PROJECTILE, Protocol.EV_THROW, Protocol.EV_MELEE:
			print("DSH_NET_EVENT kind=", kind, " from=", from_id, " data=", data)


func _apply_network_explosion(data: Dictionary, as_replay: bool) -> void:
	var castle: Node = castle_node()
	if castle == null:
		return
	var payload: Variant = data.get("e", {})
	if not (payload is Dictionary):
		return
	var event: Dictionary = (payload as Dictionary).duplicate(true)
	# `from_network = true` — это повтор уже принятого решения: применить локально
	# и ничего не рассылать. Без флага вызов идёт по хостовой ветке и рассылает
	# результат всем.
	event["from_network"] = as_replay
	var result: Variant
	if as_replay and data.get("dead") is Array:
		# Хост прислал точный список выбитых кирпичей — бьём ровно их, без
		# локального пересчёта радиуса (иначе кладка расходится на проценты).
		result = castle.call("apply_dead_cells", data.get("dead"), event)
	else:
		result = castle.call("apply_explosion", event)
	# Створки ворот считаются отдельно от кирпичей — переносим их состояние.
	if as_replay and data.get("gate") is Array:
		castle.call("apply_gate_state", data.get("gate"))
	var detached: int = -1
	if result is Dictionary:
		detached = int((result as Dictionary).get("detached", -1))
	print("NET_DESTRUCTION_APPLIED site=", data.get("site", "?"), " replay=", as_replay,
		" detached=", detached)


## Удар мечом/кувалдой по кладке: секция адресуется мировой точкой, потому что
## Node-коллайдер по сети не передать.
func _apply_network_melee_hit(data: Dictionary, as_replay: bool) -> void:
	var castle: Node = castle_node()
	if castle == null:
		return
	var key: Variant = data.get("k")
	if not (key is Vector3):
		return
	var collider: Node = castle.call("section_collider_at", key)
	if collider == null:
		return
	var point: Variant = data.get("p", key)
	var impulse: Variant = data.get("i", Vector3.DOWN)
	if as_replay:
		collider.set_meta("net_replay", true)
	var result: Variant = castle.call("apply_melee_hit", collider, point,
		float(data.get("s", 6.0)), impulse)
	if as_replay and is_instance_valid(collider):
		collider.remove_meta("net_replay")
	print("NET_MELEE_APPLIED replay=", as_replay, " result=", result)
