import assert from 'node:assert/strict';
import test from 'node:test';
import {readFile} from 'node:fs/promises';
import vm from 'node:vm';
import {
 WALK_MAP_BANK_ANCHOR_CONSUMERS,WALK_MAP_DETENTION_ANCHOR_CONSUMERS,WALK_MAP_SPECIAL_ANCHOR_ARTIFACT_IDS,
 auditWalkMapSpecialAnchorCoverage,createWalkMapSpecialAnchorAuthorityPolicy,createWalkMapSpecialAnchorMigrationPlan,
 createWalkMapSpecialAnchorStage,createWalkMapSpecialAnchorStagedExecutor,exportWalkMapSpecialAnchorStage,importWalkMapSpecialAnchorStage,
 migrateWalkMapBankAnchors,migrateWalkMapDetentionAnchors,prepareWalkMapBankAnchorBinding,
 validateWalkMapSpecialAnchorAcknowledgements,validateWalkMapSpecialAnchorReceipt
} from './walk_map_editor_special_anchor_migration.mjs';

const here=new URL('.',import.meta.url),root=new URL('../../../',import.meta.url),json=async name=>JSON.parse(await readFile(new URL(name,here),'utf8'));
const [buildings,detentionSites,detentionDestinations,safeManifest,topology,worldSource]=await Promise.all([
 json('buildings_placement.v1.json'),json('detention_native_sites.v1.json'),json('detention_destinations.v1.json'),json('interior_safe_manifest.v1.json'),json('topology_for_placement.json'),readFile(new URL('world.html',root),'utf8')
]);
const match=worldSource.match(/const BANKS = (\[[\s\S]*?\n\]);/);assert.ok(match);const legacyBanks=JSON.parse(JSON.stringify(vm.runInNewContext(`(${match[1]})`,{}, {timeout:1000})));
const bankRecords=buildings.instances.filter(record=>/^bank_/.test(record.assetId)),detentionRecords=detentionSites.instances;
const consumerIds=[...WALK_MAP_BANK_ANCHOR_CONSUMERS,...WALK_MAP_DETENTION_ANCHOR_CONSUMERS],readyConsumers=consumerIds.map(id=>({id,status:'ready',revision:`test:${id}`}));
const authority=createWalkMapSpecialAnchorAuthorityPolicy(),sourceRevisions={buildings:'sha-buildings',detentionSites:'sha-sites',detentionDestinations:'sha-destinations',worldBankRegistry:'sha-world',serverBankConfig:'sha-server'};
const bankMoves={
 'REBUILD-bank:large':{dc:-10,dr:-10,yawDegrees:90},
 'REBUILD-bank:medium':{dc:-9,dr:-10,yawDegrees:180},
 'REBUILD-bank:small':{dc:2,dr:-10,yawDegrees:180}
};
const movedBankTransform=record=>{const move=bankMoves[record.id];return {...structuredClone(record.transform),positionM:[record.transform.positionM[0]+move.dc*4.1,record.transform.positionM[1],record.transform.positionM[2]+move.dr*4.1],yawDegrees:move.yawDegrees}};

test('actual six-record inventory stays locked because live consumer receipts are absent',()=>{
 const audit=auditWalkMapSpecialAnchorCoverage({bankRecords,detentionRecords,detentionDestinations:detentionDestinations.destinations,legacyBanks,consumerInventory:[]});
 assert.equal(audit.complete,false);assert.deepEqual(audit.counts,{banks:3,detentions:3,destinations:3,requiredConsumers:consumerIds.length,readyConsumers:0});
 assert.equal(audit.bankBindings.length,3);assert.equal(audit.warnings.filter(item=>item.code==='BANK_LEGACY_AND_AUTHORED_ANCHORS_DIVERGE').length,3);
 assert.ok(audit.errors.some(item=>item.code==='CONSUMER_NOT_READY'));
 assert.throws(()=>createWalkMapSpecialAnchorMigrationPlan({coverage:audit}),error=>error.code==='SPECIAL_ANCHOR_INVENTORY_INCOMPLETE');
 const duplicateBanks=[bankRecords[0],bankRecords[0],bankRecords[2]],duplicateAudit=auditWalkMapSpecialAnchorCoverage({bankRecords:duplicateBanks,detentionRecords,detentionDestinations:detentionDestinations.destinations,legacyBanks,consumerInventory:readyConsumers});
 assert.equal(duplicateAudit.complete,false);assert.ok(duplicateAudit.errors.some(item=>item.code==='BANK_ID_SET'));
});

