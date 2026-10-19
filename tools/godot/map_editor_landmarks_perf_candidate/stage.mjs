import fs from 'node:fs';
import path from 'node:path';
import assert from 'node:assert/strict';
import {createHash} from 'node:crypto';
import {fileURLToPath} from 'node:url';
const here=path.dirname(fileURLToPath(import.meta.url)),root=path.resolve(here,'../../..'),sha=b=>createHash('sha256').update(b).digest('hex');
const baseline=path.join(root,'tools/godot/map_editor_landmarks_native_candidate'),source=path.join(root,'outputs/map_editor_protected_landmarks_source'),target=path.join(root,'outputs/map_editor_landmarks_perf_candidate');
const files=[];
const raw=fs.readFileSync(path.join(source,'manifest.json'));assert.equal(sha(raw),'4e459bda9cf6a9ab752667bc8a55fe36a6a6c4d7350a7d5ddc64e08c6a8c490c');files.push(['source/manifest.json',raw]);
for(const b of JSON.parse(raw).buffers){assert.equal(b.file,`buffers/${b.sha256}.bin`);const bytes=fs.readFileSync(path.join(source,b.file));assert.equal(sha(bytes),b.sha256);files.push(['source/'+b.file,bytes]);}
for(const[name,hash]of Object.entries({'landmarks_resource_factory.gd':'0538b04bb8bfcbd15506e5a7002e44136cc4afe108504daec44601a3dfa6706e','test_landmarks_resource_factory.gd':'123bc8090aa60026c0f9a29ef70ec0aec0181fc9ea56f89558443258d1dcbb90','project.godot':'372cefc51eab450bbae679a547c799107d3678db631e27d973ee440cacd97e26'})){const bytes=fs.readFileSync(path.join(baseline,name));assert.equal(sha(bytes),hash,'Frozen baseline unchanged');files.push([name,bytes]);}
for(const[name,hash]of Object.entries({'landmarks_cached_factory.gd':'e24f6dc7b555ce050b02b95a293a7f5355c786b6b7231ddb9ab262b099882179','test_landmarks_cached_factory.gd':'b27a17c38cfe852a6bcaef3078b59021c3bfcc14a3bb23b05e4efc94a72647ef'})){const bytes=fs.readFileSync(path.join(here,name));assert.equal(sha(bytes),hash,'Frozen optimized candidate changed');files.push([name,bytes]);}
for(const name of ['HANDOFF.md','receipt.json'])files.push([name,fs.readFileSync(path.join(here,name))]);
// Run the exact old 353646-check suite against the subclass without altering frozen source.
const original=fs.readFileSync(path.join(baseline,'test_landmarks_resource_factory.gd'),'utf8');files.push(['test_original_suite_optimized.gd',Buffer.from(original.replace('preload("res://landmarks_resource_factory.gd")','preload("res://landmarks_cached_factory.gd")'))]);
for(const[file,bytes]of files){const p=path.join(target,file);assert(p.startsWith(target+path.sep));let parent=p;while(parent!==root){if(fs.existsSync(parent))assert(!fs.lstatSync(parent).isSymbolicLink());parent=path.dirname(parent);}if(fs.existsSync(p))assert.equal(sha(fs.readFileSync(p)),sha(bytes),'Refuse changed target overwrite '+file);}
if(process.argv.includes('--stage'))for(const[file,bytes]of files){const p=path.join(target,file);fs.mkdirSync(path.dirname(p),{recursive:true});if(!fs.existsSync(p))fs.writeFileSync(p,bytes,{flag:'wx'});}
console.log(JSON.stringify({files:files.length,mode:process.argv.includes('--stage')?'staged':'read-only',target}));
