/** Opt-in isolated Godot import harness. Never writes to production/checkpoint. */
import fs from 'node:fs/promises';
import {constants} from 'node:fs';
import path from 'node:path';
import crypto from 'node:crypto';
import {fileURLToPath} from 'node:url';
import {ROOT} from '../export_map_editor_catalog.mjs';
import {verify as verifyPackage} from './stage.mjs';

const own=path.dirname(fileURLToPath(import.meta.url));
const checkpoint=path.join(ROOT,'outputs','coordinator22_residents_checkpoint','godot','mafiozi_walk');
const packageRoot=path.join(ROOT,'outputs','map-editor-missing-assets-aE6EyN');
const outputRoot=path.join(ROOT,'outputs');
const currentProject=path.join(ROOT,'godot','mafiozi_walk');
const catalogPath=path.join(currentProject,'data','map_editor','catalog.json');
const expected={
 main:'faac92194afdfac5efb4197a17a81d53738a91a46a6e41f96316f9c282112f53',
 scene:'52aa1629fe38251f27ab50e3c6c102e0d0073348d6f610319d6c6b0233618bde',
 project:'c500a17d372f149b4b751ed4ef90a5a27bcb55e1050ba9d510d33fb5bcf6ff28',
 catalog:'ae089d73eb61131bc6a38ccc6a2b9b18639f7bd8b65079f7c15c1e1cda9cde6e',
 package:'50fe3ca72c5b7a6956495e870c0c2f618019abf62c92b5eaca4f7a1cddf9fa27'
};
const sha=bytes=>crypto.createHash('sha256').update(bytes).digest('hex');
function inside(base,target){const rel=path.relative(base,target);return !!rel&&!rel.startsWith('..')&&!path.isAbsolute(rel);}
async function checkedFile(file,base){
 if(!inside(base,file))throw Error(`Path escaped source root: ${file}`);
 const stat=await fs.lstat(file);
 if(!stat.isFile()||stat.isSymbolicLink()||!inside(base,await fs.realpath(file)))throw Error(`Redirected/nonregular source: ${file}`);
 return fs.readFile(file);
}
async function captureCheckpoint(){
 const base=await fs.realpath(checkpoint);
 const files=[];
 async function walk(dir){
  const entries=(await fs.readdir(dir,{withFileTypes:true})).sort((a,b)=>a.name.localeCompare(b.name,'en'));
  for(const entry of entries){
   const absolute=path.join(dir,entry.name);
   if(entry.isSymbolicLink())throw Error(`Checkpoint symlink refused: ${absolute}`);
   if(entry.isDirectory()){
    if(entry.name!=='.godot')await walk(absolute);
   }else if(entry.isFile())files.push([path.relative(base,absolute).split(path.sep).join('/'),await checkedFile(absolute,base)]);
  }
 }
 await walk(base);
 files.sort(([a],[b])=>a.localeCompare(b,'en'));
 if(files.length<300||files.length>3000)throw Error(`Unexpected checkpoint source closure count: ${files.length}`);
 const map=new Map(files);
 for(const [relative,digest] of [['scripts/main.gd',expected.main],['scenes/main.tscn',expected.scene],['project.godot',expected.project]]){
  if(!map.has(relative)||sha(map.get(relative))!==digest)throw Error(`Checkpoint anchor drift: ${relative}`);
 }
 const bytes=files.reduce((n,[,raw])=>n+raw.length,0);
 if(bytes>250*1024*1024)throw Error(`Checkpoint source closure too large: ${bytes}`);
 const digest=sha(Buffer.from(JSON.stringify(files.map(([relative,raw])=>[relative,sha(raw)]))));
 return {base,files,map,bytes,digest};
}
export async function preflightImport(){
 const packageProof=await verifyPackage(packageRoot);
 if(packageProof.manifestSha256!==expected.package)throw Error('188-GLB package pin drift');
 const packageManifest=JSON.parse(await fs.readFile(path.join(packageRoot,'package_manifest.json'),'utf8'));
 const checkpointState=await captureCheckpoint();
 const catalog=await checkedFile(catalogPath,await fs.realpath(currentProject));
 if(sha(catalog)!==expected.catalog)throw Error('Current verified editor catalog drift');
 if(checkpointState.map.has('data/map_editor/catalog.json'))throw Error('Checkpoint unexpectedly contains editor catalog');
 const missing=packageManifest.resources.filter(row=>row.packagePath);
 const present=packageManifest.resources.filter(row=>!row.packagePath);
 if(missing.length!==188||present.length!==8)throw Error('Package set drift');
 const supplemental=[];const retained=[];
 for(const row of present){
  if(row.productionReferences.length!==1||row.declaredResPath!==`res://${row.productionReferences[0].replace('godot/mafiozi_walk/','')}`)throw Error(`Declared reference mismatch: ${row.sha256}`);
  const relative=row.productionReferences[0].slice('godot/mafiozi_walk/'.length);
  const inCheckpoint=checkpointState.map.get(relative);
  if(inCheckpoint){
   if(inCheckpoint.length!==row.bytes||sha(inCheckpoint)!==row.sha256)throw Error(`Checkpoint reference drift: ${relative}`);
   retained.push({sha256:row.sha256,path:relative,bytes:row.bytes});
  }else{
   const source=path.join(currentProject,relative);
   const raw=await checkedFile(source,await fs.realpath(currentProject));
   if(raw.length!==row.bytes||sha(raw)!==row.sha256)throw Error(`Supplemental production reference drift: ${relative}`);
   supplemental.push({sha256:row.sha256,path:relative,bytes:row.bytes,source});
  }
 }
 if(retained.length!==5||supplemental.length!==3)throw Error(`Checkpoint 5+3 declared-reference distinction drift: ${retained.length}+${supplemental.length}`);
 const overlayPaths=new Set(['data/map_editor/catalog.json','project.godot','test_import_188.gd','test_import_manifest.json','import_source_snapshot.json']);
 for(const row of missing)overlayPaths.add(row.packagePath);
 for(const row of supplemental)overlayPaths.add(row.path);
 for(const file of overlayPaths)if(file!=='project.godot'&&checkpointState.map.has(file))throw Error(`Overlay would replace checkpoint file: ${file}`);
 return {packageProof,packageManifest,checkpointState,catalog,missing,present,retained,supplemental,overlayPaths};
}
export async function stageImport(){
 const p=await preflightImport();
 const outputReal=await fs.realpath(outputRoot);
 if(outputReal!==path.resolve(outputRoot))throw Error('Output root redirected');
 const stage=await fs.mkdtemp(path.join(outputRoot,'map-editor-188-import-'));
 const projectOriginal=p.checkpointState.map.get('project.godot').toString('utf8');
 const projectText=projectOriginal.replace('config/custom_user_dir_name="MafioziGodotPreview"',`config/custom_user_dir_name="MafioziAssetImport-${crypto.randomUUID()}"`);
 if(projectText===projectOriginal)throw Error('Isolated user-dir seam missing');
 const overlays=new Map([
  ['project.godot',Buffer.from(projectText)],
  ['data/map_editor/catalog.json',p.catalog],
  ['test_import_188.gd',await fs.readFile(path.join(own,'test_import_188.gd'))],
  ['test_import_manifest.json',await fs.readFile(path.join(packageRoot,'package_manifest.json'))]
 ]);
 for(const row of p.missing)overlays.set(row.packagePath,await checkedFile(path.join(packageRoot,row.packagePath),await fs.realpath(packageRoot)));
 for(const row of p.supplemental)overlays.set(row.path,await checkedFile(row.source,await fs.realpath(currentProject)));
 if(overlays.size!==195)throw Error(`Expected 188+3+catalog+project+test+manifest overlays, got ${overlays.size}`);
 const receipt={schema:1,purpose:'headless import of 188 package GLBs plus 3 checkpoint-only exact refs; not production admission',
  checkpoint:{path:path.relative(ROOT,checkpoint).split(path.sep).join('/'),files:p.checkpointState.files.length,bytes:p.checkpointState.bytes,closureSha256:p.checkpointState.digest,anchors:{main:expected.main,scene:expected.scene,project:expected.project}},
  package:{path:path.relative(ROOT,packageRoot).split(path.sep).join('/'),manifestSha256:expected.package,missing:188,rawBytes:p.packageManifest.counts.missingBytes},
  catalogSha256:expected.catalog,retained:p.retained,supplemental:p.supplemental.map(({source,...rest})=>rest),overlays:[],files:[]};
 const staged=[...p.checkpointState.files.filter(([relative])=>!overlays.has(relative)),...overlays];
 for(const [relative,raw] of staged){
  const dest=path.join(stage,relative);
  if(!inside(stage,dest))throw Error(`Stage path escaped: ${relative}`);
  await fs.mkdir(path.dirname(dest),{recursive:true});
  await fs.writeFile(dest,raw,{flag:'wx'});
  const copied=await fs.readFile(dest);
  if(copied.length!==raw.length||sha(copied)!==sha(raw))throw Error(`Stage copy mismatch: ${relative}`);
  receipt.files.push({path:relative,sha256:sha(raw),bytes:raw.length,origin:overlays.has(relative)?'overlay':'checkpoint'});
  if(overlays.has(relative))receipt.overlays.push(relative);
 }
 let checkedCatalogPaths=0;
 for(const row of p.packageManifest.resources){
  const relative=row.proposedResPath.replace(/^res:\/\//,'');
  if(!row.proposedResPath.startsWith('res://assets/')||!relative.startsWith('assets/'))throw Error(`Unsafe catalog resource path: ${row.sha256}`);
  const asset=await checkedFile(path.join(stage,relative),await fs.realpath(stage));
  if(asset.length!==row.bytes||sha(asset)!==row.sha256)throw Error(`Staged catalog resource mismatch: ${row.sha256}`);
  checkedCatalogPaths++;
 }
 if(checkedCatalogPaths!==196)throw Error('Incomplete catalog target preflight');
 receipt.checkedCatalogPaths=checkedCatalogPaths;
 const newCheckpoint=await captureCheckpoint();
 if(newCheckpoint.digest!==p.checkpointState.digest)throw Error('Concurrent checkpoint source drift');
 if(sha(await fs.readFile(catalogPath))!==expected.catalog)throw Error('Concurrent catalog drift');
 await fs.writeFile(path.join(stage,'import_source_snapshot.json'),JSON.stringify(receipt,null,2),{flag:'wx'});
 return {stage,checkpointFiles:p.checkpointState.files.length,checkpointSha256:p.checkpointState.digest,overlays:receipt.overlays.length,checkedCatalogPaths,missingGLB:188,supplementalGLB:3,retainedGLB:5,catalogSha256:expected.catalog,packageManifestSha256:expected.package,gpu:false};
}
if(process.argv[1]&&path.resolve(process.argv[1])===fileURLToPath(import.meta.url)){
 const args=process.argv.slice(2);
 if(args.length===1&&args[0]==='--check'){
  const p=await preflightImport();
  console.log(JSON.stringify({mode:'check',checkpointFiles:p.checkpointState.files.length,checkpointBytes:p.checkpointState.bytes,checkpointSha256:p.checkpointState.digest,missingGLB:p.missing.length,supplementalGLB:p.supplemental.length,retainedGLB:p.retained.length,catalogSha256:expected.catalog,writes:false}));
 }else if(args.length===1&&args[0]==='--stage')console.log(JSON.stringify({mode:'stage',...await stageImport()}));
 else throw Error('Usage: stage_import.mjs --check | --stage');
}
