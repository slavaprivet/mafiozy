import fs from 'node:fs';
import path from 'node:path';
import crypto from 'node:crypto';
import {fileURLToPath} from 'node:url';
import {buildSource as buildResidents} from './build_candidate.mjs';
import {buildSource as buildNavigation} from '../map_editor_nav_pause_candidate/build_candidate.mjs';

const own=path.dirname(fileURLToPath(import.meta.url));
const root=path.resolve(own,'../../..');
const sourceRoot=path.join(root,'outputs','coordinator22_residents_checkpoint','godot','mafiozi_walk');
const outputRoot=path.join(root,'outputs');
const checkpointPins={
 sourceClosureSha256:'cbd7182488cbaf56a72017c8be101b4bfdf4c9c45e9088e1d414324a7e435ba6',
 mainSha256:'faac92194afdfac5efb4197a17a81d53738a91a46a6e41f96316f9c282112f53',
 sceneSha256:'52aa1629fe38251f27ab50e3c6c102e0d0073348d6f610319d6c6b0233618bde',
 projectSha256:'c500a17d372f149b4b751ed4ef90a5a27bcb55e1050ba9d510d33fb5bcf6ff28',
 navBackendSha256:'aca4ff31b689a5b652ca85ddd0999d45696debb912bb8e1495f056d02db69aab',
 navHostSha256:'0b6fd34bc1d77e1f27c2005b699477453f089f4f65bf7d21942e73adbad631d4',
 navQueueSha256:'dc19de386ccef8e23dcf1c2f0b62f6a46f7f816cf8fd5c3c26c8a6409b7be473'
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
const dirs=['scripts','scenes','data','assets','addons'];
function closure(){
 const files=[];
 function collect(dir){
  for(const entry of fs.readdirSync(dir,{withFileTypes:true})){
   const absolute=safe(path.join(dir,entry.name));
   if(entry.isSymbolicLink())throw Error(`Symlink refused: ${absolute}`);
   if(entry.isDirectory()){
    if(entry.name!=='.godot'&&entry.name!=='tests')collect(absolute);
   }else if(entry.isFile())files.push([path.relative(sourceRoot,absolute).split(path.sep).join('/'),fs.readFileSync(absolute)]);
  }
 }
 for(const dir of dirs)collect(path.join(sourceRoot,dir));
 files.sort(([a],[b])=>a.localeCompare(b));
 return files;
}
const files=closure();
if(files.length===0)throw Error('Empty actual source closure');
const sourceMap=new Map(files);
const projectOriginal=fs.readFileSync(path.join(sourceRoot,'project.godot'));
const main=sourceMap.get('scripts/main.gd');
const scene=sourceMap.get('scenes/main.tscn');
if(!main||!scene||!main.toString('utf8').includes('preload("res://scripts/preview_population.gd")'))throw Error('Actual main/population seam missing');
const sourceSnapshotAnchors={'scripts/main.gd':sha(main),'scenes/main.tscn':sha(scene),'project.godot':sha(projectOriginal)};
for(const [relative,expected] of [['scripts/main.gd',checkpointPins.mainSha256],['scenes/main.tscn',checkpointPins.sceneSha256],['project.godot',checkpointPins.projectSha256],['scripts/navigation/preview_engine_navigation.gd',checkpointPins.navBackendSha256],['scripts/navigation/preview_navigation_host.gd',checkpointPins.navHostSha256],['scripts/navigation/path_job_queue.gd',checkpointPins.navQueueSha256]]){
 const bytes=relative==='project.godot'?projectOriginal:sourceMap.get(relative);
 if(!bytes||sha(bytes)!==expected)throw Error(`Pinned checkpoint drift: ${relative}`);
}
const total=files.reduce((sum,[,bytes])=>sum+bytes.length,0);
if(total>180*1024*1024)throw Error(`Source closure too large: ${total}`);
const closureDigest=sha(Buffer.from(JSON.stringify(files.map(([relative,bytes])=>[relative,sha(bytes)]))));
if(closureDigest!==checkpointPins.sourceClosureSha256)throw Error(`Pinned checkpoint closure drift: ${closureDigest}`);
const residents=buildResidents();
const nav=buildNavigation();
const navBackendPatch=fs.readFileSync(path.join(own,'../map_editor_nav_pause_candidate/pause_backend.gd'));
const project=projectOriginal.toString('utf8').replace('config/custom_user_dir_name="MafioziGodotPreview"',`config/custom_user_dir_name="MafioziResidentPause-${crypto.randomUUID()}"`);
if(project===projectOriginal.toString('utf8'))throw Error('Isolated user directory seam missing');
const overrides=new Map([
 ['scripts/preview_population.gd',Buffer.from(residents.population)],
 ['scripts/npc_visual/preview_resident_host.gd',Buffer.from(residents.resident)],
 ['scripts/npc_visual/preview_resident_world_policy.gd',Buffer.from(residents.policy)],
 ['scripts/navigation/preview_navigation_host.gd',nav.host],
 ['scripts/navigation/path_job_queue.gd',nav.queue],
 ['scripts/navigation/pause_backend.gd',navBackendPatch],
 ['test_actual_population_pause.gd',fs.readFileSync(path.join(own,'test_actual_population_pause.gd'))],
 ['test_population_pause_negatives.gd',fs.readFileSync(path.join(own,'test_population_pause_negatives.gd'))],
 ['project.godot',Buffer.from(project)]
]);
function verifyClosure(){
 const current=closure();
 if(current.length!==files.length)throw Error('Concurrent source path-set drift');
 for(let i=0;i<files.length;i++)if(current[i][0]!==files[i][0]||sha(current[i][1])!==sha(files[i][1]))throw Error(`Concurrent source byte drift: ${files[i][0]}`);
 if(sha(fs.readFileSync(path.join(sourceRoot,'project.godot')))!==sourceSnapshotAnchors['project.godot'])throw Error('Concurrent project drift');
}
if(process.argv.includes('--dry-run')){
 verifyClosure();
 console.log(JSON.stringify({dryRun:true,sourceClosureCount:files.length,sourceClosureBytes:total,sourceClosureSha256:closureDigest,sourceSnapshotAnchors,residentHashes:residents.hashes,navHostSha256:sha(nav.host),navQueueSha256:sha(nav.queue),navBackendPauseSha256:sha(navBackendPatch),stageCreated:false,gpu:false}));
 process.exit(0);
}
const stage=safe(fs.mkdtempSync(path.join(outputRoot,'map-editor-resident-pause-')));
const staged=[...files.filter(([relative])=>!overrides.has(relative)),...overrides];
const receipt={schema:1,purpose:'stable checkpoint three-preview-resident pause seam, not default-K',sourceClosureCount:files.length,sourceClosureBytes:total,sourceClosureSha256:closureDigest,sourceSnapshotAnchors,checkpointPins,residentHashes:residents.hashes,navHostSha256:sha(nav.host),navQueueSha256:sha(nav.queue),navBackendPauseSha256:sha(navBackendPatch),files:[]};
for(const [relative,bytes] of staged){
 const dest=path.join(stage,relative);
 if(!dest.startsWith(stage+path.sep))throw Error(`Stage escape: ${relative}`);
 fs.mkdirSync(path.dirname(dest),{recursive:true});
 fs.writeFileSync(dest,bytes,{flag:'wx'});
 if(sha(fs.readFileSync(dest))!==sha(bytes))throw Error(`Stage copy mismatch: ${relative}`);
 receipt.files.push({path:relative,sha256:sha(bytes),bytes:bytes.length,origin:overrides.has(relative)?'candidate':'actual-source'});
}
verifyClosure();
fs.writeFileSync(path.join(stage,'source_snapshot.json'),JSON.stringify(receipt,null,2),{flag:'wx'});
console.log(JSON.stringify({stage,sourceClosureCount:files.length,sourceClosureBytes:total,sourceClosureSha256:closureDigest,residentHashes:residents.hashes,navHostSha256:sha(nav.host),navQueueSha256:sha(nav.queue),navBackendPauseSha256:sha(navBackendPatch),testSha256:sha(overrides.get('test_actual_population_pause.gd')),gpu:false}));
