import assert from 'node:assert/strict';
import fs from 'node:fs';
import {buildSource, patchPopulation, patchResident, patchPolicy, pinnedSource} from './build_candidate.mjs';
import {buildSource as buildNavigation} from '../map_editor_nav_pause_candidate/build_candidate.mjs';

const originals=pinnedSource();
const built=buildSource();
let checks=0;
function check(condition,label){assert.ok(condition,label);checks++;}
const resident=built.resident;
const population=built.population;
const policy=built.policy;
const navigation=buildNavigation();
check(navigation.host.toString('utf8').includes('func can_end_editor_pause(receipt: Dictionary) -> bool:'),'checkpoint nav host preflight available');
check(navigation.queue.toString('utf8').includes('func can_end_editor_pause(receipt: Dictionary) -> bool:'),'checkpoint nav queue preflight available');
check(resident.startsWith('extends RefCounted'),'resident remains actual owner source');
check(population.startsWith('extends RefCounted'),'population remains actual owner source');
check(policy.startsWith('extends RefCounted'),'policy remains actual owner source');
check(resident.includes('func begin_editor_pause(owner: Node) -> Dictionary:'),'resident owner begin');
check(resident.includes('func verify_editor_pause(receipt: Dictionary) -> bool:'),'resident owner verify');
check(resident.includes('func end_editor_pause(receipt: Dictionary) -> bool:'),'resident owner end');
check(population.includes('func begin_editor_pause(owner: Node) -> Dictionary:'),'population begin');
check(population.includes('func verify_editor_pause(receipt: Dictionary) -> bool:'),'population verify');
check(population.includes('func end_editor_pause(receipt: Dictionary) -> bool:'),'population end');
check(policy.includes('func begin_editor_pause(owner: Node) -> Dictionary:'),'policy owner begin');
check(policy.includes('func verify_editor_pause(receipt: Dictionary) -> bool:'),'policy owner verify');
check(policy.includes('func can_end_editor_pause(receipt: Dictionary) -> bool:'),'policy end preflight');
check(policy.includes('func end_editor_pause(receipt: Dictionary) -> bool:'),'policy owner end');
for(const [name,signature] of [
 ['configure','func configure(scene: Node3D, navigation: RefCounted, packet: PackedByteArray, trust: Dictionary, prepared_manifest: PackedByteArray, prepared_directory: String, owners: Dictionary, source_admit: Callable, support_height: Callable) -> Dictionary:'],
 ['route_admit','func _route_admit(point: Vector3, identity: String, generation: int) -> bool:'],
 ['admit_next','func admit_next() -> Dictionary:'],
 ['admit_stage','func admit_preview_stage(identity: String, r: float, c: float) -> Dictionary:'],
 ['admit_candidate','func admit_candidate(candidate: Dictionary, generation: int) -> Dictionary:'],
 ['placement','func bind_placement_source(receipt: Dictionary, current_validator: Callable) -> Dictionary:'],
 ['enable_walk','func enable_walk_preview() -> bool:'],
 ['walk_step','func preview_walk_step(delta: float) -> void:'],
 ['retry','func retry_pending(identity: String) -> bool:'],
 ['request','func request_walk(identity: String, target: Vector3) -> int:'],
 ['step','func step(delta: float) -> void:']
])check(resident.includes(signature+'\n\tif _editor_pause_write():'),`resident ${name} gated`);
for(const [name,signature] of [
 ['setup','func setup(scene: Node3D, staged_preview: bool = false, walking_preview: bool = true) -> bool:'],
 ['step','func step(delta: float) -> void:'],
 ['door','func door_started(key: String, opening: bool) -> void:'],
 ['request','func request_walk(identity: String, target: Vector3) -> int:']
])check(population.includes(signature+'\n\tif _editor_pause_write():'),`population ${name} gated`);
check(resident.includes('body.is_queued_for_deletion()'),'pending body deletion refused');
check(resident.includes('"body_rid":body.get_rid()'),'physical identity captured');
check(resident.includes('"poses":poses'),'skeleton pose captured');
check(resident.includes('"walk_clock":_walk_preview_clock'),'walk clock captured');
check(resident.includes('"gait_id"'),'gait identity captured');
check(resident.includes('"navigation_id":_navigation.get_instance_id()'),'resident nav dependency identity captured');
check(resident.includes('"safe_margin":body.safe_margin'),'body physics settings captured');
for(const [name,signature] of [
 ['configure','func configure(scene: Node3D, packet_rows: Array, owners: Dictionary, trust: Dictionary, access: Dictionary) -> Dictionary:'],
 ['capture_floors','func _capture_floors(scene: Node3D, surface: Dictionary) -> bool:'],
 ['dead_seen','func _owner_allowed(id: String, generation: int) -> bool:'],
 ['source_admit','func source_admit(point: Vector3, id: String, generation: int, radius: float, purpose: String) -> bool:'],
 ['support_height','func support_height(point: Vector3, id: String, generation: int) -> float:'],
 ['update_access','func update_access(version: int, states: Dictionary) -> bool:']
])check(policy.includes(signature+'\n\tif _editor_pause_write():'),`policy ${name} gated`);
check(policy.includes('if _editor_pause_active: _editor_pause_fault = true # Terminal teardown.'),'policy disposal faults receipt');
check(policy.includes('"dead_seen":record.dead_seen'),'policy owner history state captured');
check(policy.includes('"states":_states.duplicate(true)'),'policy access state captured');
check(policy.includes('"floors":floor_rows'),'policy floor state captured');
const residentBegin=population.indexOf('var resident_receipt: Dictionary = residents.begin_editor_pause(owner)');
const policyBegin=population.indexOf('var policy_receipt: Dictionary = policy.begin_editor_pause(owner)');
const navBegin=population.indexOf('var nav_receipt: Dictionary = navigation.begin_editor_pause(owner)');
check(residentBegin>0&&policyBegin>residentBegin&&navBegin>policyBegin,'resident/policy acquired before navigation');
check(population.includes('if not residents.can_end_editor_pause(resident_receipt) or not residents.end_editor_pause(resident_receipt): _editor_terminal_hold(owner)'),'failed policy begin rollback or terminal HOLD');
check(population.includes('if not policy.can_end_editor_pause(policy_receipt) or not residents.can_end_editor_pause(resident_receipt):'),'failed nav begin rollback preflight');
check(population.includes('if not policy.end_editor_pause(policy_receipt) or not residents.end_editor_pause(resident_receipt): _editor_terminal_hold(owner)'),'failed nav begin rollback terminal HOLD');
check(population.includes('navigation.verify_editor_pause(receipt.navigation)'),'composition verifies nav');
check(population.includes('policy.verify_editor_pause(receipt.policy)'),'composition verifies policy');
const end=population.slice(population.indexOf('func end_editor_pause(receipt: Dictionary) -> bool:'));
check(end.indexOf('if not _editor_pause_active: return false')>=0 && end.indexOf('if not _editor_pause_active: return false')<end.indexOf('if not _editor_pause_current(receipt):'),'stale completed lease refuses without poisoning a new K cycle');
const preflight=end.indexOf('residents.can_end_editor_pause(receipt.residents) or not policy.can_end_editor_pause(receipt.policy) or not navigation.can_end_editor_pause(receipt.navigation)');
const release=end.indexOf('navigation.end_editor_pause(receipt.navigation)');
check(preflight>0&&release>preflight,'all three end receipts verified before nav release');
check(end.includes('_editor_terminal_hold(owner)'),'failed end re-pauses terminal HOLD');
check(resident.includes('if _editor_pause_active: _editor_pause_fault = true # Terminal teardown'),'resident dispose terminal');
check(population.includes('if _editor_pause_active: _editor_pause_fault = true # Terminal teardown.'),'population dispose terminal');
check(!resident.includes('func _editor_pause_state() -> Dictionary:\n\treturn snapshot()'),'not relying on incomplete public snapshot');
check(Object.keys(originals).length===3,'three stable checkpoint source pins');
const negative=fs.readFileSync(new URL('./test_population_pause_negatives.gd',import.meta.url),'utf8');
for(const marker of [
 'population.policy.dispose()',
 'body.position.x += 0.5',
 'population.residents._navigation = RefCounted.new()',
 'body.queue_free()',
 'population.navigation._geometry_valid = false',
 'population.navigation._queue._stats.admitted += 1',
 'queue drift does not release backend or queue',
 'fault.resident = population.residents',
 'var original_policy: RefCounted = population.policy',
 'population._editor_pause_terminal_hold',
 'population.navigation._editor_pause_active'
])check(negative.includes(marker),`opt-in native negative fixture: ${marker}`);
assert.throws(()=>patchResident('extends RefCounted'),/Expected one source seam/); checks++;
assert.throws(()=>patchPopulation('extends RefCounted'),/Expected one source seam/); checks++;
assert.throws(()=>patchPolicy('extends RefCounted'),/Expected one source seam/); checks++;
console.log(JSON.stringify({checks,failures:[],hashes:built.hashes}));
