"""Create reviewed private owner patches from the exact accepted48 files."""
from pathlib import Path
import hashlib, json
HERE=Path(__file__).resolve().parent
ROOT=HERE.parents[1]
base=json.loads((ROOT/'outputs/coordinator27_release48/ACCEPTED_ASSEMBLY.json').read_text(encoding='utf-8'))
SOURCE=Path(base['game'])
def patch(name, transform):
    p=SOURCE/name
    assert hashlib.sha256(p.read_bytes()).hexdigest()==base['source_pins'][name]
    value=transform(p.read_text(encoding='utf-8'))
    out=HERE/'patches'/name
    out.parent.mkdir(parents=True,exist_ok=True)
    out.write_text(value,encoding='utf-8')
def replace(text,a,b):
    assert text.count(a)==1,(a,text.count(a))
    return text.replace(a,b)
def inventory(t):
    t=replace(t,'var _item_serial := 0','var _item_serial := 0\nvar local_restore_minted := 0')
    t=replace(t,'func _new_item_uid() -> String:\n','func _new_item_uid() -> String:\n\tlocal_restore_minted += 1\n')
    return t+'''

## PRIVATE restore49: capability-bound owner seam, never JSON authority.
func prepare_local_restore(service:RefCounted,cap:RefCounted,value:Dictionary)->Dictionary:
	if not service.allows(cap,self,"inventory") or not _available() or not _owned.is_empty() or not _drops.is_empty() or _item_serial!=0:return _failure("restore_boundary")
	var staged:Dictionary=value.duplicate(true)
	for id:String in staged.fireStates:
		if not _valid_state(staged.fireStates[id],id):return _failure("restore_fire")
	return {"ok":true,"owner":self,"cap":cap,"value":staged,"clock":Callable(service,"now")}

func commit_local_restore(service:RefCounted,cap:RefCounted,prepared:Dictionary)->void:
	assert(service.allows(cap,self,"inventory") and prepared.owner==self and prepared.cap==cap)
	var value:Dictionary=prepared.value
	_owned=value.fireStates.duplicate(true)
	_owned_uids=value.identities.owned.duplicate(true)
	_drop_uids=value.identities.dropped.duplicate(true)
	_drops={}
	for drop:Dictionary in value.dropped:_drops[drop.uid]=drop.duplicate(true)
	_equipped=value.equippedId;_serial=int(value.drop_serial);_item_serial=int(value.item_serial)
	_destroy_receipts=value.destroy_receipts.duplicate(true)
	_clock=prepared.clock
'''
def weapons(t):
    return replace(t,'var configured: Dictionary = inventory.configure(Fire.new())','var resume:RefCounted=get_tree().root.get_meta("private_restore49") if get_tree().root.has_meta("private_restore49") else null\n\tvar configured: Dictionary = inventory.configure(Fire.new(),{"ownedIds":[]} if resume!=null else {})')
def main(t):
    return replace(t,'\tpreview_ready = true','\tif get_tree().root.has_meta("private_restore49"):\n\t\tset_meta("local_restore_staged",true)\n\telse:\n\t\tpreview_ready = true')
def transport(t):
    t=replace(t,'var birth: Dictionary = runtime.bootstrap_new_session(request)','''var resume:RefCounted=get_tree().root.get_meta("private_restore49") if get_tree().root.has_meta("private_restore49") else null
	var birth:Dictionary
	if resume==null:
		birth=runtime.bootstrap_new_session(request)
	else:
		var restored:Dictionary=resume.transport_packet(self,origin)
		if not restored.get("ok",false):return _failure("resume_packet:"+str(restored))
		var begun:Dictionary=runtime.begin_session(restored.session)
		if begun.code!="OK":return _failure("resume_session")
		var published_restore:Dictionary=runtime.publish_roster(restored.roster)
		if published_restore.code!="OK":return _failure("resume_roster")
		_clock=int(restored.session.source_clock)
		birth={"code":"OK","packet":restored}
		set_meta("local_restore_without_factory",true)''')
    return replace(t,'if _vector(record.position_m).distance_to(expected) > 0.0001:','if resume==null and _vector(record.position_m).distance_to(expected) > 0.0001:')
def cargo(t):
    return t+'''

## PRIVATE restore49: validate against fresh native identity and actual geometry.
func prepare_local_restore(service:RefCounted,cap:RefCounted,value:Dictionary,serial:int)->Dictionary:
	if not service.allows(cap,self,"cargo") or not _items.is_empty() or not _pending.is_empty() or _revision!=1 or _destroyed:return _error("RESTORE_BOUNDARY")
	if value.vehicle_id!=_vehicle_id or value.life_generation!=_generation or not _identity_boundary(_generation):return _error("RESTORE_IDENTITY")
	var raw:Dictionary=_compartments.cargo_bounds()
	if raw.is_empty():return _error("RESTORE_BOUNDS")
	var bounds:=AABB(raw.min,raw.max-raw.min)
	var rows:Array[Dictionary]=[]
	for old:Dictionary in value.items:
		var entry:Dictionary=old.duplicate(true)
		var model:Dictionary=entry.model_aabb
		var box:Dictionary=entry.item_bounds_local_m
		entry.model_aabb=AABB(Vector3(model.position.x,model.position.y,model.position.z),Vector3(model.size.x,model.size.y,model.size.z))
		entry.item_bounds_local_m=AABB(Vector3(box.position.x,box.position.y,box.position.z),Vector3(box.size.x,box.size.y,box.size.z))
		var pos:Dictionary=entry.model_origin_local_m
		entry.model_origin_local_m=Vector3(pos.x,pos.y,pos.z)
		if not _normalize_item(entry.item,int(entry.capacity_units)).ok or not _contains(bounds,entry.item_bounds_local_m):return _error("RESTORE_ENTRY")
		if entry.model_aabb.size!=entry.item_bounds_local_m.size or entry.model_origin_local_m+entry.model_aabb.position!=entry.item_bounds_local_m.position:return _error("RESTORE_MODEL_TRANSFORM")
		for other:Dictionary in rows:
			if entry.item_bounds_local_m.grow(GAP_M*.5).intersects(other.item_bounds_local_m.grow(GAP_M*.5)):return _error("RESTORE_OVERLAP")
		rows.append(entry)
	return {"ok":true,"owner":self,"cap":cap,"items":rows,"revision":int(value.revision),"serial":serial}

func commit_local_restore(service:RefCounted,cap:RefCounted,prepared:Dictionary)->void:
	assert(service.allows(cap,self,"cargo") and prepared.owner==self and prepared.cap==cap)
	_items=prepared.items;_revision=prepared.revision;_serial=prepared.serial
'''
patch('scripts/main.gd',main)
patch('scripts/preview_transport.gd',transport)
patch('scripts/weapons/weapon_inventory.gd',inventory)
patch('scripts/weapons/preview_weapons.gd',weapons)
patch('scripts/transport/trunk/transport_trunk_cargo_store.gd',cargo)
p=HERE/'checkpoint.gd'
t=p.read_text(encoding='utf-8')
assert hashlib.sha256(p.read_bytes()).hexdigest()=='217669b4fb6782e745e584dadf69aa6c7bff0af733c4924e8da6d6de4d4bb11b'
t=t.replace('"process_monotonic_ms"','"local_simulation_ms"').replace('"mono_ms":Time.get_ticks_usec()/1000.0','"mono_ms":w.inventory._clock.call()')
p.write_text(t,encoding='utf-8')
print('Five private owner/startup patches; checkpoint clock domain explicit.')
