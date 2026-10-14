import assert from 'node:assert/strict';
import test from 'node:test';
import {
 WALK_MAP_GROUND_OVERLAY_DEPENDENCIES,
 WALK_MAP_GROUND_OVERLAY_MATERIALS,
 WalkMapGroundOverlayError,
 compileWalkMapGroundOverlay,
 createWalkMapGroundOverlayAddCommand,
 createWalkMapGroundOverlayDeleteCommand,
 normalizeWalkMapGroundOverlayRecord
} from './walk_map_editor_ground_overlay.mjs';
import {createEmptyWalkMapEditorCustomDataset,createWalkMapEditorCitySchemaAdapters} from './walk_map_editor_city_schema.mjs';

const map={rows:6,cols:7},masks=()=>Object.fromEntries(['protectedMask','policeMask','bridgeDeckMask'].map(name=>[name,Array.from({length:map.rows},()=>Array(map.cols).fill(0))]));
const expectCode=(fn,code)=>assert.throws(fn,error=>error instanceof WalkMapGroundOverlayError&&error.code===code);

test('only trusted earth and dirt-road overlay materials are accepted',()=>{
 assert.deepEqual(Object.keys(WALK_MAP_GROUND_OVERLAY_MATERIALS),['earth','dirt-road']);
 for(const materialId of ['asphalt','grass','sand',9,14])expectCode(()=>compileWalkMapGroundOverlay({id:'bad-material',materialId,shape:{type:'cells',cells:[[0,0]]},map}), 'UNTRUSTED_GROUND_MATERIAL');
});

test('cell overlays stay lossless while coverage and mesh plan are deterministic',()=>{
 const shape={type:'cells',cells:[[2,3],[0,1],[1,5]],brush:{name:'ручной'}},copy=structuredClone(shape),first=compileWalkMapGroundOverlay({id:'earth-yard-001',materialId:'earth',shape,map,groundHeightM:2,zOffsetM:0.025}),second=compileWalkMapGroundOverlay({id:'earth-yard-001',materialId:'earth',shape,map,groundHeightM:2,zOffsetM:0.025});
 assert.deepEqual(shape,copy);assert.deepEqual(first,second);assert.deepEqual(first.record.geometry,shape);assert.deepEqual(first.affectedCells,[[0,1],[1,5],[2,3]]);
 assert.equal(first.record.render.materialId,'city-earth-overlay-v1');assert.equal(first.record.navigation.adapter,'road-navigation-overlay/v1');assert.equal(first.record.navigation.rebuildRequired,true);
 assert.ok(first.dependencies.includes('ground-overlay-render'));assert.ok(first.dependencies.includes('road-navigation'));assert.deepEqual(first.record.dependencies,WALK_MAP_GROUND_OVERLAY_DEPENDENCIES);
 assert.equal(first.meshPlan.primitives[0].key,'cell:0:1');assert.deepEqual(first.meshPlan.primitives[0].verticesM[0],[4.1,2.025,0]);
 assert.equal(JSON.stringify(first.record).includes('"tile":9'),false);assert.equal(JSON.stringify(first.record).includes('"tile":14'),false);
});

test('polygon records preserve exact authored points and produce an exact triangle plan',()=>{
 const points=[[1,1],[1,4],[3,4],[3,3],[4,3],[4,1]],compiled=compileWalkMapGroundOverlay({id:'dirt-lane-001',materialId:'dirt-road',shape:{type:'polygon',points,authorNote:'поворот'},map});
 assert.deepEqual(compiled.record.geometry.points,points);assert.equal(compiled.record.geometry.authorNote,'поворот');assert.equal(compiled.meshPlan.primitives.length,1);assert.equal(compiled.meshPlan.primitives[0].verticesM.length,points.length);assert.equal(compiled.meshPlan.primitives[0].triangles.length,points.length-2);
 assert.deepEqual(compiled.meshPlan.primitives[0].verticesM[0],[4.1,0.02,4.1]);assert.ok(compiled.affectedCells.length>0);assert.equal(compiled.record.navigation.surfaceId,'dirt-road');assert.equal(compiled.record.navigation.vehicleSpeedFactor,0.82);
});

