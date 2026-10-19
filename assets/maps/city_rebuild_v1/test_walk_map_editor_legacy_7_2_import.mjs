import assert from 'node:assert/strict';
import {readFile} from 'node:fs/promises';
import {
 createWalkMapEditorCompileReceipt,
 createWalkMapEditorDocument,
 createWalkMapEditorSession,
 serializeWalkMapEditorDocument
} from './walk_map_editor_document.mjs';
import {createWalkMapProtectionPolicy} from './walk_map_editor_protection.mjs';
import {
 WALK_MAP_LEGACY_7_2_SOURCES,
 WalkMapLegacy72ImportError,
 applyWalkMapLegacy72Import,
 previewWalkMapLegacy72Import
} from './walk_map_editor_legacy_7_2_import.mjs';

const dir=new URL('.',import.meta.url),read=async name=>JSON.parse(await readFile(new URL(name,dir),'utf8'));
const [buildingsPlan,decorPlan,realLegacy]=await Promise.all([read('buildings_placement.v1.json'),read('decor_placement.v1.json'),read('../../../map_overrides.json')]);
const buildings=buildingsPlan.instances,decor=decorPlan.instances,building=buildings.find(item=>item.assetId!=='civic_hall'&&item.gameplayActive!==true),protectedBuilding=buildings.find(item=>item.assetId==='civic_hall'),decorItem=decor[0];
assert.ok(building&&protectedBuilding&&decorItem);
assert.deepEqual(WALK_MAP_LEGACY_7_2_SOURCES,['/__studio_map','./map_overrides.json']);

const sourceDigests={topology:'1'.repeat(64),buildings:'2'.repeat(64),decor:'3'.repeat(64)},base={topology:{sha256:sourceDigests.topology},buildings:{sha256:sourceDigests.buildings},decor:{sha256:sourceDigests.decor}},createdAt='2026-09-23T18:00:00.000Z';
const document=createWalkMapEditorDocument({documentId:'legacy-7-2-import-test',createdAt,map:{rows:200,cols:180,worldUnitsPerCell:4.1},base}),session=createWalkMapEditorSession(document),beforeSession=structuredClone(session);
const safeProtection=()=>false;

// The checked-in version-20 override is the exact JSON shape and source key used by editor 7.2.
const realPreview=previewWalkMapLegacy72Import({text:JSON.stringify(realLegacy),sourceKey:'./map_overrides.json',document,buildingRecords:buildings,decorRecords:decor,trustedSourceBase:base,isProtectedCell:safeProtection,protectedEntityIds:[protectedBuilding.id]});
assert.equal(realPreview.canApply,true);
assert.equal(realPreview.candidateDocument.surfaceStrokes.reduce((sum,stroke)=>sum+stroke.shape.cells.length,0),7);
assert.equal(realPreview.audit.unsupported.filter(item=>item.tile===9).length,3);
assert.equal(realPreview.audit.unsupported.filter(item=>item.tile===1).length,1);
assert.equal(realPreview.audit.ambiguous.length,realLegacy.decorFull.length); // no stable IDs in the old beach-decor collection
assert.equal(realPreview.candidateDocument.objectPatches.length,0);
assert.equal(Object.isFrozen(realPreview),true);assert.equal(Object.isFrozen(realPreview.audit),true);

const wrapped=previewWalkMapLegacy72Import({text:JSON.stringify({key:'/__studio_map',value:JSON.stringify({version:20,mapEdits:[{r:4,c:5,value:0}]})}),document,buildingRecords:buildings,decorRecords:decor,trustedSourceBase:base,isProtectedCell:safeProtection});
assert.equal(wrapped.audit.sourceKey,'/__studio_map');assert.deepEqual(wrapped.candidateDocument.surfaceStrokes[0].shape.cells,[[4,5]]);
assert.throws(()=>previewWalkMapLegacy72Import({text:JSON.stringify({key:'evil-key',value:'{}'}),document,trustedSourceBase:base,isProtectedCell:safeProtection}),error=>error instanceof WalkMapLegacy72ImportError&&error.code==='LEGACY_SOURCE_UNSUPPORTED');