test('bank binding preserves identity, economy, local vault/door contracts and excludes generic safes',()=>{
 for(const record of bankRecords){const legacy=legacyBanks.find(item=>`bank:${item.id}`===record.gameplayId),binding=prepareWalkMapBankAnchorBinding({before:record,record,legacyBank:legacy});
  assert.equal(binding.gameplayId,record.gameplayId);assert.equal(binding.runtime.reward_per_bag,legacy.reward_per_bag);assert.deepEqual(binding.interior.layout,record.bankLayout);assert.deepEqual(binding.interior.doorProfile,record.bankDoorProfile);assert.equal(binding.interior.safePolicy,'native-bank-vault-does-not-register-interior-safe');assert.equal(binding.propertyPolicy.bankIsNotBusinessPoi,true);assert.equal(binding.activation,'receipt-required');
  assert.ok(!safeManifest.safes.some(safe=>safe.buildingId===record.id));
 }
 const changed=structuredClone(bankRecords[0]);changed.bankLayout.roomLabels[0].label='changed';assert.throws(()=>prepareWalkMapBankAnchorBinding({before:bankRecords[0],record:changed,legacyBank:legacyBanks.find(item=>item.id==='large')}),error=>error.code==='BANK_LOCAL_CONTRACT_CHANGED');
});

test('detention anchor migration translates every world anchor but stages destination inactive',()=>{
 const before=detentionRecords[0],snapshot=structuredClone(before),near=(actual,expected)=>assert.ok(Math.abs(actual-expected)<1e-8,`${actual} != ${expected}`),nextTransform={...structuredClone(before.transform),positionM:[before.transform.positionM[0]+4.1,before.transform.positionM[1],before.transform.positionM[2]]},migration=migrateWalkMapDetentionAnchors({record:before,nextTransform});
 near(migration.record.stopFootprint.minC,before.stopFootprint.minC+1);near(migration.record.stopLane.maxC,before.stopLane.maxC+1);near(migration.record.collision.worldBodies[0].polygonCR[0][0],before.collision.worldBodies[0].polygonCR[0][0]+1);
 near(migration.destination.stop.c,detentionDestinations.destinations[0].stop.c+1);assert.equal(migration.destination.nativeReady,false);assert.equal(migration.activation,'receipt-required');assert.notEqual(migration.record,before);assert.deepEqual(before,snapshot);
 const rotated=migrateWalkMapDetentionAnchors({record:before,nextTransform:{...structuredClone(before.transform),yawDegrees:90}}),roundTrip=migrateWalkMapDetentionAnchors({record:rotated.record,nextTransform:before.transform});
 for(const key of ['footprint','entryCorridor','stopFootprint','stopLane'])for(const edge of ['minC','maxC','minR','maxR'])near(roundTrip.record[key][edge],before[key][edge]);
 for(let i=0;i<before.collision.worldBodies[0].polygonCR.length;i++)for(let axis=0;axis<2;axis++)near(roundTrip.record.collision.worldBodies[0].polygonCR[i][axis],before.collision.worldBodies[0].polygonCR[i][axis]);
 assert.throws(()=>migrateWalkMapDetentionAnchors({record:before,nextTransform:{...nextTransform,uniformScale:.9}}),error=>error.code==='DETENTION_SCALE_OR_HEIGHT_CHANGE_UNSUPPORTED');
 assert.throws(()=>migrateWalkMapDetentionAnchors({record:before,nextTransform:{...nextTransform,yawDegrees:17}}),error=>error.code==='DETENTION_CARDINAL_YAW_REQUIRED');
 assert.throws(()=>migrateWalkMapDetentionAnchors({record:before,nextTransform:{...nextTransform,modelLocalOffsetM:[1,0,0]}}),error=>error.code==='DETENTION_AUXILIARY_TRANSFORM_UNSUPPORTED');
});

