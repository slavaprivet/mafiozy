extends RefCounted
## Explicit new-local-session HP owner. No server/saved-state replacement.
## The sole melee producer must validate a current, unconsumed geometry proof.
const INITIAL_HP:=100
const MAX_RECEIPTS:=256
var _scene: Node3D
var _player: CharacterBody3D
var _producer: WeakRef
var _hp:=INITIAL_HP
var _revision:=0
var _receipts: Array[String]=[]
var _hit_age:=10.0
var _layer: CanvasLayer
var _flash: ColorRect
var _label: Label
var _chest:=-1
var _ready:=false

func configure(scene: Node3D,player: CharacterBody3D,producer: Node) -> bool:
	if _ready or not is_instance_valid(scene) or not is_instance_valid(player) or not is_instance_valid(producer):return false
	if player.has_meta("local_contact_health_owner") or player._hit_pose_decorator.is_valid():return false
	_scene=scene;_player=player;_producer=weakref(producer)
	_chest=player._pose_skeleton.find_bone("chest")
	if _chest<0 or not player.set_hit_pose_decorator(Callable(self,"decorate")):return false
	player.set_meta("local_contact_health_owner",get_instance_id())
	_layer=CanvasLayer.new();_layer.layer=18;scene.add_child(_layer)
	_flash=ColorRect.new();_flash.mouse_filter=Control.MOUSE_FILTER_IGNORE
	_flash.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	_flash.color=Color(.55,.015,.02,0);_layer.add_child(_flash)
	_label=Label.new();_label.position=Vector2(18,92);_label.mouse_filter=Control.MOUSE_FILTER_IGNORE
	_label.add_theme_font_size_override("font_size",18);_layer.add_child(_label)
	_ready=true;_refresh()
	return true

func apply_contact(contact: Dictionary,producer: Object) -> Dictionary:
	if not _ready or not is_instance_valid(_scene) or not is_instance_valid(_player) or _scene.preview_dead or _hp<=0:return {"applied":false,"reason":"inactive"}
	if _producer==null or producer!=_producer.get_ref() or not is_instance_valid(producer):return {"applied":false,"reason":"producer"}
	var id: String=str(contact.get("event_id",""))
	if id.is_empty() or _receipts.has(id) or contact.get("damage")!=12:return {"applied":false,"reason":"event"}
	if not contact.get("direction") is Vector3 or not contact.direction.is_finite() or contact.direction.length_squared()<.5:return {"applied":false,"reason":"direction"}
	if not producer.validate_melee_contact(self,contact):return {"applied":false,"reason":"contact_proof"}
	# Same source block rule as the existing input port: 90% reduction while held.
	var blocked: bool=producer._source.snapshot().get("block",false)
	var damage:=1 if blocked else 12
	var before:=_hp
	_hp=maxi(0,_hp-damage);_revision+=1;_hit_age=0.0
	if _hp>0:_player.apply_contact_melee_impulse(contact.direction,3.0 if blocked else 30.0)
	_receipts.append(id)
	if _receipts.size()>MAX_RECEIPTS:_receipts.pop_front()
	if _hp==0:
		_scene.preview_dead=true
		if is_instance_valid(_scene.preview_transport):_scene.preview_transport.mark_dead()
		else:_player.set_preview_pose_authority(&"dead")
		_player.set_mouse_captured(false)
	_refresh()
	return {"applied":true,"event_id":id,"hp_before":before,"hp_after":_hp,"revision":_revision,"blocked":blocked,"scope":"local_new_session"}

func step(delta: float) -> void:
	if not _ready or not is_finite(delta) or delta<0:return
	_hit_age+=delta
	if is_instance_valid(_flash):_flash.color.a=.32 if _hp==0 else maxf(0.0,.22*(1.0-_hit_age/.35))

func decorate(delta: float,selected: Dictionary) -> Dictionary:
	# This callback composes a proposal before the existing one bone writer.
	# The late-physics observer advances the timer; no extra pose or body writes.
	if not _ready or _hit_age>=.45 or _hp<=0 or not selected.get("valid",false):return selected
	var poses: Array=selected.poses.duplicate()
	if _chest>=poses.size():return selected
	var frame: Transform3D=poses[_chest]
	var weight:=sin(clampf(_hit_age/.45,0.0,1.0)*PI)
	frame.basis=frame.basis*Basis(Vector3.RIGHT,-.14*weight)
	poses[_chest]=frame
	var result:=selected.duplicate();result.poses=poses
	return result

func _refresh() -> void:
	if not is_instance_valid(_label):return
	_label.text="Здоровье: %d / %d" % [_hp,INITIAL_HP]
	if _hp==0:
		_label.text="ВЫ ПОГИБЛИ\nR — начать заново"
		_label.set_anchors_and_offsets_preset(Control.PRESET_CENTER)

func snapshot() -> Dictionary:
	return {"hp":_hp,"maximum":INITIAL_HP,"revision":_revision,"scope":"local_new_session","retained_receipts":_receipts.size()}

func dispose() -> void:
	if is_instance_valid(_player) and _player.get_meta("local_contact_health_owner",0)==get_instance_id():
		if _player._hit_pose_decorator==Callable(self,"decorate"):_player.set_hit_pose_decorator(Callable())
		_player.remove_meta("local_contact_health_owner")
	if is_instance_valid(_layer):_layer.queue_free()
	_ready=false;_producer=null;_scene=null;_player=null
