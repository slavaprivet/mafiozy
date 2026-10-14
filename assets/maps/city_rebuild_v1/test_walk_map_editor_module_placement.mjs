import assert from 'node:assert/strict';
import test from 'node:test';
import {createHash} from 'node:crypto';
import {readFile} from 'node:fs/promises';
import {
 createWalkMapEditorDocument,createWalkMapEditorSession,executeWalkMapEditorCommand,makeWalkMapObjectAddCommand,
 parseWalkMapEditorDocument,redoWalkMapEditorCommand,serializeWalkMapEditorDocument,undoWalkMapEditorCommand
} from './walk_map_editor_document.mjs';
import {createWalkMapProtectionPolicy} from './walk_map_editor_protection.mjs';
import {createWalkMapAssetPlacement} from './walk_map_editor_asset_placement.mjs';
import {createWalkMapEditorPalette} from './walk_map_editor_palette.mjs';
import {
 WALK_MAP_MODULE_SCHEMA,WALK_MAP_MODULE_SOCKET_CONTRACTS,createWalkMapModuleCommandPreparer,createWalkMapModuleLiveAdapter,
 createWalkMapVerifiedModulePlacement,walkMapVerifiedModuleAssetState
} from './walk_map_editor_module_placement.mjs';

const here=new URL('.',import.meta.url),load=async file=>JSON.parse(await readFile(new URL(file,here),'utf8'));
const [decorCatalog,buildingCatalog,buildings,detentions,decor]=await Promise.all([load('decor_catalog.v1.json'),load('buildings_catalog.v1.json'),load('buildings_placement.v1.json'),load('detention_native_sites.v1.json'),load('decor_placement.v1.json')]);
const entries=decorCatalog.entries.filter(entry=>entry.assetRole==='walkable_surface_adapter_required'),currentRecords=[...buildings.instances,...detentions.instances,...decor.instances];
const rows=200,cols=180,m=4.1,center=[410,0,410];
function topology(){const matrix=value=>Array.from({length:rows},()=>Array(cols).fill(value));return {map:{rows,cols,worldUnitsPerCell:m},grid:matrix(8),roadMask:matrix(0),protectedMask:matrix(0),policeMask:matrix(0),bridgeDeckMask:matrix(0)}}
function inventory(extra={}){return {complete:{buildings:true,parking:true,railway:true,modules:true},buildings:[],parkingKeepouts:[],railway:[],modules:[],...extra}}
function callbacks(entry){let surfaceAt=()=> 'grass',groundHeightAt=()=>0;if(entry.kind==='waterfront')surfaceAt=(_x,z)=>z<center[2]?'water':'grass';if(entry.kind==='surface_transition'){const [a,b]=entry.assetId.replace(/^transition_/,'').split('_');surfaceAt=(_x,z)=>z>center[2]?a:b}if(entry.assetId.endsWith('slope_up'))groundHeightAt=(_x,z)=>z<center[2]?1.2:0;if(entry.assetId.endsWith('slope_down'))groundHeightAt=(_x,z)=>z>center[2]?1.2:0;return {surfaceAt,groundHeightAt}}
function compiler(entry,{top=topology(),items=inventory(),surfaceAt,groundHeightAt}={}){const derived=callbacks(entry);return createWalkMapVerifiedModulePlacement({catalogEntries:entries,topology:top,inventory:items,metresPerCell:m,surfaceAt:surfaceAt||derived.surfaceAt,groundHeightAt:groundHeightAt||derived.groundHeightAt})}
function palette(flags={}){return createWalkMapEditorPalette({buildingCatalog,decorCatalog,currentRecords,...flags})}
function vector(){return {x:0,y:0,z:0,fromArray(a){[this.x,this.y,this.z]=a},set(x,y,z){this.x=x;this.y=y;this.z=z}}}
function root(record=null){return {position:vector(),rotation:{y:0},scale:vector(),visible:true,userData:record?{instance:record}:{},updateWorldMatrix(){this.updated=true},clone(){return root()}}}
function stage(){return {children:[],add(value){this.children.push(value)},remove(value){this.children=this.children.filter(item=>item!==value)}}}

