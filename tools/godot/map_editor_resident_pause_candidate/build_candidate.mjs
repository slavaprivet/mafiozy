import fs from 'node:fs';
import path from 'node:path';
import crypto from 'node:crypto';
import {fileURLToPath} from 'node:url';

const here=path.dirname(fileURLToPath(import.meta.url));
const root=path.resolve(here,'../../..');
const checkpoint=path.join(root,'outputs','coordinator22_residents_checkpoint');
const populationPath='godot/mafiozi_walk/scripts/preview_population.gd';
const residentPath='godot/mafiozi_walk/scripts/npc_visual/preview_resident_host.gd';
const policyPath='godot/mafiozi_walk/scripts/npc_visual/preview_resident_world_policy.gd';
const pins={
 [populationPath]:'4c25bf2644f29f91e0a75d38e4d553127fee8e127bf269435c42ab55b361c724',
 [residentPath]:'018e0ab089384e44d62fd855c0d13c5573d662ccba330c2136b04add1503a4d5',
 [policyPath]:'f4e35012690fd4c6cd2c43a6973a8bb9d92b7ad34d493eba5084715eb6ed17f8'
};
const sha=bytes=>crypto.createHash('sha256').update(bytes).digest('hex');
function once(source,needle,replacement){
 const at=source.indexOf(needle);
 if(at<0||source.indexOf(needle,at+needle.length)>=0)throw Error(`Expected one source seam: ${needle.slice(0,90)}`);
 return source.slice(0,at)+replacement+source.slice(at+needle.length);
}
function guard(source,signature,body){return once(source,signature+'\n',signature+'\n\t'+body+'\n');}
export function pinnedSource(){
 const result={};
 for(const [relative,expected] of Object.entries(pins)){
  const bytes=fs.readFileSync(path.join(checkpoint,relative));
  if(sha(bytes)!==expected)throw Error(`Actual source drift: ${relative}`);
  result[relative]=bytes.toString('utf8');
 }
 return result;
}

