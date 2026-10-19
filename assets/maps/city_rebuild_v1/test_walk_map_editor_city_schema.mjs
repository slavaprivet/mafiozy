import assert from 'node:assert/strict';
import test from 'node:test';
import {readFile} from 'node:fs/promises';
import {compileWalkMapEditorDocument,createWalkMapEditorCompileSource} from './walk_map_editor_compile.mjs';
import {createWalkMapEditorDocument,walkMapEditorEntityKey} from './walk_map_editor_document.mjs';
import {createWalkMapProtectionPolicy} from './walk_map_editor_protection.mjs';
import {createEmptyWalkMapEditorCustomDataset,createWalkMapEditorCitySchemaAdapters,WALK_MAP_EDITOR_CITY_SCHEMAS,WALK_MAP_EDITOR_CITY_SURFACE_SUPPORT} from './walk_map_editor_city_schema.mjs';

const here=new URL('.',import.meta.url),readText=file=>readFile(new URL(file,here),'utf8');
const [topologyText,buildingsText,decorText]=await Promise.all([readText('topology_for_placement.json'),readText('buildings_placement.v1.json'),readText('decor_placement.v1.json')]);
const topologyBase=JSON.parse(topologyText),buildingsBase=JSON.parse(buildingsText),decorBase=JSON.parse(decorText),customBase=createEmptyWalkMapEditorCustomDataset();
const adapters=createWalkMapEditorCitySchemaAdapters(),buildingAdapter=adapters.datasetAdapters.get('buildings'),decorAdapter=adapters.datasetAdapters.get('decor'),customAdapter=adapters.datasetAdapters.get('custom');

test('adapters are branded for the three real schemas and empty custom schema',()=>{
 assert.deepEqual(WALK_MAP_EDITOR_CITY_SCHEMAS,{topology:'mafiozy.city-rebuild-placement-topology/v1',buildings:'mafiozi.city-rebuild.buildings-placement/v1',decor:'mafiozi.city-rebuild.decor-plan/v1',custom:'mafiozi.walk-map-editor.custom/v1'});
 assert.equal(buildingAdapter.dataset,'buildings');assert.equal(decorAdapter.dataset,'decor');assert.equal(customAdapter.dataset,'custom');assert.deepEqual(customBase,{schema:WALK_MAP_EDITOR_CITY_SCHEMAS.custom,status:'empty',counts:{instances:0},instances:[]});
});

for(const [name,adapter,base] of [['buildings',buildingAdapter,buildingsBase],['decor',decorAdapter,decorBase],['custom',customAdapter,customBase]])test(`${name} dataset roundtrip preserves top-level fields and instance order`,()=>{
 const source={...structuredClone(base),futureTopLevel:{owner:'future',nested:{kept:true}}},before=structuredClone(source),entities=adapter.readEntities(source),ids=entities.map(entity=>entity.id),output=adapter.writeEntities(source,entities);
 assert.deepEqual(output,source);assert.deepEqual(output.futureTopLevel,{owner:'future',nested:{kept:true}});assert.deepEqual(output.instances.map(entity=>entity.id),ids);assert.deepEqual(source,before);assert.notEqual(output,source);assert.notEqual(output.instances,source.instances);
});

