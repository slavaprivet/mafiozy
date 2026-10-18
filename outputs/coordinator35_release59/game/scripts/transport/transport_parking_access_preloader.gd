extends RefCounted
## Loads and validates immutable source parking data off the gameplay thread.
## The caller must keep the already-loaded catalog unchanged until READY/ERROR
## and call close() before dropping an unfinished preloader.
const Parking = preload("res://scripts/transport/transport_parking_access.gd")

var _thread: Thread
var _catalog: RefCounted

func begin(catalog: RefCounted, path: String = "res://data/transport/parking_access.v1.json") -> String:
	if _thread != null: return "BUSY"
	if catalog == null or catalog.get("parking") == null: return "CATALOG"
	_catalog = catalog
	_thread = Thread.new()
	var started := _thread.start(_load.bind(path), Thread.PRIORITY_LOW)
	if started != OK:
		_thread = null
		_catalog = null
		return "THREAD_START"
	return "PENDING"

func poll() -> Dictionary:
	if _thread == null: return {"code": "IDLE"}
	if _thread.is_alive(): return {"code": "PENDING"}
	var result: Variant = _thread.wait_to_finish()
	_thread = null
	_catalog = null
	return result if result is Dictionary else {"code": "WORKER_RESULT"}

func close() -> void:
	if _thread != null:
		_thread.wait_to_finish()
		_thread = null
	_catalog = null

func _load(path: String) -> Dictionary:
	var parking := Parking.new()
	if not parking.load_file(_catalog, path):
		return {"code": "ERROR", "error": parking.error}
	return {"code": "READY", "parking": parking}
