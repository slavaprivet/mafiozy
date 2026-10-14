import assert from 'node:assert/strict';
import crypto from 'node:crypto';
import {
 assessWalkMapEditorPublishReady,
 createWalkMapEditorDocument,
 createWalkMapEditorSession,
 isWalkMapEditorCompileReceipt,
 serializeWalkMapEditorDocument,
 walkMapEditorEntityKey
} from './walk_map_editor_document.mjs';
import {createWalkMapProtectionPolicy} from './walk_map_editor_protection.mjs';
import {importWalkMapEditorText} from './walk_map_editor_storage.mjs';
import {
 compileWalkMapEditorDocument,
 createWalkMapEditorCompileSource,
 createWalkMapEditorDatasetAdapter,
 createWalkMapEditorSurfaceAdapter,
 createWalkMapEditorTopologyAdapter
} from './walk_map_editor_compile.mjs';

const canonical=value=>Array.isArray(value)?value.map(canonical):value&&typeof value==='object'?Object.fromEntries(Object.keys(value).sort().map(key=>[key,canonical(value[key])])):value;

const rows=3,cols=3,worldUnitsPerCell=4.1,revision='source-r1';
const topologyBase={grid:[['earth','earth','earth'],['earth','road','earth'],['earth','earth','earth']]};
const b1={id:'b1',assetId:'house',transform:{positionM:[4.1,0,4.1]}};
const b2={id:'b2',assetId:'shop',transform:{positionM:[8.2,0,8.2]}};
const d1={id:'d1',assetId:'lamp',transform:{positionM:[0,0,8.2]}};
const c1={id:'c1',assetId:'marker',transform:{positionM:[8.2,0,0]}};
const sourceTexts={topology:JSON.stringify(topologyBase),buildings:JSON.stringify([b1,b2]),decor:JSON.stringify([d1]),custom:JSON.stringify([c1])};
const sources=Object.fromEntries(Object.entries(sourceTexts).map(([name,text])=>[name,createWalkMapEditorCompileSource(name,text,{revision})]));
for(const [name,text] of Object.entries(sourceTexts))assert.equal(sources[name].sha256,crypto.createHash('sha256').update(text).digest('hex'));
const sourceDigests={topology:sources.topology.sha256,buildings:sources.buildings.sha256,decor:sources.decor.sha256};
const base={topology:{sha256:sources.topology.sha256,revision},buildings:{sha256:sources.buildings.sha256,revision},decor:{sha256:sources.decor.sha256,revision},extensions:{custom:{sha256:sources.custom.sha256,revision}}};

const datasetAdapters=new Map(['buildings','decor','custom'].map(dataset=>[dataset,createWalkMapEditorDatasetAdapter({dataset,id:`array-${dataset}`,version:1,readEntities:snapshot=>snapshot,writeEntities:(_snapshot,entities)=>entities})]));
const topologyAdapter=createWalkMapEditorTopologyAdapter({id:'grid-v1',dimensions:snapshot=>({rows:snapshot.grid.length,cols:snapshot.grid[0].length}),readCell:(snapshot,row,col)=>snapshot.grid[row][col],writeCell:(snapshot,row,col,value)=>{snapshot.grid[row][col]=value;},eraseCell:(snapshot,row,col)=>{snapshot.grid[row][col]=null;}});
const surfaceAdapters=new Map([['grass',createWalkMapEditorSurfaceAdapter({materialId:'grass',id:'grass-v1',paintValue:'grass'})]]);
const zero=()=>Array.from({length:rows},()=>Array(cols).fill(0)),protectedMask=zero();protectedMask[0][0]=1;
const trustedBaseEntities=new Map([[walkMapEditorEntityKey({dataset:'buildings',id:'b1'}),b1],[walkMapEditorEntityKey({dataset:'buildings',id:'b2'}),b2],[walkMapEditorEntityKey({dataset:'decor',id:'d1'}),d1],[walkMapEditorEntityKey({dataset:'custom',id:'c1'}),c1]]);
const footprint=({snapshot,map})=>[[Math.floor(snapshot.transform.positionM[2]/map.worldUnitsPerCell),Math.floor(snapshot.transform.positionM[0]/map.worldUnitsPerCell)]];
const protectionPolicy=createWalkMapProtectionPolicy({rows,cols,worldUnitsPerCell,sourceDigests,masks:{protectedMask,policeMask:zero(),bridgeDeckMask:zero()},trustedBaseEntities,footprintAdapters:new Map(['buildings','decor','custom'].map(dataset=>[dataset,{id:`footprint-${dataset}`,version:1,cellsFor:footprint}]))});

const document=createWalkMapEditorDocument({documentId:'compile-test',createdAt:'2026-09-23T11:00:00.000Z',map:{rows,cols,worldUnitsPerCell},base});
const movedB1={...b1,transform:{...b1.transform,positionM:[8.2,0,4.1]}};
const d2={id:'d2',assetId:'sign',transform:{positionM:[4.1,0,8.2]}};
document.objectPatches.push(
 {source:{dataset:'buildings',id:'b1'},action:'modify',before:b1,after:movedB1,derivedDirty:true},
 {source:{dataset:'buildings',id:'b2'},action:'delete',before:b2,after:null,derivedDirty:true},
 {source:{dataset:'decor',id:'d2'},action:'add',before:null,after:d2,derivedDirty:true}
);
document.surfaceStrokes.push(
 {id:'paint',materialId:'grass',mode:'paint',shape:{type:'cells',cells:[[2,2],[1,1]]}},
 {id:'erase',materialId:'grass',mode:'erase',shape:{type:'cells',cells:[[2,1]]}},
 {id:'restore',materialId:'grass',mode:'restore',shape:{type:'cells',cells:[[1,1]]}}
);

