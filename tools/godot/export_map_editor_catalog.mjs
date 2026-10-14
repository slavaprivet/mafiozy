/** Lossless, deterministic inventory. Does not import assets or activate gameplay. */
import {readFile, readdir, writeFile, mkdir} from 'node:fs/promises';
import {resolve, relative, dirname, sep} from 'node:path';
import {fileURLToPath} from 'node:url';
import {createHash} from 'node:crypto';
import {createLandscapePlan} from '../../assets/maps/city_rebuild_v1/landscape_plan.mjs';
import {createExplorationRailwayPlan} from '../../assets/maps/city_rebuild_v1/exploration_railway_plan.mjs';
import {createCityRoadDressingPlan} from '../../assets/maps/city_rebuild_v1/city_road_dressing_plan.mjs';
import {createCityParkingPlan} from '../../assets/maps/city_rebuild_v1/city_parking_plan.mjs';
import {planExplorationDecor} from '../../assets/maps/city_rebuild_v1/exploration_decor_plan.mjs';
import {buildWalkMapGeneratedCollections} from '../../assets/maps/city_rebuild_v1/walk_map_editor_generated_sources.mjs';
import {createWalkMapEditorPalette} from '../../assets/maps/city_rebuild_v1/walk_map_editor_palette.mjs';

