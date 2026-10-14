import fs from 'node:fs/promises';
import path from 'node:path';
import assert from 'node:assert/strict';
import {createHash} from 'node:crypto';
import {fileURLToPath} from 'node:url';
import {stageAssembly} from '../stage_map_editor_assembly.mjs';
const here=path.dirname(fileURLToPath(import.meta.url)),root=path.resolve(here,'../../..');
const hash=b=>createHash('sha256').update(b).digest('hex');
const args=process.argv.slice(2);
assert(args.length<=1&&args.every(a=>['--check','--stage'].includes(a)),'Use --check or --stage');
const receipt=JSON.parse(await fs.readFile(path.join(here,'receipt.json'),'utf8'));
for(const [relative,expected] of Object.entries(receipt.baseSources))assert.equal(hash(await fs.readFile(path.join(root,relative))),expected,'Reviewed base changed: '+relative);
const panelSource=path.join(root,'tools/godot/map_editor_paged_panel_candidate/paged_editor_panel.gd');
const panelBytes=await fs.readFile(panelSource);
assert.equal(hash(panelBytes),'a77e1e11fe2cdf8dc9ffc2dffd95c9ddf2b6b35e31b5b30b588f32ba71495a2b','Frozen paged panel changed');
const files=[['paged_editor_panel.gd',panelBytes]];
for(const [name,expected] of Object.entries(receipt.files)){
 assert(/^[a-z_\.]+$/.test(name)&&!name.startsWith('.'),'Flat frozen source names only');
 const filename=path.join(here,name),stat=await fs.lstat(filename);
 assert(stat.isFile()&&!stat.isSymbolicLink(),'Regular source files only');
 const bytes=await fs.readFile(filename);assert.equal(hash(bytes),expected,'Frozen adapter changed: '+name);
 files.push([name,bytes]);
}
const closure=await stageAssembly({stage:args.includes('--stage')});
if(closure.destination)for(const [name,bytes] of files)await fs.writeFile(path.join(closure.destination,name),bytes,{flag:'wx'});
console.log(JSON.stringify({ok:true,destination:closure.destination??null,sourceFiles:closure.files.length,candidateFiles:files.length,production:false,GPU:false}));
