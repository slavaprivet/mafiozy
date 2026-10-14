extends RefCounted
static var entries := {}
static func record(key: String,usec: int) -> void:
	if not entries.has(key): entries[key] = {"calls":0,"totalUsec":0,"maxUsec":0}
	entries[key].calls += 1
	entries[key].totalUsec += usec
	entries[key].maxUsec = maxi(entries[key].maxUsec,usec)