test('exact locked inventory is explained and all 20 verified module GLBs unlock only with their adapter',()=>{
 assert.equal(entries.length,20);const baseline=palette({roadControlAdapterAvailable:true,roadSignAdapterAvailable:false}),enabled=palette({roadControlAdapterAvailable:true,roadSignAdapterAvailable:true,modulePlacementAdapterAvailable:true});
 assert.deepEqual({total:baseline.length,available:baseline.filter(item=>item.available).length,locked:baseline.filter(item=>!item.available).length},{total:68,available:45,locked:23});
 assert.deepEqual({total:enabled.length,available:enabled.filter(item=>item.available).length,locked:enabled.filter(item=>!item.available).length},{total:68,available:68,locked:0});
 const unlocked=enabled.filter(item=>entries.some(entry=>entry.assetId===item.assetId));assert.equal(unlocked.length,20);assert.ok(unlocked.every(item=>item.available&&item.placementMode==='module'&&/spatial contract/i.test(item.reason)));
 const locked=baseline.filter(item=>entries.some(entry=>entry.assetId===item.assetId));assert.ok(locked.every(item=>!item.available&&item.placementMode==='module'&&/адаптер модульных/i.test(item.reason)));assert.deepEqual(baseline.filter(item=>!item.available&&item.placementMode==='road-control').map(item=>item.assetId).sort(),['sign_no_parking','sign_ped_crossing','sign_wayfinding']);
 for(const entry of entries){assert.equal(walkMapVerifiedModuleAssetState(entry,{adapterAvailable:true}).available,true,entry.assetId);assert.equal(enabled.find(item=>item.assetId===entry.assetId)?.binding.url,entry.lods.find(lod=>lod.lod===0).url)}
});

test('every unlocked module uses a real standalone GLB with matching bytes and SHA-256',async()=>{
 for(const entry of entries){const lod=entry.lods.find(item=>item.lod===0);assert.ok(!/collection/i.test(lod.url),entry.assetId);const bytes=await readFile(new URL(`../../..${lod.url}`,import.meta.url));assert.equal(bytes.byteLength,lod.bytes,entry.assetId);assert.equal(createHash('sha256').update(bytes).digest('hex'),lod.sha256,entry.assetId);assert.equal(entry.sourceValidation.status,'pass');assert.equal(entry.stagingStatus,'bytes_and_contract_nodes_verified')}
});

test('shore, material and slope socket coordinates are byte-for-byte derived from the real GLB nodes',async()=>{
 function gltfJson(buffer){let offset=12;while(offset<buffer.length){const length=buffer.readUInt32LE(offset),type=buffer.readUInt32LE(offset+4),chunk=buffer.subarray(offset+8,offset+8+length);if(type===0x4e4f534a)return JSON.parse(chunk.toString('utf8').replace(/\0+$/,''));offset+=8+length}throw new Error('GLB JSON chunk missing')}
 for(const [assetId,contract] of Object.entries(WALK_MAP_MODULE_SOCKET_CONTRACTS)){const entry=entries.find(value=>value.assetId===assetId),lod=entry.lods.find(item=>item.lod===0),gltf=gltfJson(await readFile(new URL(`../../..${lod.url}`,import.meta.url))),nodes=gltf.nodes||[],translation=pattern=>nodes.find(node=>pattern.test(node.name||''))?.translation||[0,0,0];if(contract.low){assert.deepEqual(contract.low,translation(/^SLOPE_LOW_SOCKET_/),assetId);assert.deepEqual(contract.high,translation(/^SLOPE_HIGH_SOCKET_/),assetId)}else if(contract.shore){assert.deepEqual(contract.shore,translation(/^SHORE_SOCKET_/),assetId);assert.deepEqual(contract.water,translation(/^WATER_EDGE_SOCKET_/),assetId)}else{assert.deepEqual(contract.a,translation(new RegExp(`^MATERIAL_${contract.aMaterial.toUpperCase()}_SOCKET_`)),assetId);assert.deepEqual(contract.b,translation(new RegExp(`^MATERIAL_${contract.bMaterial.toUpperCase()}_SOCKET_`)),assetId)}}
});

