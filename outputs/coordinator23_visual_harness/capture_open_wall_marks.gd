extends "capture_wall_marks.gd"
## Actual original facade, exact collision/render plane and clear 26cm patch.
const Support=preload("wall_mesh_support.gd")
const FIXTURE_ID="REBUILD-VISUAL-old_town_narrow_townhouse_v1-013"
const FIXTURE_POINT=Vector3(22.47031,2.2,-2.85625)
var mesh_support:=Support.new()
var support_receipt:Dictionary={}
func find_wall()->bool:
	phase="mesh_supported_wall_fixture"
	var building:Node3D=scene.get_node_or_null(FIXTURE_ID)
	if not check(is_instance_valid(building),"original_fixture_building_exists"):return false
	mesh_support.configure(building)
	support_receipt=mesh_support.patch(FIXTURE_POINT,Vector3.RIGHT)
	if not check(support_receipt.ok,"original_26cm_mesh_patch_open"):event("bad_mesh_patch",support_receipt);return false
	var query:=PhysicsRayQueryParameters3D.create(FIXTURE_POINT+Vector3.RIGHT,FIXTURE_POINT-Vector3.RIGHT,5,[player.get_rid()])
	var hit:=scene.get_world_3d().direct_space_state.intersect_ray(query)
	if not check(not hit.is_empty() and hit.collider.get_meta("source_id","")==FIXTURE_ID,"same_existing_physical_building"):return false
	target={"point":hit.position,"normal":hit.normal,"collider":hit.collider,"source_id":FIXTURE_ID,"path":str(hit.collider.get_path())}
	event("mesh_supported_fixture_selected",{"physics":target,"mesh":support_receipt});return true
func after_fixture_aim()->bool:
	# Compensate the real .75m aim shoulder using ordinary mouse events only.
	for attempt:int in 12:
		# A real OS blur can clear the first synthetic RMB in an unfocusable
		# QA window. Re-press through the viewport, never write host aim state.
		if not host._aiming:
			event("qa_repress_RMB_after_clear",{"attempt":attempt,"aiming_before":host._aiming})
			aim_input(true);await frames(18)
		var direction:Vector3=(selected_wall.point-camera.global_position).normalized()
		await orbit(atan2(-direction.x,-direction.z),asin(direction.y));await frames(3)
	if not check(host._aiming,"actual_RMB_retained:"+distance_label):return false
	var hit:=wall_ray()
	if not check(not hit.is_empty(),"aim_open_patch_hits_real_wall:"+distance_label):return false
	support_receipt=mesh_support.patch(hit.point,hit.normal)
	event("pre_shot_mesh_patch",support_receipt)
	return check(hit.point.distance_to(selected_wall.point)<.25 and support_receipt.ok,"aimed_original_open_patch:"+distance_label)
func validate_mark_surface()->bool:
	var point:Vector3=last_contact.point;var normal:Vector3=last_contact.normal
	support_receipt=mesh_support.patch(point,normal)
	var visibility:=mesh_support.visible_from(camera.global_position,point+normal*.004)
	event("actual_mark_mesh_support",{"patch":support_receipt,"camera_visibility":visibility})
	return check(support_receipt.ok and visibility.ok,"real_mark_unoccluded_on_mesh:"+distance_label)
func snapshot(label:String)->Dictionary:
	var result:=super.snapshot(label);result.mark_test.mesh_support=support_receipt
	result.mark_test.fixture_geometry="original 013 facade x=22.47031 y=2.2 z=-2.85625; native unchanged mesh and collision"
	return result
