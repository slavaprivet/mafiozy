extends RefCounted
## Source closest-surface math only; current skin/occlusion/identity/HP are caller-owned.
## PackedFloat64 intermediates avoid native Vector3 float32 determinant cancellation.
static func _p(v: Vector3) -> PackedFloat64Array: return PackedFloat64Array([v.x,v.y,v.z])
static func _v(a: PackedFloat64Array) -> Vector3: return Vector3(a[0],a[1],a[2])
static func _a(a: PackedFloat64Array,b: PackedFloat64Array) -> PackedFloat64Array: return PackedFloat64Array([a[0]+b[0],a[1]+b[1],a[2]+b[2]])
static func _s(a: PackedFloat64Array,b: PackedFloat64Array) -> PackedFloat64Array: return PackedFloat64Array([a[0]-b[0],a[1]-b[1],a[2]-b[2]])
static func _m(a: PackedFloat64Array,k: float) -> PackedFloat64Array: return PackedFloat64Array([a[0]*k,a[1]*k,a[2]*k])
static func _d(a: PackedFloat64Array,b: PackedFloat64Array) -> float: return a[0]*b[0]+a[1]*b[1]+a[2]*b[2]
static func _x(a: PackedFloat64Array,b: PackedFloat64Array) -> PackedFloat64Array: return PackedFloat64Array([a[1]*b[2]-a[2]*b[1],a[2]*b[0]-a[0]*b[2],a[0]*b[1]-a[1]*b[0]])
static func _dist(a: PackedFloat64Array,b: PackedFloat64Array) -> float:
	var x := a[0]-b[0]; var y := a[1]-b[1]; var z := a[2]-b[2]
	return x*x+y*y+z*z

static func _closest(p: PackedFloat64Array,a: PackedFloat64Array,b: PackedFloat64Array,c: PackedFloat64Array) -> PackedFloat64Array:
	var abx := b[0]-a[0]; var aby := b[1]-a[1]; var abz := b[2]-a[2]
	var acx := c[0]-a[0]; var acy := c[1]-a[1]; var acz := c[2]-a[2]
	var px := p[0]-a[0]; var py := p[1]-a[1]; var pz := p[2]-a[2]
	var d1 := abx*px+aby*py+abz*pz; var d2 := acx*px+acy*py+acz*pz
	if d1 <= 0.0 and d2 <= 0.0: return a
	px=p[0]-b[0]; py=p[1]-b[1]; pz=p[2]-b[2]
	var d3 := abx*px+aby*py+abz*pz; var d4 := acx*px+acy*py+acz*pz
	if d3 >= 0.0 and d4 <= d3: return b
	var vc := d1*d4-d3*d2
	if vc <= 0.0 and d1 >= 0.0 and d3 <= 0.0:
		var k := d1/(d1-d3)
		return PackedFloat64Array([a[0]+abx*k,a[1]+aby*k,a[2]+abz*k])
	px=p[0]-c[0]; py=p[1]-c[1]; pz=p[2]-c[2]
	var d5 := abx*px+aby*py+abz*pz; var d6 := acx*px+acy*py+acz*pz
	if d6 >= 0.0 and d5 <= d6: return c
	var vb := d5*d2-d1*d6
	if vb <= 0.0 and d2 >= 0.0 and d6 <= 0.0:
		var k := d2/(d2-d6)
		return PackedFloat64Array([a[0]+acx*k,a[1]+acy*k,a[2]+acz*k])
	var va := d3*d6-d5*d4
	if va <= 0.0 and d4-d3 >= 0.0 and d5-d6 >= 0.0:
		var k := (d4-d3)/((d4-d3)+(d5-d6))
		return PackedFloat64Array([b[0]+(c[0]-b[0])*k,b[1]+(c[1]-b[1])*k,b[2]+(c[2]-b[2])*k])
	var den := 1.0/(va+vb+vc)
	var u := vb*den; var v := vc*den
	return PackedFloat64Array([(a[0]+abx*u)+acx*v,(a[1]+aby*u)+acy*v,(a[2]+abz*u)+acz*v])