async function makeStage(){
 const coverage=auditWalkMapSpecialAnchorCoverage({bankRecords,detentionRecords,detentionDestinations:detentionDestinations.destinations,legacyBanks,consumerInventory:readyConsumers});assert.equal(coverage.complete,true);
 const bankMigrations=await Promise.all(bankRecords.map(record=>migrateWalkMapBankAnchors({record,nextTransform:movedBankTransform(record),legacyBank:legacyBanks.find(item=>`bank:${item.id}`===record.gameplayId),coordinatePolicy:authority,topology,inventory:{complete:{buildings:true,parking:true},otherInstances:buildings.instances.filter(item=>item.id!==record.id),parkingKeepouts:[]}}))),detentionMigrations=detentionRecords.map((record,index)=>migrateWalkMapDetentionAnchors({record,nextTransform:{...structuredClone(record.transform),positionM:[record.transform.positionM[0]+(index+1)*4.1,record.transform.positionM[1],record.transform.positionM[2]],yawDegrees:(record.transform.yawDegrees+90)%360}}));
 const plan=createWalkMapSpecialAnchorMigrationPlan({bankMigrations,detentionMigrations,coverage,sourceRevisions,coordinatePolicy:authority}),worldBankRegistry={version:1,banks:structuredClone(legacyBanks)},serverBankConfig={banks:Object.fromEntries(legacyBanks.map(item=>[item.id,{reward_per_bag:item.reward_per_bag}])),policeSpawn:Object.fromEntries(legacyBanks.map(item=>[item.id,{r:item.r,c:item.c}]))};
 const stage=await createWalkMapSpecialAnchorStage({plan,sources:{buildings,detentionSites,detentionDestinations,worldBankRegistry,serverBankConfig}});return {coverage,plan,stage};
}

test('authoritative bank migration derives every exterior anchor and preserves local identity',async()=>{
 const record=bankRecords.find(item=>item.id==='REBUILD-bank:small'),migration=await migrateWalkMapBankAnchors({record,nextTransform:movedBankTransform(record),legacyBank:legacyBanks.find(item=>item.id==='small'),coordinatePolicy:authority,topology,inventory:{complete:{buildings:true,parking:true},otherInstances:buildings.instances.filter(item=>item.id!==record.id),parkingKeepouts:[]}});
 assert.equal(migration.coordinatePolicy.bankExteriorAuthority,'authored-shell');assert.deepEqual(migration.consumerAnchors.interactionEntryRC,migration.exterior.entryRC);assert.deepEqual(migration.consumerAnchors.policeDispatchRC,migration.exterior.roadProbeRC);assert.deepEqual(migration.serverAnchors.policeSpawnRC,migration.exterior.roadProbeRC);assert.ok(migration.dependencies.includes('minimap'));assert.equal(migration.activation,'receipt-required');
 assert.notDeepEqual(migration.record.transform,record.transform);assert.deepEqual(migration.record.bankLayout,record.bankLayout);assert.deepEqual(migration.record.bankRoomProfile,record.bankRoomProfile);assert.deepEqual(migration.record.bankDoorProfile,record.bankDoorProfile);
 await assert.rejects(()=>migrateWalkMapBankAnchors({record,nextTransform:record.transform,legacyBank:legacyBanks.find(item=>item.id==='small'),coordinatePolicy:{...authority,legacyBankCoordinates:'keep'},topology,inventory:{complete:{buildings:true,parking:true},otherInstances:[],parkingKeepouts:[]}}),error=>error.code==='SPECIAL_ANCHOR_AUTHORITY_REQUIRED');
});

