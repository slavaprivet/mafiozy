extends RefCounted
static var values: Dictionary={}
static func record(key: String, us: int) -> void:
	var r: Array=values.get(key,[0,0,0])
	r[0]+=1;r[1]+=us;r[2]=maxi(r[2],us);values[key]=r