test('one building edit and one decor edit preserve exact order and unknown data',()=>{
 const buildingSource={...structuredClone(buildingsBase),unknownBuildingField:{keep:'yes'}},buildingBefore=structuredClone(buildingSource),buildingEntities=buildingAdapter.readEntities(buildingSource),buildingIndex=37,buildingId=buildingEntities[buildingIndex].id;buildingEntities[buildingIndex]={...buildingEntities[buildingIndex],editorFixture:'moved'};
 const buildingOutput=buildingAdapter.writeEntities(buildingSource,buildingEntities);assert.equal(buildingOutput.instances[buildingIndex].id,buildingId);assert.equal(buildingOutput.instances[buildingIndex].editorFixture,'moved');assert.deepEqual(buildingOutput.instances.map(entity=>entity.id),buildingsBase.instances.map(entity=>entity.id));assert.deepEqual(buildingOutput.unknownBuildingField,{keep:'yes'});assert.equal(buildingOutput.counts.instances,75);assert.deepEqual(buildingSource,buildingBefore);
 const decorSource={...structuredClone(decorBase),unknownDecorField:['keep']},decorBefore=structuredClone(decorSource),decorEntities=decorAdapter.readEntities(decorSource),decorIndex=80,decorId=decorEntities[decorIndex].id;decorEntities[decorIndex]={...decorEntities[decorIndex],editorFixture:'rotated'};
 const decorOutput=decorAdapter.writeEntities(decorSource,decorEntities);assert.equal(decorOutput.instances[decorIndex].id,decorId);assert.equal(decorOutput.instances[decorIndex].editorFixture,'rotated');assert.deepEqual(decorOutput.instances.map(entity=>entity.id),decorBase.instances.map(entity=>entity.id));assert.deepEqual(decorOutput.unknownDecorField,['keep']);assert.equal(decorOutput.counts.instances,164);assert.deepEqual(decorSource,decorBefore);
});

test('dataset counts change only through known fields when instance lists change',()=>{
 const buildings=buildingAdapter.readEntities(buildingsBase),withoutResidence=buildings.filter((_,index)=>index!==buildings.findIndex(entity=>entity.role==='residence')),output=buildingAdapter.writeEntities(buildingsBase,withoutResidence);assert.equal(output.counts.instances,74);assert.equal(output.counts.residences,42);assert.equal(output.counts.assetTypesPlaced,new Set(withoutResidence.map(entity=>entity.assetId)).size);assert.equal(output.counts.fixedSiteCandidates,buildingsBase.counts.fixedSiteCandidates);
 const custom=customAdapter.writeEntities(customBase,[{id:'custom-1',assetId:'marker'}]);assert.equal(custom.counts.instances,1);assert.deepEqual(custom.instances,[{id:'custom-1',assetId:'marker'}]);assert.deepEqual(customBase.instances,[]);
});

test('dataset adapters reject wrong schemas and duplicate ids',()=>{
 assert.throws(()=>buildingAdapter.readEntities({...buildingsBase,schema:'future/v2'}),/schema mismatch/);const duplicate=buildingAdapter.readEntities(buildingsBase);duplicate[1]={...duplicate[1],id:duplicate[0].id};assert.throws(()=>buildingAdapter.writeEntities(buildingsBase,duplicate),/unique string ids/);
});

test('topology dimensions and proven cell writes are exact and source-safe',()=>{
 const adapter=adapters.topologyAdapter,before=structuredClone(topologyBase);assert.deepEqual(adapter.dimensions(topologyBase),{rows:200,cols:180});assert.equal(adapter.readCell(topologyBase,0,0),8);
 const edited=structuredClone(topologyBase),oldGrass=edited.validation.counts['8'],oldRoad=edited.validation.counts['0'],oldConnected=edited.validation.connectedRoadCells;adapter.writeCell(edited,0,0,0);
 assert.equal(edited.grid[0][0],0);assert.equal(edited.roadMask[0][0],1);assert.equal(edited.walkableMask[0][0],1);assert.equal(edited.validation.counts['8'],oldGrass-1);assert.equal(edited.validation.counts['0'],oldRoad+1);assert.equal(edited.validation.connectedRoadCells,oldConnected+1);assert.deepEqual(topologyBase,before);
 adapter.writeCell(edited,0,0,8);assert.deepEqual(edited,topologyBase,'writing grass back restores every maintained topology field');
 const sidewalk=structuredClone(topologyBase);adapter.writeCell(sidewalk,0,0,9);assert.equal(sidewalk.grid[0][0],9);assert.equal(sidewalk.roadMask[0][0],0);assert.equal(sidewalk.walkableMask[0][0],1);
 const ragged=structuredClone(topologyBase);ragged.grid[0].pop();assert.throws(()=>adapter.dimensions(ragged),/grid dimensions mismatch/);assert.throws(()=>adapter.readCell(topologyBase,-1,0),/outside/);assert.throws(()=>adapter.writeCell(structuredClone(topologyBase),0,0,14),/Unsupported city surface tile/);assert.throws(()=>adapter.eraseCell(structuredClone(topologyBase),0,0),/erase is unsupported/);
 const water=structuredClone(topologyBase);let waterCell;for(let r=0;r<water.grid.length&&!waterCell;r++)for(let c=0;c<water.grid[0].length;c++)if(water.grid[r][c]===16&&!water.protectedMask[r][c]){waterCell=[r,c];break}assert.ok(waterCell);assert.throws(()=>adapter.writeCell(water,...waterCell,8),/Unsupported source tile/);
 const protectedCopy=structuredClone(topologyBase);let protectedCell;for(let r=0;r<protectedCopy.grid.length&&!protectedCell;r++)for(let c=0;c<protectedCopy.grid[0].length;c++)if(protectedCopy.protectedMask[r][c]){protectedCell=[r,c];break}assert.ok(protectedCell);assert.throws(()=>adapter.writeCell(protectedCopy,...protectedCell,0),/Protected city topology cell/);
});

