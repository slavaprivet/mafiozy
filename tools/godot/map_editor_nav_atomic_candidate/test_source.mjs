import assert from 'node:assert/strict';
import {buildAtomicSource} from './build_candidate.mjs';
const src=buildAtomicSource();
for(const [name,bytes] of Object.entries(src)){
 const source=bytes.toString('utf8');
 for(const method of ['prepare_editor_resume_atomic','commit_editor_resume_atomic','abort_editor_resume_atomic','finalize_editor_resume_atomic']){
  if(name==='pauseBackend')continue;
  assert.equal((source.match(new RegExp(`func ${method}\\(`,'g'))||[]).length,1,`${name}:${method}`);
 }
 assert.ok(!source.includes('\r\n'),`${name}:LF`);
}
const host=src.host.toString('utf8'), backend=src.backend.toString('utf8'),queue=src.queue.toString('utf8');
assert.ok(host.includes('const Backend = preload("res://scripts/navigation/atomic_backend.gd")'));
assert.ok(host.includes('func flush_editor_resume_atomic(ticket: Dictionary) -> bool:'));
assert.ok(host.includes('func cancel_editor_pause(receipt: Dictionary) -> bool:'));
assert.ok(queue.includes('func cancel_editor_pause(receipt: Dictionary) -> bool:'));
assert.ok(backend.includes('func can_cancel_editor_pause(receipt: Dictionary) -> bool:'));
assert.ok(backend.includes('if _atomic_flush_pending:'));
assert.ok(backend.includes('_atomic_owner = weakref(owner)'));
assert.ok(backend.includes('owner.get_instance_id() == int(ticket.receipt.get("owner_id", -1)) and not owner.get_tree().paused'));
assert.ok(host.indexOf('_queue.finalize_editor_resume_atomic(ticket.queue)')<host.indexOf('_backend.finalize_editor_resume_atomic(ticket.backend)'));
assert.ok(host.indexOf('_backend.flush_editor_resume_atomic(ticket.backend)')>host.indexOf('func flush_editor_resume_atomic'));
// Negative source checks: each unsafe late-flush shape must be rejected.
function lateFlushSafe(source){
 const flush=source.slice(source.indexOf('func flush_editor_resume_atomic('),source.indexOf('func _atomic_flush_owner_current('));
 return source.includes('if _atomic_flush_pending or _atomic_flushing: return {}')
  && source.includes('if _atomic_flush_pending or _atomic_flushing:\n\t\t_editor_fault = true')
  && flush.includes('or _atomic_flushing or _editor_fault or _disposed: return false')
  && flush.indexOf('_atomic_flushing = true')<flush.indexOf('while not _held_completions.is_empty():')
  && flush.includes('var completion: Dictionary = _held_completions.pop_front()')
  && flush.indexOf('var completion: Dictionary = _held_completions.pop_front()')<flush.indexOf('super._finish_bake(')
  && flush.includes('_atomic_replayed >= MAX_HELD_COMPLETIONS')
  && flush.includes('if _editor_fault or _disposed or ticket != _atomic_ticket or not _atomic_flush_owner_current(ticket):')
  && flush.indexOf('_atomic_flush_pending = false')>flush.lastIndexOf('super._finish_query(');
}
assert.ok(lateFlushSafe(backend),'bounded replay retains guard until all callbacks finish');
for(const [index,unsafe] of [
 backend.replace('if _atomic_flush_pending or _atomic_flushing: return {}','if false: return {}'),
 backend.replace('if _atomic_flush_pending or _atomic_flushing:\n\t\t_editor_fault = true','if false:\n\t\t_editor_fault = true'),
 backend.replace('_atomic_replayed >= MAX_HELD_COMPLETIONS','false'),
 backend.replace('var completion: Dictionary = _held_completions.pop_front()','var completion: Dictionary = _held_completions[0]'),
 backend.replace('or _atomic_flushing or _editor_fault or _disposed: return false','or _editor_fault or _disposed: return false'),
 backend.replace('if _editor_fault or _disposed or ticket != _atomic_ticket or not _atomic_flush_owner_current(ticket):','if false:'),
 backend.replace('_atomic_flushing = true\n','_atomic_flushing = true\n\t_atomic_flush_pending = false\n'),
].entries()) assert.ok(!lateFlushSafe(unsafe),`unsafe late-flush mutation ${index} escaped source checks`);
console.log(JSON.stringify({sourceCheck:'PASS',hostBytes:src.host.length,queueBytes:src.queue.length,backendBytes:src.backend.length,native:'NOT_RUN',production:'NOT_INSTALLED'}));
