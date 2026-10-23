extends "res://scripts/combat/weapon_solid_contact29.gd"
var negative34:Dictionary={}
func _swept_static_edge34(host:Node,overlap:Dictionary,before:Transform3D,current:Transform3D)->Dictionary:
 var actual:=super._swept_static_edge34(host,overlap,before,current)
 if not actual.get("recovered_static_edge34",false) or not negative34.is_empty():return actual
 var ready:=_ready;_ready=false
 negative34.initial_equip_stays_static=not super._swept_static_edge34(host,overlap,before,current).get("recovered_static_edge34",false)
 _ready=ready
 var resolving:=_resolving_overlap;_resolving_overlap=true
 negative34.recovery_stays_static=not super._swept_static_edge34(host,overlap,before,current).get("recovered_static_edge34",false)
 _resolving_overlap=resolving
 negative34.stationary_target_only_stays_static=not super._swept_static_edge34(host,overlap,before,before).get("recovered_static_edge34",false)
 var path:=_free_swing34;_free_swing34=[]
 negative34.no_validated_path_stays_static=not super._swept_static_edge34(host,overlap,before,current).get("recovered_static_edge34",false)
 _free_swing34=path.duplicate(true);_free_swing34.back().frame-=2
 negative34.stale_frame_stays_static=not super._swept_static_edge34(host,overlap,before,current).get("recovered_static_edge34",false)
 _free_swing34=path
 var blocked:=_free_block_frame34;_free_block_frame34=Engine.get_physics_frames()
 negative34.external_contact_stays_static=not super._swept_static_edge34(host,overlap,before,current).get("recovered_static_edge34",false)
 _free_block_frame34=blocked
 var id:String=host.get("_weapon_id");host.set("_weapon_id","spear")
 negative34.spear_stays_static=not super._swept_static_edge34(host,overlap,before,current).get("recovered_static_edge34",false)
 host.set("_weapon_id",id)
 var changed:=overlap.duplicate();changed.authored_ridge34=false
 negative34.nonridge_stays_static=not super._swept_static_edge34(host,changed,before,current).get("recovered_static_edge34",false)
 changed=overlap.duplicate();changed.source_key="unrelated_source"
 negative34.unrelated_source_stays_static=not super._swept_static_edge34(host,changed,before,current).get("recovered_static_edge34",false)
 changed=overlap.duplicate();changed.face=int(changed.face)+1
 negative34.unrelated_face_stays_static=not super._swept_static_edge34(host,changed,before,current).get("recovered_static_edge34",false)
 var key:="%s:edge"%actual.part;_contact_times[key]=true
 negative34.held_contact_stays_static=not super._swept_static_edge34(host,overlap,before,current).get("recovered_static_edge34",false)
 _contact_times.erase(key)
 negative34.real_ridge_includes_tip=_sword_ridge34(Vector3(1.05,.016,0),Vector3(1.21,0,0))
 negative34.broad_face_diagonal_not_ridge=not _sword_ridge34(Vector3(.62,.025,0),Vector3(1.05,0,.005))
 negative34.cross_section_not_ridge=not _sword_ridge34(Vector3(.62,.025,0),Vector3(.62,-.025,0))
 negative34.ricasso_not_ridge=not _sword_ridge34(Vector3(.07,.024,0),Vector3(.155,.024,0))
 return actual