test('only evidenced asphalt and grass mappings are registered',()=>{
 assert.deepEqual([...adapters.surfaceAdapters.keys()],['asphalt','grass']);assert.equal(adapters.surfaceAdapters.get('asphalt').paintValue,0);assert.equal(adapters.surfaceAdapters.get('grass').paintValue,8);
 assert.equal(WALK_MAP_EDITOR_CITY_SURFACE_SUPPORT.asphalt.available,true);assert.equal(WALK_MAP_EDITOR_CITY_SURFACE_SUPPORT.grass.available,true);assert.equal(WALK_MAP_EDITOR_CITY_SURFACE_SUPPORT.earth.available,false);assert.equal(WALK_MAP_EDITOR_CITY_SURFACE_SUPPORT['dirt-road'].available,false);assert.equal(adapters.surfaceAdapters.has('earth'),false);assert.equal(adapters.surfaceAdapters.has('dirt-road'),false);
 assert.match(WALK_MAP_EDITOR_CITY_SURFACE_SUPPORT.earth.reason,/tile 9 — бордюр\/плитка/);
});

const revision='real-city-schema-fixture-v1',customText=JSON.stringify(customBase),sourceTexts={topology:topologyText,buildings:buildingsText,decor:decorText,custom:customText};
const sources=Object.fromEntries(Object.entries(sourceTexts).map(([name,text])=>[name,createWalkMapEditorCompileSource(name,text,{revision})]));
const sourceDigests={topology:sources.topology.sha256,buildings:sources.buildings.sha256,decor:sources.decor.sha256},baseRefs={topology:{sha256:sources.topology.sha256,revision},buildings:{sha256:sources.buildings.sha256,revision},decor:{sha256:sources.decor.sha256,revision},extensions:{custom:{sha256:sources.custom.sha256,revision}}};
const trustedBaseEntities=new Map([...buildingsBase.instances.map(entity=>['buildings',entity]),...decorBase.instances.map(entity=>['decor',entity])].map(([dataset,entity])=>[walkMapEditorEntityKey({dataset,id:entity.id}),entity]));
function footprint({snapshot,map}){if(snapshot.footprint){const r=Math.floor((snapshot.footprint.minR+snapshot.footprint.maxR)/2),c=Math.floor((snapshot.footprint.minC+snapshot.footprint.maxC)/2);return [[Math.max(0,Math.min(map.rows-1,r)),Math.max(0,Math.min(map.cols-1,c))]]}const position=snapshot.transform?.positionM||[0,0,0];return [[Math.max(0,Math.min(map.rows-1,Math.floor(position[2]/map.worldUnitsPerCell))),Math.max(0,Math.min(map.cols-1,Math.floor(position[0]/map.worldUnitsPerCell)))]]}
const protectionPolicy=createWalkMapProtectionPolicy({rows:200,cols:180,worldUnitsPerCell:4.1,sourceDigests,masks:{protectedMask:topologyBase.protectedMask,policeMask:topologyBase.policeMask,bridgeDeckMask:topologyBase.bridgeDeckMask},trustedBaseEntities,footprintAdapters:new Map(['buildings','decor','custom'].map(dataset=>[dataset,{id:`city-${dataset}-footprint`,version:1,cellsFor:footprint}]))});
const compileOptions={trustedSources:sources,datasetAdapters:adapters.datasetAdapters,topologyAdapter:adapters.topologyAdapter,surfaceAdapters:adapters.surfaceAdapters,protectionPolicy,compilerId:'city-schema-test-v1',compiledAt:'2026-09-23T12:00:00.000Z'};
const emptyDocument=()=>createWalkMapEditorDocument({documentId:'city-schema-test',createdAt:'2026-09-23T11:59:00.000Z',map:{rows:200,cols:180,worldUnitsPerCell:4.1},base:baseRefs});

