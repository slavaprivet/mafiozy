import fs from 'node:fs';import path from 'node:path';import crypto from 'node:crypto';
const root=fs.realpathSync(process.cwd()),arg=process.argv[2];if(!arg)throw Error('Explicit stage required');
const stage=fs.realpathSync(arg),outputs=fs.realpathSync(path.join(root,'outputs'));
if(!stage.startsWith(outputs+path.sep)||!path.basename(stage).startsWith('actual-main-pause-probe-'))throw Error('Stage outside validated outputs');
function safe(p){let q=p;while(q!==path.dirname(q)){if(fs.lstatSync(q).isSymbolicLink())throw Error('Symlink');q=path.dirname(q);}return p;}
safe(stage);const sha=b=>crypto.createHash('sha256').update(b).digest('hex');
const snapshot=JSON.parse(fs.readFileSync(safe(path.join(stage,'source_snapshot.json')))),checked=[],currentSourceDrift=[];
for(const r of snapshot.files){if(['probe.gd','project.godot'].includes(r.path)||r.path.endsWith('.import'))continue;
const s=safe(path.join(root,'godot/mafiozi_walk',r.path)),d=safe(path.join(stage,r.path));
if(sha(fs.readFileSync(d))!==r.sha256)throw Error('Staged raw source changed '+r.path);const current=sha(fs.readFileSync(s));if(current!==r.sha256)currentSourceDrift.push({path:r.path,snapshotSha256:r.sha256,currentSha256:current});checked.push(r.path);}
const probe=fs.readFileSync(safe(path.join(stage,'probe.gd')));if(sha(probe)!==sha(fs.readFileSync(path.join(root,'tools/godot/map_editor_actual_pause_probe/probe.gd'))))throw Error('Probe mismatch');
const reportRaw=fs.readFileSync(safe(path.join(stage,'CPU_REPORT.json'))),report=JSON.parse(reportRaw);
if(!report.diagnostic_pass||report.editor_pause_ready!==false||report.gpu!==false)throw Error('Diagnostic failed or unsafe claim');
const receipt={schema:1,revision:snapshot.revision,mainSha256:snapshot.files.find(x=>x.path==='scripts/main.gd').sha256,probeSha256:sha(probe),reportSha256:sha(reportRaw),rawSourceFilesReverified:checked.length,currentSourceDrift,currentSourceMatchesSnapshot:currentSourceDrift.length===0,originalImportConfigurationsPinnedBeforeIsolatedImport:true,importedCachesAreDerivedNotAdmitted:true,engine:'4.7.2.stable.official.ed1daf0bf',headless:true,gpu:false,actualNavCompletionTested:false,editorPauseReady:false,diagnosticPass:true};
fs.writeFileSync(path.join(stage,'FINAL_DIAGNOSTIC_RECEIPT.json'),JSON.stringify(receipt,null,2),{flag:'wx'});console.log(JSON.stringify(receipt));