export const ROOT=resolve(dirname(fileURLToPath(import.meta.url)),'../..');
const SOURCE='assets/maps/city_rebuild_v1/', PROJECT='godot/mafiozi_walk/';
const digest=data=>createHash('sha256').update(data).digest('hex');
const slash=path=>path.split(sep).join('/');
const clone=value=>structuredClone(value);
export function localPosition(position,origin){
 if(!Array.isArray(position)||position.length!==3||!position.every(Number.isFinite))throw new Error('Invalid source position');
 return position.map((v,i)=>v-origin[i]);
}
export function sourceAssetPath(url,root=ROOT){
 if(typeof url!=='string'||!url.startsWith('/assets/')||url.includes('\\'))throw new Error(`Unsafe asset URL: ${url}`);
 const path=resolve(root,url.slice(1));
 if(!path.startsWith(resolve(root,'assets')+sep))throw new Error(`Asset outside assets: ${url}`);
 return path;
}
async function scanGlbs(folder){
 const result=[];
 for(const item of await readdir(folder,{withFileTypes:true})){
  const path=resolve(folder,item.name);
  if(item.isDirectory())result.push(...await scanGlbs(path));
  else if(item.isFile()&&item.name.endsWith('.glb'))result.push(path);
 }
 return result.sort();
}
export async function buildCatalog({root=ROOT}={}){
 const receipts=[];
 async function read(name){const path=resolve(root,name),raw=await readFile(path);receipts.push({path:name,sha256:digest(raw),bytes:raw.length});return JSON.parse(raw.toString('utf8').replace(/^\uFEFF/,''));}
 const buildings=await read(SOURCE+'buildings_placement.v1.json'),decor=await read(SOURCE+'decor_placement.v1.json'),detention=await read(SOURCE+'detention_native_sites.v1.json');
 const topology=await read(SOURCE+'topology_for_placement.json'),buildingCatalog=await read(SOURCE+'buildings_catalog.v1.json'),decorCatalog=await read(SOURCE+'decor_catalog.v1.json');
 const block=await read(PROJECT+'data/block.json'),origin=block.originM;
 if(buildings.metresPerCell!==4.1||topology.map.worldUnitsPerCell!==4.1)throw new Error('Native scale changed; coordinate contract must be reviewed');
 const imports=new Map();
 for(const path of await scanGlbs(resolve(root,PROJECT+'assets'))){const hash=digest(await readFile(path));const resPath='res://'+slash(relative(resolve(root,PROJECT),path));if(!imports.has(hash))imports.set(hash,[]);imports.get(hash).push(resPath);}
 const resources=new Map(),assetFileCache=new Map();
 async function resource(binding){
  const path=sourceAssetPath(binding.url,root);
  let raw=assetFileCache.get(path);if(!raw){raw=await readFile(path);assetFileCache.set(path,raw);}
  const hash=digest(raw);
  if(hash!==String(binding.sha256).toLowerCase()||raw.length!==binding.bytes)throw new Error(`Asset binding mismatch: ${binding.url}`);
  if(raw.length<20||raw.toString('ascii',0,4)!=='glTF'||raw.readUInt32LE(4)!==2||raw.readUInt32LE(8)!==raw.length||raw.readUInt32LE(16)!==0x4e4f534a)throw new Error(`Invalid GLB: ${binding.url}`);
  const gltf=JSON.parse(raw.toString('utf8',20,20+raw.readUInt32LE(12)));
  const externalDependencies=[...(gltf.buffers||[]),...(gltf.images||[])].filter(v=>v.uri&&!v.uri.startsWith('data:')).map(v=>v.uri);
  if(!resources.has(hash))resources.set(hash,{id:hash,sha256:hash,bytes:raw.length,sourcePaths:[],resPath:imports.get(hash)?.[0]||'',importedPaths:imports.get(hash)||[],status:imports.has(hash)&&!externalDependencies.length?'imported-verified':'pending-import',externalDependencies,materialCount:(gltf.materials||[]).length,meshCount:(gltf.meshes||[]).length,sharingPolicy:'One cached PackedScene/resource per SHA; preserve original materials, textures, LOD and meshes.'});
  const entry=resources.get(hash),sourcePath=slash(relative(root,path));if(!entry.sourcePaths.includes(sourcePath))entry.sourcePaths.push(sourcePath);
  return entry;
 }
 const objects=[];
 for(const [dataset,records] of [['buildings',buildings.instances],['detention',detention.instances],['decor',decor.instances]])for(const record of records){
  const res=await resource(record.binding),position=record.transform.positionM;
  objects.push({key:`${dataset}:${record.id}`,id:record.id,dataset,assetId:record.assetId,resourceId:res.id,resPath:res.resPath,positionLocalM:localPosition(position,origin),transform:clone(record.transform),sourceRecord:clone(record),status:res.status==='imported-verified'?'native-static-resource':'pending-import',available:res.status==='imported-verified',livePresent:[...(block.buildings||[]),...(block.decor||[])].some(v=>v.id===record.id),editCapability:'requires-host-registration',gameplayActive:false,sourceGameplayActive:record.gameplayActive===true});
 }
 const palette=createWalkMapEditorPalette({buildingCatalog,decorCatalog,currentRecords:[...buildings.instances,...decor.instances,...detention.instances]});
 const assets=[];
 // Include every catalog entry, including reviewed-but-not-placeable collections.
 for(const [dataset,entries] of [['building-catalog',buildingCatalog.entries],['decor-catalog',decorCatalog.entries]])for(const entry of entries){
  const lods=[];for(const binding of entry.lods||[]){const res=await resource(binding);lods.push({lod:binding.lod??0,resourceId:res.id,resPath:res.resPath,status:res.status,binding:clone(binding)});}
  const item=palette.find(v=>v.assetId===entry.assetId);
  assets.push({key:`${dataset}:${entry.assetId}`,assetId:entry.assetId,label:item?.label||entry.assetId,category:item?.category||'unsupported',lods,sourceRecord:clone(entry),sourcePaletteEligible:!!item,available:!!item&&lods.some(v=>v.lod===0&&v.status==='imported-verified'),status:lods.some(v=>v.lod===0&&v.status==='imported-verified')?'native-static-resource':'pending-import',adapterRequired:entry.assetRole?.endsWith('adapter_required')||false});
 }
 for(const record of objects)if(!assets.some(v=>v.assetId===record.assetId))assets.push({key:`placed-asset:${record.assetId}`,assetId:record.assetId,label:palette.find(v=>v.assetId===record.assetId)?.label||record.assetId,category:'buildings',lods:[{lod:record.sourceRecord.binding.lod??0,resourceId:record.resourceId,resPath:record.resPath,status:resources.get(record.resourceId).status,binding:clone(record.sourceRecord.binding)}],available:record.available,status:record.status,sourcePaletteEligible:true});
 const landscape=createLandscapePlan(),railway=createExplorationRailwayPlan({landscape,topology}),instances=[...buildings.instances,...decor.instances];
 const plans={railway,roadDressing:createCityRoadDressingPlan({topology,landscape,railPlan:railway,instances}),parking:createCityParkingPlan({topology,instances,railPlan:railway}),explorationDecor:planExplorationDecor({terrain:landscape,topology,buildings:buildings.instances,existingDecor:decor.instances,railPlan:railway})};
 const collections=buildWalkMapGeneratedCollections(plans),generatedCollections=[];
 for(const collection of collections){generatedCollections.push({dataset:collection.dataset,count:collection.records.length,dependencies:clone(collection.dependencies),sourceFile:collection.sourceFile,status:'pending-native-generator'});for(const record of collection.records){objects.push({key:`${collection.dataset}:${record.id}`,id:record.id,dataset:collection.dataset,kind:record.kind,label:collection.labelOf(record),category:collection.category,positionLocalM:Number.isFinite(record.x)&&Number.isFinite(record.z)?localPosition([record.x,record.y||0,record.z],origin):null,sourceRecord:clone(record),available:false,status:'pending-native-generator',editCapability:'requires-native-dependency-rebuild',dependencies:clone(collection.dependencies)});}}
 for(const name of ['landscape_plan.mjs','exploration_railway_plan.mjs','city_road_dressing_plan.mjs','city_parking_plan.mjs','exploration_decor_plan.mjs','walk_map_editor_generated_sources.mjs']){const raw=await readFile(resolve(root,SOURCE+name));receipts.push({path:SOURCE+name,bytes:raw.length,sha256:digest(raw)});}
 // Source objects are lossless. Do not serialize repeated CPU navigation indexes
 // (laneGraph/trafficPlan alone exceed 47MB) into a visual editor inventory.
 const generatedPlans={
  railway:Object.fromEntries(Object.entries(plans.railway).filter(([key])=>key!=='landscape'&&key!=='mapFeatures')),
  roadDressing:{markings:plans.roadDressing.markings,signs:plans.roadDressing.signs,signals:plans.roadDressing.signals},
  parking:{lots:plans.parking.lots,bays:plans.parking.bays,signs:plans.parking.signs,surfaceRects:plans.parking.surfaceRects},
  explorationDecor:{objects:plans.explorationDecor.objects}
 };
 const keys=new Set();for(const item of objects){if(keys.has(item.key))throw new Error(`Duplicate stable key ${item.key}`);keys.add(item.key);}
 const resourceList=[...resources.values()].sort((a,b)=>a.id.localeCompare(b.id));for(const entry of resourceList)entry.sourcePaths.sort();
 return {
  schema:'mafiozi.godot.map-editor-catalog/v1',scope:'full source inventory; imported resource availability is not full-map LIVE acceptance',
  originM:origin,metresPerCell:4.1,
  coordinateContract:'RH Y-up. Native source position in metres: local=source-origin. No additional 4.1 scaling. Tile c/r to source X/Z uses 4.1m. Positive yawDegrees preserved. Horizontal scale and modelLocalOffsetM remain authored.',
  sources:receipts.sort((a,b)=>a.path.localeCompare(b.path)),resources:resourceList,
  assets:assets.sort((a,b)=>a.key.localeCompare(b.key)),objects:objects.sort((a,b)=>a.key.localeCompare(b.key)),
  generatedCollections,generatedPlans,
  surface:{dataset:'topology',sourcePath:SOURCE+'topology_for_placement.json',sourceDocument:topology,status:'pending-native-topology-editor'},
  authoredExtras:{decorSurfaces:decor.surfaces||[],asphaltRects:decor.asphaltRects||[],materialDescriptors:decor.materialDescriptors||[],protectedRects:buildings.protectedRects||[],unresolved:{buildings:buildings.unresolved||[],decor:decor.unresolved||[]}},
  counts:{authoredBuildings:buildings.instances.length,detention:detention.instances.length,authoredDecor:decor.instances.length,generated:collections.reduce((n,v)=>n+v.records.length,0),objects:objects.length,resources:resourceList.length,importedResources:resourceList.filter(v=>v.status==='imported-verified').length,liveAuthoredObjects:objects.filter(v=>v.livePresent).length},
  limitations:['Native generated geometry, terrain, railway, traffic authority and editor dependency rebuilds are pending; original records are preserved, never substituted by dummy geometry.','Imported GLB proves identical bytes only; it does not certify visual parity, doors/interiors/gameplay, collision wiring or FPS.','Special building/vehicle-only collision flags, protected masks, source IDs and ownership contracts must survive host integration.','generatedPlans retains complete original object records, not runtime traffic/navigation/collider caches; rebuild those from hashed source planners.']
 };
}
export function serializeCatalog(catalog){return JSON.stringify(catalog)+'\n';}
if(process.argv[1]&&resolve(process.argv[1])===fileURLToPath(import.meta.url)){
 const result=serializeCatalog(await buildCatalog()),path=resolve(ROOT,PROJECT+'data/map_editor/catalog.json');
 if(process.argv.includes('--check')){if(await readFile(path,'utf8')!==result)throw new Error('Map editor catalog is stale');}
 else {await mkdir(dirname(path),{recursive:true});await writeFile(path,result);}
 console.log(JSON.stringify({path:slash(relative(ROOT,path)),counts:JSON.parse(result).counts,bytes:Buffer.byteLength(result),checked:process.argv.includes('--check')}));
}