const anchor=[Math.floor(building.transform.positionM[2]/4.1),Math.floor(building.transform.positionM[0]/4.1)];
const exactPayload={
 version:20,
 decorFull:[{id:decorItem.id,kind:decorItem.assetId,r:decorItem.r+1,c:decorItem.c+2,_studioRot:Math.PI/2}],
 buildingMoves:[{id:building.id,from:[{r:anchor[0],c:anchor[1]},{r:anchor[0]+1,c:anchor[1]}],to:[{r:anchor[0]+2,c:anchor[1]-1},{r:anchor[0]+3,c:anchor[1]-1}]}],
 mapEdits:[{r:10,c:11,value:0},{r:12,c:13,value:8},{r:15,c:16,value:9},{r:15,c:17,value:14},{r:15,c:18,value:16}],
 unlock:true,allowProtected:true,html:'<img src=x onerror="globalThis.pwned=1">'
};
const exact=previewWalkMapLegacy72Import({text:JSON.stringify(exactPayload),document,buildingRecords:buildings,decorRecords:decor,trustedSourceBase:base,isProtectedCell:safeProtection,protectedEntityIds:[protectedBuilding.id]});
assert.equal(exact.canApply,true);assert.equal(exact.candidateDocument.objectPatches.length,2);assert.equal(exact.candidateDocument.surfaceStrokes.length,2);
const decorPatch=exact.candidateDocument.objectPatches.find(patch=>patch.source.dataset==='decor'),buildingPatch=exact.candidateDocument.objectPatches.find(patch=>patch.source.dataset==='buildings');
assert.deepEqual(decorPatch.after.transform.positionM,[exactPayload.decorFull[0].c*4.1,decorItem.transform.positionM[1],exactPayload.decorFull[0].r*4.1]);assert.ok(Math.abs(decorPatch.after.transform.yawDegrees-90)<1e-10);
assert.deepEqual(buildingPatch.after.transform.positionM,[building.transform.positionM[0]-4.1,building.transform.positionM[1],building.transform.positionM[2]+8.2]);
assert.equal(exact.audit.unsupported.length,3);assert.equal(exact.audit.ignoredUnsafeFlags.length,2);assert.ok(exact.audit.unknown.some(item=>item.path==='$.html'));
const productionText=serializeWalkMapEditorDocument(exact.candidateDocument);assert.equal(productionText.includes('onerror'),false);assert.equal(productionText.includes('allowProtected'),false);assert.equal(productionText.includes('unlock'),false);

// Identical duplicates coalesce; conflicting duplicates are ambiguous and never enter production.
const duplicate=previewWalkMapLegacy72Import({text:JSON.stringify({version:20,decorFull:[exactPayload.decorFull[0],exactPayload.decorFull[0],{...exactPayload.decorFull[0],r:decorItem.r+9}],mapEdits:[{r:1,c:1,value:0},{r:1,c:1,value:0},{r:1,c:1,value:8}]}),document,buildingRecords:buildings,decorRecords:decor,trustedSourceBase:base,isProtectedCell:safeProtection});
assert.equal(duplicate.candidateDocument.objectPatches.length,0);assert.equal(duplicate.candidateDocument.surfaceStrokes.length,0);assert.equal(duplicate.audit.duplicates.length,2);assert.equal(duplicate.audit.ambiguous.length,2);
const legacyAdded=previewWalkMapLegacy72Import({text:JSON.stringify({version:20,decor:[{added:true,data:{id:decorItem.id,kind:decorItem.assetId,r:1,c:1}}]}),document,buildingRecords:buildings,decorRecords:decor,trustedSourceBase:base,isProtectedCell:safeProtection});
assert.equal(legacyAdded.candidateDocument.objectPatches.length,0);assert.match(legacyAdded.audit.dropped[0].reason,/3D binding/);

