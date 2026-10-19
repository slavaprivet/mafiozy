/** Outputs-only manifest for canonical SHA paths; never installs assets. */
import assert from 'node:assert/strict';
import crypto from 'node:crypto';
import fs from 'node:fs';
import path from 'node:path';
import {fileURLToPath} from 'node:url';
import {CATALOG_SHA256} from './source_index.mjs';

const ROOT=path.resolve(path.dirname(fileURLToPath(import.meta.url)),'../../..');
const PACKAGE='outputs/map-editor-missing-assets-aE6EyN';
const PACKAGE_MANIFEST_SHA='50fe3ca72c5b7a6956495e870c0c2f618019abf62c92b5eaca4f7a1cddf9fa27';
const GAME='godot/mafiozi_walk';
const sha=bytes=>crypto.createHash('sha256').update(bytes).digest('hex');
const validId=id=>/^[0-9a-f]{64}$/.test(id);
const within=(base,target)=>{const rel=path.relative(base,target);return rel!==''&&!rel.startsWith('..')&&!path.isAbsolute(rel);};
function regular(rel){
 assert.ok(!path.isAbsolute(rel)&&!rel.split(/[\\/]/).includes('..'),'unsafe relative path');
 const target=path.resolve(ROOT,rel),stat=fs.lstatSync(target);
 assert.ok(stat.isFile()&&!stat.isSymbolicLink(),'not a regular file: '+rel);
 assert.ok(within(ROOT,fs.realpathSync(target)),'source escapes repository: '+rel);
 return fs.readFileSync(target);
}
function listing(rel){
 const dir=path.resolve(ROOT,rel),stat=fs.lstatSync(dir);
 assert.ok(stat.isDirectory()&&!stat.isSymbolicLink()&&within(ROOT,fs.realpathSync(dir)),'unsafe directory: '+rel);
 const found=[];
 function walk(current,prefix=''){
  for(const entry of fs.readdirSync(current,{withFileTypes:true})){
   assert.ok(!entry.isSymbolicLink(),'symlink in GLB path set: '+entry.name);
   const name=prefix+entry.name,child=path.join(current,entry.name);
   if(entry.isDirectory())walk(child,name+'/');
   else if(entry.name.endsWith('.glb')){assert.ok(entry.isFile(),'nonfile GLB path');found.push(name);}
  }
 }
 walk(dir);
 return found.sort();
}
export function buildActivation(){
 const catalogBytes=regular(`${GAME}/data/map_editor/catalog.json`);
 assert.equal(sha(catalogBytes),CATALOG_SHA256,'catalog lineage drift');
 const packageBytes=regular(`${PACKAGE}/package_manifest.json`);
 assert.equal(sha(packageBytes),PACKAGE_MANIFEST_SHA,'missing-package lineage drift');
 const catalog=JSON.parse(catalogBytes),pkg=JSON.parse(packageBytes);
 assert.equal(pkg.schema,'mafiozi.map-editor-missing-assets-package/v1');
 assert.equal(pkg.catalog.sha256,CATALOG_SHA256);
 assert.equal(pkg.counts.resources,196);
 assert.equal(pkg.counts.missing,188);
 assert.equal(pkg.counts.presentReferences,8);
 assert.equal(catalog.resources.length,196);
 assert.equal(pkg.resources.length,196);
 const source=new Map(catalog.resources.map(row=>[row.id,row]));
 assert.equal(source.size,196,'duplicate catalog resource');
 const rows=[],packageNames=[],presentNames=[],historicNames=[];
 let pendingBytes=0;
 for(const entry of pkg.resources){
  const id=entry.sha256,original=source.get(id);
  assert.ok(validId(id)&&original&&entry.bytes===original.bytes&&original.sha256===id&&original.id===id,'resource receipt mismatch');
  assert.equal(entry.declaredResPath,original.resPath);
  assert.deepEqual(entry.sourcePaths,original.sourcePaths);
  const dest=`${GAME}/assets/map_editor/${id}.glb`;
  assert.equal(entry.proposedResPath,entry.packagePath?`res://assets/map_editor/${id}.glb`:original.resPath);
  let from,action;
  if(entry.packagePath){
   assert.equal(entry.packagePath,`assets/map_editor/${id}.glb`);
   assert.deepEqual(entry.productionReferences,[]);
   assert.equal(original.resPath,'');
   from=`${PACKAGE}/${entry.packagePath}`;
   action='copy-exclusive-package';
   packageNames.push(`${id}.glb`);
  }else{
   assert.equal(entry.productionReferences.length,1);
   from=entry.productionReferences[0].replaceAll('\\','/');
   assert.ok(from.startsWith(`${GAME}/assets/`),'unexpected historical reference');
   assert.equal(original.resPath,`res://${from.slice((GAME+'/').length)}`);
   if(from===dest){action='verify-existing-canonical';presentNames.push(`${id}.glb`);}
   else{action='copy-exclusive-historical';historicNames.push(from);}
  }
  const raw=regular(from);
  assert.equal(raw.length,entry.bytes,'source byte mismatch: '+id);
  assert.equal(sha(raw),id,'source SHA mismatch: '+id);
  const exists=fs.existsSync(path.resolve(ROOT,dest));
  assert.equal(exists,action==='verify-existing-canonical','canonical destination collision/drift: '+id);
  if(exists){const installed=regular(dest);assert.equal(installed.length,entry.bytes);assert.equal(sha(installed),id);}
  else pendingBytes+=entry.bytes;
  rows.push({id,bytes:entry.bytes,action,source:from,destination:dest,resPath:`res://assets/map_editor/${id}.glb`,historicalResPath:original.resPath||null});
 }
 assert.equal(new Set(rows.map(row=>row.id)).size,196);
 assert.equal(new Set(rows.map(row=>row.destination)).size,196);
 assert.equal(packageNames.length,188);
 assert.equal(historicNames.length,5);
 assert.equal(presentNames.length,3);
 assert.deepEqual(listing(`${PACKAGE}/assets/map_editor`),packageNames.sort(),'package GLB path-set drift');
 assert.deepEqual(listing(`${GAME}/assets/map_editor`),presentNames.sort(),'production canonical GLB path-set drift');
 rows.sort((a,b)=>a.id.localeCompare(b.id));
 return {schema:'mafiozi.map-editor-canonical-activation-plan/v1',mode:'outputs-only-not-installed',catalogSha256:CATALOG_SHA256,missingPackageManifestSha256:PACKAGE_MANIFEST_SHA,sourcePackage:PACKAGE,productionProject:GAME,counts:{resources:196,copyFromPackage:188,copyFromHistorical:5,alreadyCanonical:3,copyBytes:pendingBytes},preflight:{packageGlbNames:packageNames,canonicalGlbNames:presentNames,historicalSources:historicNames.sort()},rows,limits:['No Godot import or runtime activation was performed.','Catalog resPath and available flags are not rewritten or edit-owner receipts.','Install only after fresh whole-path-set and SHA preflight against this receipt.']};
}

if(process.argv[1]&&path.resolve(process.argv[1])===fileURLToPath(import.meta.url)){
 const args=process.argv.slice(2);
 assert.ok(args.length===1&&['--check','--stage'].includes(args[0]),'usage: node canonical_activation.mjs --check|--stage');
 const plan=buildActivation();
 if(args[0]==='--check')console.log(JSON.stringify({status:'PASS_READONLY',...plan.counts,catalogSha256:plan.catalogSha256,packageSha256:plan.missingPackageManifestSha256}));
 else{
  const dir=fs.mkdtempSync(path.join(ROOT,'outputs/map-editor-canonical-activation-'));
  const bytes=Buffer.from(JSON.stringify(plan,null,2)+'\n');
  const target=path.join(dir,'activation_manifest.json');
  fs.writeFileSync(target,bytes,{flag:'wx'});
  assert.equal(sha(fs.readFileSync(target)),sha(bytes));
  console.log(JSON.stringify({status:'STAGED_OUTPUT_ONLY',manifest:path.relative(ROOT,target).replaceAll('\\','/'),sha256:sha(bytes),...plan.counts}));
 }
}
