extends Node
## DSH_NET — единственный владелец сетевого сокета в игре (автозагрузка `Net`).
##
## Роли:
##   * OFFLINE — обычная одиночная игра; ни одно сетевое поле не читается.
##   * HOST    — listen-server: сам играет и рассылает состояние всем клиентам.
##   * CLIENT  — подключается к хосту, публикует своё состояние, получает чужие.
##
## Почему ENet опрашивается напрямую (`poll()` + `get_packet()`), а не через
## `SceneTree.multiplayer`: `SceneMultiplayer` трактует первый байт пакета как
## служебную команду и срезает его, а часть пакетов уводит в свой RPC-разбор
## (`scene_replication_interface`). Проверено на живых сокетах: пакет 84 байта
## приходил 83-м. Прямой опрос `MultiplayerPeer` отдаёт ровно те байты, что ушли.
##
## Про идентификаторы: ENet выдаёт пирам произвольные 32-битные id (не 2, 3, 4),
## а сервер всегда 1. Поэтому игровой id = ENet id, хост — 1.
##
## Что здесь есть и чего здесь НЕТ (важно для следующего агента):
##   * ЕСТЬ транспорт, состав игроков, обмен состоянием (20 Гц), шина событий,
##     пинг, тайм-ауты.
##   * НЕТ игровой логики: этот файл не знает ни про замок, ни про мечи.
##   * Авторитет в v1 клиентский по КИНЕМАТИКЕ игрока, но серверный по СОБЫТИЯМ
##     (урон, разрушения, снаряды решает хост и рассылает результат). Осознанный
##     первый шаг: играбельный кооп за дни. Этап 8 в docs/ai/NETWORK_ONLINE_PLAN.md
##     переносит авторитет движения на хост.
##
## Запуск:
##   godot --path . -- --net-host --net-port=7777 --net-name=Хозяин
##   godot --path . -- --net-join=192.168.1.10:7777 --net-name=Гость

const Protocol = preload("res://scripts/net/net_protocol.gd")

signal role_changed(role: int)
signal peer_joined(id: int, info: Dictionary)
signal peer_left(id: int)
signal connected_to_host()
signal connection_failed(reason: String)
signal host_lost()
signal snapshot_received(states: Dictionary)
signal event_received(kind: String, data: Dictionary, from_id: int)
signal status_changed()

enum Role { OFFLINE, HOST, CLIENT }

const ROLE_NAMES := ["offline", "host", "client"]
const CONNECT_TIMEOUT_S := 12.0

var role: int = Role.OFFLINE
## Клиентская сторона: этот id выдал хост (у хоста всегда 1).
var local_id: int = 0
var port: int = 0
var player_name: String = "player"
## id -> {"name": String, "joined_ms": int}
var players: Dictionary = {}
## id -> последнее известное состояние (позиция, скорость, флаги).
var states: Dictionary = {}
var rtt_ms: int = 0
var last_error: String = ""
var events_sent: int = 0
var events_received: int = 0
var snapshots_sent: int = 0
var snapshots_received: int = 0
## Версия сборки игры: хост и клиент обязаны играть один и тот же мир.
var build_tag: String = ""

var _peer: ENetMultiplayerPeer = null
var _packets_in: int = 0
var _packets_out: int = 0
var _tick: int = 0
var _snapshot_clock: float = 0.0
var _state_clock: float = 0.0
var _ping_clock: float = 0.0
var _last_seen: Dictionary = {}
var _known_peers: Array = []
var _handshake_sent: bool = false
var _connect_clock: float = 0.0
var _wanted_host: bool = false
var _wanted_join: String = ""
var _wanted_port: int = Protocol.DEFAULT_PORT
## Явно ли задан порт: адрес вида `host:PORT` не должен перетираться значением
## по умолчанию, иначе гость молча стучится в 7777 при живом хосте на 7831.
var _port_given: bool = false
var _started_by_cmdline: bool = false


