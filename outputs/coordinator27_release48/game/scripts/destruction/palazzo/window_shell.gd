extends RefCounted
## Cold geometry only: an XY opening in a local, axis-aligned wall box.
## All returned pieces are real boxes; no convex hull is made across the opening.
const COLUMNS := 4
const ROWS := 5
const MAX_PARTS := 64

static func ring(size: Vector3, center: Vector2, width: float, height: float) -> Dictionary:
	if not size.is_finite() or not center.is_finite() or not is_finite(width) or not is_finite(height): return {"ok":false,"reason":"nonfinite_window"}
	if size.x<=0 or size.y<=0 or size.z<=0 or width<.05 or height<.05: return {"ok":false,"reason":"window_dimensions"}
	var lo:=Vector2(-size.x*.5,-size.y*.5)
	var hi:=Vector2(size.x*.5,size.y*.5)
	var opening:=Rect2(center-Vector2(width,height)*.5,Vector2(width,height))
	if opening.position.x<=lo.x or opening.position.y<=lo.y or opening.end.x>=hi.x or opening.end.y>=hi.y: return {"ok":false,"reason":"window_outside_wall"}
	var rects: Array[Rect2]=[
		Rect2(lo,Vector2(opening.position.x-lo.x,size.y)),
		Rect2(Vector2(opening.end.x,lo.y),Vector2(hi.x-opening.end.x,size.y)),
		Rect2(Vector2(opening.position.x,lo.y),Vector2(width,opening.position.y-lo.y)),
		Rect2(Vector2(opening.position.x,opening.end.y),Vector2(width,hi.y-opening.end.y))]
	var boxes: Array[Dictionary]=[]
	for rect in rects:
		boxes.append({"size":Vector3(rect.size.x,rect.size.y,size.z),"at":Vector3(rect.get_center().x,rect.get_center().y,0.0)})
	return {"ok":true,"opening":opening,"boxes":boxes,"solid_volume_m3":(size.x*size.y-width*height)*size.z}

static func tiles(size: Vector3, parts: Array) -> Dictionary:
	if not size.is_finite() or size.x<=0 or size.y<=0 or size.z<=0 or parts.is_empty() or parts.size()>MAX_PARTS: return {"ok":false,"reason":"panel_or_part_budget"}
	for part: Dictionary in parts:
		if not part.get("size") is Vector3 or not part.get("at") is Vector3 or not part.size.is_finite() or not part.at.is_finite() or part.size.x<=0 or part.size.y<=0 or part.size.z<=0: return {"ok":false,"reason":"invalid_box_part"}
	var cell_size:=Vector3(size.x/COLUMNS,size.y/ROWS,size.z)
	var result: Array[Dictionary]=[]
	for row in ROWS:
		for col in COLUMNS:
			var center:=Vector3(-size.x*.5+(col+.5)*cell_size.x,-size.y*.5+(row+.5)*cell_size.y,0)
			var clipped: Array[Dictionary]=[]
			var physical: int=0
			for part: Dictionary in parts:
				var low: Vector3=part.at-part.size*.5
				var high: Vector3=part.at+part.size*.5
				# Preserve overhanging sills/decor once, in the outermost cell.
				if col>0: low.x=maxf(low.x,center.x-cell_size.x*.5)
				if col<COLUMNS-1: high.x=minf(high.x,center.x+cell_size.x*.5)
				if row>0: low.y=maxf(low.y,center.y-cell_size.y*.5)
				if row<ROWS-1: high.y=minf(high.y,center.y+cell_size.y*.5)
				if high.x<=low.x or high.y<=low.y: continue
				var copy: Dictionary=part.duplicate()
				copy.size=high-low
				copy.at=(high+low)*.5-center
				clipped.append(copy)
				if bool(copy.get("physical",false)): physical+=1
			# Never invent a full tile behind the pane, including decoration-only air.
			if physical==0:
				if not clipped.is_empty(): return {"ok":false,"reason":"unattached_window_decor","row":row,"col":col}
				continue
			result.append({"center":center,"size":cell_size,"parts":clipped,"row":row,"col":col})
	return {"ok":true,"tiles":result,"grid_cells":COLUMNS*ROWS,"omitted_air_cells":COLUMNS*ROWS-result.size()}
