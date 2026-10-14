import assert from 'node:assert/strict';
import fs from 'node:fs';
import path from 'node:path';
import crypto from 'node:crypto';
import {execFileSync} from 'node:child_process';
import {fileURLToPath} from 'node:url';
import {deriveWorkspace,buildCandidate} from './build_candidate.mjs';

const own=path.dirname(fileURLToPath(import.meta.url));
const root=path.resolve(own,'../../..');
const sourcePath=path.join(root,'tools/godot/map_editor_main_pause_candidate/pause_workspace.gd');
const mainPath=path.join(root,'godot/mafiozi_walk/scripts/main.gd');
const sha=bytes=>crypto.createHash('sha256').update(bytes).digest('hex');
const before=sha(fs.readFileSync(mainPath));
const original=fs.readFileSync(sourcePath,'utf8');
let checks=0;
function check(condition,label){assert.ok(condition,label);checks++;}
function exact(text,fragment){check(text.split(fragment).length===2,`exactly one ${fragment.slice(0,45)}`);}
const candidate=buildCandidate();
const workspace=candidate.workspace.toString('utf8');
exact(workspace,'func _pause_gameplay(request: Dictionary) -> Dictionary:');
exact(workspace,'func _verify_pause(receipt: Dictionary) -> bool:');
exact(workspace,'func _resume_gameplay(receipt: Dictionary, document: Dictionary, ground: Dictionary) -> Dictionary:');
exact(workspace,'func _notification(what: int) -> void:');
exact(workspace,'func _emergency_cancel(reason: String) -> void:');
check(workspace.includes('_main.preview_population.begin_editor_pause(_main)'),'real population lease acquired');
check(workspace.includes('while is_instance_valid(_main) and not _main.preview_ready and Time.get_ticks_msec() < deadline:'),'workspace waits for async resident-ready main before mounting');
check(workspace.indexOf('begin_editor_pause(_main)')<workspace.indexOf('clock.pause(_main, melee)'),'population before clock');
check(workspace.indexOf('clock.pause(_main, melee)')<workspace.indexOf('_pause_tree.paused = true\n\treturn {"ok":true,"receipt"'),'clock before tree pause');
check(workspace.includes('_main.preview_population.verify_editor_pause(_population_receipt)'),'lease verified on K entrance');
check(workspace.includes('_population_current() and not is_instance_valid(_main.preview_character_impacts)'),'no residents-off bypass in verification');
check(workspace.includes('population.prepare_editor_resume_atomic(_population_receipt)'),'atomic prepare');
check(workspace.includes('population.commit_editor_resume_atomic(ticket)'),'atomic commit');
check(workspace.includes('population.finalize_editor_resume_atomic(ticket)'),'atomic finalization');
check(workspace.includes('population.flush_editor_resume_atomic(ticket)'),'held callbacks flushed');
check(workspace.indexOf('population.commit_editor_resume_atomic(ticket)')<workspace.indexOf('clock.resume(_clock_receipt)'),'commit precedes clock');
check(workspace.indexOf('clock.resume(_clock_receipt)')<workspace.indexOf('population.finalize_editor_resume_atomic(ticket)'),'known one-way clock ordering hazard remains HOLD');
check(workspace.indexOf('population.finalize_editor_resume_atomic(ticket)')<workspace.indexOf('_pause_tree.paused = false'),'owners finalized before unpause');
check(workspace.indexOf('_pause_tree.paused = false')<workspace.indexOf('population.flush_editor_resume_atomic(ticket)'),'callback replay after unpause');
check(workspace.includes('if _owns_tree_pause:\n\t\t_terminal_hold("post_pause_cancel_refused")'),'post-pause rollback refuses');
check(workspace.includes('_terminal_hold("unsafe_recovery_refused:" + reason)'),'no implicit unsafe recovery');
check(!workspace.includes('if _main.preview_population != null or _main.preview_residents_enabled'),'residents-off admission removed');
check(workspace.includes('if _main.preview_population == null or not _main.preview_residents_enabled'),'default resident admission required');
for(const method of ['prepare_editor_resume_atomic','commit_editor_resume_atomic','abort_editor_resume_atomic','finalize_editor_resume_atomic','flush_editor_resume_atomic','cancel_editor_pause']){
  check(candidate.population.population.includes(`func ${method}(`),`population source exposes ${method}`);
  check(candidate.navigation.host.includes(`func ${method}(`),`nav source exposes ${method}`);
}
const corrupted=original.replace('func _resume_gameplay(receipt: Dictionary, document: Dictionary, ground: Dictionary) -> Dictionary:','func _resume_broken(receipt: Dictionary, document: Dictionary, ground: Dictionary) -> Dictionary:');
assert.throws(()=>deriveWorkspace(corrupted),/Missing\/ambiguous workspace block/);checks++;
const corruptedOwner=original.replace('preview_population == null','preview_population != null');
assert.throws(()=>deriveWorkspace(corruptedOwner),/Missing\/ambiguous workspace seam/);checks++;
const stageResult=JSON.parse(execFileSync(process.execPath,[path.join(own,'stage.mjs'),'--dry-run'],{cwd:root,encoding:'utf8'}));
check(stageResult.sourceFiles===192 && stageResult.defaultResidents===true && stageResult.pauseOnly===true,'exact resident checkpoint staged preflight');
check(stageResult.stageCreated===false && stageResult.godotRun===false && stageResult.gpu===false,'dry-run creates no stage or engine process');
check(sha(fs.readFileSync(mainPath))===before,'production main unchanged');
console.log(JSON.stringify({checks,failures:[],workspaceSha256:sha(candidate.workspace),sourceClosureSha256:stageResult.sourceClosureSha256,clockOrderingHazard:true,editorReady:false,scope:'source/static only; native parse and K runtime unverified'}));