func _ready() -> void:
	process_mode = Node.PROCESS_MODE_ALWAYS
	set_process(true)
	_read_cmdline()
	if _wanted_host or not _wanted_join.is_empty():
		_started_by_cmdline = true
		call_deferred("_autostart")


# ------------------------------------------------------------------ публичный API

func online() -> bool:
	return role != Role.OFFLINE


func role_name() -> String:
	return ROLE_NAMES[role]


func is_host() -> bool:
	return role == Role.HOST


func is_client() -> bool:
	return role == Role.CLIENT


## Запрашивались ли сетевые аргументы в командной строке. Нужен игре, чтобы
## поставить сетевой слой до того, как хост/клиент реально подключился.
func requested() -> bool:
	return _wanted_host or not _wanted_join.is_empty() or _started_by_cmdline


func status_line() -> String:
	if role == Role.OFFLINE:
		return "offline" + ("" if last_error.is_empty() else " (" + last_error + ")")
	return "%s id=%d players=%d rtt=%dms" % [ROLE_NAMES[role], local_id, players.size(), rtt_ms]


func start_host(host_port: int = Protocol.DEFAULT_PORT, host_name: String = "") -> bool:
	if role != Role.OFFLINE:
		leave("restart")
	var candidate: ENetMultiplayerPeer = ENetMultiplayerPeer.new()
	var error: int = candidate.create_server(maxi(1, host_port), Protocol.MAX_CLIENTS, 0, 0, 0)
	if error != OK:
		last_error = "не удалось открыть порт %d (код %d)" % [host_port, error]
		push_warning("DSH_NET host failed: " + last_error)
		_report_status()
		role_changed.emit(Role.OFFLINE)
		return false
	if not host_name.is_empty():
		player_name = host_name
	_peer = candidate
	port = host_port
	role = Role.HOST
	local_id = 1
	players = {1: _player_entry(player_name)}
	states = {}
	_known_peers = []
	_rtt_reset()
	print("DSH_NET_HOST port=", host_port, " max_clients=", Protocol.MAX_CLIENTS,
		" proto=", Protocol.VERSION, " build=", build_tag)
	_report_status()
	role_changed.emit(Role.HOST)
	return true


func start_client(address: String, join_port: int = Protocol.DEFAULT_PORT, join_name: String = "") -> bool:
	if role != Role.OFFLINE:
		leave("restart")
	var target: ENetMultiplayerPeer = ENetMultiplayerPeer.new()
	var error: int = target.create_client(address, maxi(1, join_port), 0, 0, 0)
	if error != OK:
		last_error = "не удалось начать подключение к %s:%d (код %d)" % [address, join_port, error]
		push_warning("DSH_NET join failed: " + last_error)
		_report_status()
		role_changed.emit(Role.OFFLINE)
		return false
	if not join_name.is_empty():
		player_name = join_name
	_peer = target
	port = join_port
	role = Role.CLIENT
	local_id = 0
	players = {}
	states = {}
	_known_peers = []
	_handshake_sent = false
	_connect_clock = 0.0
	_rtt_reset()
	print("DSH_NET_JOIN address=", address, " port=", join_port, " proto=", Protocol.VERSION,
		" build=", build_tag)
	_report_status()
	role_changed.emit(Role.CLIENT)
	return true


func leave(reason: String = "left") -> void:
	if role != Role.OFFLINE:
		print("DSH_NET_LEAVE role=", ROLE_NAMES[role], " reason=", reason)
		if _peer != null and _peer.get_connection_status() == MultiplayerPeer.CONNECTION_CONNECTED:
			_broadcast(Protocol.make(Protocol.MSG_BYE, {"reason": reason}))
	if _peer != null:
		_peer.close()
		_peer = null
	role = Role.OFFLINE
	local_id = 0
	players = {}
	states = {}
	_known_peers = []
	_handshake_sent = false
	rtt_ms = 0
	_report_status()
	role_changed.emit(Role.OFFLINE)


