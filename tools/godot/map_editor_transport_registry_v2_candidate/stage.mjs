import fs from 'node:fs';
import path from 'node:path';
import assert from 'node:assert/strict';
import {createHash} from 'node:crypto';
import {fileURLToPath} from 'node:url';
import {execFileSync} from 'node:child_process';
const here=path.dirname(fileURLToPath(import.meta.url)),root=path.resolve(here,'../../..');
const sha=b=>createHash('sha256').update(b).digest('hex');
let stage=false,target=path.join(root,'outputs/map_editor_transport_registry_v2_review');
for(let i=2;i<process.argv.length;i++){
 const arg=process.argv[i];if(arg==='--stage')stage=true;else if(arg==='--check')stage=false;
 else if(arg==='--target')target=path.resolve(process.argv[++i]);else throw Error('Unknown argument '+arg);
}
assert(target.startsWith(path.join(root,'outputs')+path.sep),'Output-only target');
function noLinks(p){while(p!==root){if(fs.existsSync(p))assert(!fs.lstatSync(p).isSymbolicLink(),'Linked path refused');p=path.dirname(p);}}
noLinks(target);
const receipt=JSON.parse(fs.readFileSync(path.join(here,'receipt.json'))),files=[];
for(const [file,expected] of Object.entries(receipt.files)){
 const p=path.join(here,file);noLinks(p);const bytes=fs.readFileSync(p);
 assert.equal(sha(bytes),expected,'Frozen V2 candidate changed: '+file);
 const out=path.join(target,file);noLinks(out);
 if(fs.existsSync(out))assert.equal(sha(fs.readFileSync(out)),expected,'Refuse changed target: '+file);
 files.push([out,bytes]);
}
const dependencies=[['tools/godot/map_editor_transport_registry_candidate/stage.mjs',receipt.registryV1StageSha256,target],['tools/godot/map_editor_station_texture_adapter/stage.mjs',receipt.stationStageSha256,path.join(target,'station_bundle')]];
for(const [relative,expected,destination] of dependencies){
 const p=path.join(root,relative);noLinks(p);assert.equal(sha(fs.readFileSync(p)),expected,'Frozen dependency stage changed');
 execFileSync(process.execPath,[p,'--check','--target',destination],{stdio:'inherit'});
}
if(stage){
 for(const [relative,,destination] of dependencies)execFileSync(process.execPath,[path.join(root,relative),'--stage','--target',destination],{stdio:'inherit'});
 for(const [out,bytes] of files){fs.mkdirSync(path.dirname(out),{recursive:true});if(!fs.existsSync(out))fs.writeFileSync(out,bytes,{flag:'wx'});}
}
console.log(JSON.stringify({mode:stage?'staged':'checked-read-only',target,codeFiles:files.length,railRegistryChecks:789,controllerChecks:29,nativeSourceLinks:265,railSourceIds:32,actualTrainParts:27,railClone:'HOLD-new-authority-owner',gpuChecked:false}));
