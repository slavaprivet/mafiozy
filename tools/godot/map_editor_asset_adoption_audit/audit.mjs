/** Read-only deterministic GLB/source-dependency audit. Never installs/imports. */
import {readFile,readdir,lstat,realpath} from 'node:fs/promises';
import {resolve,relative,isAbsolute,join} from 'node:path';
import {fileURLToPath} from 'node:url';
import {createHash} from 'node:crypto';
import {ROOT,sourceAssetPath} from '../export_map_editor_catalog.mjs';
import {inspectGlb} from '../install_map_editor_assets.mjs';

const hash=raw=>createHash('sha256').update(raw).digest('hex');
function inside(base,path){const rel=relative(base,path);return rel!==''&&!rel.startsWith('..')&&!isAbsolute(rel);}
async function regular(path,base){
 try{const stat=await lstat(path);if(!stat.isFile()||stat.isSymbolicLink()||!inside(base,await realpath(path)))return null;return readFile(path);}catch(error){if(error.code==='ENOENT')return null;throw error;}
}
async function glbs(dir,base){
 const found=[];
 async function visit(path){
  let rows;try{rows=await readdir(path,{withFileTypes:true});}catch(error){if(error.code==='ENOENT')return;throw error;}
  rows.sort((a,b)=>a.name.localeCompare(b.name,'en'));
  for(const row of rows){
   const target=join(path,row.name);
   if(row.isSymbolicLink())continue;
   if(row.isDirectory())await visit(target);
   else if(row.isFile()&&row.name.toLowerCase().endsWith('.glb')&&inside(base,target))found.push(target);
  }
 }
 await visit(dir);return found;
}
export async function audit({root=ROOT}={}){
 const base=await realpath(root),catalogPath=resolve(base,'godot/mafiozi_walk/data/map_editor/catalog.json');
 const catalogRaw=await regular(catalogPath,base);
 if(!catalogRaw)throw Error('Catalog missing/redirected');
 const catalog=JSON.parse(catalogRaw);
 if(catalog.schema!=='mafiozi.godot.map-editor-catalog/v1'||catalog.resources.length!==196)throw Error('Unexpected catalog schema/count');
 const assetRoot=resolve(base,'godot/mafiozi_walk/assets');
 const production=new Map();
 for(const path of await glbs(assetRoot,base)){
  const raw=await regular(path,base);if(!raw)throw Error('Production GLB changed during audit');
  const sha256=hash(raw),item={path:relative(base,path).replaceAll('\\','/'),bytes:raw.length};
  if(!production.has(sha256))production.set(sha256,[]);
  production.get(sha256).push(item);
 }
 const placements=new Map();
 for(const object of catalog.objects){
  if(!object.resourceId)continue;
  if(!placements.has(object.resourceId))placements.set(object.resourceId,{objects:0,assetIds:new Set()});
  const value=placements.get(object.resourceId);value.objects++;value.assetIds.add(String(object.assetId??''));
 }
 const resources=[];
 for(const entry of [...catalog.resources].sort((a,b)=>a.id.localeCompare(b.id,'en'))){
  if(!/^[a-f0-9]{64}$/.test(entry.id)||entry.id!==entry.sha256||!Array.isArray(entry.sourcePaths)||!entry.sourcePaths.length)throw Error('Invalid GLB receipt');
  const sourcePaths=[];
  for(const sourcePath of entry.sourcePaths){
   const absolute=sourceAssetPath('/'+sourcePath,base),raw=await regular(absolute,base);
   sourcePaths.push({path:sourcePath,exists:!!raw,bytes:raw?.length??null,sha256:raw?hash(raw):null});
  }
  const first=sourcePaths[0],sourceValid=sourcePaths.every(item=>item.exists&&item.bytes===entry.bytes&&item.sha256===entry.sha256);
  const firstRaw=first.exists?await regular(sourceAssetPath('/'+first.path,base),base):null;
  const glb=firstRaw&&sourceValid?inspectGlb(firstRaw):null;
  const placed=placements.get(entry.id);
  const matches=production.get(entry.id)||[];
  const declaredResPath=entry.resPath??'';
  if(typeof declaredResPath!=='string')throw Error('Invalid declared resPath');
  let declaredProductionPath='';
  if(declaredResPath){
   if(!declaredResPath.startsWith('res://assets/')||declaredResPath.includes('\\')||declaredResPath.slice('res://'.length).split('/').some(part=>!part||part==='.'||part==='..'))throw Error('Unsafe declared resPath');
   const absolute=resolve(base,'godot/mafiozi_walk',declaredResPath.slice('res://'.length));
   if(!inside(assetRoot,absolute))throw Error('Declared resPath escaped asset root');
   declaredProductionPath=relative(base,absolute).replaceAll('\\','/');
  }
  const canonicalPath=`godot/mafiozi_walk/assets/map_editor/${entry.id}.glb`;
  resources.push({id:entry.id,bytes:entry.bytes,sourcePaths,sourceValid,externalDependencies:entry.externalDependencies||[],inspectedExternalUris:glb?0:null,placedObjects:placed?.objects??0,placedAssetIds:placed?[...placed.assetIds].sort():[],declaredResPath,declaredProductionPath,declaredResPathPresent:!!declaredProductionPath&&matches.some(match=>match.path===declaredProductionPath&&match.bytes===entry.bytes),canonicalPath,canonicalPresent:matches.some(match=>match.path===canonicalPath&&match.bytes===entry.bytes),productionMatches:matches,productionPresent:matches.some(match=>match.bytes===entry.bytes),catalogStatus:entry.status});
 }
 const dependencies=[];
 for(const entry of [...catalog.sources].sort((a,b)=>a.path.localeCompare(b.path,'en'))){
  const path=resolve(base,entry.path);if(!inside(base,path))throw Error('Dependency path escaped root');
  const raw=await regular(path,base);
  dependencies.push({path:entry.path,expectedBytes:entry.bytes,expectedSha256:entry.sha256,actualBytes:raw?.length??null,actualSha256:raw?hash(raw):null,valid:!!raw&&raw.length===entry.bytes&&hash(raw)===entry.sha256});
 }
 const placedTypes=resources.filter(row=>row.placedObjects>0);
 const missing=resources.filter(row=>!row.productionPresent);
 return {schema:'mafiozi.map-editor-asset-adoption-audit/v2',catalog:{path:'godot/mafiozi_walk/data/map_editor/catalog.json',bytes:catalogRaw.length,sha256:hash(catalogRaw)},counts:{catalogResources:resources.length,placedTypes:placedTypes.length,placedObjects:placedTypes.reduce((n,row)=>n+row.placedObjects,0),productionGLBFiles:[...production.values()].reduce((n,rows)=>n+rows.length,0),productionExactPresent:resources.length-missing.length,productionMissing:missing.length,declaredResPaths:resources.filter(row=>!!row.declaredResPath).length,declaredResPathPresent:resources.filter(row=>row.declaredResPathPresent).length,declaredResPathMissing:resources.filter(row=>!!row.declaredResPath&&!row.declaredResPathPresent).length,canonicalPresent:resources.filter(row=>row.canonicalPresent).length,canonicalMissing:resources.filter(row=>!row.canonicalPresent).length,placedExactPresent:placedTypes.filter(row=>row.productionPresent).length,placedMissing:placedTypes.filter(row=>!row.productionPresent).length,placedDeclaredResPathPresent:placedTypes.filter(row=>row.declaredResPathPresent).length,placedCanonicalPresent:placedTypes.filter(row=>row.canonicalPresent).length,sourceGLBValid:resources.filter(row=>row.sourceValid).length,externalGLBDependencies:resources.reduce((n,row)=>n+row.externalDependencies.length,0),catalogDependencies:dependencies.length,catalogDependenciesValid:dependencies.filter(row=>row.valid).length},dependencies,resources,missingIds:missing.map(row=>row.id),placedTypes:placedTypes.map(row=>({id:row.id,assetIds:row.placedAssetIds,objects:row.placedObjects,productionPresent:row.productionPresent,declaredResPathPresent:row.declaredResPathPresent,canonicalPresent:row.canonicalPresent})),notes:['Exact raw-byte SHA/size only; .glb.import, Godot generated cache, scene behavior and GPU appearance are not acceptance.','declaredResPath is the current catalog load path; canonicalPath is a prospective SHA-addressed migration path, not the catalog path.','Catalog status is historical metadata; productionPresent is computed from current asset files.','No assets copied and no Godot process started.']};
}
export function compact(result){
 return {schema:'mafiozi.map-editor-asset-adoption-manifest/v2',catalog:result.catalog,counts:{...result.counts,sourcePaths:result.resources.reduce((n,row)=>n+row.sourcePaths.length,0),missingRawBytes:result.resources.filter(row=>!row.productionPresent).reduce((n,row)=>n+row.bytes,0)},dependencies:result.dependencies.map(row=>({path:row.path,bytes:row.expectedBytes,sha256:row.expectedSha256,valid:row.valid})),resourceFields:['sha256','bytes','sourcePaths','placedObjects','assetIds','exactProductionPaths','canonicalPresent','declaredResPath','declaredResPathPresent'],resources:result.resources.map(row=>[row.id,row.bytes,row.sourcePaths.map(source=>source.path),row.placedObjects,row.placedAssetIds,row.productionMatches.map(match=>match.path),row.canonicalPresent,row.declaredResPath,row.declaredResPathPresent]),missingIds:result.missingIds,placedTypes:result.placedTypes};
}
if(process.argv[1]&&resolve(process.argv[1])===fileURLToPath(import.meta.url)){
 const args=process.argv.slice(2);if(args.some(arg=>arg!=='--manifest'))throw Error('Use --manifest for compact saved format, or no flag for full audit');
 const result=await audit();console.log(JSON.stringify(args.includes('--manifest')?compact(result):result));
}