static func _edge(from: PackedFloat64Array,to: PackedFloat64Array,p: PackedFloat64Array,q: PackedFloat64Array) -> PackedFloat64Array:
	var dx := to[0]-from[0]; var dy := to[1]-from[1]; var dz := to[2]-from[2]
	var ex := q[0]-p[0]; var ey := q[1]-p[1]; var ez := q[2]-p[2]
	var rx := from[0]-p[0]; var ry := from[1]-p[1]; var rz := from[2]-p[2]
	var a := dx*dx+dy*dy+dz*dz; var e := ex*ex+ey*ey+ez*ez; var f := ex*rx+ey*ry+ez*rz
	var s := 0.0; var t := 0.0
	if a < 1e-14: t=clampf(f/e,0,1) if e > 1e-14 else 0.0
	else:
		var c := dx*rx+dy*ry+dz*rz
		if e < 1e-14: s=clampf(-c/a,0,1)
		else:
			var b := dx*ex+dy*ey+dz*ez; var den := a*e-b*b
			s=clampf((b*f-c*e)/den,0,1) if den > 1e-14 else 0.0
			t=(b*s+f)/e
			if t < 0.0: t=0.0; s=clampf(-c/a,0,1)
			elif t > 1.0: t=1.0; s=clampf((b-c)/a,0,1)
	return PackedFloat64Array([from[0]+dx*s,from[1]+dy*s,from[2]+dz*s,p[0]+ex*t,p[1]+ey*t,p[2]+ez*t])

static func _ray(from: PackedFloat64Array,direction: PackedFloat64Array,a: PackedFloat64Array,b: PackedFloat64Array,c: PackedFloat64Array) -> Variant:
	var ex := b[0]-a[0]; var ey := b[1]-a[1]; var ez := b[2]-a[2]
	var fx := c[0]-a[0]; var fy := c[1]-a[1]; var fz := c[2]-a[2]
	var nx := ey*fz-ez*fy; var ny := ez*fx-ex*fz; var nz := ex*fy-ey*fx
	var ddn := direction[0]*nx+direction[1]*ny+direction[2]*nz; var sign := 1.0
	if ddn > 0.0: sign=1.0
	elif ddn < 0.0: sign=-1.0; ddn=-ddn
	else: return null
	var dx := from[0]-a[0]; var dy := from[1]-a[1]; var dz := from[2]-a[2]
	var u := sign*(direction[0]*(dy*fz-dz*fy)+direction[1]*(dz*fx-dx*fz)+direction[2]*(dx*fy-dy*fx))
	if u < 0.0: return null
	var v := sign*(direction[0]*(ey*dz-ez*dy)+direction[1]*(ez*dx-ex*dz)+direction[2]*(ex*dy-ey*dx))
	if v < 0.0 or u+v > ddn: return null
	var distance := -sign*(dx*nx+dy*ny+dz*nz)
	if distance < 0.0: return null
	var k := distance/ddn
	return PackedFloat64Array([from[0]+direction[0]*k,from[1]+direction[1]*k,from[2]+direction[2]*k])

static func sample(from: Vector3,to: Vector3,radius: float,a: Vector3,b: Vector3,c: Vector3) -> Dictionary:
	for value in [from,to,a,b,c]:
		if not value.is_finite(): return {"valid":false,"error":"nonfinite"}
		if maxf(absf(value.x),maxf(absf(value.y),absf(value.z))) > 10000000.0: return {"valid":false,"error":"world_bound"}
	if not is_finite(radius) or radius <= 0.0 or radius > .5: return {"valid":false,"error":"radius"}
	return _sample(_p(from),_p(to),radius,_p(a),_p(b),_p(c))

