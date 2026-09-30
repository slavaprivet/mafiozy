extends RefCounted
## Explicit local preview composition requested by the user on 2026-10-01.
## Source bytes, terrain, actor identities and archived assets remain intact.
const MODE := "palazzo_only43"

static func prepare_block(source: Dictionary) -> Dictionary:
	var result: Dictionary = source.duplicate(true)
	result["buildings"] = []
	var decor: Array = result.get("decor", [])
	result["anchorId"] = str(decor[0].id) if not decor.is_empty() else ""
	var paths: Dictionary = {str(result.hero.path): true}
	var bodies := 0
	for record: Dictionary in decor:
		paths[str(record.path)] = true
		bodies += record.get("collisionBodiesM", []).size()
	result.counts.buildings = 0
	result.counts.decor = decor.size()
	result.counts.collisionBodies = bodies
	result.counts.uniqueGlbs = paths.size()
	return result

static func is_current(source: Dictionary, candidate: Dictionary) -> bool:
	return candidate == prepare_block(source)