const residentLease=`var _editor_pause_active := false
var _editor_pause_fault := false
var _editor_pause_serial := 0
var _editor_pause_receipt: Dictionary = {}
var _editor_pause_owner: WeakRef
var _editor_pause_snapshot: Dictionary = {}

func _editor_pause_write() -> bool:
\tif not _editor_pause_active: return false
\t_editor_pause_fault = true
\treturn true

func _editor_pause_state() -> Dictionary:
\tif _disposed or _dispose_requested or _busy or _scene == null or not _navigation is Navigation or not _admit.is_valid() or not _support.is_valid() or _records.size() != MAX_RESIDENTS: return {}
\tvar scene: Node3D = _scene.get_ref()
\tif not is_instance_valid(scene) or scene.is_queued_for_deletion() or not scene.is_inside_tree(): return {}
\tvar rows: Array = []
\tvar ids: Array = _records.keys()
\tids.sort()
\tfor id: String in ids:
\t\tvar record: Dictionary = _records[id]
\t\tif not _living(record) or int(record.request) >= 0: return {}
\t\tvar owner: Queue.Owner = record.owner
\t\tvar body: CharacterBody3D = record.body
\t\tvar motion: Node3D = record.motion
\t\tvar gait: Gait = record.gait
\t\tif not is_instance_valid(owner) or owner.empire_route_queued or owner.empire_pending_route or owner.search_pending or owner.continuation != null or owner.search_kind != null or owner.request_at != null or not is_instance_valid(body) or body.is_queued_for_deletion() or not body.is_inside_tree() or body.get_parent() != scene or not is_instance_valid(motion) or motion.is_queued_for_deletion() or not is_instance_valid(gait): return {}
\t\tif body.get_meta("source_id", "") != id or body.get_meta("session_id", "") != _session or body.get_meta("descriptor_sha256", "") != record.row.descriptor_sha256: return {}
\t\tif body.get_child_count() < 2: return {}
\t\tvar shape: Node = body.get_child(0)
\t\tif not shape is CollisionShape3D or shape.is_queued_for_deletion() or shape.disabled or not shape.shape is CapsuleShape3D: return {}
\t\tvar rigs: Array[Node] = motion.find_children("*", "Skeleton3D", true, false)
\t\tif rigs.size() != 1: return {}
\t\tvar rig: Skeleton3D = rigs[0] as Skeleton3D
\t\tif rig.is_queued_for_deletion(): return {}
\t\tvar poses: Array[Transform3D] = []
\t\tfor bone: int in range(rig.get_bone_count()): poses.append(rig.get_bone_pose(bone))
\t\tvar nodes: Array = []
\t\tvar descendants: Array[Node] = body.find_children("*", "Node3D", true, false)
\t\tfor node: Node in descendants:
\t\t\tif node.is_queued_for_deletion(): return {}
\t\t\tvar spatial: Node3D = node as Node3D
\t\t\tnodes.append({"id":spatial.get_instance_id(),"parent_id":spatial.get_parent().get_instance_id(),"transform":spatial.transform,"visible":spatial.visible})
\t\tvar owner_state := {"id":owner.get_instance_id(),"source_id":owner.source_id,"generation":owner.life_generation,"dead":owner.dead,"route_queued":owner.empire_route_queued,"pending_route":owner.empire_pending_route,"search_pending":owner.search_pending,"continuation":owner.continuation,"search_kind":owner.search_kind,"request_at":owner.request_at,"attempt_us":owner.attempt_us,"admitted_us":owner.admitted_us,"wait_start_us":owner.wait_start_us,"last_wait_us":owner.last_wait_us,"last_cpu_us":owner.last_cpu_us,"total_cpu_us":owner.total_cpu_us,"quanta":owner.quanta}
\t\trows.append({"id":id,"row":record.row.duplicate(true),"owner":owner_state,"generation":record.generation,"speed":record.speed,"status":record.status,"reason":record.reason,"attempted":record.attempted,"request":record.request,"origin":record.origin,"placement_mode":record.get("placement_mode", "NONE"),"display_yaw":record.get("display_y"),"turn_from":record.get("turn_from"),"turn_to":record.get("turn_to"),"turn_elapsed":record.get("turn_elapsed"),"body_id":body.get_instance_id(),"body_rid":body.get_rid(),"body_transform":body.transform,"body_velocity":body.velocity,"body_layer":body.collision_layer,"body_mask":body.collision_mask,"body_floor_snap":body.floor_snap_length,"body_on_floor":body.is_on_floor(),"shape_id":shape.get_instance_id(),"shape_rid":shape.shape.get_rid(),"shape_transform":shape.transform,"shape_radius":shape.shape.radius,"shape_height":shape.shape.height,"motion_id":motion.get_instance_id(),"rig_id":rig.get_instance_id(),"poses":poses,"nodes":nodes,"gait":gait.get_status(),"gait_pose_active":gait.get("_pose_active")})
\t\trows[rows.size() - 1]["gait_id"] = gait.get_instance_id()
\t\trows[rows.size() - 1]["physics"] = {"safe_margin":body.safe_margin,"max_slides":body.max_slides,"motion_mode":body.motion_mode,"up_direction":body.up_direction,"floor_max_angle":body.floor_max_angle,"floor_stop_on_slope":body.floor_stop_on_slope,"floor_block_on_wall":body.floor_block_on_wall,"floor_constant_speed":body.floor_constant_speed,"slide_on_ceiling":body.slide_on_ceiling,"platform_floor_layers":body.platform_floor_layers,"platform_wall_layers":body.platform_wall_layers,"platform_on_leave":body.platform_on_leave}
\treturn {"scene_id":scene.get_instance_id(),"navigation_id":_navigation.get_instance_id() if is_instance_valid(_navigation) else -1,"admit_owner":_admit.get_object_id(),"admit_method":_admit.get_method(),"support_owner":_support.get_object_id(),"support_method":_support.get_method(),"session":_session,"manifest_sha":_manifest_sha,"manifest":_manifest.duplicate(),"directory":_directory,"rows":rows,"walk_enabled":_walk_preview_enabled,"walk_clock":_walk_preview_clock,"walk":_walk_preview.duplicate(true),"stats":_stats.duplicate(true),"placement_receipt":_placement_receipt.duplicate(true)}

func begin_editor_pause(owner: Node) -> Dictionary:
\tif not Thread.is_main_thread() or _editor_pause_active or not is_instance_valid(owner) or owner.is_queued_for_deletion() or not owner.is_inside_tree() or owner.get_tree().paused or _scene == null or _scene.get_ref() != owner: return {}
\tvar state: Dictionary = _editor_pause_state()
\tif state.is_empty(): return {}
\t_editor_pause_serial += 1
\t_editor_pause_owner = weakref(owner)
\t_editor_pause_snapshot = state.duplicate(true)
\t_editor_pause_receipt = {"serial":_editor_pause_serial,"owner_id":owner.get_instance_id(),"host_id":get_instance_id(),"session":_session}
\t_editor_pause_fault = false
\t_editor_pause_active = true
\treturn _editor_pause_receipt.duplicate(true)

func _editor_pause_current(receipt: Dictionary) -> bool:
\tif not Thread.is_main_thread() or not _editor_pause_active or _editor_pause_fault or receipt != _editor_pause_receipt or _editor_pause_owner == null: return false
\tvar owner: Node = _editor_pause_owner.get_ref()
\tif not is_instance_valid(owner) or owner.is_queued_for_deletion() or not owner.is_inside_tree() or owner.get_instance_id() != int(receipt.get("owner_id", -1)):
\t\t_editor_pause_fault = true
\t\treturn false
\tvar state: Dictionary = _editor_pause_state()
\tif state.is_empty() or state != _editor_pause_snapshot:
\t\t_editor_pause_fault = true
\t\treturn false
\treturn true

func verify_editor_pause(receipt: Dictionary) -> bool:
\tif not _editor_pause_current(receipt): return false
\treturn _editor_pause_owner.get_ref().get_tree().paused

func can_end_editor_pause(receipt: Dictionary) -> bool:
\treturn _editor_pause_current(receipt) and not _editor_pause_owner.get_ref().get_tree().paused

func end_editor_pause(receipt: Dictionary) -> bool:
\tif not can_end_editor_pause(receipt): return false
\t_editor_pause_active = false
\t_editor_pause_receipt.clear(); _editor_pause_snapshot.clear(); _editor_pause_owner = null
\treturn true

`;

