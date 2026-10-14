import assert from 'node:assert/strict';
import { readFileSync } from 'node:fs';
import { resolve } from 'node:path';

const root = resolve(import.meta.dirname, '../../..');
const read = p => readFileSync(resolve(root, p), 'utf8');
const gate = read('tools/godot/map_editor_two_phase_resume_candidate/two_phase_resume.gd');
const main = read('tools/godot/map_editor_main_pause_candidate/pause_workspace.gd');
const pop = read('tools/godot/map_editor_resident_pause_candidate/build_candidate.mjs');
const nav = read('tools/godot/map_editor_nav_pause_candidate/build_candidate.mjs');
let checks = 0;
function check(ok, name) { assert.ok(ok, name); checks++; }
check(gate.includes('func prepare(') && gate.includes('func commit(') && gate.includes('func abort('), 'two phase source present');
check(gate.includes('workspace._verify_pause(main_receipt)') && gate.includes('population.verify_editor_pause(population_receipt)'), 'both receipts');
check(gate.includes('workspace._transaction_ready(main_receipt)'), 'neutral input and source bytes');
check(gate.includes('atomic_owner_api_missing') && gate.includes('editor_resume_contract_version'), 'missing owner fails closed');
check(gate.includes('return _hold(root, "atomic_commit_refused_or_ambiguous")'), 'late refusal holds');
check(gate.includes('root.get_tree().paused = true'), 'failed commit pauses tree');
check(gate.includes('abort_editor_resume_atomic') && gate.includes('editor_still_paused'), 'rollback reservation remains paused');
check(!main.includes('func prepare_editor_resume_atomic('), 'old main lacks atomic API');
check(main.includes('clock.resume(_clock_receipt)') && main.includes('_main.get_tree().paused = false'), 'old exit releases clock');
check(pop.includes('if not navigation.end_editor_pause(receipt.navigation):'), 'population nav first');
check(nav.includes('if not _queue.end_editor_pause(receipt.queue) or not _backend.end_editor_pause(receipt.backend):'), 'nav queue before backend');
console.log(`${checks} source checks passed; native and LIVE unrun`);
