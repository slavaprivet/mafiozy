import fs from 'node:fs';
import path from 'node:path';
import assert from 'node:assert/strict';
import {createHash} from 'node:crypto';
import {fileURLToPath} from 'node:url';
import {execFileSync} from 'node:child_process';
const here=path.dirname(fileURLToPath(import.meta.url)),root=path.resolve(here,'../../..');
const hash=b=>createHash('sha256').update(b).digest('hex');
let install=false,target=path.join(root,'outputs/map_editor_transport_registry_review');
for(let i=2;i<process.argv.length;i++){
 const a=process.argv[i];
 if(a==='--stage')install=true;
 else if(a==='--check')install=false;
 else if(a==='--target')target=path.resolve(process.argv[++i]);
 else throw Error('Unknown argument: '+a);
}
assert(target.startsWith(path.join(root,'outputs')+path.sep),'Output subdirectory only');
function noLinks(p){while(p!==root){if(fs.existsSync(p))assert(!fs.lstatSync(p).isSymbolicLink(),'Linked path refused');p=path.dirname(p);}}
noLinks(target);
const receipt=JSON.parse(fs.readFileSync(path.join(here,'receipt.json')));
const files=[];
for(const [file,sha] of Object.entries(receipt.files)){
 const p=path.join(here,file);noLinks(p);const bytes=fs.readFileSync(p);
 assert.equal(hash(bytes),sha,'Frozen candidate changed: '+file);
 const out=path.join(target,file);noLinks(out);
 if(fs.existsSync(out))assert.equal(hash(fs.readFileSync(out)),sha,'Refuse changed target: '+file);
 files.push([out,bytes]);
}
const original=path.join(root,'tools/godot/map_editor_transport_decor_native_candidate/stage.mjs');
assert.equal(hash(fs.readFileSync(original)),receipt.consumerStageSha256,'Frozen original consumer stage changed');
// Original checks all source buffers/train and its frozen consumer files.
execFileSync(process.execPath,[original,install?'--stage':'--check','--target',target],{stdio:'inherit'});
if(install)for(const [out,bytes] of files){fs.mkdirSync(path.dirname(out),{recursive:true});if(!fs.existsSync(out))fs.writeFileSync(out,bytes,{flag:'wx'});}
console.log(JSON.stringify({mode:install?'staged':'checked-read-only',target,codeFiles:files.length,registryChecks:852,controllerChecks:26,parkingNativeMockOwner:233,railHeld:32,gpuChecked:false}));