export function patchResident(source){
 let output=once(source,'func configure(scene: Node3D, navigation: RefCounted, packet: PackedByteArray, trust: Dictionary, prepared_manifest: PackedByteArray, prepared_directory: String, owners: Dictionary, source_admit: Callable, support_height: Callable) -> Dictionary:',residentLease+'func configure(scene: Node3D, navigation: RefCounted, packet: PackedByteArray, trust: Dictionary, prepared_manifest: PackedByteArray, prepared_directory: String, owners: Dictionary, source_admit: Callable, support_height: Callable) -> Dictionary:');
 const guards=[
  ['func configure(scene: Node3D, navigation: RefCounted, packet: PackedByteArray, trust: Dictionary, prepared_manifest: PackedByteArray, prepared_directory: String, owners: Dictionary, source_admit: Callable, support_height: Callable) -> Dictionary:','if _editor_pause_write(): return {"ok":false,"error":"EDITOR_PAUSED"}'],
  ['func _route_admit(point: Vector3, identity: String, generation: int) -> bool:','if _editor_pause_write(): return false'],
  ['func admit_next() -> Dictionary:','if _editor_pause_write(): return {"status":"EDITOR_PAUSED"}'],
  ['func admit_preview_stage(identity: String, r: float, c: float) -> Dictionary:','if _editor_pause_write(): return {"status":"EDITOR_PAUSED"}'],
  ['func _reject(record: Dictionary, reason: String) -> Dictionary:','if _editor_pause_write(): return {"status":"EDITOR_PAUSED"}'],
  ['func bind_placement_source(receipt: Dictionary, current_validator: Callable) -> Dictionary:','if _editor_pause_write(): return {"ok":false,"error":"EDITOR_PAUSED"}'],
  ['func admit_candidate(candidate: Dictionary, generation: int) -> Dictionary:','if _editor_pause_write(): return {"status":"EDITOR_PAUSED"}'],
  ['func _admit_record(record: Dictionary, candidate: Dictionary = {}, preview_stage: Dictionary = {}) -> Dictionary:','if _editor_pause_write(): return {"status":"EDITOR_PAUSED"}'],
  ['func enable_walk_preview() -> bool:','if _editor_pause_write(): return false'],
  ['func preview_walk_step(delta: float) -> void:','if _editor_pause_write(): return'],
  ['func retry_pending(identity: String) -> bool:','if _editor_pause_write(): return false'],
  ['func request_walk(identity: String, target: Vector3) -> int:','if _editor_pause_write(): return -1'],
  ['func step(delta: float) -> void:','if _editor_pause_write(): return']
 ];
 for(const [sig,body] of guards)output=guard(output,sig,body);
 output=guard(output,'func dispose() -> void:','if _editor_pause_active: _editor_pause_fault = true # Terminal teardown, never resumable.');
 return output;
}