test('canonical compiler roundtrip without edits reproduces all real snapshots',()=>{
 const sourceBefore=Object.fromEntries(Object.entries(sources).map(([name,source])=>[name,structuredClone(source.snapshot)])),first=compileWalkMapEditorDocument(emptyDocument(),compileOptions),second=compileWalkMapEditorDocument(emptyDocument(),compileOptions);
 assert.deepEqual(first.artifacts,second.artifacts);assert.deepEqual(first.artifacts.topology.value,topologyBase);assert.deepEqual(first.artifacts.buildings.value,buildingsBase);assert.deepEqual(first.artifacts.decor.value,decorBase);assert.deepEqual(first.artifacts.custom.value,customBase);
 assert.deepEqual(Object.fromEntries(Object.entries(sources).map(([name,source])=>[name,source.snapshot])),sourceBefore);
});

test('canonical compiler applies one exact asphalt edit without mutating sources',()=>{
 const document=emptyDocument(),before=Object.fromEntries(Object.entries(sources).map(([name,source])=>[name,structuredClone(source.snapshot)]));document.surfaceStrokes.push({id:'asphalt-one-cell',materialId:'asphalt',mode:'paint',shape:{type:'cells',cells:[[0,0]]}});
 const result=compileWalkMapEditorDocument(document,compileOptions),output=result.artifacts.topology.value;assert.equal(output.grid[0][0],0);assert.equal(output.roadMask[0][0],1);assert.equal(output.walkableMask[0][0],1);assert.deepEqual(result.artifacts.buildings.value,buildingsBase);assert.deepEqual(result.artifacts.decor.value,decorBase);assert.deepEqual(result.artifacts.custom.value,customBase);assert.deepEqual(Object.fromEntries(Object.entries(sources).map(([name,source])=>[name,source.snapshot])),before);
});

test('canonical compiler appends one custom entity and keeps prior order',()=>{
 const document=emptyDocument(),entity={id:'custom-marker-1',assetId:'marker',transform:{positionM:[2.05,0,2.05]}};document.objectPatches.push({source:{dataset:'custom',id:entity.id},action:'add',before:null,after:entity,derivedDirty:true});const result=compileWalkMapEditorDocument(document,compileOptions);assert.deepEqual(result.artifacts.custom.value.instances,[entity]);assert.equal(result.artifacts.custom.value.counts.instances,1);assert.deepEqual(result.artifacts.buildings.value.instances.map(item=>item.id),buildingsBase.instances.map(item=>item.id));assert.deepEqual(result.artifacts.decor.value.instances.map(item=>item.id),decorBase.instances.map(item=>item.id));
});

test('unsupported earth and dirt-road materials fail closed in canonical compile',()=>{
 for(const materialId of ['earth','dirt-road']){const document=emptyDocument();document.surfaceStrokes.push({id:`unsupported-${materialId}`,materialId,mode:'paint',shape:{type:'cells',cells:[[0,0]]}});assert.throws(()=>compileWalkMapEditorDocument(document,compileOptions),new RegExp(`SURFACE_ADAPTER_MISSING: ${materialId}`))}
});
