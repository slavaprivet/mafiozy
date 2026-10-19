import fs from 'node:fs/promises';
import path from 'node:path';
import assert from 'node:assert/strict';
import {createHash} from 'node:crypto';
import {fileURLToPath} from 'node:url';
import {stageAssembly} from '../stage_map_editor_assembly.mjs';
const here=path.dirname(fileURLToPath(import.meta.url)),root=path.resolve(here,'../../..');
const sha=b=>createHash('sha256').update(b).digest('hex');
const args=process.argv.slice(2);assert(args.length<=1&&args.every(a=>['--check','--stage'].includes(a)),'Use --check or --stage');
const install=args.includes('--stage');
const receipt=JSON.parse(await fs.readFile(path.join(here,'receipt.json'),'utf8'));
const files=[];
for(const [name,expected] of Object.entries(receipt.files)){
	assert(/^[A-Za-z0-9_\.]+$/.test(name)&&name!=='.'&&name!=='..','Flat candidate path only');
	const input=path.join(here,name),stat=await fs.lstat(input);assert(stat.isFile()&&!stat.isSymbolicLink(),'Regular candidate file required');
 const bytes=await fs.readFile(input);assert.equal(sha(bytes),expected,'Frozen performance candidate changed: '+name);files.push([name,bytes]);
}
for(const [relative,expected] of Object.entries(receipt.baseSources))assert.equal(sha(await fs.readFile(path.join(root,relative))),expected,'Frozen base registry changed: '+relative);
const closure=await stageAssembly({stage:install,procedural:true,transport:true});
if(install)for(const [name,bytes] of files)await fs.writeFile(path.join(closure.destination,name),bytes,{flag:'wx'});
console.log(JSON.stringify({mode:install?'staged':'checked-read-only',destination:closure.destination,sourceFileCount:closure.files.length,candidateFiles:files.length,sourceClosure:closure.files.filter(row=>row.path.endsWith('.gd')).map(row=>({path:row.path,sha256:row.sha256})),gpu:false,production:false}));
