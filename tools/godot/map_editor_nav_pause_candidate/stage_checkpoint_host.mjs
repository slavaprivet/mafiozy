import fs from 'node:fs';
import path from 'node:path';
import crypto from 'node:crypto';
import {fileURLToPath} from 'node:url';
import {patchNavigationHost,patchQueue} from './build_candidate.mjs';

// Immutable Coordinator 22 publication; never read a moving production file.
const own=path.dirname(fileURLToPath(import.meta.url));
const root=path.resolve(own,'../../..');
const checkpoint=path.join(root,'outputs','coordinator22_residents_checkpoint','godot','mafiozi_walk');
const outputRoot=path.join(root,'outputs');
const pins={
 'scripts/main.gd':'faac92194afdfac5efb4197a17a81d53738a91a46a6e41f96316f9c282112f53',
 'scenes/main.tscn':'52aa1629fe38251f27ab50e3c6c102e0d0073348d6f610319d6c6b0233618bde',
 'project.godot':'c500a17d372f149b4b751ed4ef90a5a27bcb55e1050ba9d510d33fb5bcf6ff28',
 'scripts/navigation/preview_engine_navigation.gd':'aca4ff31b689a5b652ca85ddd0999d45696debb912bb8e1495f056d02db69aab',
 'scripts/navigation/preview_navigation_host.gd':'0b6fd34bc1d77e1f27c2005b699477453f089f4f65bf7d21942e73adbad631d4',
 'scripts/navigation/path_job_queue.gd':'dc19de386ccef8e23dcf1c2f0b62f6a46f7f816cf8fd5c3c26c8a6409b7be473',
 'scripts/preview_printshop_interior.gd':'f6f082584ada23dcd55b384c629505730c80a59080768910a17c653d7eb1b5df',
 'scripts/preview_interior_finish.gd':'666bb28093d3bc9fbf17b702dda9c460d1364c64dee63c236b02fc9d80519ced'
};
const sha=bytes=>crypto.createHash('sha256').update(bytes).digest('hex');
function safe(p){
 let cursor=p;
 while(cursor!==path.dirname(cursor)){
  if(fs.existsSync(cursor)&&fs.lstatSync(cursor).isSymbolicLink())throw Error(`Symlink refused: ${cursor}`);
  cursor=path.dirname(cursor);
 }
 return p;
}
for(const p of [checkpoint,outputRoot,own])safe(p);
const dirs=['scripts','scenes','data','assets','addons'];
function collect(dir,destination){
 for(const entry of fs.readdirSync(dir,{withFileTypes:true})){
  const absolute=safe(path.join(dir,entry.name));
  if(entry.isSymbolicLink())throw Error(`Symlink refused: ${absolute}`);
  if(entry.isDirectory()){
   const relative=path.relative(checkpoint,absolute).split(path.sep).join('/');
   if(entry.name==='.godot'||relative==='scripts/tests')continue;
   collect(absolute,destination);
  }else if(entry.isFile())destination.push([path.relative(checkpoint,absolute).split(path.sep).join('/'),fs.readFileSync(absolute)]);
 }
}
function inventory(){
 const result=[];
 for(const dir of dirs)collect(path.join(checkpoint,dir),result);
 result.sort(([a],[b])=>a.localeCompare(b));
 return result;
}
function verifyInventory(initial){
 const current=inventory();
 if(current.length!==initial.length)throw Error(`Checkpoint path-set drift: ${initial.length}→${current.length}`);
 for(let i=0;i<initial.length;i++){
  const [expectedPath,expectedBytes]=initial[i];
  const [currentPath,currentBytes]=current[i];
  if(expectedPath!==currentPath||expectedBytes.length!==currentBytes.length||sha(expectedBytes)!==sha(currentBytes))throw Error(`Checkpoint path/byte drift: ${expectedPath} / ${currentPath}`);
 }
 if(sha(fs.readFileSync(path.join(checkpoint,'project.godot')))!==pins['project.godot'])throw Error('Checkpoint project drift');
}
const files=inventory();
if(files.length<10||files.length>2000)throw Error(`Implausible checkpoint closure: ${files.length}`);
const sourceBytes=files.reduce((sum,[,bytes])=>sum+bytes.length,0);
if(sourceBytes>180*1024*1024)throw Error(`Checkpoint source size exceeded: ${sourceBytes}`);
const sourceMap=new Map(files);
for(const [relative,expected] of Object.entries(pins)){
 const bytes=relative==='project.godot'?fs.readFileSync(path.join(checkpoint,relative)):sourceMap.get(relative);
 if(!bytes||sha(bytes)!==expected)throw Error(`Pinned checkpoint drift: ${relative}`);
}
const sourceClosureSha256=sha(Buffer.from(JSON.stringify(files.map(([relative,bytes])=>[relative,sha(bytes)]))));
const patchedHost=Buffer.from(patchNavigationHost(sourceMap.get('scripts/navigation/preview_navigation_host.gd').toString('utf8')));
const patchedQueue=Buffer.from(patchQueue(sourceMap.get('scripts/navigation/path_job_queue.gd').toString('utf8')));
const originalProject=fs.readFileSync(path.join(checkpoint,'project.godot'));
const isolatedProject=originalProject.toString('utf8').replace('config/custom_user_dir_name="MafioziGodotPreview"',`config/custom_user_dir_name="MafioziNavCheckpoint-${crypto.randomUUID()}"`);
if(isolatedProject===originalProject.toString('utf8'))throw Error('Checkpoint user-dir seam missing');
const test=fs.readFileSync(path.join(own,'test_actual_host_pause.gd'));
if(process.argv.includes('--dry-run')){
 verifyInventory(files);
 console.log(JSON.stringify({dryRun:true,stageCreated:false,checkpoint,sourceClosureCount:files.length,sourceClosureBytes:sourceBytes,sourceClosureSha256,mainSha256:pins['scripts/main.gd'],sceneSha256:pins['scenes/main.tscn'],projectSha256:pins['project.godot'],checkpointInteriorSha256:pins['scripts/preview_printshop_interior.gd'],checkpointFinishSha256:pins['scripts/preview_interior_finish.gd'],patchedHostSha256:sha(patchedHost),patchedQueueSha256:sha(patchedQueue),testSha256:sha(test),gpu:false}));
 process.exit(0);
}
const hostOverride='scripts/navigation/preview_navigation_host.gd';
const queueOverride='scripts/navigation/path_job_queue.gd';
const staged=[...files.filter(([relative])=>relative!==hostOverride&&relative!==queueOverride),[hostOverride,patchedHost],[queueOverride,patchedQueue],
 ['scripts/navigation/pause_backend.gd',fs.readFileSync(path.join(own,'pause_backend.gd'))],
 ['test_actual_host_pause.gd',test],['project.godot',Buffer.from(isolatedProject)]];
