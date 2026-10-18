extends RefCounted
## Bounded contextual card placement. Logical viewport coordinates, no scene/model mutations.
## Protect real projected target first, then hero/reticle and persistent HUD.

static func projected_bounds(camera: Camera3D, bounds: AABB, world: Transform3D) -> Dictionary:
	var rect: Rect2; var first:=true
	for index: int in 8:
		var point: Vector3=world*bounds.get_endpoint(index)
		if camera.is_position_behind(point): return {"ok":false}
		var screen: Vector2=camera.unproject_position(point)
		if first: rect=Rect2(screen,Vector2.ZERO); first=false
		else: rect=rect.expand(screen)
	return {"ok":true,"rect":rect}

static func choose(viewport: Rect2, card_size: Vector2, target: Rect2, protected: Array[Rect2], previous: Rect2=Rect2()) -> Dictionary:
	var safe: Rect2=viewport.grow(-12)
	if card_size.x>safe.size.x or card_size.y>safe.size.y: return {"ok":false,"reason":"card_larger_than_viewport"}
	var keepout: Rect2=target.grow(18)
	var middle: Vector2=target.get_center()
	var candidates: Array[Vector2]=[
		Vector2(keepout.position.x-card_size.x,middle.y-card_size.y*.5),
		Vector2(keepout.end.x,middle.y-card_size.y*.5),
		Vector2(middle.x-card_size.x*.5,keepout.position.y-card_size.y),
		Vector2(middle.x-card_size.x*.5,keepout.end.y),
		safe.position,Vector2(safe.end.x-card_size.x,safe.position.y),
		Vector2(safe.position.x,safe.end.y-card_size.y),safe.end-card_size]
	# Preserve previous side/position unless it now obscures protected content.
	if previous.size.is_equal_approx(card_size) and safe.encloses(previous) and not previous.intersects(keepout):
		var old_clear:=true
		for obstacle: Rect2 in protected:
			if previous.intersects(obstacle.grow(8)): old_clear=false; break
		if old_clear and previous.get_center().distance_to(middle)<480:
			return {"ok":true,"rect":previous,"retained":true,"candidates_tested":0}
	var best:=Rect2(); var score:=INF; var found:=false; var examined:=0
	for point: Vector2 in candidates:
		examined+=1
		point.x=clampf(point.x,safe.position.x,safe.end.x-card_size.x)
		point.y=clampf(point.y,safe.position.y,safe.end.y-card_size.y)
		var candidate:=Rect2(point,card_size)
		if candidate.intersects(keepout): continue
		var clear:=true
		for obstacle: Rect2 in protected:
			if candidate.intersects(obstacle.grow(8)): clear=false; break
		if not clear: continue
		var distance:=candidate.get_center().distance_squared_to(middle)
		if distance<score: score=distance; best=candidate; found=true
	if not found: return {"ok":false,"reason":"no_unobscured_slot","candidates_tested":examined}
	return {"ok":true,"rect":best,"retained":false,"candidates_tested":examined}