const staleBase=previewWalkMapLegacy72Import({text:JSON.stringify({version:20,mapEdits:[{r:1,c:2,value:0}]}),document,buildingRecords:buildings,decorRecords:decor,trustedSourceBase:{...base,topology:{sha256:'9'.repeat(64)}},isProtectedCell:safeProtection});
assert.equal(staleBase.canApply,false);assert.ok(staleBase.audit.blocking.some(item=>item.code==='LEGACY_BASE_STALE_OR_UNVERIFIED'));
const protectedCell=previewWalkMapLegacy72Import({text:JSON.stringify({version:20,mapEdits:[{r:2,c:3,value:8}]}),document,buildingRecords:buildings,decorRecords:decor,trustedSourceBase:base,isProtectedCell:(r,c)=>r===2&&c===3});
assert.equal(protectedCell.canApply,false);assert.equal(protectedCell.audit.protected.length,1);
const protectedObject=previewWalkMapLegacy72Import({text:JSON.stringify({version:20,deletedBuildings:[{id:protectedBuilding.id,cells:[{r:1,c:1}]}]}),document,buildingRecords:buildings,decorRecords:decor,trustedSourceBase:base,isProtectedCell:safeProtection,protectedEntityIds:[protectedBuilding.id]});
assert.equal(protectedObject.canApply,false);assert.ok(protectedObject.audit.blocking.some(item=>item.code==='LEGACY_PROTECTED_ACTION'));
assert.throws(()=>applyWalkMapLegacy72Import(session,protectedObject,{}),error=>error.code==='LEGACY_PREVIEW_BLOCKED');assert.deepEqual(session,beforeSession);

assert.throws(()=>previewWalkMapLegacy72Import({text:'{"version":20,"__proto__":{"polluted":true}}',document,trustedSourceBase:base,isProtectedCell:safeProtection}),error=>error.code==='LEGACY_DANGEROUS_KEY');
assert.equal(globalThis.pwned,undefined);

// Dry-run never invokes the current storage importer.
const dry=applyWalkMapLegacy72Import(session,exact,{dryRun:true});assert.equal(dry.applied,false);assert.equal(dry.preview,exact);assert.deepEqual(session,beforeSession);

const zero=()=>Array.from({length:200},()=>Array(180).fill(0)),masks={protectedMask:zero(),policeMask:zero(),bridgeDeckMask:zero()},trustedBaseEntities=new Map(exact.candidateDocument.objectPatches.map(patch=>[patch.key,patch.before]));
const footprint={id:'legacy-test-position-cell',version:1,cellsFor:({snapshot})=>snapshot?.transform?.positionM?[[Math.max(0,Math.min(199,Math.floor(snapshot.transform.positionM[2]/4.1))),Math.max(0,Math.min(179,Math.floor(snapshot.transform.positionM[0]/4.1)))]]:[]};
const policy=createWalkMapProtectionPolicy({rows:200,cols:180,worldUnitsPerCell:4.1,sourceDigests,masks,trustedBaseEntities,footprintAdapters:new Map([['buildings',footprint],['decor',footprint]])});
const resolver=source=>{const record=source.dataset==='buildings'?buildings.find(item=>item.id===source.id):decor.find(item=>item.id===source.id);return record?{status:'found',entity:record}:{status:'absent',entity:null}};
const preflight=context=>({allowed:true,receiptId:'legacy-7-2-preflight',compilerId:'legacy-test',compileReceipt:createWalkMapEditorCompileReceipt(context.after,{protectionPolicy:policy,sourceDigests,compilerId:'legacy-test',compiledAt:createdAt,outputDigests:{placements:'4'.repeat(64)}})});
const importOptions={protectionPolicy:policy,resolveBaseEntity:resolver,preflight,registeredObjectDatasets:['buildings','decor'],registeredSurfaceMaterials:['asphalt','grass'],updatedAt:'2026-09-23T18:01:00.000Z'};

// Rejected preflight proves atomic rollback: the original mutable session is untouched.
assert.throws(()=>applyWalkMapLegacy72Import(session,exact,{...importOptions,preflight:()=>({allowed:false})}),/IMPORT_PREFLIGHT_REJECTED/);assert.deepEqual(session,beforeSession);
const applied=applyWalkMapLegacy72Import(session,exact,importOptions);assert.equal(applied.session.document.revision,1);assert.equal(applied.session.document.objectPatches.length,2);assert.equal(applied.preflightReceipt.receiptId,'legacy-7-2-preflight');assert.deepEqual(session,beforeSession);
assert.throws(()=>applyWalkMapLegacy72Import(applied.session,exact,importOptions),error=>error.code==='LEGACY_PREVIEW_STALE');

console.log(`walk map editor legacy 7.2 import: PASS (real ${realLegacy.decorFull.length} decor audited, 7 topology cells converted, ${realPreview.audit.unsupported.length} unsupported)`);