## Публикует собственное состояние. Игра зовёт это каждый кадр; отправка
## ограничена частотой Protocol.INPUT_HZ внутри `_process`.
func publish_state(state: Dictionary) -> void:
	if role == Role.OFFLINE or local_id <= 0:
		return
	states[local_id] = state


func state_for(id: int) -> Dictionary:
	var state: Variant = states.get(id)
	return state if state is Dictionary else {}


func peer_name(id: int) -> String:
	var info: Variant = players.get(id)
	if info is Dictionary:
		return str(info.get("name", "player"))
	return "player"


## Мгновенное действие: на хосте выполняется локально и рассылается всем, на
## клиенте уходит хосту (хост перешлёт остальным и применит у себя).
func send_event(kind: String, data: Dictionary = {}) -> void:
	if role == Role.OFFLINE:
		return
	events_sent += 1
	if role == Role.HOST:
		event_received.emit(kind, data, local_id)
		_broadcast(Protocol.make(Protocol.MSG_EVENT, {"e": kind, "d": data}))
	else:
		_send_to(1, Protocol.make(Protocol.MSG_EVENT, {"e": kind, "d": data}))


## Запрос, который обслуживает только хост. Не пересылается другим клиентам и
## не вызывает обработчик у отправителя: клиент ждёт результата отдельным
## событием (`destruction` и т.п.).
func send_event_to_host(kind: String, data: Dictionary = {}) -> void:
	if role != Role.CLIENT:
		return
	events_sent += 1
	_send_to(1, Protocol.make(Protocol.MSG_EVENT, {"e": kind, "d": data}))


## Результат, который хост уже применил у себя. Без локального эха, иначе хост
## применил бы одно и то же дважды.
func broadcast_event(kind: String, data: Dictionary = {}) -> void:
	if role != Role.HOST:
		return
	events_sent += 1
	_broadcast(Protocol.make(Protocol.MSG_EVENT, {"e": kind, "d": data}))


# ------------------------------------------------------------------ аргументы CLI

func _read_cmdline() -> void:
	var args: PackedStringArray = PackedStringArray()
	args.append_array(OS.get_cmdline_user_args())
	args.append_array(OS.get_cmdline_args())
	for argument: String in args:
		if argument == "--net-host":
			_wanted_host = true
		elif argument.begins_with("--net-host="):
			_wanted_host = true
			_wanted_port = maxi(1, int(argument.substr("--net-host=".length())))
			_port_given = true
		elif argument == "--net-join":
			_wanted_join = "127.0.0.1"
		elif argument.begins_with("--net-join="):
			_wanted_join = argument.substr("--net-join=".length())
		elif argument.begins_with("--net-port="):
			_wanted_port = maxi(1, int(argument.substr("--net-port=".length())))
			_port_given = true
		elif argument.begins_with("--net-name="):
			player_name = argument.substr("--net-name=".length())


func _autostart() -> void:
	if not _wanted_join.is_empty():
		var parsed: Dictionary = Protocol.parse_address(_wanted_join)
		var join_port: int = int(parsed["port"])
		if _port_given:
			join_port = _wanted_port
		start_client(str(parsed["address"]), join_port, player_name)
	elif _wanted_host:
		start_host(_wanted_port, player_name)


# ------------------------------------------------------------------ транспорт

func _broadcast(message: Dictionary) -> void:
	if _peer == null:
		return
	if _peer.get_connection_status() != MultiplayerPeer.CONNECTION_CONNECTED:
		return
	_peer.set_target_peer(MultiplayerPeer.TARGET_PEER_BROADCAST)
	_peer.put_packet(Protocol.encode(message))
	_peer.set_target_peer(MultiplayerPeer.TARGET_PEER_BROADCAST)
	_packets_out += 1


func _send_to(id: int, message: Dictionary) -> void:
	if _peer == null or id <= 0:
		return
	if _peer.get_connection_status() != MultiplayerPeer.CONNECTION_CONNECTED:
		return
	if id != 1 and not _peer_known(id):
		return
	_peer.set_target_peer(id)
	_peer.put_packet(Protocol.encode(message))
	_peer.set_target_peer(MultiplayerPeer.TARGET_PEER_BROADCAST)
	_packets_out += 1


