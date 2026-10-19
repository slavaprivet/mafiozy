/** Reproducible CPU fixture from source only; never copies import/UID caches. */
import {readFile,mkdir,mkdtemp,writeFile,lstat,realpath} from 'node:fs/promises';
import {resolve,relative,isAbsolute,dirname} from 'node:path';
import {fileURLToPath} from 'node:url';
import {createHash} from 'node:crypto';
import {ROOT,sourceAssetPath} from './export_map_editor_catalog.mjs';
import {inspectGlb} from './install_map_editor_assets.mjs';
const sha=bytes=>createHash('sha256').update(bytes).digest('hex');
function within(parent,path){const r=relative(parent,path);return r!==''&&!r.startsWith('..')&&!isAbsolute(r);}
export async function stageAssembly({root=ROOT,stage=false,procedural=false,transport=false,registryPerf=false,authoredPerf=false,pagedEditor=false}={}){
 if(transport&&!procedural)throw Error('Transport assembly requires --procedural');
 if(registryPerf&&!transport)throw Error('Registry performance assembly requires --procedural --transport');
 if(authoredPerf&&!registryPerf)throw Error('Combined authored performance assembly requires --procedural --transport --registry-perf');
 if(pagedEditor&&!authoredPerf)throw Error('Full paged editor assembly requires --procedural --transport --registry-perf --authored-perf');
 const base=await realpath(root),files=new Map();
 async function add(source,target){
  const path=resolve(base,source),stat=await lstat(path);
  if(!stat.isFile()||stat.isSymbolicLink()||!within(base,await realpath(path)))throw Error('Source must be a regular repository file: '+source);
  if(target.includes('..')||isAbsolute(target)||files.has(target))throw Error('Invalid/duplicate stage path: '+target);
  files.set(target,await readFile(path));
 }
 await add('godot/mafiozi_walk/data/map_editor/catalog.json','data/catalog.json');
 const catalog=JSON.parse(files.get('data/catalog.json'));
 if(catalog.schema!=='mafiozi.godot.map-editor-catalog/v1')throw Error('Catalog schema changed');
 const hashes=new Set();let assetBytes=0;
 for(const resource of catalog.resources){
  if(!/^[a-f0-9]{64}$/.test(resource.sha256)||resource.id!==resource.sha256||hashes.has(resource.sha256)||!resource.sourcePaths?.length)throw Error('Invalid resource identity');
  hashes.add(resource.sha256);
  const path=sourceAssetPath('/'+resource.sourcePaths[0],base);
  const target='assets/map_editor/'+resource.sha256+'.glb';
  await add(relative(base,path),target);
  const bytes=files.get(target);
  if(bytes.length!==resource.bytes||sha(bytes)!==resource.sha256)throw Error('Source asset changed: '+resource.sha256);
  inspectGlb(bytes);assetBytes+=bytes.length;
 }
	const scripts='tools/godot/map_editor_candidate/scripts/map_editor';
 // Explicit assembly closure; do not silently copy another author's WIP module.
 const modules=['atomic_map_import','catalog_ui','composite_registry','editor_camera','editor_controller','editor_host_adapter','editor_input_router','editor_panel','editor_persistence','editor_workspace','map_bundle_store','map_bundle','map_document','map_patch','map_store','object_registry','preview_host_bridge','selection_outline','trusted_json'];
 for(const module of modules)await add(scripts+'/'+module+'.gd','scripts/map_editor/'+module+'.gd');
 const fixture='tools/godot/map_editor_assembly_candidate';
 await add(fixture+'/catalog_factory.gd','scripts/map_editor/catalog_factory.gd');
 for(const name of ['test_combined_persistence.gd','test_atomic_import.gd','test_editor_assembly.gd'])await add(fixture+'/'+name,name);
 for(const name of ['test_editor_input_router.gd','test_document_full_catalog.gd'])await add('tools/godot/map_editor_candidate/tests/map_editor/'+name,name);
 for(const name of ['ground_document.gd','ground_renderer.gd','ground_brush.gd','ground_panel.gd','ground_preview.gd'])await add('tools/godot/map_editor_ground_candidate/'+name,name);
 await add('godot/mafiozi_walk/scripts/preview_surface_materials.gd','preview_surface_materials.gd');
 await add('godot/mafiozi_walk/data/block.json','data/block.json');
 await add('assets/maps/city_rebuild_v1/topology_for_placement.json','data/topology_for_placement.json');
 files.set('project.godot',Buffer.from('config_version=5\n[application]\nconfig/name="Map Editor Source Only QA"\n[rendering]\nrenderer/rendering_method="gl_compatibility"\n'));
 if(procedural){
  await add('godot/mafiozi_walk/data/map_editor/catalog.json','catalog.json');
  const manifestPath='outputs/map_editor_procedural_source/manifest.json';
  await add(manifestPath,'manifest.json');
  if(sha(files.get('manifest.json'))!=='82e6ef82a824e002d0f315972ffd3d967102b7c36256371699992bcfb76220dd')throw Error('Procedural source requires new admission');
  const manifest=JSON.parse(files.get('manifest.json'));
  for(const input of manifest.dependencies){
   const raw=await readFile(resolve(base,input.path));
   if(sha(raw)!==input.sha256||raw.length!==input.bytes)throw Error('Procedural dependency changed: '+input.path);
  }
  const catalogReceipt=manifest.dependencies.find(x=>x.path==='godot/mafiozi_walk/data/map_editor/catalog.json');
  if(!catalogReceipt||sha(files.get('data/catalog.json'))!==catalogReceipt.sha256)throw Error('Procedural/catalog lineage changed');
  for(const buffer of manifest.buffers){
   if(!/^[a-f0-9]{64}$/.test(buffer.sha256)||buffer.file!=='buffers/'+buffer.sha256+'.bin')throw Error('Invalid procedural buffer');
   await add('outputs/map_editor_procedural_source/'+buffer.file,buffer.file);
   const raw=files.get(buffer.file);
   if(sha(raw)!==buffer.sha256||raw.length!==buffer.bytes)throw Error('Procedural bytes changed');
  }
  for(const name of ['procedural_factory','procedural_registry','road_visual_policy'])await add('tools/godot/map_editor_procedural_native_v3/scripts/'+name+'.gd','scripts/'+name+'.gd');
  await add(fixture+'/test_unified_registry.gd','test_unified_registry.gd');
 }
 if(transport){
  await add('outputs/map_editor_transport_decor_source/manifest.json','transport_source/manifest.json');
  const raw=files.get('transport_source/manifest.json');
  if(sha(raw)!=='69ecbd14108fd151b504a41dc3d00ab5dbeca98b8c5ccd6251553fb60189546b')throw Error('Transport source requires new admission');
  const manifest=JSON.parse(raw);
  for(const buffer of manifest.buffers){
   if(!/^[a-f0-9]{64}$/.test(buffer.sha256)||buffer.file!=='buffers/'+buffer.sha256+'.bin')throw Error('Invalid transport buffer');
   await add('outputs/map_editor_transport_decor_source/'+buffer.file,'transport_source/'+buffer.file);
   const bytes=files.get('transport_source/'+buffer.file);
   if(sha(bytes)!==buffer.sha256||bytes.length!==buffer.bytes)throw Error('Transport bytes changed');
  }
  await add(manifest.railway.trainAsset.path,'transport_source/train.glb');
  if(sha(files.get('transport_source/train.glb'))!==manifest.railway.trainAsset.sha256)throw Error('Source train changed');
  await add('tools/godot/map_editor_transport_decor_native_candidate/transport_decor_factory.gd','transport_decor_factory.gd');
  await add('tools/godot/map_editor_transport_registry_candidate/transport_registry.gd','transport_registry.gd');
  await add('tools/godot/map_editor_transport_registry_candidate/scripts/frames.gd','scripts/frames.gd');
  await add(fixture+'/test_full_registry.gd','test_full_registry.gd');
 }
 if(registryPerf){
  const source='tools/godot/map_editor_import_perf_candidate';
  await add(source+'/receipt.json','registry_perf_receipt.json');
  if(sha(files.get('registry_perf_receipt.json'))!=='7c8b0b818982a4790f57b42486d6b3a53f8838afd496ef1b65c8b23a11f19520')throw Error('Registry performance package requires new admission');
  const admitted=JSON.parse(files.get('registry_perf_receipt.json'));
  if(admitted.schema!=='mafiozi.import-provenance-perf/v1'||admitted.production!==false||admitted.gpu!==false)throw Error('Unadmitted registry performance receipt');
  for(const [path,expected] of Object.entries(admitted.baseSources)){
   const candidate=resolve(base,path),stat=await lstat(candidate);
   if(!within(base,candidate)||stat.isSymbolicLink()||!stat.isFile()||!within(base,await realpath(candidate)))throw Error('Invalid performance baseline path');
   if(sha(await readFile(candidate))!==expected)throw Error('Registry baseline changed: '+path);
  }
  for(const name of ['procedural_registry_perf.gd','transport_registry_perf.gd','provenance.gd','exact_equal.gd','test_exact_equal.gd']){
   await add(source+'/'+name,name);
   if(sha(files.get(name))!==admitted.files[name])throw Error('Frozen registry optimization changed: '+name);
  }
  await add(fixture+'/test_full_registry_perf.gd','test_full_registry_perf.gd');
 }
 if(authoredPerf){
  const source='tools/godot/map_editor_authored_perf_candidate';
  await add(source+'/receipt.json','authored_perf_receipt.json');
  if(sha(files.get('authored_perf_receipt.json'))!=='74aa8c1ff506aaf06518ead23f64234ce67c2cc755035611bcac3eae62d34c89')throw Error('Authored performance package requires new admission');
  const admitted=JSON.parse(files.get('authored_perf_receipt.json'));
  if(admitted.schema!=='mafiozi.authored-object-perf/v1'||admitted.production!==false||admitted.gpu!==false)throw Error('Unadmitted authored performance receipt');
  for(const [path,expected] of Object.entries(admitted.baseSources)){
   const candidate=resolve(base,path),stat=await lstat(candidate);
   if(!within(base,candidate)||stat.isSymbolicLink()||!stat.isFile()||!within(base,await realpath(candidate)))throw Error('Invalid authored performance baseline path');
   if(sha(await readFile(candidate))!==expected)throw Error('Authored baseline changed: '+path);
  }
  for(const name of ['authored_factory_perf.gd','authored_registry_perf.gd']){
   await add(source+'/'+name,name);
   if(sha(files.get(name))!==admitted.files[name])throw Error('Frozen authored optimization changed: '+name);
  }
  await add(fixture+'/test_full_all_perf.gd','test_full_all_perf.gd');
 }
 if(pagedEditor){
  const source='tools/godot/map_editor_paged_controller_candidate';
  await add(source+'/receipt.json','paged_editor_receipt.json');
  if(sha(files.get('paged_editor_receipt.json'))!=='694b160720396dce61e5b257623c344b13b1cea77e05f4baac2b3f8a02ca1139')throw Error('Paged editor package requires new admission');
  const admitted=JSON.parse(files.get('paged_editor_receipt.json'));
  if(admitted.schema!=='mafiozi.map-editor.paged-controller-candidate/v1'||admitted.productionInstalled!==false||admitted.GPU!==false)throw Error('Unadmitted paged editor receipt');
  for(const [path,expected] of Object.entries(admitted.baseSources)){
   const candidate=resolve(base,path),stat=await lstat(candidate);
   if(!within(base,candidate)||stat.isSymbolicLink()||!stat.isFile()||!within(base,await realpath(candidate)))throw Error('Invalid paged editor baseline path');
   if(sha(await readFile(candidate))!==expected)throw Error('Paged editor baseline changed: '+path);
  }
  await add('tools/godot/map_editor_paged_panel_candidate/paged_editor_panel.gd','paged_editor_panel.gd');
  for(const name of ['paged_editor_controller.gd','test_paged_editor_controller.gd']){
   await add(source+'/'+name,name);
   if(sha(files.get(name))!==admitted.files[name])throw Error('Frozen paged editor changed: '+name);
  }
  await add(fixture+'/test_full_paged_editor.gd','test_full_paged_editor.gd');
 }
 const receipts=[...files].map(([path,bytes])=>({path,bytes:bytes.length,sha256:sha(bytes)}));
 const receipt={schema:'mafiozi.editor-assembly-source/v1',files:receipts,resources:hashes.size,assetBytes,procedural,transport,registryPerf,authoredPerf,pagedEditor,cacheCopied:false,productionWired:false,gpu:false};
 let destination=null;
 if(stage){
  const out=resolve(base,'outputs');await mkdir(out,{recursive:true});
  if(await realpath(out)!==out||(await lstat(out)).isSymbolicLink())throw Error('Refuse redirected outputs');
  destination=await mkdtemp(resolve(out,'map_editor_source_assembly_'));
  for(const [path,bytes] of files){
   const target=resolve(destination,path);if(!within(destination,target))throw Error('Stage path escaped');
   await mkdir(dirname(target),{recursive:true});await writeFile(target,bytes,{flag:'wx'});
   if(sha(await readFile(target))!==sha(bytes))throw Error('Stage readback failed: '+path);
  }
  await writeFile(resolve(destination,'source_receipt.json'),JSON.stringify(receipt,null,2)+'\n',{flag:'wx'});
 }
 return {mode:stage?'stage':'check',destination,...receipt};
}
if(process.argv[1]&&resolve(process.argv[1])===fileURLToPath(import.meta.url)){
 const args=process.argv.slice(2);if(args.some(x=>!['--stage','--check','--procedural','--transport','--registry-perf','--authored-perf','--paged-editor'].includes(x))||args.includes('--stage')&&args.includes('--check'))throw Error('Use --check or --stage, optionally --procedural --transport --registry-perf --authored-perf --paged-editor');
 const {files,...summary}=await stageAssembly({stage:args.includes('--stage'),procedural:args.includes('--procedural'),transport:args.includes('--transport'),registryPerf:args.includes('--registry-perf'),authoredPerf:args.includes('--authored-perf'),pagedEditor:args.includes('--paged-editor')});console.log(JSON.stringify({...summary,fileCount:files.length}));
}
