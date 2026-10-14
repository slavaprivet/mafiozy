import assert from 'node:assert/strict';
import {
 WALK_MAP_EDITOR_SCHEMA,
 walkMapEditorEntityKey,
 createWalkMapEditorDocument,
 createWalkMapEditorRecoveryEnvelope,
 createWalkMapEditorSession,
 executeWalkMapEditorCommand,
 executeWalkMapEditorTransaction,
 undoWalkMapEditorCommand,
 redoWalkMapEditorCommand,
 makeWalkMapObjectAddCommand,
 makeWalkMapObjectTransformCommand,
 makeWalkMapObjectDeleteCommand,
 makeWalkMapSurfacePaintCommand,
 parseWalkMapEditorDocument,
 parseWalkMapEditorRecoveryEnvelope,
 serializeWalkMapEditorDocument,
 validateWalkMapEditorDocument,
 createWalkMapEditorCompileReceipt,
 isWalkMapEditorCompileReceipt,
 walkMapEditorCanonicalDigest,
 assessWalkMapEditorPublishReady
} from './walk_map_editor_document.mjs';
import {createWalkMapProtectionPolicy,isWalkMapProtectionAuditReceipt} from './walk_map_editor_protection.mjs';

const sourceDigests={topology:'a'.repeat(64),buildings:'b'.repeat(64),decor:'c'.repeat(64)};
const base={topology:{sha256:sourceDigests.topology},buildings:{sha256:sourceDigests.buildings},decor:{sha256:sourceDigests.decor}};
const createdAt='2026-09-23T12:00:00.000Z';
const house={id:'house-1',assetId:'garden_lane_house_v1',transform:{positionM:[100,0,200],yawDegrees:0,uniformScale:1},futureBuildingField:{kept:true}};
const emptyMask=()=>Array.from({length:200},()=>Array(180).fill(0));
const protectionPolicy=createWalkMapProtectionPolicy({rows:200,cols:180,worldUnitsPerCell:4.1,sourceDigests,masks:{protectedMask:emptyMask(),policeMask:emptyMask(),bridgeDeckMask:emptyMask()},trustedBaseEntities:new Map([[walkMapEditorEntityKey({dataset:'buildings',id:house.id}),house]]),footprintAdapters:new Map([
 ['buildings',{id:'building-cell',version:1,cellsFor:({snapshot,map})=>[[Math.floor(snapshot.transform.positionM[2]/map.worldUnitsPerCell),Math.floor(snapshot.transform.positionM[0]/map.worldUnitsPerCell)]]}],
 ['custom',{id:'custom-cell',version:1,cellsFor:({snapshot,map})=>snapshot.transform?[[Math.floor(snapshot.transform.positionM[2]/map.worldUnitsPerCell),Math.floor(snapshot.transform.positionM[0]/map.worldUnitsPerCell)]]:[]}]
])});
const resolveBaseEntity=source=>source.dataset==='buildings'&&source.id===house.id?{status:'found',entity:house}:{status:'absent'};
const spatialOptions={resolveBaseEntity,protectionPolicy};
const original=createWalkMapEditorDocument({base,createdAt,documentId:'editor-test-map',metadata:{futureField:{kept:true}}});
assert.equal(original.schema,WALK_MAP_EDITOR_SCHEMA);
assert.equal(original.map.worldUnitsPerCell,4.1);

const lamp={
 id:'editor-lamp-1',assetId:'lamp_bellini_v1',category:'lamp',
 transform:{positionM:[10,0,20],yawDegrees:0,uniformScale:1},
 futurePayload:{colorTemperature:2700}
};
let session=createWalkMapEditorSession(original);
session=executeWalkMapEditorCommand(session,makeWalkMapObjectAddCommand({source:{dataset:'custom',id:lamp.id},object:lamp}),spatialOptions);
assert.equal(session.document.objectPatches.length,1);
assert.equal(session.document.objectPatches[0].after.futurePayload.colorTemperature,2700);
assert.equal(session.undoStack[0].protectionExecutions[0].decision,'clear');
assert.equal(session.undoStack[0].protectionExecutions[0].scope.operation,'commit');
assert.equal(isWalkMapProtectionAuditReceipt(session.undoStack[0].protectionExecutions[0]),true);

