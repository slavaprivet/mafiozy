import fs from 'node:fs';
import path from 'node:path';
import crypto from 'node:crypto';
import {fileURLToPath} from 'node:url';
import {loadPinned,pins,makeIndex} from './source_index.mjs';

const here=path.dirname(fileURLToPath(import.meta.url));
const root=path.resolve(here,'../../..');
const outputRoot=path.join(root,'outputs');
const sourceRoot=path.join(outputRoot,'map_editor_procedural_source');
const original=path.join(root,'tools','godot','map_editor_procedural_native_v3');
const sha=bytes=>crypto.createHash('sha256').update(bytes).digest('hex');
const roadPolicySha256='82cee4f07bcd1aeca9a41b081c592a33fcd5de54a925498f3df602021922ae1a';
const write=process.argv.includes('--stage');
if(process.argv.some((value,index)=>index>1&&!['--stage','--check'].includes(value)))throw Error('Only --check or --stage accepted');
function noLink(location){
 for(let cursor=location;cursor!==path.dirname(root);cursor=path.dirname(cursor))if(fs.existsSync(cursor)&&fs.lstatSync(cursor).isSymbolicLink())throw Error(`Symlink refused: ${cursor}`);
}
const pinned=loadPinned();
const index=makeIndex(pinned.manifest,pinned.catalog,pinned.bufferHashes);
const files=[
 ['project.godot',path.join(original,'project.godot')],
 ['manifest.json',path.join(sourceRoot,'manifest.json')],
 ['catalog.json',path.join(root,'godot','mafiozi_walk','data','map_editor','catalog.json')],
 ['scripts/procedural_factory.gd',path.join(original,'scripts','procedural_factory.gd')],
 ['scripts/road_visual_policy.gd',path.join(original,'scripts','road_visual_policy.gd')],
 ['scripts/incremental_factory.gd',path.join(here,'incremental_factory.gd')],
 ['test_incremental_factory.gd',path.join(here,'test_incremental_factory.gd')],
 ...pinned.manifest.buffers.map(entry=>[entry.file,path.join(sourceRoot,entry.file)])
];
const seen=new Set(),candidate=[];
for(const [relative,location] of files){
 if(seen.has(relative))throw Error(`Duplicate stage path: ${relative}`);
 seen.add(relative);noLink(location);
 const bytes=fs.readFileSync(location);
 candidate.push({path:relative,sha256:sha(bytes),bytes:bytes.length,source:location,content:bytes});
}
if(candidate.find(x=>x.path==='manifest.json').sha256!==pins.manifest||candidate.find(x=>x.path==='catalog.json').sha256!==pins.catalog||candidate.find(x=>x.path==='scripts/procedural_factory.gd').sha256!==pins.factory||candidate.find(x=>x.path==='scripts/road_visual_policy.gd').sha256!==roadPolicySha256)throw Error('Pinned stage drift');
const total=candidate.reduce((n,x)=>n+x.bytes,0);
if(total>180*1024*1024)throw Error('Stage exceeds bounded source size');
if(!write){
 console.log(JSON.stringify({mode:'checked-only',stageCreated:false,files:candidate.length,bytes:total,manifestSha256:pins.manifest,indexSha256:index.digest,explorationBatchCandidate:464,roadBatchCandidate:67,renderedIds:0,candidateFactorySha256:candidate.find(x=>x.path==='scripts/incremental_factory.gd').sha256,gpu:false}));
 process.exit(0);
}
noLink(outputRoot);
const stage=fs.mkdtempSync(path.join(outputRoot,'map-editor-incremental-exploration-'));
const receipt={schema:1,scope:'tools-only unrun incremental 2440-ID exploration fixture; roads HOLD',manifestSha256:pins.manifest,indexSha256:index.digest,files:[]};
for(const entry of candidate){
 const destination=path.join(stage,entry.path);
 if(!destination.startsWith(stage+path.sep))throw Error(`Stage path escape: ${entry.path}`);
 fs.mkdirSync(path.dirname(destination),{recursive:true});
 fs.writeFileSync(destination,entry.content,{flag:'wx'});
 if(sha(fs.readFileSync(destination))!==entry.sha256)throw Error(`Stage copy mismatch: ${entry.path}`);
 receipt.files.push({path:entry.path,sha256:entry.sha256,bytes:entry.bytes});
}
for(const entry of candidate)if(sha(fs.readFileSync(entry.source))!==entry.sha256)throw Error(`Concurrent source drift: ${entry.source}`);
fs.writeFileSync(path.join(stage,'source_snapshot.json'),JSON.stringify(receipt,null,2),{flag:'wx'});
console.log(JSON.stringify({mode:'staged-unrun',stage,files:candidate.length,bytes:total,manifestSha256:pins.manifest,indexSha256:index.digest,candidateFactorySha256:candidate.find(x=>x.path==='scripts/incremental_factory.gd').sha256,gpu:false}));
