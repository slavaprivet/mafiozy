import assert from 'node:assert/strict';
import fs from 'node:fs';
import {fileURLToPath} from 'node:url';
import {buildSource,patchQueue,patchNavigationHost} from './build_candidate.mjs';

const source=buildSource();
const host=source.host.toString('utf8');
const queue=source.queue.toString('utf8');
const backend=fs.readFileSync(fileURLToPath(new URL('./pause_backend.gd',import.meta.url)),'utf8');
const native=fs.readFileSync(fileURLToPath(new URL('./test_editor_pause_receipt.gd',import.meta.url)),'utf8');
let checks=0;
const has=(text,needle)=>{assert(text.includes(needle),needle);checks++};
const guard=(signature,returnValue)=>{
 const start=host.indexOf(signature);
 assert(start>=0,signature);checks++;
 assert.equal(host.slice(start+signature.length).split('\n')[1].trim(),`if _reject_editor_write(): ${returnValue}`);checks++;
};
has(host,'const Backend = preload("res://scripts/navigation/pause_backend.gd")');
has(host,'scene != owner: return {}');
has(host,'owner.is_queued_for_deletion()');
has(host,'float(door.fraction) != float(door.target): return {}');
has(host,'float(door.target) != saved.target');
has(host,'door.node.transform != saved.pivot_transform');
has(host,'not _records.is_empty()');
for(const api of ['begin_editor_pause','verify_editor_pause','can_end_editor_pause','end_editor_pause','_editor_receipt_current'])has(host,`func ${api}(`);
for(const api of ['begin_editor_pause','verify_editor_pause','can_end_editor_pause','end_editor_pause','_editor_pause_current'])has(queue,`func ${api}(`);
has(host,'var queue_receipt: Dictionary = _queue.begin_editor_pause(owner)');
has(host,'"queue":queue_receipt');
has(host,'_queue.verify_editor_pause(receipt.queue) and _backend.verify_editor_pause(receipt.backend)');
has(host,'_queue.can_end_editor_pause(receipt.queue) and _backend.can_end_editor_pause(receipt.backend)');
has(host,'if not _queue.end_editor_pause(receipt.queue) or not _backend.end_editor_pause(receipt.backend):');
const hostEnd=host.slice(host.indexOf('func end_editor_pause(receipt: Dictionary) -> bool:'));
assert(hostEnd.indexOf('_queue.end_editor_pause(receipt.queue)') < hostEnd.indexOf('_backend.end_editor_pause(receipt.backend)'));checks++;
const hostPreflight=host.slice(host.indexOf('func can_end_editor_pause(receipt: Dictionary) -> bool:'),host.indexOf('func end_editor_pause(receipt: Dictionary) -> bool:'));
assert(!hostPreflight.includes('_backend.end_editor_pause(receipt.backend)')&&!hostPreflight.includes('_editor_pause_active = false'));checks++;
const queuePreflight=queue.slice(queue.indexOf('func can_end_editor_pause(receipt: Dictionary) -> bool:'),queue.indexOf('func end_editor_pause(receipt: Dictionary) -> bool:'));
assert(!queuePreflight.includes('_editor_pause_active = false')&&!queuePreflight.includes('_now()'));checks++;
has(queue,'if _disposed or _busy or not _native_enabled or not _queue.is_empty()');
has(queue,'if _editor_pause_write(): return false');
has(queue,'if _editor_pause_write(): return -1');
has(queue,'if _editor_pause_active: return {"error":"EDITOR_PAUSED"}');
for(const [signature,result] of [
 ['func door_transition_started(key: String, target_fraction: float) -> bool:','return false'],
 ['func update_access_version(version: int) -> bool:','return false'],
 ['func request(owner: RefCounted, body: CharacterBody3D, target: Vector3, trusted_admit: Callable) -> int:','return -1'],
 ['func step(id: int, delta: float, speed: float, gravity: float) -> Dictionary:','return {"status":"EDITOR_PAUSED"}'],
 ['func pump(frame_id: int) -> void:','return']
])guard(signature,result);
for(const api of ['_finish_bake','_finish_query','publish_source','request_path','admit_motion','poll','dispose'])has(backend,`func ${api}(`);
has(backend,'func can_end_editor_pause(receipt: Dictionary) -> bool:');
const backendPreflight=backend.slice(backend.indexOf('func can_end_editor_pause(receipt: Dictionary) -> bool:'),backend.indexOf('func end_editor_pause(receipt: Dictionary) -> bool:'));
assert(!backendPreflight.includes('_editor_paused = false')&&!backendPreflight.includes('super._finish_'));checks++;
has(backend,'_held_completions.append(completion)');
has(backend,'owner.is_queued_for_deletion()');
has(backend,'not _jobs.is_empty() or not _by_owner.is_empty()');
has(backend,'super._finish_bake(');
has(backend,'super._finish_query(');
has(native,'async_completions_held');
has(native,'door_rejected');
has(native,'host_step_rejected');
for(const negative of ['backend_stale_receipt_refused','backend_preflight_does_not_replay','queue_stale_receipt_refused','queue_preflight_no_release_or_clock_step','nonempty_queue_refused','queue_foreign_write_faults_receipt','fault_queue_cannot_release'])has(native,negative);
assert.throws(()=>patchQueue('extends RefCounted'),/Expected one source seam/);checks++;
assert.throws(()=>patchNavigationHost('extends RefCounted'),/Expected one source seam/);checks++;
console.log(JSON.stringify({suite:'navigation-editor-pause-source-seam',checks,failures:[],nativeExecuted:false,productionChanged:false}));