const policyLease=`var _editor_pause_active := false
var _editor_pause_fault := false
var _editor_pause_serial := 0
var _editor_pause_receipt: Dictionary = {}
var _editor_pause_owner: WeakRef
var _editor_pause_snapshot: Dictionary = {}

func _editor_pause_write() -> bool:
\tif not _editor_pause_active: return false
\t_editor_pause_fault = true
\treturn true

func _editor_pause_state() -> Dictionary:
\tif _disposed or _busy or _scene == null or _ray == null or _owners.size() != 3: return {}
\tvar scene: Node3D = _scene.get_ref()
\tif not is_instance_valid(scene) or scene.is_queued_for_deletion() or not scene.is_inside_tree(): return {}
\tvar owner_rows := {}
\tfor id: String in _owners:
\t\tvar record: Dictionary = _owners[id]
\t\tvar owner: Queue.Owner = record.owner
\t\tif not is_instance_valid(owner) or owner.dead or owner.source_id != id or owner.life_generation != 1 or record.dead_seen: return {}
\t\towner_rows[id] = {"owner_id":owner.get_instance_id(),"dead_seen":record.dead_seen,"dead":owner.dead,"generation":owner.life_generation}
\tvar floor_rows := {}
\tfor rid: RID in _floors:
\t\tvar record: Dictionary = _floors[rid]
\t\tvar body: StaticBody3D = record.body.get_ref()
\t\tvar shape: CollisionShape3D = record.shape.get_ref()
\t\tif not is_instance_valid(body) or body.is_queued_for_deletion() or body.get_parent() != scene or not is_instance_valid(shape) or shape.is_queued_for_deletion() or not shape.shape is BoxShape3D: return {}
\t\tfloor_rows[rid] = {"body_id":body.get_instance_id(),"body_rid":body.get_rid(),"frame":body.global_transform,"collision_layer":body.collision_layer,"collision_mask":body.collision_mask,"shape_id":shape.get_instance_id(),"shape_rid":shape.shape.get_rid(),"shape_transform":shape.transform,"disabled":shape.disabled,"size":shape.shape.size,"record_frame":record.frame,"record_size":record.size}
\treturn {"scene_id":scene.get_instance_id(),"owners":owner_rows,"states":_states.duplicate(true),"version":_version,"land":_land.duplicate(),"heights":_heights.duplicate(),"cells":_cells.duplicate(true),"floors":floor_rows,"ray_id":_ray.get_instance_id(),"ray_from":_ray.from,"ray_to":_ray.to,"ray_mask":_ray.collision_mask,"ray_exclude":_ray.exclude.duplicate(),"ray_bodies":_ray.collide_with_bodies,"ray_areas":_ray.collide_with_areas,"ray_back_faces":_ray.hit_back_faces,"ray_from_inside":_ray.hit_from_inside}

func begin_editor_pause(owner: Node) -> Dictionary:
\tif not Thread.is_main_thread() or _editor_pause_active or not is_instance_valid(owner) or owner.is_queued_for_deletion() or not owner.is_inside_tree() or owner.get_tree().paused or _scene == null or _scene.get_ref() != owner: return {}
\tvar state: Dictionary = _editor_pause_state()
\tif state.is_empty(): return {}
\t_editor_pause_serial += 1
\t_editor_pause_owner = weakref(owner)
\t_editor_pause_snapshot = state.duplicate(true)
\t_editor_pause_receipt = {"serial":_editor_pause_serial,"owner_id":owner.get_instance_id(),"policy_id":get_instance_id(),"version":_version}
\t_editor_pause_fault = false; _editor_pause_active = true
\treturn _editor_pause_receipt.duplicate(true)

func _editor_pause_current(receipt: Dictionary) -> bool:
\tif not Thread.is_main_thread() or not _editor_pause_active or _editor_pause_fault or receipt != _editor_pause_receipt or _editor_pause_owner == null: return false
\tvar owner: Node = _editor_pause_owner.get_ref()
\tvar state: Dictionary = _editor_pause_state()
\tif not is_instance_valid(owner) or owner.is_queued_for_deletion() or not owner.is_inside_tree() or owner.get_instance_id() != int(receipt.get("owner_id", -1)) or state.is_empty() or state != _editor_pause_snapshot:
\t\t_editor_pause_fault = true
\t\treturn false
\treturn true

func verify_editor_pause(receipt: Dictionary) -> bool:
\treturn _editor_pause_current(receipt) and _editor_pause_owner.get_ref().get_tree().paused

func can_end_editor_pause(receipt: Dictionary) -> bool:
\treturn _editor_pause_current(receipt) and not _editor_pause_owner.get_ref().get_tree().paused

func end_editor_pause(receipt: Dictionary) -> bool:
\tif not can_end_editor_pause(receipt): return false
\t_editor_pause_active = false
\t_editor_pause_receipt.clear(); _editor_pause_snapshot.clear(); _editor_pause_owner = null
\treturn true

`;