test('all three protection masks reject cell and polygon coverage fail-closed',()=>{
 for(const maskName of ['protectedMask','policeMask','bridgeDeckMask']){
  const protectionMasks=masks();protectionMasks[maskName][1][1]=1;
  assert.throws(()=>compileWalkMapGroundOverlay({id:`blocked-${maskName.toLowerCase()}`,materialId:'earth',shape:{type:'cells',cells:[[1,1]]},map,protectionMasks}),error=>error.code==='PROTECTED_GROUND_OVERLAY_CELL'&&error.details.mask===maskName&&assert.deepEqual(error.details.cell,[1,1])===undefined);
 }
 const protectionMasks=masks();protectionMasks.protectedMask[2][2]=1;
 expectCode(()=>compileWalkMapGroundOverlay({id:'blocked-polygon',materialId:'dirt-road',shape:{type:'polygon',points:[[1,1],[1,3],[3,3],[3,1]]},map,protectionMasks}),'PROTECTED_GROUND_OVERLAY_CELL');
 protectionMasks.protectedMask.pop();expectCode(()=>compileWalkMapGroundOverlay({id:'bad-mask',materialId:'earth',shape:{type:'cells',cells:[[0,0]]},map,protectionMasks}),'INVALID_PROTECTION_MASK_DIMENSIONS');
});

test('invalid geometry, bounds, ids and self intersections fail closed',()=>{
 expectCode(()=>compileWalkMapGroundOverlay({id:'bad duplicate',materialId:'earth',shape:{type:'cells',cells:[[0,0]]},map}),'INVALID_OVERLAY_ID');
 expectCode(()=>compileWalkMapGroundOverlay({id:'duplicates',materialId:'earth',shape:{type:'cells',cells:[[0,0],[0,0]]},map}),'DUPLICATE_OVERLAY_CELL');
 expectCode(()=>compileWalkMapGroundOverlay({id:'outside',materialId:'earth',shape:{type:'cells',cells:[[9,0]]},map}),'OVERLAY_CELL_OUT_OF_BOUNDS');
 expectCode(()=>compileWalkMapGroundOverlay({id:'zero-area',materialId:'earth',shape:{type:'polygon',points:[[0,0],[1,1],[2,2]]},map}),'ZERO_AREA_OVERLAY_POLYGON');
 expectCode(()=>compileWalkMapGroundOverlay({id:'bow-tie',materialId:'earth',shape:{type:'polygon',points:[[0,0],[3,3],[0,3],[3,0]]},map}),'SELF_INTERSECTING_OVERLAY_POLYGON');
});

test('unknown record fields round-trip and inputs remain immutable',()=>{
 const input={id:'earth-meta-001',materialId:'earth',geometry:{type:'cells',cells:[[4,5]]},unknownTop:{future:true},render:{unknownRender:'keep'},navigation:{unknownNavigation:7}},copy=structuredClone(input),record=normalizeWalkMapGroundOverlayRecord(input,{map});
 assert.deepEqual(input,copy);assert.deepEqual(record.unknownTop,{future:true});assert.equal(record.render.unknownRender,'keep');assert.equal(record.navigation.unknownNavigation,7);
});

test('custom add and delete commands are complete undoable object snapshots',()=>{
 const compiled=compileWalkMapGroundOverlay({id:'dirt-lane-command-001',materialId:'dirt-road',shape:{type:'cells',cells:[[2,1],[2,2]]},map}),add=createWalkMapGroundOverlayAddCommand({record:compiled.record,map,metadata:{label:'Добавить дорогу'}}),remove=createWalkMapGroundOverlayDeleteCommand({record:compiled.record,map,metadata:{label:'Удалить дорогу'}});
 assert.equal(add.type,'object.set-patch');assert.equal(add.patch.action,'add');assert.equal(add.patch.source.dataset,'custom');assert.equal(add.patch.source.id,compiled.record.id);assert.equal(add.patch.before,null);assert.deepEqual(add.patch.after,compiled.record);
 assert.equal(remove.patch.action,'delete');assert.deepEqual(remove.patch.before,compiled.record);assert.equal(remove.patch.after,null);assert.deepEqual(remove.patch.source,add.patch.source);
 assert.ok(add.patch.metadata.dependencies.includes('ground-overlay-render'));assert.ok(add.patch.metadata.dependencies.includes('road-navigation'));assert.deepEqual(add.patch.metadata.affectedCells,compiled.affectedCells);
});

test('records compile through the real custom dataset adapter without touching topology',()=>{
 const {datasetAdapters}=createWalkMapEditorCitySchemaAdapters(),adapter=datasetAdapters.get('custom'),snapshot=createEmptyWalkMapEditorCustomDataset(),copy=structuredClone(snapshot),record=compileWalkMapGroundOverlay({id:'earth-custom-001',materialId:'earth',shape:{type:'cells',cells:[[0,0]]},map}).record;
 const output=adapter.writeEntities(snapshot,[record]);assert.deepEqual(snapshot,copy);assert.deepEqual(output.instances,[record]);assert.equal(output.counts.instances,1);assert.deepEqual(adapter.readEntities(output),[record]);
});
