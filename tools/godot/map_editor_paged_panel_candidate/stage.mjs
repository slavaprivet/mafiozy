import fs from 'node:fs/promises';
import path from 'node:path';
import assert from 'node:assert/strict';
import {createHash} from 'node:crypto';
import {fileURLToPath} from 'node:url';
const here=path.dirname(fileURLToPath(import.meta.url));
const root=path.resolve(here,'../../..');
const args=process.argv.slice(2);
assert(args.length<=1&&args.every(a=>['--check','--stage'].includes(a)),'Use --check or --stage');
const bases={
 'tools/godot/map_editor_candidate/scripts/map_editor/editor_panel.gd':['scripts/map_editor/editor_panel.gd','af393e8eef857e60933705dd64b4fd03131133439b6be12d5dc3d8fa909f44ce'],
 'tools/godot/map_editor_candidate/scripts/map_editor/catalog_ui.gd':['scripts/map_editor/catalog_ui.gd','f7a5c9f8088a6a127bfe9a5ef6f3015df24d97be6793911bbdc3b06db08c31b8'],
 'godot/mafiozi_walk/data/map_editor/catalog.json':['data/catalog.json','ae089d73eb61131bc6a38ccc6a2b9b18639f7bd8b65079f7c15c1e1cda9cde6e'],
};
const files=[];
for(const [source,[destination,expected]] of Object.entries(bases)){
 const bytes=await fs.readFile(path.join(root,source));
 assert.equal(createHash('sha256').update(bytes).digest('hex'),expected,'Source changed: '+source);
 files.push([destination,bytes]);
}
const receipt=JSON.parse(await fs.readFile(path.join(here,'receipt.json'),'utf8'));
for(const [name,expected] of Object.entries(receipt.files)){
 assert(/^[a-z_\.]+$/.test(name)&&!name.startsWith('.'),'Flat frozen filenames only');
 const source=path.join(here,name),stat=await fs.lstat(source);
 assert(stat.isFile()&&!stat.isSymbolicLink(),'Regular source files only');
 const bytes=await fs.readFile(source);
 assert.equal(createHash('sha256').update(bytes).digest('hex'),expected,'Frozen paged panel changed: '+name);
 files.push([name,bytes]);
}
let destination=null;
if(args.includes('--stage')){
 const outputs=path.join(root,'outputs');await fs.mkdir(outputs,{recursive:true});
 destination=await fs.mkdtemp(path.join(outputs,'map_editor_paged_panel_'));
 for(const [relative,bytes] of files){
  const target=path.join(destination,relative);await fs.mkdir(path.dirname(target),{recursive:true});
  await fs.writeFile(target,bytes,{flag:'wx'});
 }
}
console.log(JSON.stringify({ok:true,mode:destination?'stage':'check',destination,fileCount:files.length,production:false,GPU:false}));
