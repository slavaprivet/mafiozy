import {buildSource as buildPauseSource} from '../map_editor_nav_pause_candidate/build_candidate.mjs';
import fs from 'node:fs';
import path from 'node:path';
import {fileURLToPath} from 'node:url';

const own=path.dirname(fileURLToPath(import.meta.url));
function once(source,needle,replacement){
 const at=source.indexOf(needle);
 if(at<0||source.indexOf(needle,at+needle.length)>=0)throw Error(`Missing/ambiguous source seam: ${needle.slice(0,70)}`);
 return source.slice(0,at)+replacement+source.slice(at+needle.length);
}
function replaceBlock(source,start,end,replacement){
 const a=source.indexOf(start),b=source.indexOf(end,a+start.length);
 if(a<0||b<0||source.indexOf(start,a+start.length)>=0)throw Error('Missing/ambiguous block');
 return source.slice(0,a)+replacement+source.slice(b);
}
const queueAtomic=`var _atomic_resume_ticket: Dictionary = {}
var _atomic_resume_serial := 0
var _atomic_resume_committed := false

func prepare_editor_resume_atomic(receipt: Dictionary) -> Dictionary:
\tif not _editor_pause_current(receipt) or _atomic_resume_committed: return {}
\tvar owner: Node = _editor_pause_owner.get_ref()
\tif not owner.get_tree().paused: return {}
\t_atomic_resume_serial += 1
\t_atomic_resume_ticket = {"serial":_atomic_resume_serial,"queue_id":get_instance_id(),"receipt":receipt.duplicate(true)}
\treturn _atomic_resume_ticket.duplicate(true)

func commit_editor_resume_atomic(ticket: Dictionary) -> Dictionary:
\tif not Thread.is_main_thread() or ticket.is_empty() or ticket != _atomic_resume_ticket or _atomic_resume_committed: return {}
\tif not _editor_pause_current(_atomic_resume_ticket.receipt): return {}
\tvar owner: Node = _editor_pause_owner.get_ref()
\tif not owner.get_tree().paused: return {}
\t_atomic_resume_committed = true
\treturn ticket.duplicate(true)

func abort_editor_resume_atomic(ticket: Dictionary) -> bool:
\tif not Thread.is_main_thread() or ticket.is_empty() or ticket != _atomic_resume_ticket or not _editor_pause_active: return false
\t_atomic_resume_committed = false; _atomic_resume_ticket.clear()
\treturn true

func finalize_editor_resume_atomic(ticket: Dictionary) -> bool:
\tif not Thread.is_main_thread() or ticket.is_empty() or ticket != _atomic_resume_ticket or not _atomic_resume_committed or not _editor_pause_active or _editor_pause_owner == null: return false
\tvar owner: Node = _editor_pause_owner.get_ref()
\tif not is_instance_valid(owner) or not owner.get_tree().paused: return false
\t_editor_pause_active = false
\t_editor_pause_receipt.clear(); _editor_pause_snapshot.clear(); _editor_pause_owner = null
\t_atomic_resume_committed = false; _atomic_resume_ticket.clear()
\treturn true

func cancel_editor_pause(receipt: Dictionary) -> bool:
\tif not can_end_editor_pause(receipt) or not _atomic_resume_ticket.is_empty(): return false
\t_editor_pause_active = false
\t_editor_pause_receipt.clear(); _editor_pause_snapshot.clear(); _editor_pause_owner = null
\treturn true

func end_editor_pause(_receipt: Dictionary) -> bool:
\treturn false # Old one-shot release cannot bypass the compound ticket.

`;
const hostAtomic=`var _atomic_resume_ticket: Dictionary = {}
var _atomic_resume_serial := 0
var _atomic_resume_committed := false
var _atomic_resume_flush_pending := false
var _atomic_resume_owner: WeakRef

func prepare_editor_resume_atomic(receipt: Dictionary) -> Dictionary:
\tif not _editor_receipt_current(receipt) or _atomic_resume_committed or _atomic_resume_flush_pending: return {}
\tvar owner: Node = _editor_pause_owner.get_ref()
\tif not owner.get_tree().paused: return {}
\tvar queue_ticket: Dictionary = _queue.prepare_editor_resume_atomic(receipt.queue)
\tif queue_ticket.is_empty(): return {}
\tvar backend_ticket: Dictionary = _backend.prepare_editor_resume_atomic(receipt.backend)
\tif backend_ticket.is_empty():
\t\tif not _queue.abort_editor_resume_atomic(queue_ticket): _editor_terminal_hold(owner)
\t\treturn {}
\t_atomic_resume_serial += 1
\t_atomic_resume_ticket = {"serial":_atomic_resume_serial,"host_id":get_instance_id(),"receipt":receipt.duplicate(true),"queue":queue_ticket,"backend":backend_ticket}
\treturn _atomic_resume_ticket.duplicate(true)

func commit_editor_resume_atomic(ticket: Dictionary) -> Dictionary:
\tif not Thread.is_main_thread() or ticket.is_empty() or ticket != _atomic_resume_ticket or _atomic_resume_committed or _atomic_resume_flush_pending: return {}
\tvar receipt: Dictionary = _atomic_resume_ticket.receipt
\tif not _editor_receipt_current(receipt): return {}
\tvar owner: Node = _editor_pause_owner.get_ref()
\tif not owner.get_tree().paused: return {}
\tif _queue.commit_editor_resume_atomic(ticket.queue).is_empty(): return {}
\tif _backend.commit_editor_resume_atomic(ticket.backend).is_empty():
\t\tif not _queue.abort_editor_resume_atomic(ticket.queue): _editor_terminal_hold(owner)
\t\treturn {}
\t_atomic_resume_committed = true
\treturn ticket.duplicate(true)

func abort_editor_resume_atomic(ticket: Dictionary) -> bool:
\tif not Thread.is_main_thread() or ticket.is_empty() or ticket != _atomic_resume_ticket or not _editor_pause_active: return false
\tvar queue_ok: bool = _queue.abort_editor_resume_atomic(ticket.queue)
\tvar backend_ok: bool = _backend.abort_editor_resume_atomic(ticket.backend)
\tif not queue_ok or not backend_ok:
\t\t_editor_terminal_hold(_editor_pause_owner.get_ref())
\t\treturn false
\t_atomic_resume_committed = false; _atomic_resume_ticket.clear()
\treturn true

func finalize_editor_resume_atomic(ticket: Dictionary) -> bool:
\tif not Thread.is_main_thread() or ticket.is_empty() or ticket != _atomic_resume_ticket or not _atomic_resume_committed or not _editor_pause_active: return false
\tvar owner: Node = _editor_pause_owner.get_ref()
\tif not is_instance_valid(owner) or not owner.get_tree().paused: return false
\t# The tickets were committed synchronously with the paused tree. Child finalizers
\t# only clear guards; the backend keeps callbacks queued until flush below.
\tif not _queue.finalize_editor_resume_atomic(ticket.queue) or not _backend.finalize_editor_resume_atomic(ticket.backend):
\t\t_editor_terminal_hold(owner)
\t\treturn false
\t_editor_pause_active = false; _editor_pause_receipt.clear(); _editor_pause_owner = null
\t_editor_pause_leaves.clear(); _editor_pause_doors.clear(); _editor_pause_queue = null
\t_atomic_resume_owner = weakref(owner)
\t_atomic_resume_committed = false; _atomic_resume_flush_pending = true
\treturn true

func flush_editor_resume_atomic(ticket: Dictionary) -> bool:
\tif not Thread.is_main_thread() or ticket.is_empty() or ticket != _atomic_resume_ticket or not _atomic_resume_flush_pending or _editor_pause_terminal_hold: return false
\tif not _backend.flush_editor_resume_atomic(ticket.backend):
\t\t_editor_terminal_hold(_atomic_resume_owner.get_ref() if _atomic_resume_owner != null else null)
\t\treturn false
\t_atomic_resume_flush_pending = false; _atomic_resume_ticket.clear(); _atomic_resume_owner = null
\treturn true

func cancel_editor_pause(receipt: Dictionary) -> bool:
\tif not can_end_editor_pause(receipt) or not _atomic_resume_ticket.is_empty() or not _backend.can_cancel_editor_pause(receipt.backend): return false
\tvar owner: Node = _editor_pause_owner.get_ref()
\tif not _queue.cancel_editor_pause(receipt.queue) or not _backend.cancel_editor_pause(receipt.backend):
\t\t_editor_terminal_hold(owner)
\t\treturn false
\t_editor_pause_active = false; _editor_pause_receipt.clear(); _editor_pause_owner = null
\t_editor_pause_leaves.clear(); _editor_pause_doors.clear(); _editor_pause_queue = null
\treturn true

func end_editor_pause(_receipt: Dictionary) -> bool:
\treturn false # No legacy one-shot release.

`;
export function buildAtomicSource(){
 const base=buildPauseSource();
 let queue=replaceBlock(base.queue.toString('utf8'),'func end_editor_pause(receipt: Dictionary) -> bool:\n','func _init(clock_usec: Callable',queueAtomic);
 let host=replaceBlock(base.host.toString('utf8'),'func end_editor_pause(receipt: Dictionary) -> bool:\n','func _reject_editor_write() -> bool:',hostAtomic);
 host=once(host,'const Backend = preload("res://scripts/navigation/pause_backend.gd")','const Backend = preload("res://scripts/navigation/atomic_backend.gd")');
 return {host:Buffer.from(host),queue:Buffer.from(queue),backend:fs.readFileSync(path.join(own,'atomic_backend.gd')),pauseBackend:fs.readFileSync(path.join(own,'../map_editor_nav_pause_candidate/pause_backend.gd'))};
}
if(process.argv[1]&&path.resolve(process.argv[1])===fileURLToPath(import.meta.url)){
 const src=buildAtomicSource();
 console.log(JSON.stringify(Object.fromEntries(Object.entries(src).map(([k,v])=>[k,v.length]))));
}