export function patchPolicy(source){
 let output=once(source,'func configure(scene: Node3D, packet_rows: Array, owners: Dictionary, trust: Dictionary, access: Dictionary) -> Dictionary:',policyLease+'func configure(scene: Node3D, packet_rows: Array, owners: Dictionary, trust: Dictionary, access: Dictionary) -> Dictionary:');
 for(const [sig,body] of [
  ['func configure(scene: Node3D, packet_rows: Array, owners: Dictionary, trust: Dictionary, access: Dictionary) -> Dictionary:','if _editor_pause_write(): return {"ok":false,"error":"EDITOR_PAUSED"}'],
  ['func _capture_floors(scene: Node3D, surface: Dictionary) -> bool:','if _editor_pause_write(): return false'],
  ['func _owner_allowed(id: String, generation: int) -> bool:','if _editor_pause_write(): return false'],
  ['func source_admit(point: Vector3, id: String, generation: int, radius: float, purpose: String) -> bool:','if _editor_pause_write(): return false'],
  ['func support_height(point: Vector3, id: String, generation: int) -> float:','if _editor_pause_write(): return NAN'],
  ['func update_access(version: int, states: Dictionary) -> bool:','if _editor_pause_write(): return false']
 ])output=guard(output,sig,body);
 output=guard(output,'func dispose() -> void:','if _editor_pause_active: _editor_pause_fault = true # Terminal teardown.');
 return output;
}

