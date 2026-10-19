// Explicit isolated copies only; never runs an engine or changes production.
import fs from 'node:fs/promises';
import path from 'node:path';
import assert from 'node:assert/strict';
import {createHash} from 'node:crypto';
import {fileURLToPath} from 'node:url';
const here=path.dirname(fileURLToPath(import.meta.url)),root=path.resolve(here,'../../..');
const args=process.argv.slice(2);assert(args.length<=1&&args.every(a=>['--check','--stage'].includes(a)),'Use --check or --stage');
const hash=b=>createHash('sha256').update(b).digest('hex');
const receipt=JSON.parse(await fs.readFile(path.join(here,'receipt.json')));
assert.equal(receipt.ready,false);assert.equal(receipt.gpu,false);
const source=path.resolve(root,receipt.sourceStage);
const within=(dir,file)=>{const rel=path.relative(dir,file);return rel!==''&&!rel.startsWith('..')&&!path.isAbsolute(rel);};
assert(within(path.join(root,'outputs'),source));
assert.equal((await fs.realpath(source)).toLowerCase(),source.toLowerCase(),'Stage alias refused');
const files=[];
async function read(dir,name,pin,size=null){
 assert(name.split('/').every(v=>v!==''&&v!=='.'&&v!=='..')&&!path.isAbsolute(name)&&!name.includes('\\'),'Safe source relative name');
 const target=path.join(dir,name),stat=await fs.lstat(target),real=await fs.realpath(target);
 assert(stat.isFile()&&!stat.isSymbolicLink()&&within(dir,real),'Regular scoped source only');
 const bytes=await fs.readFile(target);assert.equal(hash(bytes),pin,'Source SHA changed: '+name);if(size!==null)assert.equal(bytes.length,size,'Source bytes changed: '+name);
 files.push([name,bytes]);return bytes;
}
const snapshot=JSON.parse(await read(source,'source_snapshot.json',receipt.sourceSnapshotSha256));
assert.equal(snapshot.revision,'s01-20260927-melee21');
const names=new Set(['source_snapshot.json']);
for(const item of snapshot.files){assert(!names.has(item.path),'Duplicate source path');names.add(item.path);if(item.path==='probe.gd')continue;await read(source,item.path,item.sha256,item.bytes);}
assert.equal(hash(await fs.readFile(path.join(root,'godot/mafiozi_walk/scripts/main.gd'))),receipt.mainSha256,'Production main changed; review newer terrain construction first');
for(const [name,pin] of Object.entries(receipt.files)){assert(!names.has(name));names.add(name);await read(here,name,pin);}
let destination=null;
if(args.includes('--stage')){
 const outputs=path.join(root,'outputs');assert.equal((await fs.realpath(outputs)).toLowerCase(),outputs.toLowerCase());
 destination=await fs.mkdtemp(path.join(outputs,'actual-terrain-inventory-'));
 for(const [name,bytes] of files){const target=path.join(destination,name);assert(within(destination,target));await fs.mkdir(path.dirname(target),{recursive:true});await fs.writeFile(target,bytes,{flag:'wx'});assert.equal(hash(await fs.readFile(target)),hash(bytes));}
}
console.log(JSON.stringify({ok:true,destination,files:files.length,bytes:files.reduce((n,entry)=>n+entry[1].length,0),gpu:false,ready:false,productionInstalled:false,importCacheCopied:false}));