function ackReport(stage,status){return {consumers:stage.plan.requiredConsumers.map(id=>({id,status:'rebuilt',revision:`consumer:${id}`,planDigest:stage.planDigest})),artifacts:stage.plan.artifacts.map(id=>({id,status,revision:`artifact:${id}`,planDigest:stage.planDigest,digest:stage.afterDigests[id]}))}}
function executorHarness(stage,{failInstall=false,denyProtection=false,initialSourceRevisions=stage.sourceRevisions,initialArtifacts=stage.beforeArtifacts}={}){
 let state={documentId:'editor-document',revision:7,sourceRevisions:structuredClone(initialSourceRevisions),artifacts:structuredClone(initialArtifacts)},restores=0,installs=0;
 const executor=createWalkMapSpecialAnchorStagedExecutor({executorId:'test-atomic-executor',getState:()=>structuredClone(state),authorizeProtection:request=>denyProtection?{allowed:false,reason:'protected'}:{allowed:true,approvalId:`approval:${request.operation}`,actor:'unit-test',policyDigest:'policy-sha',planDigest:request.planDigest},buildDetached:request=>({targetArtifacts:structuredClone(request.targetArtifacts),targetDigests:structuredClone(request.targetDigests)}),validateDetached:({stage:active,targetDigests})=>({consumers:active.plan.requiredConsumers.map(id=>({id,status:'rebuilt',revision:`detached:${id}`,planDigest:active.planDigest})),artifacts:active.plan.artifacts.map(id=>({id,status:'staged',revision:`detached:${id}`,planDigest:active.planDigest,digest:targetDigests[id]}))}),installDetached:({stage:active,detached,targetDigests,operation})=>{installs++;state={...state,revision:state.revision+1,artifacts:structuredClone(detached.targetArtifacts),sourceRevisions:Object.fromEntries(Object.entries(state.sourceRevisions).map(([id,value])=>[id,`${value}|${operation}:${installs}`]))};if(failInstall)throw Object.assign(new Error('injected install failure'),{code:'INJECTED_INSTALL_FAILURE'});return {consumers:active.plan.requiredConsumers.map(id=>({id,status:'rebuilt',revision:`installed:${id}`,planDigest:active.planDigest})),artifacts:active.plan.artifacts.map(id=>({id,status:'published',revision:`installed:${id}`,planDigest:active.planDigest,digest:targetDigests[id]}))}},restoreSnapshot:({snapshot})=>{restores++;state=structuredClone(snapshot)}});
 return {executor,get state(){return structuredClone(state)},get restores(){return restores}};
}

test('stage export/import is lossless and rejects self-consistent-looking semantic tampering',async()=>{
 const {stage}=await makeStage(),saved=exportWalkMapSpecialAnchorStage(stage),loaded=await importWalkMapSpecialAnchorStage(saved);assert.deepEqual(exportWalkMapSpecialAnchorStage(loaded),saved);assert.notEqual(loaded,saved);
 const reload=executorHarness(loaded),receipt=await reload.executor.execute(loaded,{operation:'reload',expectedDocumentId:'editor-document',expectedRevision:7});assert.equal(receipt.operation,'reload');assert.deepEqual(reload.state.artifacts,loaded.afterArtifacts);
 const corrupt=structuredClone(saved);corrupt.afterArtifacts['server-bank-config'].banks.small.exteriorEntryRC.r+=1;await assert.rejects(()=>importWalkMapSpecialAnchorStage(corrupt),error=>error.code==='SPECIAL_ANCHOR_STAGE_DIGEST_MISMATCH');
 const untrusted=structuredClone(saved);assert.throws(()=>exportWalkMapSpecialAnchorStage(untrusted),error=>error.code==='SPECIAL_ANCHOR_STAGE_UNTRUSTED');
});