func _peer_known(id: int) -> bool:
	if _peer == null:
		return false
	return _peer.get_peer(id) != null


func _drain_packets() -> void:
	if _peer == null:
		return
	var debug_packets: bool = OS.get_cmdline_user_args().has("--net-debug-packets")
	var guard: int = 0
	while _peer.get_available_packet_count() > 0 and guard < 512:
		guard += 1
		# Отправителя спрашиваем ДО `get_packet()`: после чтения пакета
		# `get_packet_peer()` на клиенте отдаёт мусор вместо id.
		var sender: int = _peer.get_packet_peer()
		var packet: PackedByteArray = _peer.get_packet()
		_packets_in += 1
		_last_seen[sender] = Time.get_ticks_msec()
		var message: Dictionary = Protocol.decode(packet)
		if message.is_empty():
			continue
		if debug_packets and _packets_in < 12:
			print("DSH_NET_DEBUG pkt kind=", message.get("kind", "?"), " from=", sender)
		if role == Role.HOST and sender != 1 and not players.has(sender):
			_on_peer_connected(sender)
		_handle(message, sender)


func _handle(message: Dictionary, sender: int) -> void:
	var kind: String = str(message.get("kind", ""))
	match kind:
		Protocol.MSG_HELLO:
			_on_hello(message, sender)
		Protocol.MSG_WELCOME:
			_on_welcome(message)
		Protocol.MSG_ROSTER:
			_on_roster(message)
		Protocol.MSG_STATE:
			_on_state(message, sender)
		Protocol.MSG_SNAPSHOT:
			_on_snapshot(message)
		Protocol.MSG_EVENT:
			_on_event(message, sender)
		Protocol.MSG_PING:
			_send_to(sender, Protocol.make(Protocol.MSG_PONG, {"t": message.get("t", 0)}))
		Protocol.MSG_PONG:
			var sent_at: float = float(message.get("t", 0.0))
			if sent_at > 0.0:
				rtt_ms = int(maxf(0.0, Time.get_ticks_msec() - sent_at))
				status_changed.emit()
		Protocol.MSG_BYE:
			if role == Role.HOST and _peer_known(sender) and _peer != null:
				_peer.disconnect_peer(sender)
			elif role == Role.CLIENT:
				last_error = "хост закрыл игру"
				leave("host_closed")
				host_lost.emit()


func _on_hello(message: Dictionary, sender: int) -> void:
	if role != Role.HOST or _peer == null:
		return
	var version: int = int(message.get("v", 0))
	if version != Protocol.VERSION:
		_send_to(sender, Protocol.make(Protocol.MSG_WELCOME, {
			"ok": false, "reason": "version", "v": Protocol.VERSION}))
		_peer.disconnect_peer(sender)
		print("DSH_NET_REJECT id=", sender, " reason=protocol version=", version)
		return
	var name: String = str(message.get("name", "player")).strip_edges()
	if name.is_empty():
		name = "player"
	if name.length() > 24:
		name = name.substr(0, 24)
	players[sender] = _player_entry(name)
	_send_to(sender, Protocol.make(Protocol.MSG_WELCOME, {
		"ok": true,
		"id": sender,
		"v": Protocol.VERSION,
		"roster": players,
		"host": player_name,
		"build": build_tag,
	}))
	_broadcast_roster()
	if not states.is_empty():
		_send_to(sender, Protocol.make(Protocol.MSG_SNAPSHOT, {"t": _tick, "s": states}))
	print("DSH_NET_PEER_JOINED id=", sender, " name=", name, " total=", players.size())
	peer_joined.emit(sender, players[sender])
	_report_status()