const populationLease=`var _editor_pause_active := false
var _editor_pause_fault := false
var _editor_pause_terminal_hold := false
var _editor_pause_serial := 0
var _editor_pause_receipt: Dictionary = {}
var _editor_pause_owner: WeakRef
var _editor_pause_residents: RefCounted
var _editor_pause_navigation: RefCounted
var _editor_pause_policy: RefCounted
var _editor_pause_owners: Dictionary = {}

func _editor_pause_write() -> bool:
\tif not _editor_pause_active and not _editor_pause_terminal_hold: return false
\t_editor_pause_fault = true
\treturn true

func _editor_terminal_hold(owner: Node) -> void:
\t_editor_pause_fault = true
\t_editor_pause_terminal_hold = true
\tif is_instance_valid(owner) and owner.is_inside_tree(): owner.get_tree().paused = true

func _editor_owner_state() -> Dictionary:
\tif _disposed or status != "ready" or residents == null or navigation == null or policy == null or owners.size() != 3: return {}
\tvar state := {"policy_version":policy.access_version(),"owners":{}}
\tfor id: String in owners:
\t\tvar owner: Queue.Owner = owners[id]
\t\tif not is_instance_valid(owner) or owner.dead or owner.source_id != id or owner.life_generation != 1: return {}
\t\tstate.owners[id] = {"instance_id":owner.get_instance_id(),"source_id":owner.source_id,"generation":owner.life_generation,"dead":owner.dead}
\treturn state

func begin_editor_pause(owner: Node) -> Dictionary:
\tif not Thread.is_main_thread() or _editor_pause_active or _editor_pause_terminal_hold or not is_instance_valid(owner) or owner.is_queued_for_deletion() or not owner.is_inside_tree() or owner.get_tree().paused or navigation == null or residents == null or policy == null: return {}
\tif not navigation.has_method("begin_editor_pause") or not navigation.has_method("can_end_editor_pause") or not residents.has_method("begin_editor_pause") or not policy.has_method("begin_editor_pause"): return {}
\tvar state: Dictionary = _editor_owner_state()
\tif state.is_empty(): return {}
\tvar resident_receipt: Dictionary = residents.begin_editor_pause(owner)
\tif resident_receipt.is_empty(): return {}
\tvar policy_receipt: Dictionary = policy.begin_editor_pause(owner)
\tif policy_receipt.is_empty():
\t\tif not residents.can_end_editor_pause(resident_receipt) or not residents.end_editor_pause(resident_receipt): _editor_terminal_hold(owner)
\t\treturn {}
\t# Navigation is acquired last. A failed nav begin cannot strand a nav lease
\t# under live resident physics; the already-held owners roll back first.
\tvar nav_receipt: Dictionary = navigation.begin_editor_pause(owner)
\tif nav_receipt.is_empty():
\t\tif not policy.can_end_editor_pause(policy_receipt) or not residents.can_end_editor_pause(resident_receipt):
\t\t\t_editor_terminal_hold(owner)
\t\t\treturn {}
\t\tif not policy.end_editor_pause(policy_receipt) or not residents.end_editor_pause(resident_receipt): _editor_terminal_hold(owner)
\t\treturn {}
\t_editor_pause_serial += 1
\t_editor_pause_owner = weakref(owner)
\t_editor_pause_navigation = navigation; _editor_pause_residents = residents; _editor_pause_policy = policy
\t_editor_pause_owners = state
\t_editor_pause_receipt = {"serial":_editor_pause_serial,"owner_id":owner.get_instance_id(),"population_id":get_instance_id(),"session":SESSION,"packet_sha":PACKET_SHA,"prepared_sha":PREPARED_SHA,"navigation":nav_receipt,"residents":resident_receipt,"policy":policy_receipt}
\t_editor_pause_fault = false; _editor_pause_active = true
\treturn _editor_pause_receipt.duplicate(true)

func _editor_pause_current(receipt: Dictionary) -> bool:
\tif not Thread.is_main_thread() or not _editor_pause_active or _editor_pause_fault or receipt != _editor_pause_receipt or _editor_pause_owner == null or _disposed: return false
\tvar owner: Node = _editor_pause_owner.get_ref()
\tif not is_instance_valid(owner) or owner.is_queued_for_deletion() or not owner.is_inside_tree() or owner.get_instance_id() != int(receipt.get("owner_id", -1)) or residents != _editor_pause_residents or navigation != _editor_pause_navigation or policy != _editor_pause_policy or _editor_owner_state() != _editor_pause_owners:
\t\t_editor_pause_fault = true
\t\treturn false
\treturn true

func verify_editor_pause(receipt: Dictionary) -> bool:
\tif not _editor_pause_current(receipt): return false
\tif not _editor_pause_owner.get_ref().get_tree().paused: return false
\treturn residents.verify_editor_pause(receipt.residents) and policy.verify_editor_pause(receipt.policy) and navigation.verify_editor_pause(receipt.navigation)

func end_editor_pause(receipt: Dictionary) -> bool:
\t# A stale second end after a completed lease is a harmless refusal, not a
\t# fault of a live owner. Otherwise repeated K cycles become impossible.
\tif not _editor_pause_active: return false
\tif not _editor_pause_current(receipt):
\t\tvar failed_owner: Node = _editor_pause_owner.get_ref() if _editor_pause_owner != null else null
\t\t_editor_terminal_hold(failed_owner)
\t\treturn false
\tvar owner: Node = _editor_pause_owner.get_ref()
\tif owner.get_tree().paused: return false
\t# Two-phase preflight: do not release/replay nav if a body, gait, policy or
\t# nav receipt is already stale. All calls are synchronous on the main thread.
\tif not residents.can_end_editor_pause(receipt.residents) or not policy.can_end_editor_pause(receipt.policy) or not navigation.can_end_editor_pause(receipt.navigation):
\t\t_editor_terminal_hold(owner)
\t\treturn false
\tif not navigation.end_editor_pause(receipt.navigation):
\t\t_editor_terminal_hold(owner)
\t\treturn false
\tif not policy.end_editor_pause(receipt.policy) or not residents.end_editor_pause(receipt.residents):
\t\t_editor_terminal_hold(owner)
\t\treturn false
\t_editor_pause_active = false
\t_editor_pause_receipt.clear(); _editor_pause_owner = null
\t_editor_pause_residents = null; _editor_pause_navigation = null; _editor_pause_policy = null; _editor_pause_owners.clear()
\treturn true

`;

