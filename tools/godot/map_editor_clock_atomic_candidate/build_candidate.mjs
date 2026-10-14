import fs from 'node:fs';
import path from 'node:path';
import crypto from 'node:crypto';
import {fileURLToPath} from 'node:url';
import {buildWorkspace} from '../map_editor_actual_k_composition_candidate/build_candidate.mjs';

const own = path.dirname(fileURLToPath(import.meta.url));
const root = path.resolve(own, '../../..');
const clockPath = path.join(root, 'tools/godot/map_editor_native_clock_candidate/gameplay_clock.gd');
const clockPin = '842d7d811490a993248e22c7f6844afd41d0d58a184b868188abf9aa8505e160';
const sha = bytes => crypto.createHash('sha256').update(bytes).digest('hex');

function once(source, needle, replacement) {
  const at = source.indexOf(needle);
  if (at < 0 || source.indexOf(needle, at + needle.length) >= 0) throw Error(`Missing/ambiguous seam: ${needle.slice(0, 75)}`);
  return source.slice(0, at) + replacement + source.slice(at + needle.length);
}

export function deriveClock(source) {
  let out = once(source, 'var _resume_boundary_pending := false', 'var _resume_boundary_pending := false\nvar _resume_ticket: Dictionary = {}');
  const start = out.indexOf('func resume(receipt: Dictionary) -> bool:\n');
  const end = out.indexOf('func is_paused() -> bool:', start);
  if (start < 0 || end < 0 || out.indexOf('func resume(receipt: Dictionary) -> bool:\n', start + 1) >= 0) throw Error('Missing/ambiguous clock resume block');
  out = out.slice(0, start) + `# Prepare while the scene tree and every gameplay owner are still paused.
# No wall-time change occurs until commit. The ticket belongs to this pause serial.
func prepare_resume(receipt: Dictionary) -> Dictionary:
\tif not receipt_live(receipt) or _resume_ticket.size() != 0: return {}
\tvar owner: Node3D = _owner.get_ref()
\tif not owner.get_tree().paused: return {}
\t_resume_ticket = {"serial":_serial,"generation":_generation,"clock":self,"pause_wall_ms":_pause_wall_ms}
\treturn _resume_ticket.duplicate(true)

func abort_resume(ticket: Dictionary) -> bool:
\tif _resume_ticket.is_empty() or ticket != _resume_ticket or _pause_wall_ms < 0.0: return false
\t_resume_ticket.clear()
\treturn true

# This is deliberately the last owner mutation before tree unpause. Population
# finalizers may refuse; in that case the clock remains paused. This commit is
# arithmetic and private-state mutation only: no _live(), signals or callbacks.
# A ticket mismatch is a terminal HOLD, never permission to unpause.
func commit_resume(ticket: Dictionary) -> bool:
\tif _resume_ticket.is_empty() or ticket != _resume_ticket or _pause_wall_ms < 0.0: return false
\t_paused_total_ms += maxf(0.0, Time.get_ticks_usec() / 1000.0 - _pause_wall_ms)
\t_pause_wall_ms = -1.0
\t_resume_boundary_pending = true
\t_resume_ticket.clear()
\treturn true

# Keep the original one-step contract for non-editor users; a staged editor
# ticket cannot be bypassed through this route.
func resume(receipt: Dictionary) -> bool:
\tif not _resume_ticket.is_empty() or not receipt_live(receipt): return false
\t_paused_total_ms += maxf(0.0, Time.get_ticks_usec() / 1000.0 - _pause_wall_ms)
\t_pause_wall_ms = -1.0
\t_resume_boundary_pending = true
\treturn true

` + out.slice(end);
  return out;
}

export function deriveWorkspace(source) {
  let out = once(source, 'if not clock.receipt_live(_clock_receipt): return {"ok":false,"reason":"clock_receipt"}', 'if not clock.receipt_live(_clock_receipt): return {"ok":false,"reason":"clock_receipt"}\n\tvar clock_ticket: Dictionary = clock.prepare_resume(_clock_receipt)\n\tif clock_ticket.is_empty(): return {"ok":false,"reason":"clock_prepare"}');
  out = once(out, 'if ticket.is_empty(): return {"ok":false,"reason":"population_prepare"}', 'if ticket.is_empty():\n\t\tif not clock.abort_resume(clock_ticket): _terminal_hold("clock_prepare_abort")\n\t\treturn {"ok":false,"reason":"population_prepare"}');
  out = once(out, 'if not population.abort_editor_resume_atomic(ticket): _terminal_hold("population_commit_abort")', 'if not population.abort_editor_resume_atomic(ticket): _terminal_hold("population_commit_abort")\n\t\tif not clock.abort_resume(clock_ticket): _terminal_hold("clock_commit_abort")');
  out = once(out, `\t# No await, deferred call or event-loop turn from commit through finalization,
\t# tree unpause and callback flush. Clock resumes while the tree is still held.
\tif not clock.resume(_clock_receipt):
\t\tif not population.abort_editor_resume_atomic(ticket): _terminal_hold("clock_resume_abort")
\t\treturn {"ok":false,"reason":"clock_resume"}
\tif not population.finalize_editor_resume_atomic(ticket):
\t\t_terminal_hold("population_finalize")
\t\treturn {"ok":false,"reason":status}`, `\t# No await, deferred call or event-loop turn until owners are finalized,
\t# clock committed, and tree unpaused. A failed finalizer keeps clock paused.
\tif not population.finalize_editor_resume_atomic(ticket):
\t\tif not clock.abort_resume(clock_ticket): _terminal_hold("clock_finalize_abort")
\t\t_terminal_hold("population_finalize")
\t\treturn {"ok":false,"reason":status}
\tif not clock.commit_resume(clock_ticket):
\t\t_terminal_hold("clock_commit_after_finalize")
\t\treturn {"ok":false,"reason":status}`);
  return out;
}

export function buildSource() {
  const source = fs.readFileSync(clockPath);
  if (sha(source) !== clockPin) throw Error('Pinned gameplay clock source drift');
  return {clock: Buffer.from(deriveClock(source.toString('utf8'))), workspace: Buffer.from(deriveWorkspace(buildWorkspace())), clockPin};
}

if (process.argv[1] && path.resolve(process.argv[1]) === fileURLToPath(import.meta.url)) {
  const candidate = buildSource();
  console.log(JSON.stringify({clockPin,clockSha256:sha(candidate.clock),workspaceSha256:sha(candidate.workspace),production:false,nativeRun:false}));
}