test('palette selection and preview placement compile every unlocked type without visual substitution',async()=>{
 const enabled=palette({roadControlAdapterAvailable:true,modulePlacementAdapterAvailable:true}),scene=stage(),records=[];
 for(const entry of entries){const item=enabled.find(value=>value.assetId===entry.assetId),placement=compiler(entry),api=createWalkMapAssetPlacement({scene,loadTemplate:async binding=>{assert.equal(binding.sha256,item.binding.sha256);return root()},compileRecord:placement.compileAssetRecord,idExists:()=>false});const preview=await api.begin(item,{positionM:center,yawDegrees:0});assert.equal(scene.children[0],preview);assert.equal(preview.userData.editorAssetKey,item.key);if(records.length===0){assert.equal(api.cancel('escape'),true);assert.equal(scene.children.length,0);await api.begin(item,{positionM:center,yawDegrees:0})}const result=await api.commit();assert.equal(result.record.schema,WALK_MAP_MODULE_SCHEMA);assert.equal(result.record.assetId,entry.assetId);assert.deepEqual(result.record.binding,item.binding);assert.deepEqual(result.record.sourceContract.visualBoundsBlenderM,entry.visualBoundsBlenderM);assert.ok(result.record.collision.worldBodies.length===entry.collisionBodiesGltfM.length);assert.equal(scene.children.length,0);records.push(result.record);api.dispose()}
 assert.equal(records.length,20);assert.equal(new Set(records.map(record=>record.id)).size,20);
});

test('water, transition materials and slope sockets are validated from their real contract',()=>{
 const waterfront=entries.find(entry=>entry.assetId==='fishing_pier_short'),transition=entries.find(entry=>entry.assetId==='transition_sand_grass'),slope=entries.find(entry=>entry.assetId==='forest_path_dirt_slope_up');
 assert.equal(compiler(waterfront).compileAssetRecord({asset:waterfront,transform:{positionM:center,yawDegrees:0}}).record.assetId,waterfront.assetId);
 assert.throws(()=>compiler(waterfront,{surfaceAt:()=> 'grass'}).compileAssetRecord({asset:waterfront,transform:{positionM:center}}),error=>error.code==='MODULE_SHORE_MISMATCH');
 assert.equal(compiler(transition).compileAssetRecord({asset:transition,transform:{positionM:center}}).record.assetId,transition.assetId);
 assert.throws(()=>compiler(transition,{surfaceAt:()=> 'grass'}).compileAssetRecord({asset:transition,transform:{positionM:center}}),error=>error.code==='MODULE_MATERIAL_MISMATCH');
 const sloped=compiler(slope).compileAssetRecord({asset:slope,transform:{positionM:center}}).record;assert.ok(Math.abs(sloped.transform.positionM[1]+.11999999731779099)<1e-9);
 assert.throws(()=>compiler(slope,{groundHeightAt:()=>0}).compileAssetRecord({asset:slope,transform:{positionM:center}}),error=>error.code==='MODULE_SLOPE_MISMATCH');
});

test('topology and complete occupancy guards fail closed for protected, road, water, entry, parking and railway conflicts',()=>{
 const entry=entries.find(value=>value.assetId==='forest_path_dirt_straight'),compileWith=(top,items=inventory())=>compiler(entry,{top,items}).compileAssetRecord({asset:entry,transform:{positionM:center}});
 const protectedTop=topology();protectedTop.protectedMask[100][100]=1;assert.throws(()=>compileWith(protectedTop),error=>error.code==='MODULE_ON_PROTECTED');
 const roadTop=topology();roadTop.roadMask[100][100]=1;assert.throws(()=>compileWith(roadTop),error=>error.code==='MODULE_ON_ROAD');
 const waterTop=topology();waterTop.grid[100][100]=16;assert.throws(()=>compileWith(waterTop),error=>error.code==='MODULE_ON_WATER');
 const rect={minX:405,minZ:405,maxX:415,maxZ:415};assert.throws(()=>compileWith(topology(),inventory({buildings:[{id:'b',entryCorridor:rect}]})),error=>error.code==='MODULE_BUILDING_OVERLAP');
 assert.throws(()=>compileWith(topology(),inventory({parkingKeepouts:[{id:'p',rectM:rect}]})),error=>error.code==='MODULE_PARKING_OVERLAP');
 assert.throws(()=>compileWith(topology(),inventory({railway:[{id:'r',rectM:rect}]})),error=>error.code==='MODULE_RAILWAY_OVERLAP');
 assert.throws(()=>compiler(entry,{items:{complete:{buildings:true},buildings:[],parkingKeepouts:[],railway:[],modules:[]}}).compileAssetRecord({asset:entry,transform:{positionM:center}}),error=>error.code==='MODULE_INVENTORY_INCOMPLETE');
 assert.throws(()=>compiler(entry).compileAssetRecord({asset:entry,transform:{positionM:center,uniformScale:2}}),error=>error.code==='MODULE_SCALE_LOCKED');
});

