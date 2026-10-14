/** Isolated opt-in fixture; base/frozen packages are read only. */
import {readFile,writeFile,lstat,realpath} from 'node:fs/promises';
import {resolve,relative,isAbsolute} from 'node:path';
import {fileURLToPath} from 'node:url';
import {createHash} from 'node:crypto';
import {ROOT} from '../export_map_editor_catalog.mjs';
import {stageAssembly} from '../stage_map_editor_assembly.mjs';

const sha=b=>createHash('sha256').update(b).digest('hex');
const pins={
 'tools/godot/map_editor_candidate/scripts/map_editor/editor_controller.gd':'d1812cb127b6526a14e12cbf047ef2a0365aba036d031060844dfc369b5e40c4',
 'tools/godot/map_editor_candidate/scripts/map_editor/map_document.gd':'09b32b7623dd66aa623fd0fc469fa3feee3d84f6de60ca26d6553f8954b1911e',
 'tools/godot/map_editor_candidate/scripts/map_editor/trusted_json.gd':'40e455e671f00bb130cbcdf8ce119a95ef0ef6dcfa4d8772790568efe48a7ccb',
 'tools/godot/map_editor_assembly_candidate/test_full_paged_editor.gd':'f525eb0cfe19da73bbc9f0a236d7b2b05ebe583dd9dbe2c3ac7c5bc4657963e0'
};
function within(base,target){const rel=relative(base,target);return rel!==''&&!rel.startsWith('..')&&!isAbsolute(rel);}
export async function stageIncremental({stage=false,root=ROOT}={}){
 const base=await realpath(root);
 for(const [path,expected] of Object.entries(pins)){
  const source=resolve(base,path),stat=await lstat(source);
  if(!stat.isFile()||stat.isSymbolicLink()||!within(base,await realpath(source))||sha(await readFile(source))!==expected)throw Error('Frozen dependency changed: '+path);
 }
 const assembly=await stageAssembly({root:base,stage,procedural:true,transport:true,registryPerf:true,authoredPerf:true,pagedEditor:true});
 const files=[];
 for(const name of ['incremental_prepare.gd','test_incremental_prepare.gd']){
  const source=resolve(base,'tools/godot/map_editor_incremental_prepare_candidate',name),stat=await lstat(source);
  if(!stat.isFile()||stat.isSymbolicLink()||!within(base,await realpath(source)))throw Error('Candidate source escaped: '+name);
  const bytes=await readFile(source);files.push({path:name,bytes:bytes.length,sha256:sha(bytes)});
  if(stage){
   const target=resolve(assembly.destination,name);
   if(!within(assembly.destination,target))throw Error('Candidate stage escaped');
   await writeFile(target,bytes,{flag:'wx'});
   if(sha(await readFile(target))!==sha(bytes))throw Error('Candidate stage readback failed');
  }
 }
 const receipt={schema:'mafiozi.editor-incremental-prepare-source/v1',destination:assembly.destination,sourceObjects:9901,baseFileCount:assembly.files.length,files,pins,productionWired:false,gpu:false};
 if(stage)await writeFile(resolve(assembly.destination,'incremental_prepare_receipt.json'),JSON.stringify(receipt,null,2)+'\n',{flag:'wx'});
 return receipt;
}
if(process.argv[1]&&resolve(process.argv[1])===fileURLToPath(import.meta.url)){
 const args=process.argv.slice(2);
 if(args.length>1||args.some(x=>!['--check','--stage'].includes(x)))throw Error('Use --check or --stage');
 console.log(JSON.stringify(await stageIncremental({stage:args.includes('--stage')})));
}