func _on_welcome(message: Dictionary) -> void:
	if role != Role.CLIENT:
		return
	if not bool(message.get("ok", false)):
		last_error = "хост отклонил подключение: " + str(message.get("reason", "unknown"))
		print("DSH_NET_WELCOME_REJECT reason=", last_error)
		leave("rejected")
		connection_failed.emit(last_error)
		return
	local_id = int(message.get("id", 0))
	if local_id <= 0:
		last_error = "хост не выдал id"
		leave("no_id")
		connection_failed.emit(last_error)
		return
	var roster: Variant = message.get("roster", {})
	# До welcome свой id неизвестен (0), и состояние записывалось под нулём.
	# Выбрасываем этот мусор, иначе на клиенте появится аватар «игрока 0».
	states.clear()
	players = (roster as Dictionary).duplicate(true) if roster is Dictionary else {}
	if not players.has(local_id):
		players[local_id] = _player_entry(player_name)
	var host_build: String = str(message.get("build", ""))
	if not build_tag.is_empty() and not host_build.is_empty() and build_tag != host_build:
		print("DSH_NET_WARN build_mismatch host=", host_build, " client=", build_tag)
	print("DSH_NET_WELCOME id=", local_id, " host=", message.get("host", ""),
		" players=", players.size(), " build=", build_tag)
	_report_status()
	connected_to_host.emit()
	# Сразу отдаём хосту своё состояние, чтобы он увидел нас без ожидания тика.
	_state_clock = 1.0


func _on_roster(message: Dictionary) -> void:
	var roster: Variant = message.get("p", {})
	if roster is Dictionary:
		players = (roster as Dictionary).duplicate(true)
		status_changed.emit()
		_report_status()


func _on_state(message: Dictionary, sender: int) -> void:
	if role != Role.HOST or not players.has(sender):
		return
	var state: Variant = message.get("s", {})
	if state is Dictionary:
		states[sender] = state


func _on_snapshot(message: Dictionary) -> void:
	if role != Role.CLIENT:
		return
	var incoming: Variant = message.get("s", {})
	if not (incoming is Dictionary):
		return
	snapshots_received += 1
	var snapshot: Dictionary = incoming
	for id: Variant in snapshot:
		states[int(id)] = snapshot[id]
	for id: Variant in states:
		if not players.has(int(id)):
			players[int(id)] = _player_entry("player")
	snapshot_received.emit(states)


func _on_event(message: Dictionary, sender: int) -> void:
	var kind: String = str(message.get("e", ""))
	var data: Variant = message.get("d", {})
	if not (data is Dictionary):
		data = {}
	events_received += 1
	if role == Role.HOST:
		var from_id: int = sender if sender > 0 else local_id
		event_received.emit(kind, data, from_id)
		# Запросы вида `*_request` обслуживает только хост — остальным они не нужны.
		if not kind.ends_with("_request"):
			_broadcast(Protocol.make(Protocol.MSG_EVENT, {"e": kind, "d": data, "f": from_id}))
	else:
		event_received.emit(kind, data, int(message.get("f", sender)))


# ------------------------------------------------------------------ соединения

## Хост узнаёт о подключении по первому пакету от нового id, об уходе — по
## исчезновению пира из ENet. Клиент — по статусу соединения.
func _poll_connections() -> void:
	if _peer == null:
		return
	if role == Role.HOST:
		for id: Variant in _known_peers.duplicate():
			if not _peer_known(int(id)):
				_known_peers.erase(int(id))
				_on_peer_disconnected(int(id))
	elif role == Role.CLIENT:
		var status: int = _peer.get_connection_status()
		if status == MultiplayerPeer.CONNECTION_CONNECTED:
			if not _handshake_sent:
				_handshake_sent = true
				print("DSH_NET_HELLO name=", player_name)
				_send_to(1, Protocol.make(Protocol.MSG_HELLO, {"name": player_name}))
		elif status == MultiplayerPeer.CONNECTION_DISCONNECTED:
			if _handshake_sent:
				last_error = "связь с хостом потеряна"
				print("DSH_NET_SERVER_DISCONNECTED")
				leave("server_lost")
				host_lost.emit()
			else:
				last_error = "не удалось подключиться"
				print("DSH_NET_CONNECTION_FAILED")
				leave("failed")
				connection_failed.emit(last_error)