static func _sample(from: PackedFloat64Array,to: PackedFloat64Array,radius: float,a: PackedFloat64Array,b: PackedFloat64Array,c: PackedFloat64Array) -> Dictionary:
	var bx := b[0]-a[0]; var by := b[1]-a[1]; var bz := b[2]-a[2]
	var cx := c[0]-a[0]; var cy := c[1]-a[1]; var cz := c[2]-a[2]
	var nx := by*cz-bz*cy; var ny := bz*cx-bx*cz; var nz := bx*cy-by*cx
	var normal_squared := nx*nx+ny*ny+nz*nz
	if normal_squared < 1e-14: return {"valid":true,"hit":false}
	var inverse_length := 1.0/sqrt(normal_squared)
	nx*=inverse_length; ny*=inverse_length; nz*=inverse_length
	var dx := to[0]-from[0]; var dy := to[1]-from[1]; var dz := to[2]-from[2]
	var length := sqrt(dx*dx+dy*dy+dz*dz)
	var nearest_point: PackedFloat64Array; var nearest_line: PackedFloat64Array; var best := 0.0
	var intersection: Variant = null
	if length > 1e-10:
		inverse_length=1.0/length
		intersection=_ray(from,PackedFloat64Array([dx*inverse_length,dy*inverse_length,dz*inverse_length]),a,b,c)
	if intersection is PackedFloat64Array and _dist(from,intersection) <= length*length+1e-10:
		nearest_point=intersection; nearest_line=intersection
	else:
		nearest_point=_closest(from,a,b,c); nearest_line=from; best=_dist(from,nearest_point)
		var point := _closest(to,a,b,c); var distance := _dist(to,point)
		if distance < best: best=distance; nearest_point=point; nearest_line=to
		for i in 3:
			var pair := _edge(from,to,a if i==0 else b if i==1 else c,b if i==0 else c if i==1 else a)
			var px := pair[0]-pair[3]; var py := pair[1]-pair[4]; var pz := pair[2]-pair[5]
			distance=px*px+py*py+pz*pz
			if distance < best:
				best=distance; nearest_line=pair.slice(0,3); nearest_point=pair.slice(3,6)
	if best > radius*radius+1e-10: return {"valid":true,"hit":false}
	var ox := nearest_line[0]-nearest_point[0]; var oy := nearest_line[1]-nearest_point[1]; var oz := nearest_line[2]-nearest_point[2]
	var outward_squared := ox*ox+oy*oy+oz*oz
	if (outward_squared > 1e-12 and nx*ox+ny*oy+nz*oz < 0.0) or (outward_squared <= 1e-12 and nx*dx+ny*dy+nz*dz > 0.0): nx=-nx; ny=-ny; nz=-nz
	var px := nearest_point[0]-a[0]; var py := nearest_point[1]-a[1]; var pz := nearest_point[2]-a[2]
	var d00 := cx*cx+cy*cy+cz*cz; var d01 := cx*bx+cy*by+cz*bz; var d02 := cx*px+cy*py+cz*pz
	var d11 := bx*bx+by*by+bz*bz; var d12 := bx*px+by*py+bz*pz
	var determinant := d00*d11-d01*d01
	if determinant == 0.0: return {"valid":false,"error":"unrepresentable_triangle"}
	var inv := 1.0/determinant
	var u := (d11*d02-d01*d12)*inv; var v := (d00*d12-d01*d02)*inv
	var point := _v(nearest_point); var line := _v(nearest_line); var outward_normal := Vector3(nx,ny,nz)
	if not point.is_finite() or not line.is_finite() or not outward_normal.is_finite() or not is_finite(u) or not is_finite(v) or not is_finite(best): return {"valid":false,"error":"arithmetic_range"}
	return {"valid":true,"hit":true,"point":point,"line_point":line,"normal":outward_normal,"weights":Vector3(1.0-u-v,v,u),"score":_dist(from,nearest_line)+best,"distance_squared":best}