test('atomic executor reauthorizes commit/undo/redo and yields only branded receipts',async()=>{
 const {plan,stage}=await makeStage(),h=executorHarness(stage),commit=await h.executor.execute(stage,{expectedDocumentId:'editor-document',expectedRevision:7});const accepted=await validateWalkMapSpecialAnchorReceipt(plan,commit);assert.equal(accepted.commandEligible,true);assert.deepEqual(h.state.artifacts,stage.afterArtifacts);
 const undo=await h.executor.execute(stage,{operation:'undo',previousReceipt:commit,expectedRevision:8});assert.deepEqual(h.state.artifacts,stage.beforeArtifacts);const redo=await h.executor.execute(stage,{operation:'redo',previousReceipt:undo,expectedRevision:9});assert.deepEqual(h.state.artifacts,stage.afterArtifacts);await validateWalkMapSpecialAnchorReceipt(plan,redo);
 await assert.rejects(()=>validateWalkMapSpecialAnchorReceipt(plan,structuredClone(commit)),error=>error.code==='ATOMIC_RECEIPT_REQUIRED');
 h.executor.dispose();await assert.rejects(()=>h.executor.execute(stage),error=>error.code==='SPECIAL_ANCHOR_EXECUTOR_DISPOSED');
});

test('every missing consumer/artifact acknowledgement fails closed',async()=>{
 const {stage}=await makeStage(),full=ackReport(stage,'staged');for(const id of consumerIds){const report=structuredClone(full);report.consumers=report.consumers.filter(item=>item.id!==id);assert.throws(()=>validateWalkMapSpecialAnchorAcknowledgements({stage,report,phase:'detached',targetDigests:stage.afterDigests}),error=>error.code==='ATOMIC_ACK_SET_INVALID',id)}for(const id of WALK_MAP_SPECIAL_ANCHOR_ARTIFACT_IDS){const report=structuredClone(full);report.artifacts=report.artifacts.filter(item=>item.id!==id);assert.throws(()=>validateWalkMapSpecialAnchorAcknowledgements({stage,report,phase:'detached',targetDigests:stage.afterDigests}),error=>error.code==='ATOMIC_ACK_SET_INVALID',id)}
});

test('stale, denied and failed installs leave the exact state unchanged',async()=>{
 const {stage}=await makeStage(),stale=executorHarness(stage),before=stale.state;await assert.rejects(()=>stale.executor.execute(stage,{expectedRevision:6}),error=>error.code==='SPECIAL_ANCHOR_REVISION_STALE');assert.deepEqual(stale.state,before);
 const staleSources=structuredClone(stage.sourceRevisions);staleSources.buildings='newer-buildings';const sourceGuard=executorHarness(stage,{initialSourceRevisions:staleSources}),sourceBefore=sourceGuard.state;await assert.rejects(()=>sourceGuard.executor.execute(stage,{expectedRevision:7}),error=>error.code==='SPECIAL_ANCHOR_SOURCE_REVISION_STALE');assert.deepEqual(sourceGuard.state,sourceBefore);
 const staleArtifacts=structuredClone(stage.beforeArtifacts);staleArtifacts['server-bank-config'].banks.small.changed=true;const artifactGuard=executorHarness(stage,{initialArtifacts:staleArtifacts}),artifactBefore=artifactGuard.state;await assert.rejects(()=>artifactGuard.executor.execute(stage,{expectedRevision:7}),error=>error.code==='SPECIAL_ANCHOR_ARTIFACT_STALE');assert.deepEqual(artifactGuard.state,artifactBefore);
 const denied=executorHarness(stage,{denyProtection:true}),deniedBefore=denied.state;await assert.rejects(()=>denied.executor.execute(stage,{expectedRevision:7}),error=>error.code==='SPECIAL_ANCHOR_PROTECTION_DENIED');assert.deepEqual(denied.state,deniedBefore);
 const failed=executorHarness(stage,{failInstall:true}),failedBefore=failed.state;await assert.rejects(()=>failed.executor.execute(stage,{expectedRevision:7}),error=>error.code==='INJECTED_INSTALL_FAILURE');assert.equal(failed.restores,1);assert.deepEqual(failed.state,failedBefore);
});
