/** Deterministic, byte-preserving 188-GLB package outside the Godot project. */
import fs from 'node:fs/promises';
import {constants} from 'node:fs';
import path from 'node:path';
import crypto from 'node:crypto';
import {fileURLToPath} from 'node:url';
import {audit,compact} from '../map_editor_asset_adoption_audit/audit.mjs';
import {ROOT,sourceAssetPath} from '../export_map_editor_catalog.mjs';
import {inspectGlb} from '../install_map_editor_assets.mjs';

const own=path.dirname(fileURLToPath(import.meta.url));
const project=path.join(ROOT,'godot','mafiozi_walk');
const outputRoot=path.join(ROOT,'outputs');
const catalogRelative='godot/mafiozi_walk/data/map_editor/catalog.json';
const auditRelative='tools/godot/map_editor_asset_adoption_audit/manifest.json';
const auditSha='48d9806e512e02b5ff53e67a7289d18fcd91cfc44cecbf2f7235009c7d20e13d';
const sha=bytes=>crypto.createHash('sha256').update(bytes).digest('hex');
const inside=(base,target)=>{const rel=path.relative(base,target);return !!rel&&!rel.startsWith('..')&&!path.isAbsolute(rel);};
async function regular(file,base){
 if(!inside(base,file))throw Error(`Path escaped source root: ${file}`);
 const stat=await fs.lstat(file);
 if(!stat.isFile()||stat.isSymbolicLink()||!inside(base,await fs.realpath(file)))throw Error(`Redirected/nonregular source: ${file}`);
 return fs.readFile(file);
}
export function glbCounts(raw){
 const basic=inspectGlb(raw);
 const jsonSize=raw.readUInt32LE(12);
 const json=JSON.parse(raw.toString('utf8',20,20+jsonSize));
 const images=json.images||[];
 let embedded=0;
 for(const image of images){
  if(Number.isSafeInteger(image.bufferView)&&image.bufferView>=0&&image.bufferView<(json.bufferViews||[]).length)embedded++;
  else if(typeof image.uri==='string'&&image.uri.startsWith('data:'))embedded++;
  else throw Error('GLB image is not embedded');
 }
 return {materials:basic.materials,meshes:basic.meshes,images:images.length,embeddedImages:embedded};
}
export async function preflight(){
 const rootReal=await fs.realpath(ROOT);
 const auditRaw=await regular(path.join(ROOT,auditRelative),rootReal);
 if(sha(auditRaw)!==auditSha)throw Error('Verified adoption manifest drift');
 const saved=JSON.parse(auditRaw.toString('utf8'));
 const fresh=compact(await audit());
 if(JSON.stringify(saved)!==JSON.stringify(fresh))throw Error('Current catalog/source/production audit diverges from verified manifest');
 const catalogRaw=await regular(path.join(ROOT,catalogRelative),rootReal);
 if(catalogRaw.length!==saved.catalog.bytes||sha(catalogRaw)!==saved.catalog.sha256)throw Error('Catalog bytes drift');
 const catalog=JSON.parse(catalogRaw.toString('utf8'));
 if(catalog.schema!=='mafiozi.godot.map-editor-catalog/v1'||catalog.resources.length!==196||saved.missingIds.length!==188||saved.counts.productionExactPresent!==8)throw Error('Unexpected catalog/adoption scope');
 const auditRows=new Map(saved.resources.map(row=>[row[0],row]));
 const missing=new Set(saved.missingIds);
 const records=[];let missingBytes=0,present=0;
 for(const entry of [...catalog.resources].sort((a,b)=>a.id.localeCompare(b.id,'en'))){
  if(!/^[a-f0-9]{64}$/.test(entry.id)||entry.id!==entry.sha256||!auditRows.has(entry.id)||!Number.isSafeInteger(entry.bytes)||entry.bytes<20)throw Error(`Invalid catalog resource: ${entry.id}`);
  const audited=auditRows.get(entry.id);
  if(audited[1]!==entry.bytes||JSON.stringify(audited[2])!==JSON.stringify(entry.sourcePaths)||audited[7]!==entry.resPath)throw Error(`Audit/catalog mismatch: ${entry.id}`);
  if(!Array.isArray(entry.sourcePaths)||entry.sourcePaths.length===0)throw Error(`No source paths: ${entry.id}`);
  const source=sourceAssetPath('/'+entry.sourcePaths[0],ROOT);
  const raw=await regular(source,rootReal);
  if(raw.length!==entry.bytes||sha(raw)!==entry.id)throw Error(`Source bytes drift: ${entry.id}`);
  const counts=glbCounts(raw);
  if(counts.materials!==entry.materialCount||counts.meshes!==entry.meshCount||counts.images!==counts.embeddedImages||(entry.externalDependencies||[]).length)throw Error(`GLB/catalog structure drift: ${entry.id}`);
  const isMissing=missing.has(entry.id);
  const refs=audited[5];
  if(isMissing){
   if(refs.length!==0||entry.resPath!=='')throw Error(`Missing resource unexpectedly has production path: ${entry.id}`);
   missingBytes+=entry.bytes;
  }else{
   present++;
   if(!audited[8]||!entry.resPath||refs.length===0)throw Error(`Present reference not declared: ${entry.id}`);
   for(const ref of refs){
    const target=path.join(ROOT,ref);
    const actual=await regular(target,rootReal);
    if(actual.length!==entry.bytes||sha(actual)!==entry.id)throw Error(`Present production reference drift: ${ref}`);
   }
  }
  records.push({sha256:entry.id,bytes:entry.bytes,sourcePaths:[...entry.sourcePaths],declaredResPath:entry.resPath,
   materials:counts.materials,meshes:counts.meshes,images:counts.images,embeddedImages:counts.embeddedImages,
   productionReferences:[...refs],packagePath:isMissing?`assets/map_editor/${entry.id}.glb`:null,
   proposedResPath:isMissing?`res://assets/map_editor/${entry.id}.glb`:entry.resPath,
   placedObjects:audited[3],assetIds:audited[4]});
 }
 if(records.length!==196||present!==8||records.filter(row=>row.packagePath).length!==188||missingBytes!==25601564)throw Error('Exact 188/8 resource count or bytes drift');
 const manifest={schema:'mafiozi.map-editor-missing-assets-package/v1',catalog:{path:catalogRelative,sha256:saved.catalog.sha256,bytes:saved.catalog.bytes},
  adoptionAudit:{path:auditRelative,sha256:auditSha},counts:{resources:196,missing:188,presentReferences:8,missingBytes},
  resources:records,limitations:['Raw GLBs only; no Godot import/cache, scene, collisions, nav, interior or FPS acceptance.','Missing catalog resPath entries remain empty until owner-controlled catalog admission.','Eight exact production references are not recopied.']};
 return {manifest,sourceById:new Map(records.filter(row=>row.packagePath).map(row=>[row.sha256,sourceAssetPath('/'+row.sourcePaths[0],ROOT)]))};
}
export async function stage(){
 const {manifest,sourceById}=await preflight();
 const outputReal=await fs.realpath(outputRoot);
 if(outputReal!==path.resolve(outputRoot))throw Error('Output root redirected');
 const targetRoot=await fs.mkdtemp(path.join(outputRoot,'map-editor-missing-assets-'));
 let copied=0;
 for(const row of manifest.resources){
  if(!row.packagePath)continue;
  const target=path.join(targetRoot,row.packagePath);
  if(!inside(targetRoot,target))throw Error('Package path escaped target');
  await fs.mkdir(path.dirname(target),{recursive:true});
  await fs.copyFile(sourceById.get(row.sha256),target,constants.COPYFILE_EXCL);
  const raw=await fs.readFile(target);
  if(raw.length!==row.bytes||sha(raw)!==row.sha256||JSON.stringify(glbCounts(raw))!==JSON.stringify({materials:row.materials,meshes:row.meshes,images:row.images,embeddedImages:row.embeddedImages}))throw Error(`Post-copy mismatch: ${row.sha256}`);
  copied++;
 }
 if(copied!==188)throw Error(`Incomplete package: ${copied}`);
 const manifestRaw=Buffer.from(JSON.stringify(manifest)+'\n');
 await fs.writeFile(path.join(targetRoot,'package_manifest.json'),manifestRaw,{flag:'wx'});
 return {targetRoot,manifestSha256:sha(manifestRaw),catalogSha256:manifest.catalog.sha256,adoptionAuditSha256:auditSha,copied,rawBytes:manifest.counts.missingBytes,presentReferences:8};
}
export async function verify(targetRoot){
 const outputReal=await fs.realpath(outputRoot);
 const targetReal=await fs.realpath(targetRoot);
 if(!inside(outputReal,targetReal))throw Error('Package outside outputs');
 const raw=await regular(path.join(targetReal,'package_manifest.json'),targetReal);
 const manifest=JSON.parse(raw.toString('utf8'));
 if(manifest.schema!=='mafiozi.map-editor-missing-assets-package/v1'||manifest.counts.missing!==188||manifest.counts.presentReferences!==8)throw Error('Package manifest schema/count drift');
 const current=(await preflight()).manifest;
 if(JSON.stringify(manifest)!==JSON.stringify(current))throw Error('Package manifest differs from current verified source');
 const rootEntries=(await fs.readdir(targetReal)).sort();
 const assetsEntries=(await fs.readdir(path.join(targetReal,'assets'))).sort();
 const assetFiles=(await fs.readdir(path.join(targetReal,'assets','map_editor'))).sort();
 const expectedFiles=manifest.resources.filter(row=>row.packagePath).map(row=>`${row.sha256}.glb`).sort();
 if(JSON.stringify(rootEntries)!==JSON.stringify(['assets','package_manifest.json'])||JSON.stringify(assetsEntries)!==JSON.stringify(['map_editor'])||JSON.stringify(assetFiles)!==JSON.stringify(expectedFiles))throw Error('Package path-set drift');
 let count=0,bytes=0;
 for(const row of manifest.resources){
  if(!row.packagePath)continue;
  const file=path.join(targetReal,row.packagePath);
  const asset=await regular(file,targetReal);
  if(asset.length!==row.bytes||sha(asset)!==row.sha256||JSON.stringify(glbCounts(asset))!==JSON.stringify({materials:row.materials,meshes:row.meshes,images:row.images,embeddedImages:row.embeddedImages}))throw Error(`Package GLB mismatch: ${row.sha256}`);
  count++;bytes+=asset.length;
 }
 if(count!==188||bytes!==25601564)throw Error('Package count/bytes mismatch');
 return {targetRoot:targetReal,manifestSha256:sha(raw),files:count,bytes,presentReferences:8,verified:true};
}
if(process.argv[1]&&path.resolve(process.argv[1])===fileURLToPath(import.meta.url)){
 const args=process.argv.slice(2);
 if(args.length===1&&args[0]==='--check'){
  const {manifest}=await preflight();
  console.log(JSON.stringify({mode:'check',catalog:manifest.catalog,counts:manifest.counts,manifestSha256:sha(Buffer.from(JSON.stringify(manifest)+'\n')),writes:false}));
 }else if(args.length===1&&args[0]==='--stage')console.log(JSON.stringify({mode:'stage',...await stage()}));
 else if(args.length===2&&args[0]==='--verify')console.log(JSON.stringify({mode:'verify',...await verify(args[1])}));
 else throw Error('Usage: stage.mjs --check | --stage | --verify <package-dir>');
}