const compileOptions={trustedSources:sources,datasetAdapters,topologyAdapter,surfaceAdapters,protectionPolicy,compilerId:'compile-test-v1',compiledAt:'2026-09-23T11:01:00.000Z'};
const sourceBefore=structuredClone(Object.fromEntries(Object.entries(sources).map(([name,source])=>[name,source.snapshot])));
const first=compileWalkMapEditorDocument(document,compileOptions),second=compileWalkMapEditorDocument(document,compileOptions);
assert.deepEqual(first.artifacts,second.artifacts);assert.deepEqual(first.compileReceipt,second.compileReceipt);
assert.deepEqual(first.artifacts.buildings.value,[movedB1]);
assert.deepEqual(first.artifacts.decor.value,[d1,d2]);assert.deepEqual(first.artifacts.custom.value,[c1]);
assert.equal(first.artifacts.topology.value.grid[2][2],'grass');assert.equal(first.artifacts.topology.value.grid[2][1],null);assert.equal(first.artifacts.topology.value.grid[1][1],'road');
assert.deepEqual(Object.fromEntries(Object.entries(sources).map(([name,source])=>[name,source.snapshot])),sourceBefore);
for(const artifact of Object.values(first.artifacts)){assert.equal(artifact.json,JSON.stringify(canonical(artifact.value)));assert.equal(artifact.sha256,crypto.createHash('sha256').update(artifact.json).digest('hex'));}
assert.equal(isWalkMapEditorCompileReceipt(first.compileReceipt),true);
const readiness=assessWalkMapEditorPublishReady(document,{registeredObjectDatasets:['buildings','decor','custom'],registeredSurfaceMaterials:['grass'],compileReceipt:first.compileReceipt});assert.equal(readiness.ready,true);
const changedRevision=structuredClone(document);changedRevision.revision++;assert.equal(assessWalkMapEditorPublishReady(changedRevision,{registeredObjectDatasets:['buildings','decor','custom'],registeredSurfaceMaterials:['grass'],compileReceipt:first.compileReceipt}).ready,false);
const baseByKey=new Map([[walkMapEditorEntityKey({dataset:'buildings',id:'b1'}),b1],[walkMapEditorEntityKey({dataset:'buildings',id:'b2'}),b2],[walkMapEditorEntityKey({dataset:'decor',id:'d1'}),d1],[walkMapEditorEntityKey({dataset:'custom',id:'c1'}),c1]]),resolver=source=>{const value=baseByKey.get(walkMapEditorEntityKey(source));return value?{status:'found',entity:value}:{status:'absent'};};
const blankSession=createWalkMapEditorSession(createWalkMapEditorDocument({documentId:'compile-test',createdAt:'2026-09-23T11:00:00.000Z',map:{rows,cols,worldUnitsPerCell},base}));
const storageImport=importWalkMapEditorText(blankSession,serializeWalkMapEditorDocument(document),{protectionPolicy,resolveBaseEntity:resolver,registeredObjectDatasets:['buildings','decor','custom'],registeredSurfaceMaterials:['grass'],preflight:context=>({allowed:true,receiptId:'real-compiler',compileReceipt:compileWalkMapEditorDocument(context.after,compileOptions).compileReceipt})});
assert.equal(storageImport.session.document.revision,1);assert.equal(isWalkMapEditorCompileReceipt(storageImport.preflightReceipt.compileReceipt),true);

const protectedDocument=structuredClone(document);protectedDocument.surfaceStrokes.push({id:'protected',materialId:'grass',mode:'paint',shape:{type:'cells',cells:[[0,0]]}});
assert.throws(()=>compileWalkMapEditorDocument(protectedDocument,compileOptions),/PROTECTED_EDIT/);

const missingAdapter=new Map(datasetAdapters);missingAdapter.delete('decor');assert.throws(()=>compileWalkMapEditorDocument(document,{...compileOptions,datasetAdapters:missingAdapter}),/DATASET_ADAPTER_MISSING: decor/);
const unknownSurface=structuredClone(document);unknownSurface.surfaceStrokes[0].materialId='future-lava';assert.throws(()=>compileWalkMapEditorDocument(unknownSurface,compileOptions),/SURFACE_ADAPTER_MISSING: future-lava/);
const mismatchedBase=structuredClone(document);mismatchedBase.base.topology.sha256='f'.repeat(64);assert.throws(()=>compileWalkMapEditorDocument(mismatchedBase,compileOptions),/COMPILE_SOURCE_MISMATCH: topology/);
const mismatchedRevision=structuredClone(document);mismatchedRevision.base.decor.revision='wrong';assert.throws(()=>compileWalkMapEditorDocument(mismatchedRevision,compileOptions),/COMPILE_SOURCE_MISMATCH: decor/);
const missingEntity=structuredClone(document);missingEntity.objectPatches[0]={source:{dataset:'buildings',id:'missing'},action:'modify',before:{id:'missing',transform:{positionM:[4.1,0,4.1]}},after:{id:'missing',transform:{positionM:[8.2,0,4.1]}},derivedDirty:true};assert.throws(()=>compileWalkMapEditorDocument(missingEntity,compileOptions),/BASE_ENTITY_MISSING|ENTITY_MISSING/);
assert.deepEqual(Object.fromEntries(Object.entries(sources).map(([name,source])=>[name,source.snapshot])),sourceBefore);
console.log('walk map editor compile: PASS');
