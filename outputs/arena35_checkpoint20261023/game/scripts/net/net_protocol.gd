extends RefCounted
## DSH_NET — проводной протокол онлайн-игры, версия 1.
##
## Один пакет = один Variant-словарь, сериализованный `var_to_bytes`. Такой формат
## читается без отдельного парсера, переживает Vector3/Transform3D и позволяет
## следующему агенту добавить новое поле, не ломая старые сообщения: неизвестные
## ключи просто игнорируются принимающей стороной.
##
## Соглашения:
##  * `kind` — строка-тип сообщения (обязательное поле каждого пакета).
##  * `Net` (автозагрузка `scripts/net/net_session.gd`) — единственный владелец сокета.
##    Игровые системы НЕ трогают ENet напрямую, они зовут `Net.send_event()`.
##  * Снаряды, разрушения, взрывы и прочие мгновенные действия идут событиями
##    (`Net.send_event(kind, data)`), а не потоком трансформов. Постоянное состояние
##    (позиции игроков, HP кирпичей) — отдельными каналами снапшота.
##
## Версия поднимается при несовместимом изменении; несовпадение версий отклоняет
## подключение с понятной причиной, а не «молчаливой рассинхронизацией».

const VERSION := 1

## Порт по умолчанию. Переопределяется `--net-port=N` или `--net-host=N`.
const DEFAULT_PORT := 7777
const MAX_CLIENTS := 8

## Защита от мусорного/огромного пакета: всё, что больше, отбрасывается до разбора.
const MAX_PACKET_BYTES := 256 * 1024

## Частота публикации состояния игрока и рассылки снапшота.
const SNAPSHOT_HZ := 20.0
const INPUT_HZ := 20.0
const PING_INTERVAL := 1.0

## Клиент считается мёртвым, если не прислал ни одного пакета столько секунд.
const PEER_TIMEOUT_S := 10.0

# --- типы сообщений -----------------------------------------------------------
const MSG_HELLO := "hello"        # client -> host: имя, версия протокола
const MSG_WELCOME := "welcome"    # host -> client: id, состав, версия
const MSG_ROSTER := "roster"      # host -> client: состав изменился
const MSG_STATE := "state"        # client -> host: моё состояние (позиция и т.п.)
const MSG_SNAPSHOT := "snapshot"  # host -> client: состояния всех
const MSG_EVENT := "event"        # обе стороны: мгновенное действие
const MSG_PING := "ping"
const MSG_PONG := "pong"
const MSG_BYE := "bye"

# --- события, которые уже понимает игра (расширять по мере переноса систем) ----
const EV_CHAT := "chat"
const EV_DESTRUCTION := "destruction"   # взрыв/удар по кладке: точка, радиус, сила
const EV_PROJECTILE := "projectile"     # запуск снаряда: вид, откуда, куда, скорость
const EV_MELEE := "melee"               # замах/удар/контакт
const EV_THROW := "throw"               # бросок меча/копья
const EV_VEHICLE := "vehicle"           # посадка/управление кораблём, шаром, конём
const EV_NPC := "npc"                   # состояние жителя, которого видно всем


## Кадр пакета — просто сериализованный Variant, без обёрток.
##
## Важно: `Net` опрашивает `ENetMultiplayerPeer` напрямую (`poll()` +
## `get_packet()`), а НЕ через `SceneTree.multiplayer`. Причина: `SceneMultiplayer`
## считает первый байт пакета служебной командой и срезает его до выдачи в
## `peer_packet`, а также может увести пакет в свой RPC/replication-разбор.
## Прямой опрос отдаёт байты ровно в том виде, в каком они ушли.
static func encode(message: Dictionary) -> PackedByteArray:
	return var_to_bytes(message)


## Возвращает пустой словарь на любом мусоре: сеть не должна ронять игру.
static func decode(data: PackedByteArray) -> Dictionary:
	if data == null or data.size() < 3 or data.size() > MAX_PACKET_BYTES:
		return {}
	# Смещение 0 — штатный путь; 1 — страховка на случай внешнего префикса.
	for offset: int in [0, 1]:
		if offset >= data.size():
			continue
		var slice: PackedByteArray = data if offset == 0 else data.slice(offset)
		var value: Variant = bytes_to_var(slice)
		if value is Dictionary:
			var message: Dictionary = value
			if message.has("kind"):
				return message
	return {}


static func make(kind: String, extra: Dictionary = {}) -> Dictionary:
	var message: Dictionary = {"kind": kind, "v": VERSION}
	for key: Variant in extra:
		message[key] = extra[key]
	return message


## Адрес вида `host`, `host:port`, `[::1]:port`.
static func parse_address(text: String) -> Dictionary:
	var address: String = text.strip_edges()
	var port: int = DEFAULT_PORT
	if address.begins_with("["):
		var close_index: int = address.find("]")
		if close_index > 0:
			var tail: String = address.substr(close_index + 1)
			address = address.substr(1, close_index - 1)
			if tail.begins_with(":"):
				port = int(tail.substr(1))
	else:
		var colon: int = address.rfind(":")
		if colon > 0:
			var maybe_port: String = address.substr(colon + 1)
			if maybe_port.is_valid_int():
				port = int(maybe_port)
				address = address.substr(0, colon)
	if address.is_empty():
		address = "127.0.0.1"
	if port <= 0 or port > 65535:
		port = DEFAULT_PORT
	return {"address": address, "port": port}
