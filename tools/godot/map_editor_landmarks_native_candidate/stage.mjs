import fs from 'node:fs';
import path from 'node:path';
import assert from 'node:assert/strict';
import {createHash} from 'node:crypto';
import {fileURLToPath} from 'node:url';
const here=path.dirname(fileURLToPath(import.meta.url)),root=path.resolve(here,'../../..');
const sha=b=>createHash('sha256').update(b).digest('hex');
const admitted='4e459bda9cf6a9ab752667bc8a55fe36a6a6c4d7350a7d5ddc64e08c6a8c490c';
const source=path.join(root,'outputs/map_editor_protected_landmarks_source'),target=path.join(root,'outputs/map_editor_landmarks_native_candidate');
assert(process.argv.slice(2).every(x=>['--stage','--check'].includes(x)));
const raw=fs.readFileSync(path.join(source,'manifest.json'));assert.equal(sha(raw),admitted);
const m=JSON.parse(raw),files=[['source/manifest.json',raw]];
const frozenCode={
 'landmarks_resource_factory.gd':'0538b04bb8bfcbd15506e5a7002e44136cc4afe108504daec44601a3dfa6706e',
 'test_landmarks_resource_factory.gd':'123bc8090aa60026c0f9a29ef70ec0aec0181fc9ea56f89558443258d1dcbb90',
 'project.godot':'372cefc51eab450bbae679a547c799107d3678db631e27d973ee440cacd97e26'
};
for(const b of m.buffers){assert.equal(b.file,`buffers/${b.sha256}.bin`);const bytes=fs.readFileSync(path.join(source,b.file));assert.equal(sha(bytes),b.sha256);files.push(['source/'+b.file,bytes]);}
for(const [name,expected]of Object.entries(frozenCode)){const bytes=fs.readFileSync(path.join(here,name));assert.equal(sha(bytes),expected,'Frozen native source changed');files.push([name,bytes]);}
for(const name of ['HANDOFF.md','receipt.json'])files.push([name,fs.readFileSync(path.join(here,name))]);
for(const [file,bytes]of files){const p=path.join(target,file);assert(p.startsWith(target+path.sep));let parent=p;while(parent!==root){if(fs.existsSync(parent))assert(!fs.lstatSync(parent).isSymbolicLink());parent=path.dirname(parent);}if(fs.existsSync(p))assert.equal(sha(fs.readFileSync(p)),sha(bytes),'Refuse changed candidate overwrite '+file);}
if(process.argv.includes('--stage'))for(const[file,bytes]of files){const p=path.join(target,file);fs.mkdirSync(path.dirname(p),{recursive:true});if(!fs.existsSync(p))fs.writeFileSync(p,bytes,{flag:'wx'});}
console.log(JSON.stringify({files:files.length,sourceSHA:admitted,mode:process.argv.includes('--stage')?'staged':'readonly-check',target}));
