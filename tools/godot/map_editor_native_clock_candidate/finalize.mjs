import fs from 'node:fs';
import path from 'node:path';
import crypto from 'node:crypto';

const root=fs.realpathSync(process.cwd());
const outputRoot=fs.realpathSync(path.join(root,'outputs'));
const own=fs.realpathSync(path.join(root,'tools/godot/map_editor_native_clock_candidate'));
const source=fs.realpathSync(path.join(root,'godot/mafiozi_walk'));
const arg=process.argv[2];if(!arg)throw Error('Explicit stage required');
const stage=fs.realpathSync(arg);
if(!stage.startsWith(outputRoot+path.sep)||!path.basename(stage).startsWith('actual-native-clock-'))throw Error('Invalid stage');
function safe(p){let q=p;while(q!==path.dirname(q)){if(fs.lstatSync(q).isSymbolicLink())throw Error('Symlink refused '+q);q=path.dirname(q);}return p;}
safe(stage);
const sha=b=>crypto.createHash('sha256').update(b).digest('hex');
const manifest=JSON.parse(fs.readFileSync(safe(path.join(stage,'source_snapshot.json'))));
const sourceDrift=[];let stagedSourceVerified=0,candidatesVerified=0;
for(const row of manifest.files){
  const dest=safe(path.join(stage,row.path));
  if(row.path.endsWith('.import'))continue; // Godot importer owns derived config fields after import.
  if(sha(fs.readFileSync(dest))!==row.sha256)throw Error('Staged file changed '+row.path);
  if(row.origin==='candidate'){
    const current=sha(fs.readFileSync(safe(path.join(own,path.basename(row.path)))));
    if(current!==row.sha256)throw Error('Candidate changed '+row.path);
    candidatesVerified++;
  }else if(row.origin==='source'){
    const current=sha(fs.readFileSync(safe(path.join(source,row.path))));
    if(current!==row.sha256)sourceDrift.push({path:row.path,snapshotSha256:row.sha256,currentSha256:current});
    stagedSourceVerified++;
  }
}
if(sha(fs.readFileSync(safe(path.join(source,'project.godot'))))!==manifest.originalProjectSha256)sourceDrift.push({path:'project.godot'});
if(sha(fs.readFileSync(safe(path.join(source,'scenes/main.tscn'))))!==manifest.originalSceneSha256)sourceDrift.push({path:'scenes/main.tscn'});
const reportRaw=fs.readFileSync(safe(path.join(stage,'CPU_REPORT.json')));
const report=JSON.parse(reportRaw);
if(report.diagnostic_pass!==true||report.gpu!==false||report.editor_pause_ready!==false||report.source_parity_claim!==false||report.actual_navigation_tested!==false||report.failures.length)throw Error('Diagnostic failed or claim exceeded');
if(!(report.initial_clock.wall_before_ms-1<=report.initial_clock.candidate_ms&&report.initial_clock.candidate_ms<=report.initial_clock.wall_after_ms+1&&report.first_attack.original_seq===1&&report.first_attack.candidate_seq===1&&report.first_attack.original_cooldown&&report.first_attack.candidate_cooldown&&report.first_attack.original_timers===report.first_attack.candidate_timers&&report.first_attack.candidate_wall_before_ms-1<=report.first_attack.candidate_last_punch_ms&&report.first_attack.candidate_last_punch_ms<=report.first_attack.candidate_wall_after_ms+1))throw Error('Initial absolute clock/native first attack evidence incomplete');
if(!(report.pause.wall_elapsed_us>=650000&&report.pause.entry_clock_ms===report.pause.lease_at_ms&&report.pause.clock_after_pause_ms===report.pause.lease_at_ms&&report.resume.release_boundary_clock_ms===report.pause.lease_at_ms&&report.pause.clock_delta_ms===0&&report.pause.body_tick_before===report.pause.body_tick_after&&report.pause.cooldown&&report.resume.immediate_cooldown&&report.resume.early_wall_us>=100000&&report.resume.early_wall_us<280000&&report.resume.at_100ms_cooldown&&report.resume.drained_wall_us>=370000&&!report.resume.after_370ms_cooldown&&report.resume.source_timers===0))throw Error('Clock/physics evidence incomplete');
const receipt={schema:1,engine:'4.7.2.stable.official.ed1daf0bf',headless:true,gpu:false,actualMainSha256:manifest.mainSha256,actualMeleeHostSha256:manifest.meleeHostSha256,originalSceneSha256:manifest.originalSceneSha256,reportSha256:sha(reportRaw),candidateSha256:Object.fromEntries(manifest.files.filter(r=>r.origin==='candidate').map(r=>[path.basename(r.path),r.sha256])),stagedSourceVerified,candidatesVerified,sourceDrift,currentSourceMatchesSnapshot:sourceDrift.length===0,actualNavigationTested:false,editorPauseReady:false,diagnosticPass:true};
fs.writeFileSync(path.join(stage,'FINAL_DIAGNOSTIC_RECEIPT.json'),JSON.stringify(receipt,null,2),{flag:'wx'});
console.log(JSON.stringify(receipt));