const moved={...lamp,transform:{...lamp.transform,positionM:[12,0,24],yawDegrees:90}};
session=executeWalkMapEditorCommand(session,makeWalkMapObjectTransformCommand({source:{dataset:'custom',id:lamp.id},before:lamp,after:moved}),spatialOptions);
assert.deepEqual(session.document.objectPatches[0].after.transform.positionM,[12,0,24]);
session=undoWalkMapEditorCommand(session,{protectionPolicy});
assert.equal(session.document.objectPatches[0].action,'add');
session=redoWalkMapEditorCommand(session,{protectionPolicy});
assert.equal(session.document.objectPatches[0].action,'add');

session=executeWalkMapEditorCommand(session,makeWalkMapObjectDeleteCommand({source:{dataset:'custom',id:lamp.id},before:moved}),spatialOptions);
assert.equal(session.document.objectPatches.length,0);
session=undoWalkMapEditorCommand(session,{protectionPolicy});
assert.equal(session.document.objectPatches[0].action,'add');
assert.equal(session.document.objectPatches[0].after.futurePayload.colorTemperature,2700);

const houseMoved={...house,transform:{...house.transform,positionM:[110,0,210],yawDegrees:30}};
session=executeWalkMapEditorCommand(session,makeWalkMapObjectTransformCommand({source:{dataset:'buildings',id:house.id},before:house,after:houseMoved}),spatialOptions);
const houseMovedAgain={...houseMoved,transform:{...houseMoved.transform,positionM:[120,0,220]}};
session=executeWalkMapEditorCommand(session,makeWalkMapObjectTransformCommand({source:{dataset:'buildings',id:house.id},before:houseMoved,after:houseMovedAgain}),spatialOptions);
const housePatch=session.document.objectPatches.find(patch=>patch.source.id===house.id);
assert.equal(housePatch.action,'modify');
assert.deepEqual(housePatch.before,house);
assert.deepEqual(housePatch.after,houseMovedAgain);

session=executeWalkMapEditorCommand(session,makeWalkMapSurfacePaintCommand({
 id:'street-1',materialId:'dirt-road',mode:'paint',shape:{type:'cells',cells:[[1,2],{r:1,c:3}]},futureBrush:{falloff:.25}
}),{protectionPolicy});
assert.deepEqual(session.document.surfaceStrokes[0].shape.cells,[[1,2],[1,3]]);
assert.equal(session.document.surfaceStrokes[0].futureBrush.falloff,.25);

const json=serializeWalkMapEditorDocument(session.document);
const roundTrip=parseWalkMapEditorDocument(json);
assert.deepEqual(roundTrip,session.document);
assert.equal(roundTrip.metadata.futureField.kept,true);

const recovery=createWalkMapEditorRecoveryEnvelope(roundTrip,{savedAt:createdAt});
assert.deepEqual(parseWalkMapEditorRecoveryEnvelope(recovery),roundTrip);
assert.throws(()=>parseWalkMapEditorRecoveryEnvelope({...recovery,checksum:'00000000'}),/checksum mismatch/);

const duplicated=structuredClone(roundTrip);
duplicated.objectPatches.push(structuredClone(duplicated.objectPatches[0]));
assert.equal(validateWalkMapEditorDocument(duplicated).ok,false);

const compileReceipt=createWalkMapEditorCompileReceipt(roundTrip,{protectionPolicy,sourceDigests,compilerId:'editor-document-test',compiledAt:createdAt,outputDigests:{placements:'d'.repeat(64)}});
assert.equal(isWalkMapEditorCompileReceipt(compileReceipt),true);
assert.match(walkMapEditorCanonicalDigest(roundTrip),/^[a-f0-9]{64}$/);
const publish=assessWalkMapEditorPublishReady(roundTrip,{registeredObjectDatasets:['custom','buildings'],registeredSurfaceMaterials:['dirt-road'],compileReceipt});
assert.equal(publish.ready,true);
assert.ok(publish.warnings.some(message=>message.includes('Derived placement data')));
assert.equal(assessWalkMapEditorPublishReady(roundTrip,{registeredObjectDatasets:['custom','buildings'],registeredSurfaceMaterials:['dirt-road'],compiled:true}).ready,false);
assert.equal(assessWalkMapEditorPublishReady(roundTrip,{registeredObjectDatasets:['custom','buildings'],registeredSurfaceMaterials:['dirt-road'],compileReceipt:structuredClone(compileReceipt)}).ready,false);
const newerRevision=structuredClone(roundTrip);newerRevision.revision++;
assert.equal(assessWalkMapEditorPublishReady(newerRevision,{registeredObjectDatasets:['custom','buildings'],registeredSurfaceMaterials:['dirt-road'],compileReceipt}).ready,false);
assert.throws(()=>createWalkMapEditorCompileReceipt(roundTrip,{protectionPolicy,sourceDigests:{...sourceDigests,decor:'e'.repeat(64)},compilerId:'bad-source',outputDigests:{placements:'d'.repeat(64)}}),/COMPILE_SOURCE_MISMATCH/);

