import fs from 'node:fs';
import path from 'node:path';
import crypto from 'node:crypto';
import {execFileSync} from 'node:child_process';
import {fileURLToPath} from 'node:url';
import {buildTeardownSource} from './teardown_variant.mjs';

const own=path.dirname(fileURLToPath(import.meta.url));
const sha=bytes=>crypto.createHash('sha256').update(bytes).digest('hex');
const candidate=buildTeardownSource();
const dry=process.argv.includes('--dry-run');
if(dry) {
  console.log(JSON.stringify({workspaceSha256:sha(candidate.workspace),guardSha256:sha(candidate.guard),stageCreated:false,production:false,gpu:false}));
  process.exit(0);
}
if(!process.argv.includes('--stage')) throw Error('Specify --dry-run or --stage');
const baseline=JSON.parse(execFileSync(process.execPath,[path.join(own,'stage.mjs'),'--stage','--clock-atomic'],{encoding:'utf8'}));
if(!baseline.clockAtomic || !baseline.stageCreated || !baseline.pauseOnly) throw Error('Unexpected baseline stage');
const stage=path.resolve(baseline.stage);
const manifestPath=path.join(stage,'source_snapshot.json');
const manifest=JSON.parse(fs.readFileSync(manifestPath,'utf8'));
const workspacePath=path.join(stage,'diagnostic/pause_workspace.gd');
const guardPath=path.join(stage,'diagnostic/teardown_guard.gd');
const old=fs.readFileSync(workspacePath);
if(sha(old)!==baseline.workspaceSha256) throw Error('Baseline workspace drift');
fs.writeFileSync(workspacePath,candidate.workspace);
fs.writeFileSync(guardPath,candidate.guard,{flag:'wx'});
const entry=manifest.files.find(file=>file.path==='diagnostic/pause_workspace.gd');
if(!entry || entry.sha256!==sha(old)) throw Error('Workspace manifest drift');
entry.sha256=sha(candidate.workspace); entry.bytes=candidate.workspace.length; entry.origin='teardown_variant';
manifest.files.push({path:'diagnostic/teardown_guard.gd',sha256:sha(candidate.guard),bytes:candidate.guard.length,origin:'teardown_variant'});
manifest.stagedFiles=manifest.files.length;
manifest.stagedBytes=manifest.files.reduce((sum,file)=>sum+file.bytes,0);
manifest.workspaceSha256=sha(candidate.workspace);
manifest.teardownGuardSha256=sha(candidate.guard);
manifest.teardownVariant=true;
manifest.nativeRun=false;
fs.writeFileSync(manifestPath,JSON.stringify(manifest,null,2));
console.log(JSON.stringify({stage,stageCreated:true,workspaceSha256:manifest.workspaceSha256,guardSha256:manifest.teardownGuardSha256,clockAtomic:true,pauseOnly:true,production:false,gpu:false}));
