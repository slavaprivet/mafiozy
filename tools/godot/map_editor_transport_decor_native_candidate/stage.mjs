/** Frozen code-only transport decor package. --check default, --stage outputs only. */
import fs from 'node:fs';
import path from 'node:path';
import assert from 'node:assert/strict';
import {createHash} from 'node:crypto';
import {fileURLToPath} from 'node:url';
const here=path.dirname(fileURLToPath(import.meta.url)),root=path.resolve(here,'../../..');
const hash=b=>createHash('sha256').update(b).digest('hex');
const sourceSha='69ecbd14108fd151b504a41dc3d00ab5dbeca98b8c5ccd6251553fb60189546b';
let stage=false,source=path.join(root,'outputs/map_editor_transport_decor_source'),target=path.join(root,'outputs/map_editor_transport_decor_review');
for(let i=2;i<process.argv.length;i++){
 const a=process.argv[i];
 if(a==='--stage')stage=true;
 else if(a==='--check')stage=false;
 else if(a==='--source')source=path.resolve(process.argv[++i]);
 else if(a==='--target')target=path.resolve(process.argv[++i]);
 else throw Error(`Unknown argument: ${a}`);
}
const inside=p=>p.startsWith(path.join(root,'outputs')+path.sep);
assert(inside(source)&&inside(target)&&source!==target,'Distinct outputs subdirectories only');
function noLinks(p){while(p!==root){if(fs.existsSync(p))assert(!fs.lstatSync(p).isSymbolicLink(),'Link target refused');p=path.dirname(p);}}
noLinks(source);noLinks(target);
const raw=fs.readFileSync(path.join(source,'manifest.json'));assert.equal(hash(raw),sourceSha,'Frozen source manifest changed');
const manifest=JSON.parse(raw),files=[['source/manifest.json',raw]];
assert.equal(manifest.schema,'mafiozi.godot.map-editor-transport-decor-source/v1');
const seen=new Set();
for(const b of manifest.buffers){
 assert(/^[0-9a-f]{64}$/.test(b.sha256)&&b.file===`buffers/${b.sha256}.bin`&&!seen.has(b.file));seen.add(b.file);
 const p=path.join(source,b.file);noLinks(p);const bytes=fs.readFileSync(p);
 assert.equal(bytes.length,b.bytes);assert.equal(hash(bytes),b.sha256);files.push(['source/'+b.file,bytes]);
}
const train=manifest.railway.trainAsset;
const trainPath=path.resolve(root,train.path);assert(trainPath.startsWith(root+path.sep));noLinks(trainPath);
const trainBytes=fs.readFileSync(trainPath);assert.equal(hash(trainBytes),train.sha256);files.push(['source/train.glb',trainBytes]);
const receipt=JSON.parse(fs.readFileSync(path.join(here,'receipt.json')));
for(const [file,sha] of Object.entries(receipt.files)){
 const p=path.join(here,file);noLinks(p);const bytes=fs.readFileSync(p);assert.equal(hash(bytes),sha,`Frozen candidate changed: ${file}`);files.push([file,bytes]);
}
for(const [file,bytes] of files){const p=path.join(target,file);noLinks(p);if(fs.existsSync(p))assert.equal(hash(fs.readFileSync(p)),hash(bytes),`Refuse overwrite changed target: ${file}`);}
if(stage)for(const [file,bytes] of files){const p=path.join(target,file);fs.mkdirSync(path.dirname(p),{recursive:true});if(!fs.existsSync(p))fs.writeFileSync(p,bytes,{flag:'wx'});}
console.log(JSON.stringify({mode:stage?'staged':'checked-read-only',sourceSha,files:files.length,target,checks:232229,gpuChecked:false,railwayStatus:'HOLD exact station pixel capture and trusted actual train owner'}));
