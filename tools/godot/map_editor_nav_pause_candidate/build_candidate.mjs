import fs from 'node:fs';
import path from 'node:path';
import crypto from 'node:crypto';
import {fileURLToPath} from 'node:url';

const here=path.dirname(fileURLToPath(import.meta.url));
const root=path.resolve(here,'../../..');
const backendPath='godot/mafiozi_walk/scripts/navigation/preview_engine_navigation.gd';
const hostPath='godot/mafiozi_walk/scripts/navigation/preview_navigation_host.gd';
const queuePath='godot/mafiozi_walk/scripts/navigation/path_job_queue.gd';
const interiorPath='godot/mafiozi_walk/scripts/preview_printshop_interior.gd';
const finishPath='godot/mafiozi_walk/scripts/preview_interior_finish.gd';
const pins={
 [backendPath]:'aca4ff31b689a5b652ca85ddd0999d45696debb912bb8e1495f056d02db69aab',
 [hostPath]:'0b6fd34bc1d77e1f27c2005b699477453f089f4f65bf7d21942e73adbad631d4',
 [queuePath]:'dc19de386ccef8e23dcf1c2f0b62f6a46f7f816cf8fd5c3c26c8a6409b7be473',
 [interiorPath]:'300b48c8efa0d0b953514b36e0c0319febfd6d9a2ff61450601a45e1109e37f4',
 [finishPath]:'f2137740ac1b31669454f18c258db3560bf3c9eb9ff35b0a00875db0ee6bb497'
};
const hash=bytes=>crypto.createHash('sha256').update(bytes).digest('hex');
export function pinnedSource(){
 const result={};
 for(const [relative,expected] of Object.entries(pins)){
  const bytes=fs.readFileSync(path.join(root,relative));
  if(hash(bytes)!==expected)throw Error(`Actual source drift: ${relative}`);
  result[relative]=bytes;
 }
 return result;
}
function once(source,needle,replacement){
 const at=source.indexOf(needle);
 if(at<0||source.indexOf(needle,at+needle.length)>=0)throw Error(`Expected one source seam: ${needle.slice(0,80)}`);
 return source.slice(0,at)+replacement+source.slice(at+needle.length);
}
const queueLease=`var _editor_pause_active := false
var _editor_pause_fault := false
var _editor_pause_owner: WeakRef
var _editor_pause_receipt: Dictionary = {}
var _editor_pause_serial := 0
var _editor_pause_snapshot: Dictionary = {}

func _editor_pause_write() -> bool:
\tif not _editor_pause_active: return false
\t_editor_pause_fault = true
\treturn true

func _editor_pause_state() -> Dictionary:
\tif _disposed or _busy or not _native_enabled or not _queue.is_empty() or not _batch.is_empty() or not _served.is_empty() or _current != null or _started != null or _deadline != 0 or _batch_count != 0: return {}
\treturn {"clock_owner":_clock.get_object_id(),"clock_method":_clock.get_method(),"native_enabled":_native_enabled,"last_clock":_last_clock,"frame":_frame,"deadline":_deadline,"count":_count,"epoch":_epoch,"used":_used,"started":_started,"batch_count":_batch_count,"stats":_stats.duplicate(true),"rejected_calls":rejected_calls}

func begin_editor_pause(owner: Node) -> Dictionary:
\tif not Thread.is_main_thread() or _editor_pause_active or not is_instance_valid(owner) or owner.is_queued_for_deletion() or not owner.is_inside_tree() or owner.get_tree().paused: return {}
\tvar state: Dictionary = _editor_pause_state()
\tif state.is_empty(): return {}
\t_editor_pause_serial += 1
\t_editor_pause_owner = weakref(owner)
\t_editor_pause_snapshot = state.duplicate(true)
\t_editor_pause_receipt = {"serial":_editor_pause_serial,"owner_id":owner.get_instance_id(),"queue_id":get_instance_id(),"epoch":_epoch}
\t_editor_pause_fault = false; _editor_pause_active = true
\treturn _editor_pause_receipt.duplicate(true)

func _editor_pause_current(receipt: Dictionary) -> bool:
\tif not Thread.is_main_thread() or not _editor_pause_active or _editor_pause_fault or receipt != _editor_pause_receipt or _editor_pause_owner == null: return false
\tvar owner: Node = _editor_pause_owner.get_ref()
\tvar state: Dictionary = _editor_pause_state()
\tif not is_instance_valid(owner) or owner.is_queued_for_deletion() or not owner.is_inside_tree() or owner.get_instance_id() != int(receipt.get("owner_id", -1)) or state.is_empty() or state != _editor_pause_snapshot:
\t\treturn false
\treturn true

func verify_editor_pause(receipt: Dictionary) -> bool:
\treturn _editor_pause_current(receipt) and _editor_pause_owner.get_ref().get_tree().paused

## Read-only preflight; no queue release or clock advancement.
func can_end_editor_pause(receipt: Dictionary) -> bool:
\treturn _editor_pause_current(receipt) and not _editor_pause_owner.get_ref().get_tree().paused

func end_editor_pause(receipt: Dictionary) -> bool:
\tif not can_end_editor_pause(receipt): return false
\t_editor_pause_active = false
\t_editor_pause_receipt.clear(); _editor_pause_snapshot.clear(); _editor_pause_owner = null
\treturn true

`;
export function patchQueue(source){
 let output=once(source,'func _init(clock_usec: Callable = Callable(), native_enabled: bool = true) -> void:',queueLease+'func _init(clock_usec: Callable = Callable(), native_enabled: bool = true) -> void:');
 for(const [signature,guard] of [
  ['func _enter() -> bool:','if _editor_pause_write(): return false'],
  ['func _now() -> int:','if _editor_pause_write(): return -1'],
  ['func _finish_at(now: int) -> void:','if _editor_pause_write(): return'],
  ['func diagnostics() -> Dictionary:','if _editor_pause_active: return {"error":"EDITOR_PAUSED"}']
 ])output=once(output,signature+'\n',signature+'\n\t'+guard+'\n');
 output=once(output,'func dispose() -> bool:\n','func dispose() -> bool:\n\tif _editor_pause_active:\n\t\t_editor_pause_fault = true; _editor_pause_active = false # Terminal teardown.\n');
 return output;
}
const hostLease=`var _editor_pause_active := false
var _editor_pause_fault := false
var _editor_pause_terminal_hold := false
var _editor_pause_owner: WeakRef
var _editor_pause_receipt: Dictionary = {}
var _editor_pause_serial := 0
var _editor_pause_leaves: Array[Dictionary] = []
var _editor_pause_doors: Dictionary = {}
var _editor_pause_queue: RefCounted

func _editor_terminal_hold(owner: Node) -> void:
\t_editor_pause_fault = true
\t_editor_pause_terminal_hold = true
\tif is_instance_valid(owner) and owner.is_inside_tree(): owner.get_tree().paused = true

func begin_editor_pause(owner: Node) -> Dictionary:
\tif not Thread.is_main_thread() or _editor_pause_active or _editor_pause_terminal_hold or _disposed or _busy or _backend == null or _queue == null or not _geometry_valid or not _transitions.is_empty() or not _records.is_empty() or not _owner_records.is_empty() or not _body_records.is_empty() or not _source_records.is_empty() or not is_instance_valid(owner) or owner.is_queued_for_deletion() or not owner.is_inside_tree() or owner.get_tree().paused:
\t\treturn {}
\tif not _backend.has_method("begin_editor_pause") or not _backend.has_method("can_end_editor_pause") or not _queue.has_method("begin_editor_pause") or not _queue.has_method("can_end_editor_pause"): return {}
\tvar interior: Node3D = _interior.get_ref()
\tvar scene: Node3D = _root.get_ref()
\tif not is_instance_valid(interior) or interior.is_queued_for_deletion() or not is_instance_valid(scene) or scene != owner: return {}
\tvar doors: Dictionary = {}
\tfor key: String in ["public", "service"]:
\t\tif not interior._doors.has(key): return {}
\t\tvar door: Dictionary = interior._doors[key]
\t\tif not is_instance_valid(door.node) or door.node.is_queued_for_deletion() or float(door.fraction) != float(door.target): return {}
\t\tdoors[key] = {"fraction":float(door.fraction),"target":float(door.target),"pivot_id":door.node.get_instance_id(),"pivot_transform":door.node.transform}
\tvar leaves: Array[Dictionary] = []
\tfor leaf: Dictionary in _leaves:
\t\tvar node: CollisionShape3D = leaf.node.get_ref()
\t\tif not is_instance_valid(node): return {}
\t\tleaves.append({"node":weakref(node),"transform":node.global_transform,"disabled":node.disabled})
\tvar queue_receipt: Dictionary = _queue.begin_editor_pause(owner)
\tif queue_receipt.is_empty(): return {}
\tvar native_receipt: Dictionary = _backend.begin_editor_pause(owner)
\tif native_receipt.is_empty():
\t\tif not _queue.can_end_editor_pause(queue_receipt) or not _queue.end_editor_pause(queue_receipt): _editor_terminal_hold(owner)
\t\treturn {}
\t_editor_pause_serial += 1
\t_editor_pause_owner = weakref(owner); _editor_pause_leaves = leaves
\t_editor_pause_doors = doors; _editor_pause_queue = _queue
\t_editor_pause_receipt = {"serial":_editor_pause_serial,"owner_id":owner.get_instance_id(),"scene_id":scene.get_instance_id(),"revision":_revision,"geometry_version":_geometry_version,"access_version":_access_version,"records":_records.size(),"backend":native_receipt,"queue":queue_receipt,"queue_id":_queue.get_instance_id()}
\t_editor_pause_fault = false; _editor_pause_active = true
\treturn _editor_pause_receipt.duplicate(true)

func _editor_receipt_current(receipt: Dictionary) -> bool:
\tif not Thread.is_main_thread() or not _editor_pause_active or _editor_pause_fault or _disposed or receipt != _editor_pause_receipt or _editor_pause_owner == null: return false
\tvar owner: Node = _editor_pause_owner.get_ref()
\tvar scene: Node3D = _root.get_ref()
\tvar interior: Node3D = _interior.get_ref()
\tif not is_instance_valid(owner) or owner.is_queued_for_deletion() or not owner.is_inside_tree() or owner.get_instance_id() != int(receipt.get("owner_id",-1)) or not is_instance_valid(scene) or scene.is_queued_for_deletion() or scene.get_instance_id() != int(receipt.get("scene_id",-1)) or not is_instance_valid(interior) or interior.is_queued_for_deletion(): return false
\tif _revision != receipt.revision or _geometry_version != receipt.geometry_version or _access_version != receipt.access_version or _records.size() != receipt.records or not _transitions.is_empty() or not _geometry_valid or _queue == null or _queue != _editor_pause_queue or _queue.get_instance_id() != int(receipt.get("queue_id", -1)): return false
\tfor key: String in ["public", "service"]:
\t\tif not interior._doors.has(key): return false
\t\tvar door: Dictionary = interior._doors[key]
\t\tvar saved: Dictionary = _editor_pause_doors[key]
\t\tif not is_instance_valid(door.node) or door.node.is_queued_for_deletion() or float(door.fraction) != saved.fraction or float(door.target) != saved.target or door.node.get_instance_id() != saved.pivot_id or door.node.transform != saved.pivot_transform: return false
\tfor leaf: Dictionary in _editor_pause_leaves:
\t\tvar node: CollisionShape3D = leaf.node.get_ref()
\t\tif not is_instance_valid(node) or node.global_transform != leaf.transform or node.disabled != leaf.disabled: return false
\treturn true

func verify_editor_pause(receipt: Dictionary) -> bool:
\tif not _editor_receipt_current(receipt): return false
\tvar owner: Node = _editor_pause_owner.get_ref()
\treturn owner.get_tree().paused and _queue.verify_editor_pause(receipt.queue) and _backend.verify_editor_pause(receipt.backend)

## Read-only unpaused preflight of host, queue and backend; no callback replay.
func can_end_editor_pause(receipt: Dictionary) -> bool:
\tif not _editor_receipt_current(receipt): return false
\tvar owner: Node = _editor_pause_owner.get_ref()
\treturn not owner.get_tree().paused and _queue.can_end_editor_pause(receipt.queue) and _backend.can_end_editor_pause(receipt.backend)

## After unpausing the tree but before its next physics tick; integration is not
## atomic until PreviewPopulation/resident owner and root compose this lease.
func end_editor_pause(receipt: Dictionary) -> bool:
\tif not can_end_editor_pause(receipt): return false
\tvar owner: Node = _editor_pause_owner.get_ref()
\t# Queue release cannot replay callbacks. Release it first: backend replay may
\t# invoke queue admission synchronously, which must then see the live clock.
\t# A late backend failure after this point is not atomic; terminal HOLD only.
\tif not _queue.end_editor_pause(receipt.queue) or not _backend.end_editor_pause(receipt.backend):
\t\t_editor_terminal_hold(owner)
\t\treturn false
\t_editor_pause_active = false; _editor_pause_receipt.clear(); _editor_pause_owner = null
\t_editor_pause_leaves.clear(); _editor_pause_doors.clear(); _editor_pause_queue = null
\treturn true

func _reject_editor_write() -> bool:
\tif not _editor_pause_active and not _editor_pause_terminal_hold: return false
\t_editor_pause_fault = true
\treturn true

`;
export function patchNavigationHost(source){
 let output=once(source,'const Backend = preload("res://scripts/navigation/preview_engine_navigation.gd")','const Backend = preload("res://scripts/navigation/pause_backend.gd")');
 output=once(output,'func _v(a: Array) -> Vector3:',hostLease+'func _v(a: Array) -> Vector3:');
 const guards=[
  ['func _publish() -> bool:','if _reject_editor_write(): return false'],
  ['func _invalidate(reason: String) -> void:','if _reject_editor_write(): return'],
  ['func door_transition_started(key: String, target_fraction: float) -> bool:','if _reject_editor_write(): return false'],
  ['func update_access_version(version: int) -> bool:','if _reject_editor_write(): return false'],
  ['func pump(frame_id: int) -> void:','if _reject_editor_write(): return'],
  ['func request(owner: RefCounted, body: CharacterBody3D, target: Vector3, trusted_admit: Callable) -> int:','if _reject_editor_write(): return -1'],
  ['func poll(id: int) -> Dictionary:','if _reject_editor_write(): return {"status":"EDITOR_PAUSED"}'],
  ['func step(id: int, delta: float, speed: float, gravity: float) -> Dictionary:','if _reject_editor_write(): return {"status":"EDITOR_PAUSED"}'],
  ['func cancel(id: int) -> void:','if _reject_editor_write(): return']
 ];
 for(const [signature,guard] of guards)output=once(output,signature+'\n',signature+'\n\t'+guard+'\n');
 return output;
}
export function buildSource(){
 const sources=pinnedSource();
 return {backend:sources[backendPath],queue:Buffer.from(patchQueue(sources[queuePath].toString('utf8'))),host:Buffer.from(patchNavigationHost(sources[hostPath].toString('utf8'))),interior:sources[interiorPath],finish:sources[finishPath]};
}
export function stageNativeTest(){
 const source=buildSource();
 const stage=fs.mkdtempSync(path.join(root,'outputs','map-editor-nav-pause-'));
 const navDir=path.join(stage,'scripts','navigation');
 fs.mkdirSync(navDir,{recursive:true});
 fs.writeFileSync(path.join(stage,'project.godot'),'config_version=5\n[application]\nconfig/name="Map Editor Nav Pause Candidate"\n[rendering]\nrenderer/rendering_method="gl_compatibility"\n');
 fs.writeFileSync(path.join(navDir,'preview_engine_navigation.gd'),source.backend);
 fs.writeFileSync(path.join(navDir,'path_job_queue.gd'),source.queue);
 fs.writeFileSync(path.join(navDir,'pause_backend.gd'),fs.readFileSync(path.join(here,'pause_backend.gd')));
 fs.writeFileSync(path.join(navDir,'preview_navigation_host.gd'),source.host);
 fs.writeFileSync(path.join(stage,'scripts','preview_printshop_interior.gd'),source.interior);
 fs.writeFileSync(path.join(stage,'scripts','preview_interior_finish.gd'),source.finish);
 fs.writeFileSync(path.join(stage,'test_editor_pause_receipt.gd'),fs.readFileSync(path.join(here,'test_editor_pause_receipt.gd')));
 return {stage,sourceHashes:pins,patchedHostSha256:hash(source.host),patchedQueueSha256:hash(source.queue),backendPauseSha256:hash(fs.readFileSync(path.join(here,'pause_backend.gd')))};
}
if(process.argv[1]&&path.resolve(process.argv[1])===fileURLToPath(import.meta.url))console.log(JSON.stringify(stageNativeTest()));
