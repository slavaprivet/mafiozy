extends RefCounted
## A second FIFO for the single cashier/medic. Capacity/door claims stay untouched.
const MAX_CUSTOMERS := 512
var queues: Dictionary = {}
var keys: Dictionary = {}

func enqueue(key: String, venue: String) -> bool:
	if keys.has(key): return keys[key] == venue
	if keys.size() >= MAX_CUSTOMERS or key.is_empty() or venue.is_empty(): return false
	if not queues.has(venue): queues[venue] = []
	queues[venue].append(key); keys[key] = venue
	return true

func owns(key: String, venue: String) -> bool:
	return queues.has(venue) and not queues[venue].is_empty() and queues[venue][0] == key

func release(key: String) -> void:
	var venue: String = str(keys.get(key, ""))
	if queues.has(venue):
		queues[venue].erase(key)
		if queues[venue].is_empty(): queues.erase(venue)
	keys.erase(key)

func unregister(venue: String) -> void:
	for key: Variant in (queues.get(venue, []) as Array).duplicate(): keys.erase(key)
	queues.erase(venue)