const unknownSurface=structuredClone(roundTrip);
unknownSurface.surfaceStrokes[0].materialId='future-volcanic-soil';
const forwardCompatible=assessWalkMapEditorPublishReady(unknownSurface,{registeredObjectDatasets:['custom','buildings'],registeredSurfaceMaterials:['dirt-road'],compileReceipt});
assert.equal(forwardCompatible.ready,false);
assert.ok(forwardCompatible.errors.some(message=>message.includes('future-volcanic-soil')));

assert.throws(()=>executeWalkMapEditorCommand(session,makeWalkMapSurfacePaintCommand({
 id:'outside',materialId:'grass',shape:{type:'cells',cells:[[-1,2]]}
}),{protectionPolicy}),/outside/);
assert.throws(()=>executeWalkMapEditorCommand(session,makeWalkMapSurfacePaintCommand({
 id:'duplicate',materialId:'grass',shape:{type:'cells',cells:[[1,2],[1,2]]}
}),{protectionPolicy}),/Duplicate/);

const beforeAtomic=structuredClone(session);
assert.throws(()=>executeWalkMapEditorTransaction(session,[
 makeWalkMapObjectAddCommand({source:{dataset:'custom',id:'prefab-a'},object:{id:'prefab-a',transform:{positionM:[1,0,1]}}}),
 makeWalkMapSurfacePaintCommand({id:'bad-stroke',materialId:'grass',shape:{type:'cells',cells:[[999,999]]}})
],{...spatialOptions,updatedAt:createdAt}),/outside/);
assert.deepEqual(session,beforeAtomic);

const atomic=executeWalkMapEditorTransaction(session,[
 makeWalkMapObjectAddCommand({source:{dataset:'custom',id:'prefab-a'},object:{id:'prefab-a',transform:{positionM:[1,0,1]}}}),
 makeWalkMapObjectAddCommand({source:{dataset:'custom',id:'prefab-b'},object:{id:'prefab-b',transform:{positionM:[2,0,2]}}})
],{...spatialOptions,updatedAt:'2026-09-23T12:01:00.000Z',label:'Поставить светофор'});
assert.equal(atomic.undoStack.length,session.undoStack.length+1);
assert.equal(atomic.document.objectPatches.filter(patch=>patch.source.id.startsWith('prefab-')).length,2);
const atomicUndone=undoWalkMapEditorCommand(atomic,{protectionPolicy});
assert.equal(atomicUndone.document.objectPatches.filter(patch=>patch.source.id.startsWith('prefab-')).length,0);

assert.throws(()=>executeWalkMapEditorCommand(session,makeWalkMapObjectAddCommand({source:{dataset:'custom',id:'stale'},object:{id:'stale'}}),{...spatialOptions,expectedRevision:session.revision-1}),/Stale editor revision/);
assert.throws(()=>executeWalkMapEditorCommand(session,makeWalkMapSurfacePaintCommand({id:'no-policy',materialId:'grass',shape:{type:'cells',cells:[[5,5]]}})),/PROTECTION_POLICY_REQUIRED/);
assert.throws(()=>executeWalkMapEditorCommand(createWalkMapEditorSession(original),makeWalkMapObjectAddCommand({source:{dataset:'custom',id:'unresolved-base'},object:{id:'unresolved-base',transform:{positionM:[4.1,0,4.1]}}}),{resolveBaseEntity:()=>undefined,protectionPolicy}),/BASE_RESOLUTION_INVALID/);
assert.throws(()=>executeWalkMapEditorCommand(createWalkMapEditorSession(original),makeWalkMapObjectAddCommand({source:{dataset:'buildings',id:house.id},object:house}),{resolveBaseEntity:()=>({status:'absent'}),protectionPolicy}),/BASE_ENTITY_EXISTS/);
assert.throws(()=>executeWalkMapEditorCommand(createWalkMapEditorSession(original),makeWalkMapObjectAddCommand({source:{dataset:'custom',id:'empty-footprint'},object:{id:'empty-footprint',assetId:'marker'}}),{resolveBaseEntity:()=>({status:'absent'}),protectionPolicy}),/EMPTY_TRUSTED_FOOTPRINT/);

const cyclic=structuredClone(original);cyclic.metadata.self=cyclic.metadata;
assert.equal(validateWalkMapEditorDocument(cyclic).ok,false);

console.log('walk map editor document: PASS');