func _on_peer_connected(id: int) -> void:
	_last_seen[id] = Time.get_ticks_msec()
	_known_peers.append(id)
	if not players.has(id):
		players[id] = _player_entry("player")
	_report_status()


func _on_peer_disconnected(id: int) -> void:
	players.erase(id)
	states.erase(id)
	_last_seen.erase(id)
	print("DSH_NET_PEER_LEFT id=", id, " total=", players.size())
	peer_left.emit(id)
	_report_status()
	if role == Role.HOST:
		_broadcast_roster()


# ------------------------------------------------------------------ кадровый цикл

func _process(delta: float) -> void:
	if role == Role.OFFLINE:
		return
	if _peer == null:
		return
	_peer.poll()
	_drain_packets()
	_poll_connections()
	if role == Role.OFFLINE:
		return
	if role == Role.CLIENT:
		_connect_clock += delta
		if not _handshake_sent and _connect_clock > CONNECT_TIMEOUT_S:
			last_error = "хост не отвечает"
			leave("timeout")
			connection_failed.emit(last_error)
			return
	if _peer.get_connection_status() != MultiplayerPeer.CONNECTION_CONNECTED:
		return
	var step: float = maxf(0.0, minf(delta, 0.25))
	if role == Role.HOST:
		_tick += 1
		_snapshot_clock += step
		var interval: float = 1.0 / Protocol.SNAPSHOT_HZ
		if _snapshot_clock >= interval:
			_snapshot_clock = fmod(_snapshot_clock, interval)
			if not states.is_empty():
				_broadcast(Protocol.make(Protocol.MSG_SNAPSHOT, {"t": _tick, "s": states}))
				snapshots_sent += 1
		_check_timeouts()
	else:
		_state_clock += step
		var state_interval: float = 1.0 / Protocol.INPUT_HZ
		if _state_clock >= state_interval and _handshake_sent:
			_state_clock = fmod(_state_clock, state_interval)
			var mine: Variant = states.get(local_id)
			if mine is Dictionary:
				_send_to(1, Protocol.make(Protocol.MSG_STATE, {"s": mine}))
		_ping_clock += step
		if _ping_clock >= Protocol.PING_INTERVAL and _handshake_sent:
			_ping_clock = 0.0
			_send_to(1, Protocol.make(Protocol.MSG_PING, {"t": Time.get_ticks_msec()}))
			_update_rtt_from_enet()


func _update_rtt_from_enet() -> void:
	if _peer == null:
		return
	var host_peer: ENetPacketPeer = _peer.get_peer(1)
	if host_peer == null:
		return
	var measured: float = float(host_peer.get_statistic(ENetPacketPeer.PEER_ROUND_TRIP_TIME))
	if measured > 0.0:
		rtt_ms = int(measured)
		status_changed.emit()


func _check_timeouts() -> void:
	if role != Role.HOST:
		return
	var now: int = Time.get_ticks_msec()
	for id: Variant in _last_seen.keys():
		var peer_id: int = int(id)
		if peer_id == 1:
			continue
		if now - int(_last_seen[id]) > int(Protocol.PEER_TIMEOUT_S * 1000.0):
			print("DSH_NET_TIMEOUT id=", peer_id)
			if _peer != null and _peer_known(peer_id):
				_peer.disconnect_peer(peer_id)
			_on_peer_disconnected(peer_id)


# ------------------------------------------------------------------ мелочи

func _broadcast_roster() -> void:
	_broadcast(Protocol.make(Protocol.MSG_ROSTER, {"p": players}))


func _player_entry(entry_name: String) -> Dictionary:
	return {"name": entry_name, "joined_ms": Time.get_ticks_msec()}


func _rtt_reset() -> void:
	rtt_ms = 0
	_tick = 0
	_snapshot_clock = 0.0
	_state_clock = 0.0
	_ping_clock = 0.0


func _report_status() -> void:
	status_changed.emit()