test('live preview supports cancel, move, rotate, commit, delete and tombstone/reactivation with exact root transforms',async()=>{
 const entry=entries.find(value=>value.assetId==='forest_path_gravel_straight'),placement=compiler(entry),record=placement.compileAssetRecord({asset:entry,transform:{positionM:center}}).record,node=root(record),commits=[],live=createWalkMapModuleLiveAdapter({placement,records:[record],roots:[node],onCommit:event=>commits.push(event)});
 live.beginPreview(record.id);const moved=live.updatePreview(record.id,{...record.transform,positionM:[430,0,430],yawDegrees:90});assert.deepEqual([node.position.x,node.position.y,node.position.z],moved.transform.positionM);assert.ok(Math.abs(node.rotation.y-Math.PI/2)<1e-12);assert.deepEqual([node.scale.x,node.scale.y,node.scale.z],[1,1,1]);assert.equal(live.cancelPreview(record.id),true);assert.deepEqual([node.position.x,node.position.y,node.position.z],record.transform.positionM);
 live.beginPreview(record.id);const after=live.updatePreview(record.id,{...record.transform,positionM:[430,0,430],yawDegrees:90});const command=live.commitPreview(record.id);assert.equal(command.patch.action,'modify');assert.deepEqual(command.patch.after,after);assert.equal(commits.length,1);assert.equal(live.deleteCommand(record.id).patch.action,'delete');assert.equal(live.deactivate(record.id),true);assert.equal(node.visible,false);live.replaceRecord(record.id,record,node);assert.equal(node.visible,true);assert.deepEqual([node.position.x,node.position.y,node.position.z],record.transform.positionM);live.dispose();
});

test('stale-current preparer and document undo/redo/save/reload preserve the exact trusted module record',async()=>{
 const entry=entries.find(value=>value.assetId==='forest_path_gravel_curve'),placement=compiler(entry),record=placement.compileAssetRecord({asset:entry,transform:{positionM:center}}).record,after=placement.compileTransform({currentRecord:record,nextTransform:{...record.transform,positionM:[430,0,430],yawDegrees:90}}).record;
 const raw={type:'object.set-patch',patch:{source:{dataset:'custom',id:record.id},action:'modify',before:record,after}},prepare=createWalkMapModuleCommandPreparer({resolveCurrentEntity:()=>record,placement}),prepared=await prepare(raw);assert.deepEqual(prepared.command.patch.after,after);await assert.rejects(()=>createWalkMapModuleCommandPreparer({resolveCurrentEntity:()=>({...record,kind:'changed'}),placement})(raw),error=>error.code==='STALE_MODULE_PREVIEW');
 const digests={topology:'1'.repeat(64),buildings:'2'.repeat(64),decor:'3'.repeat(64)},base={topology:{sha256:digests.topology},buildings:{sha256:digests.buildings},decor:{sha256:digests.decor}},masks={protectedMask:topology().protectedMask,policeMask:topology().policeMask,bridgeDeckMask:topology().bridgeDeckMask},policy=createWalkMapProtectionPolicy({rows,cols,worldUnitsPerCell:m,sourceDigests:digests,masks,footprintAdapters:new Map([['custom',{id:'verified-module-cells',version:1,cellsFor:({snapshot})=>snapshot.spatial.cells}]])});
 const doc=createWalkMapEditorDocument({documentId:'module-history',createdAt:'2026-09-23T20:00:00.000Z',map:{rows,cols,worldUnitsPerCell:m},base}),options={protectionPolicy:policy,resolveBaseEntity:()=>({status:'absent',entity:null}),updatedAt:'2026-09-23T20:01:00.000Z'},add=makeWalkMapObjectAddCommand({source:{dataset:'custom',id:record.id},object:record,metadata:{adapter:'test'}});let session=executeWalkMapEditorCommand(createWalkMapEditorSession(doc),add,options);assert.equal(session.document.objectPatches.length,1);session=undoWalkMapEditorCommand(session,{protectionPolicy:policy,updatedAt:'2026-09-23T20:02:00.000Z'});assert.equal(session.document.objectPatches.length,0);session=redoWalkMapEditorCommand(session,{protectionPolicy:policy,updatedAt:'2026-09-23T20:03:00.000Z'});assert.deepEqual(session.document.objectPatches[0].after,record);
 const reloaded=parseWalkMapEditorDocument(serializeWalkMapEditorDocument(session.document));assert.deepEqual(reloaded.objectPatches[0].after,record);assert.equal(reloaded.objectPatches[0].after.binding.sha256,entry.lods.find(lod=>lod.lod===0).sha256);
});

console.log('walk map editor verified module placement: PASS');