const stage=safe(fs.mkdtempSync(path.join(outputRoot,'map-editor-nav-checkpoint-')));
const receipt={schema:1,purpose:'Coordinator22 immutable checkpoint, actual main residents-off navigation host pause proof; not default-K admission',checkpoint,sourceClosureCount:files.length,sourceClosureBytes:sourceBytes,sourceClosureSha256,pins,projectDifference:'custom user directory only',patchedHostSha256:sha(patchedHost),patchedQueueSha256:sha(patchedQueue),testSha256:sha(test),files:[]};
for(const [relative,bytes] of staged){
 const dest=path.join(stage,relative);
 if(!dest.startsWith(stage+path.sep))throw Error(`Stage escape: ${relative}`);
 fs.mkdirSync(path.dirname(dest),{recursive:true});
 fs.writeFileSync(dest,bytes,{flag:'wx'});
 if(sha(fs.readFileSync(dest))!==sha(bytes))throw Error(`Stage copy mismatch: ${relative}`);
 receipt.files.push({path:relative,sha256:sha(bytes),bytes:bytes.length,origin:relative===hostOverride||relative===queueOverride||relative==='scripts/navigation/pause_backend.gd'||relative==='test_actual_host_pause.gd'?'candidate':relative==='project.godot'?'isolated-project':'checkpoint-source'});
}
verifyInventory(files);
fs.writeFileSync(path.join(stage,'source_snapshot.json'),JSON.stringify(receipt,null,2),{flag:'wx'});
console.log(JSON.stringify({stage,sourceClosureCount:files.length,sourceClosureBytes:sourceBytes,sourceClosureSha256,mainSha256:pins['scripts/main.gd'],sceneSha256:pins['scenes/main.tscn'],projectSha256:pins['project.godot'],patchedHostSha256:sha(patchedHost),patchedQueueSha256:sha(patchedQueue),testSha256:sha(test),gpu:false}));
