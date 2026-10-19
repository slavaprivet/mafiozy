extends SceneTree
const Loader = preload("res://captured_image_loader.gd")
var failures := []
func load_all(loader: RefCounted,ids: Array) -> int:
	var started := Time.get_ticks_usec()
	for id: String in ids:
		var result: Dictionary = loader.load_image(id)
		if not result.ok: failures.append(str(result.get("error","")))
	return Time.get_ticks_usec()-started
func percentile(values: Array,p: float) -> int:
	var ordered := values.duplicate()
	ordered.sort()
	return ordered[clampi(ceili(values.size()*p)-1,0,values.size()-1)]
func _initialize() -> void: call_deferred("run")
func run() -> void:
	var loader := Loader.new()
	if not loader.configure().ok:
		print("CAPTURE_LOADER_BENCH metadata admission failed")
		quit(1)
		return
	load_all(loader,loader.ids()) # one warmup, not reported
	var pairs := []
	var cold := []
	var warm := []
	for i in 7:
		if not loader.configure().ok: failures.append("generation admission failed")
		var ids: Array = loader.ids()
		var cold_usec := load_all(loader,ids)
		var before: Dictionary = loader.stats().counters
		var warm_usec := load_all(loader,ids)
		var after: Dictionary = loader.stats().counters
		if before.png_decodes!=43 or before.image_reads!=86 or before.image_hashes!=86 or after.png_decodes!=43 or after.image_reads!=86 or after.image_hashes!=86 or after.image_cache_hits!=43:
			failures.append("once-only byte validation/decode invariant")
		cold.append(cold_usec)
		warm.append(warm_usec)
		pairs.append({"pair":i,"coldUsec":cold_usec,"warmUsec":warm_usec,"counters":after})
	print(JSON.stringify({"suite":"actual43-captured-image-CPU-cache-paired","pairs":pairs,"coldP50Usec":percentile(cold,.5),"coldP95Usec":percentile(cold,.95),"warmP50Usec":percentile(warm,.5),"warmP95Usec":percentile(warm,.95),"failures":failures,"coldDefinition":"new loader generation,43 original PNG+RGBA reads/hashes/native decode; OS filecache warmed","warmDefinition":"same approved immutable generation,43 defensive Image/metadata copies; zero newIO/hash/decode","gpu":false,"ready":false}))
	quit(0 if failures.is_empty() else 1)
