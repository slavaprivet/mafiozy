extends RefCounted
## Original mercenary_walk.mjs ownMember projection for recruitment UI.
## The source host exclusively owns every action and inventory change.
## Enrich the real roster with live getMember state and actual focus distance
## at each UI refresh, just as the source presentation adapter does.
var _host: RefCounted
var _world: Node3D

func _init(host: RefCounted,world: Node3D) -> void:
	_host = host
	_world = world

func get_roster() -> Dictionary:
	var roster: Dictionary = _host.get_roster()
	var focus: Variant = _world.get_player_position()
	for row: Dictionary in roster.members:
		var live: Variant = _host.get_member(str(row.id))
		if live is Dictionary:
			row.merge(live,true)
		var position: Variant = live.get("position") if live is Dictionary else null
		row.distanceMeters = Vector2(float(position.x)-float(focus.x),float(position.z)-float(focus.z)).length() if position is Dictionary and focus is Dictionary else INF
	return roster

func recruit(id: String,weapon_id: String = "") -> Dictionary:
	return _host.recruit(id,weapon_id)

func equip(id: String,weapon_id: String) -> Dictionary:
	return _host.equip(id,weapon_id)

func dismiss(id: String) -> Dictionary:
	return _host.dismiss(id)

func upgrade(id: String,skill: String = "") -> Dictionary:
	return _host.upgrade(id,skill)
