import assert from 'node:assert/strict';
import fs from 'node:fs';
import path from 'node:path';
import crypto from 'node:crypto';
import {fileURLToPath} from 'node:url';
import {buildSource,deriveClock,deriveWorkspace} from './build_candidate.mjs';
import {buildWorkspace} from '../map_editor_actual_k_composition_candidate/build_candidate.mjs';

const own = path.dirname(fileURLToPath(import.meta.url));
const root = path.resolve(own, '../../..');
const mainPath = path.join(root, 'godot/mafiozi_walk/scripts/main.gd');
const clockPath = path.join(root, 'tools/godot/map_editor_native_clock_candidate/gameplay_clock.gd');
const sha = bytes => crypto.createHash('sha256').update(bytes).digest('hex');
const mainBefore = sha(fs.readFileSync(mainPath));
const nativeBefore = sha(fs.readFileSync(clockPath));
const {clock,workspace,clockPin} = buildSource();
const c = clock.toString('utf8'), w = workspace.toString('utf8');
let checks = 0;
function check(ok,label) { assert.ok(ok,label); checks++; }
function index(source, needle) { const at=source.indexOf(needle); check(at>=0,`present: ${needle}`); check(source.indexOf(needle,at+needle.length)<0,`unique: ${needle}`); return at; }

check(clockPin === nativeBefore,'original gameplay clock pinned');
for (const method of ['prepare_resume','abort_resume','commit_resume','resume','now_ms','receipt_live']) index(c,`func ${method}(`);
check(c.includes('if not owner.get_tree().paused: return {}'),'prepare requires paused tree');
check(c.includes('if not _resume_ticket.is_empty() or not receipt_live(receipt): return false'),'legacy resume refuses editor ticket');
check(c.includes('if _resume_boundary_pending:\n\t\t_resume_boundary_pending = false\n\t\treturn _last_ms'),'original boundary semantics retained');
const commit = c.slice(index(c,'func commit_resume(ticket: Dictionary) -> bool:'),index(c,'func resume(receipt: Dictionary) -> bool:'));
check(!commit.includes('_live()') && !commit.includes('emit_signal') && !commit.includes('await '),'commit has no late external owner check/yield/callback');
check(commit.indexOf('_paused_total_ms +=') < commit.indexOf('_pause_wall_ms = -1.0'),'elapsed accounting before unpause');
check(commit.includes('_resume_boundary_pending = true'),'boundary monotonicity retained');

const prep = index(w,'clock.prepare_resume(_clock_receipt)');
const popPrep = index(w,'population.prepare_editor_resume_atomic(_population_receipt)');
const popCommit = index(w,'population.commit_editor_resume_atomic(ticket)');
const popFinalize = index(w,'population.finalize_editor_resume_atomic(ticket)');
const clockCommit = index(w,'clock.commit_resume(clock_ticket)');
const treeUnpause = index(w,'_pause_tree.paused = false');
check(prep<popPrep && popPrep<popCommit && popCommit<popFinalize && popFinalize<clockCommit && clockCommit<treeUnpause,'all owners finalize before clock commit, then tree unpause');
check(w.includes('if not clock.abort_resume(clock_ticket): _terminal_hold("clock_finalize_abort")'),'failed finalizer aborts clock ticket');
check(!w.includes('clock.resume(_clock_receipt)'),'old one-way clock call absent in workspace');
check(w.includes('_terminal_hold("clock_commit_after_finalize")'),'unexpected commit mismatch holds tree');
check(w.includes('if not population.flush_editor_resume_atomic(ticket):'),'callback flush retained');
check(sha(fs.readFileSync(mainPath))===mainBefore && sha(fs.readFileSync(clockPath))===nativeBefore,'no production or original-clock write');

assert.throws(()=>deriveClock(fs.readFileSync(clockPath,'utf8').replace('func resume(receipt: Dictionary) -> bool:', 'func resume_broken(receipt: Dictionary) -> bool:')),/Missing\/ambiguous clock resume block/); checks++;
assert.throws(()=>deriveWorkspace(buildWorkspace().replace('clock.resume(_clock_receipt)','clock.resume_broken(_clock_receipt)')),/Missing\/ambiguous seam/); checks++;
console.log(JSON.stringify({checks,failures:[],clockSha256:sha(clock),workspaceSha256:sha(workspace),production:false,nativeRun:false,editorReady:false,scope:'source/static only'}));
