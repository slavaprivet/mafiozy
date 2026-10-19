import fs from 'node:fs/promises';
import path from 'node:path';
import assert from 'node:assert/strict';
import {createHash} from 'node:crypto';
import {fileURLToPath} from 'node:url';
import {stageAssembly} from '../stage_map_editor_assembly.mjs';
const here=path.dirname(fileURLToPath(import.meta.url)),root=path.resolve(here,'../../..');
const sha=b=>createHash('sha256').update(b).digest('hex');
const args=process.argv.slice(2);assert(args.length<=1&&args.every(a=>['--check','--stage'].includes(a)),'Use --check or --stage');
const receipt=JSON.parse(await fs.readFile(path.join(here,'receipt.json'),'utf8'));
const files=[];
for(const [name,expected] of Object.entries(receipt.files)){
 assert(/^[A-Za-z0-9_\.]+$/.test(name)&&name!=='.'&&name!=='..','Flat paths only');
 const input=path.join(here,name),stat=await fs.lstat(input);assert(stat.isFile()&&!stat.isSymbolicLink(),'Regular candidate files only');
 const bytes=await fs.readFile(input);assert.equal(sha(bytes),expected,'Frozen authored candidate changed');files.push([name,bytes]);
}
for(const [relative,expected] of Object.entries(receipt.baseSources))assert.equal(sha(await fs.readFile(path.join(root,relative))),expected,'Base constructor requires new audit');
const closure=await stageAssembly({stage:args.includes('--stage')});
if(closure.destination)for(const [name,bytes] of files)await fs.writeFile(path.join(closure.destination,name),bytes,{flag:'wx'});
console.log(JSON.stringify({mode:closure.mode,destination:closure.destination,sourceFileCount:closure.files.length,candidateFiles:files.length,checks:receipt.checks,gpu:false,production:false}));
