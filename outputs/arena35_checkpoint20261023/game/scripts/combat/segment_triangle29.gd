extends RefCounted
## A finite segment test whose parallel tolerance scales with both operands.
## An absolute determinant epsilon misses short motions against small triangles.
const PARALLEL_RELATIVE := 0.00000001
const BARYCENTRIC_MARGIN := 0.00001
const SEGMENT_MARGIN := 0.000001

static func intersect(from:Vector3,to:Vector3,a:Vector3,b:Vector3,c:Vector3)->Variant:
	var direction:=to-from
	if direction.length_squared()<=1e-20:return null
	var first:=b-a
	var second:=c-a
	var cross_direction:=direction.cross(second)
	var determinant:=first.dot(cross_direction)
	var scale:=sqrt(first.length_squared()*cross_direction.length_squared())
	if absf(determinant)<=PARALLEL_RELATIVE*scale:return null
	var inverse:=1.0/determinant
	var offset:=from-a
	var u:=offset.dot(cross_direction)*inverse
	if u < -BARYCENTRIC_MARGIN or u > 1.0+BARYCENTRIC_MARGIN:return null
	var cross_offset:=offset.cross(first)
	var v:=direction.dot(cross_offset)*inverse
	if v < -BARYCENTRIC_MARGIN or u+v > 1.0+BARYCENTRIC_MARGIN:return null
	var distance:=second.dot(cross_offset)*inverse
	if distance < -SEGMENT_MARGIN or distance > 1.0+SEGMENT_MARGIN:return null
	return from+direction*clampf(distance,0.0,1.0)
