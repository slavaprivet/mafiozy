import fs from 'node:fs';
import path from 'node:path';
import crypto from 'node:crypto';
import {fileURLToPath} from 'node:url';
import {buildSource} from './build_candidate.mjs';

const own=path.dirname(fileURLToPath(import.meta.url));
const root=path.resolve(own,'../../..');
const sourceRoot=path.join(root,'godot','mafiozi_walk');
const outputRoot=path.join(root,'outputs');
const expected={
 'scripts/main.gd':'faac92194afdfac5efb4197a17a81d53738a91a46a6e41f96316f9c282112f53',
 'scenes/main.tscn':'b30a6aca7fef43d24ca4027f957fc411bd0bcddd36555a03ec646cee0e2689a6',
 'project.godot':'f7c9f0509cac7d8dc70ab81919cac2fcdc5444292d67a3df8e362eb40bb2e087'
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
for(const p of [sourceRoot,outputRoot,own])safe(p);
const files=[];
function collect(dir,destination){
 for(const entry of fs.readdirSync(dir,{withFileTypes:true})){
  const absolute=safe(path.join(dir,entry.name));
  if(entry.isSymbolicLink())throw Error(`Symlink refused: ${absolute}`);
  if(entry.isDirectory()){
   if(entry.name==='.godot')continue; // import cache, never source
   if(path.relative(sourceRoot,absolute).split(path.sep).join('/')==='scripts/tests')continue; // game bootstrap does not depend on test fixtures
   collect(absolute,destination);
  }
  else if(entry.isFile())destination.push([path.relative(sourceRoot,absolute).split(path.sep).join('/'),fs.readFileSync(absolute)]);
 }
}
const dirs=['scripts','scenes','data','assets','addons'];
for(const dir of dirs)collect(path.join(sourceRoot,dir),files);
files.sort(([a],[b])=>a.localeCompare(b));
function verifyCurrentClosure(initial){
 const current=[];
 for(const dir of dirs)collect(path.join(sourceRoot,dir),current);
 const expectedFiles=new Map(initial.map(([relative,bytes])=>[relative,{sha256:sha(bytes),bytes:bytes.length}]));
 if(current.length!==initial.length||expectedFiles.size!==initial.length)throw Error(`Concurrent source path-set drift: initial=${initial.length} current=${current.length}`);
 const seen=new Set();
 for(const [relative,bytes] of current){
  if(seen.has(relative)||!expectedFiles.has(relative))throw Error(`Concurrent source path-set drift: ${relative}`);
  seen.add(relative);
  const expectedFile=expectedFiles.get(relative);
  if(bytes.length!==expectedFile.bytes||sha(bytes)!==expectedFile.sha256)throw Error(`Concurrent source byte drift: ${relative}`);
 }
 if(seen.size!==expectedFiles.size)throw Error('Concurrent source path-set drift: removed path');
}
if(files.length<10||files.length>2000)throw Error(`Implausible source closure count: ${files.length}`);
const sourceMap=new Map(files);
for(const [relative,digest] of Object.entries(expected)){
 const bytes=relative==='project.godot'?fs.readFileSync(path.join(sourceRoot,relative)):sourceMap.get(relative);
 if(!bytes||sha(bytes)!==digest)throw Error(`Pinned actual source drift: ${relative}`);
}
const closureBytes=files.reduce((sum,[,bytes])=>sum+bytes.length,0);
if(closureBytes>180*1024*1024)throw Error(`Stage source size exceeded: ${closureBytes}`);
const closureSha256=sha(Buffer.from(JSON.stringify(files.map(([relative,bytes])=>[relative,sha(bytes)]))));
if(!/^[0-9a-f]{64}$/.test(closureSha256))throw Error('Missing source closure digest');
const source=buildSource();
const originalProject=fs.readFileSync(path.join(sourceRoot,'project.godot'));
const projectText=originalProject.toString('utf8');
const changedProject=projectText.replace('config/custom_user_dir_name="MafioziGodotPreview"',`config/custom_user_dir_name="MafioziNavPause-${crypto.randomUUID()}"`);
if(changedProject===projectText)throw Error('Isolated user directory seam missing');
if(process.argv.includes('--dry-run')){
 verifyCurrentClosure(files);
 if(sha(fs.readFileSync(path.join(sourceRoot,'project.godot')))!==expected['project.godot'])throw Error('Concurrent project drift');
 console.log(JSON.stringify({dryRun:true,sourceClosureCount:files.length,sourceClosureBytes:closureBytes,sourceClosureSha256:closureSha256,mainSha256:expected['scripts/main.gd'],sceneSha256:expected['scenes/main.tscn'],projectSha256:expected['project.godot'],patchedHostSha256:sha(source.host),patchedQueueSha256:sha(source.queue),stageCreated:false,headless:true,gpu:false}));
 process.exit(0);
}
const hostOverride='scripts/navigation/preview_navigation_host.gd';
const queueOverride='scripts/navigation/path_job_queue.gd';
const staged=[...files.filter(([relative])=>relative!==hostOverride&&relative!==queueOverride),[hostOverride,source.host],[queueOverride,source.queue],
 ['scripts/navigation/pause_backend.gd',fs.readFileSync(path.join(own,'pause_backend.gd'))],
 ['test_actual_host_pause.gd',fs.readFileSync(path.join(own,'test_actual_host_pause.gd'))],
 ['project.godot',Buffer.from(changedProject)]];
const stage=safe(fs.mkdtempSync(path.join(outputRoot,'map-editor-nav-actual-host-')));
const receipt={schema:1,purpose:'actual main residents-off native navigation host pause proof; not default-K admission',sourceClosureCount:files.length,sourceClosureBytes:closureBytes,sourceClosureSha256:closureSha256,mainSha256:expected['scripts/main.gd'],sceneSha256:expected['scenes/main.tscn'],projectSha256:expected['project.godot'],projectDifference:'isolated custom user directory only',overriddenHostSha256:sha(source.host),overriddenQueueSha256:sha(source.queue),testSha256:sha(staged.find(([relative])=>relative==='test_actual_host_pause.gd')[1]),files:[]};
for(const [relative,bytes] of staged){
 const dest=path.join(stage,relative);
 if(!dest.startsWith(stage+path.sep))throw Error(`Stage escape: ${relative}`);
 fs.mkdirSync(path.dirname(dest),{recursive:true});
 fs.writeFileSync(dest,bytes,{flag:'wx'});
 if(sha(fs.readFileSync(dest))!==sha(bytes))throw Error(`Stage copy mismatch: ${relative}`);
 receipt.files.push({path:relative,sha256:sha(bytes),bytes:bytes.length,origin:relative===hostOverride||relative===queueOverride||relative==='scripts/navigation/pause_backend.gd'||relative==='test_actual_host_pause.gd'?'candidate':relative==='project.godot'?'isolated-project':'actual-source'});
}
verifyCurrentClosure(files);
if(sha(fs.readFileSync(path.join(sourceRoot,'project.godot')))!==expected['project.godot'])throw Error('Concurrent project drift');
fs.writeFileSync(path.join(stage,'source_snapshot.json'),JSON.stringify(receipt,null,2),{flag:'wx'});
console.log(JSON.stringify({stage,sourceClosureCount:files.length,sourceClosureBytes:closureBytes,mainSha256:receipt.mainSha256,sceneSha256:receipt.sceneSha256,projectSha256:receipt.projectSha256,overriddenHostSha256:receipt.overriddenHostSha256,overriddenQueueSha256:receipt.overriddenQueueSha256,testSha256:receipt.testSha256,headless:true,gpu:false}));