export function patchPopulation(source){
 let output=once(source,'func setup(scene: Node3D, staged_preview: bool = false, walking_preview: bool = true) -> bool:',populationLease+'func setup(scene: Node3D, staged_preview: bool = false, walking_preview: bool = true) -> bool:');
 for(const [sig,body] of [
  ['func setup(scene: Node3D, staged_preview: bool = false, walking_preview: bool = true) -> bool:','if _editor_pause_write(): return false'],
  ['func step(delta: float) -> void:','if _editor_pause_write(): return'],
  ['func door_started(key: String, opening: bool) -> void:','if _editor_pause_write(): return'],
  ['func request_walk(identity: String, target: Vector3) -> int:','if _editor_pause_write(): return -1']
 ])output=guard(output,sig,body);
 output=guard(output,'func dispose() -> void:','if _editor_pause_active: _editor_pause_fault = true # Terminal teardown.');
 return output;
}

export function buildSource(){
 const original=pinnedSource();
 const resident=patchResident(original[residentPath]);
 const population=patchPopulation(original[populationPath]);
 const policy=patchPolicy(original[policyPath]);
 return {resident,population,policy,sourcePins:pins,hashes:{resident:sha(resident),population:sha(population),policy:sha(policy)}};
}
if(process.argv[1]&&path.resolve(process.argv[1])===fileURLToPath(import.meta.url))console.log(JSON.stringify(buildSource().hashes));
