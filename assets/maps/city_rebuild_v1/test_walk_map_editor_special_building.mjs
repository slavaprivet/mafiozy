import assert from 'node:assert/strict';
import test from 'node:test';
import {readFile} from 'node:fs/promises';
import {makeWalkMapObjectTransformCommand,createWalkMapEditorDocument,createWalkMapEditorSession,executeWalkMapEditorCommand} from './walk_map_editor_document.mjs';
import {auditWalkMapSpecialBuildings,classifyWalkMapSpecialBuilding,compileWalkMapSpecialBuildingFullRebuild,createWalkMapSpecialBuildingCommandPreparer,WalkMapSpecialBuildingError,WALK_MAP_SPECIAL_BUILDING_DEPENDENCIES} from './walk_map_editor_special_building.mjs';

const here=new URL('.',import.meta.url),json=async file=>JSON.parse(await readFile(new URL(file,here),'utf8'));
const [fixtures,buildings,detentions]=await Promise.all([json('test_fixtures/walk_map_editor_special_buildings.json'),json('buildings_placement.v1.json'),json('detention_native_sites.v1.json')]);
const M=fixtures.metresPerCell,base=fixtures.supportedCivic;
const topology=()=>{const rows=20,cols=20,grid=Array.from({length:rows},()=>Array(cols).fill(8)),roadMask=Array.from({length:rows},()=>Array(cols).fill(0)),zero=()=>Array.from({length:rows},()=>Array(cols).fill(0));for(let r=0;r<rows;r++){grid[r][8]=0;roadMask[r][8]=1}return {grid,roadMask,protectedMask:zero(),policeMask:zero(),bridgeDeckMask:zero()}};
const inventory=(otherInstances=[base],parkingKeepouts=[])=>({complete:{buildings:true,parking:true},otherInstances,parkingKeepouts});
const approve=async request=>({allowed:true,approvalId:`approved:${request.source.id}`,actor:'test-host',reason:'fixture approval'});
const expectCode=async(promise,code)=>assert.rejects(promise,error=>error instanceof WalkMapSpecialBuildingError&&error.code===code);

test('real special-building inventory classifies every blocked record with Russian reasons',()=>{
 const audit=auditWalkMapSpecialBuildings({buildingRecords:buildings.instances,detentionRecords:detentions.instances});
 assert.deepEqual(audit.counts,{total:8,movable:2,locked:6});
 assert.deepEqual(audit.items.filter(item=>!item.locked).map(item=>item.assetId).sort(),['civic_hall','hospital']);
 assert.equal(audit.items.filter(item=>item.kind==='detention').length,3);assert.equal(audit.items.filter(item=>item.kind==='bank').length,3);
 for(const item of audit.items){assert.equal(item.visible,true);assert.ok(item.reason);assert.doesNotMatch(item.reason,/^[A-Z0-9_]+$/)}
 for(const item of audit.items.filter(item=>item.locked))assert.deepEqual(item.capabilities,{move:false,rotate:false,delete:false,paint:false});
 assert.match(audit.lockedReasons['REBUILD-bank:large'],/якор/i);assert.match(audit.lockedReasons['REBUILD-DETENTION-southside'],/stopFootprint/);
});

test('gameplay-active and incomplete protected records remain visibly locked',()=>{
 const active=classifyWalkMapSpecialBuilding(fixtures.gameplayActive),incomplete=classifyWalkMapSpecialBuilding({id:'protected-empty',assetId:'house',transform:{}},{protectedEntityIds:['protected-empty']});
 assert.equal(active.locked,true);assert.equal(active.code,'GAMEPLAY_ACTIVE_BINDINGS_UNMODELED');assert.match(active.reason,/игров/i);
 assert.equal(incomplete.locked,true);assert.equal(incomplete.code,'SPECIAL_BUILDING_GEOMETRY_INCOMPLETE');assert.equal(incomplete.visible,true);
});

test('supported full rebuild preserves raw unknown and scale fields without mutating input',async()=>{
 const before=structuredClone(base),nextTransform={...structuredClone(base.transform),positionM:[16.4,0,12.3],yawDegrees:0,horizontalScale:[1.4,0.8]},plan=await compileWalkMapSpecialBuildingFullRebuild({trustedBase:base,nextTransform,topology:topology(),inventory:inventory(),protectedEntityIds:[base.id],authorizeProtected:approve,metresPerCell:M});
 assert.deepEqual(base,before);assert.deepEqual(plan.record.unknownFuture,base.unknownFuture);assert.equal(plan.record.transform.futureScaleField,17);assert.deepEqual(plan.record.transform.horizontalScale,[1.4,0.8]);assert.deepEqual(plan.record.transform.modelLocalOffsetM,[0,0.62,0]);
 assert.equal(plan.mode,'full');assert.equal(plan.visualOnly,false);assert.equal(plan.requiresProtectionPolicy,true);assert.equal(plan.authorization.preflightOnly,true);assert.equal(plan.authorization.protectionPolicyStillRequired,true);assert.ok(plan.dependencies.includes('interior-collision'));assert.ok(plan.dependencies.includes('road-navigation'));assert.ok(plan.dependencies.includes('civic-interior'));
});

test('an otherwise ordinary owner-protected building is routed through the same authorized full rebuild',async()=>{
 const house={...structuredClone(base),id:'OWNER-PROTECTED-HOUSE-001',assetId:'garden_lane_house_v1',role:'residence'},state=classifyWalkMapSpecialBuilding(house,{protectedEntityIds:[house.id]});
 assert.equal(state.kind,'protected');assert.equal(state.locked,false);assert.equal(state.requiresAuthorization,true);
 let requests=0;const plan=await compileWalkMapSpecialBuildingFullRebuild({trustedBase:house,nextTransform:{...house.transform,positionM:[16.4,0,12.3]},topology:topology(),inventory:inventory([house]),protectedEntityIds:[house.id],authorizeProtected:async request=>{requests++;return approve(request)},metresPerCell:M});
 assert.equal(requests,1);assert.equal(plan.classification.kind,'protected');assert.equal(plan.classification.protectedByOwner,true);assert.equal(plan.requiresProtectionPolicy,true);
});

test('authorization, topology and complete inventories are mandatory',async()=>{
 const args={trustedBase:base,nextTransform:base.transform,topology:topology(),inventory:inventory(),protectedEntityIds:[base.id],metresPerCell:M};
 await expectCode(compileWalkMapSpecialBuildingFullRebuild(args),'SPECIAL_BUILDING_AUTHORIZATION_REQUIRED');
 await expectCode(compileWalkMapSpecialBuildingFullRebuild({...args,authorizeProtected:async()=>({allowed:false})}),'SPECIAL_BUILDING_AUTHORIZATION_REQUIRED');
 await expectCode(compileWalkMapSpecialBuildingFullRebuild({...args,topology:null,authorizeProtected:approve}),'FULL_REBUILD_TOPOLOGY_REQUIRED');
 await expectCode(compileWalkMapSpecialBuildingFullRebuild({...args,inventory:{otherInstances:[],parkingKeepouts:[],complete:{buildings:true,parking:false}},authorizeProtected:approve}),'FULL_REBUILD_INVENTORY_INCOMPLETE');
});

test('bounds, overlap, parking and road access remain fail-closed',async()=>{
 const args={trustedBase:base,topology:topology(),inventory:inventory(),authorizeProtected:approve,metresPerCell:M};
 await expectCode(compileWalkMapSpecialBuildingFullRebuild({...args,nextTransform:{...base.transform,positionM:[200,0,200]}}),'BUILDING_OUT_OF_BOUNDS');
 const blocker={id:'blocker',footprint:{minC:3,minR:2,maxC:6,maxR:4}};await expectCode(compileWalkMapSpecialBuildingFullRebuild({...args,nextTransform:{...base.transform,positionM:[16.4,0,12.3]},inventory:inventory([base,blocker])}),'BUILDING_OVERLAP');
 await expectCode(compileWalkMapSpecialBuildingFullRebuild({...args,nextTransform:base.transform,inventory:inventory([base],[{id:'parking',rectCR:{minC:2,minR:2,maxC:4,maxR:4}}])}),'PARKING_OVERLAP');
 const noRoad=topology();for(const row of noRoad.roadMask)row.fill(0);for(const row of noRoad.grid)for(let c=0;c<row.length;c++)row[c]=8;await expectCode(compileWalkMapSpecialBuildingFullRebuild({...args,nextTransform:base.transform,topology:noRoad}),'NO_STRAIGHT_ROAD_ACCESS');
});

test('detention and bank compile attempts return their exact locked reasons',async()=>{
 for(const record of [detentions.instances[0],buildings.instances.find(item=>item.assetId==='bank_small_shell_v1')]){const state=classifyWalkMapSpecialBuilding(record);await expectCode(compileWalkMapSpecialBuildingFullRebuild({trustedBase:record,nextTransform:record.transform,topology:topology(),inventory:inventory([record]),authorizeProtected:approve}),state.code)}
});

test('preparer requires full executor binding and cannot emit a visual-only command',async()=>{
 const preview={...structuredClone(base),transform:{...structuredClone(base.transform),positionM:[16.4,0,12.3]}},raw=makeWalkMapObjectTransformCommand({source:{dataset:'buildings',id:base.id},before:base,after:preview,metadata:{label:'Перенести общественный зал'}});
 assert.throws(()=>createWalkMapSpecialBuildingCommandPreparer({resolveCurrentEntity:()=>base}),/full rebuild executor/i);
 const visualOnly=createWalkMapSpecialBuildingCommandPreparer({resolveCurrentEntity:()=>base,topology:topology(),inventory:inventory(),authorizeProtected:approve,bindFullRebuild:plan=>({accepted:true,mode:'full',visualOnly:true,executorId:'bad',dependencies:plan.dependencies})});
 await expectCode(visualOnly([raw]),'FULL_REBUILD_EXECUTOR_REQUIRED');
 const missingDependency=createWalkMapSpecialBuildingCommandPreparer({resolveCurrentEntity:()=>base,topology:topology(),inventory:inventory(),authorizeProtected:approve,bindFullRebuild:plan=>({accepted:true,mode:'full',visualOnly:false,executorId:'incomplete',dependencies:plan.dependencies.filter(item=>item!=='road-navigation')})});
 await expectCode(missingDependency([raw]),'FULL_REBUILD_EXECUTOR_REQUIRED');
});

test('prepared command is authoritative, full-rebuild-only and still requires document protection policy',async()=>{
 const preview={...structuredClone(base),transform:{...structuredClone(base.transform),positionM:[16.4,0,12.3]}},raw=makeWalkMapObjectTransformCommand({source:{dataset:'buildings',id:base.id},before:base,after:preview}),prepare=createWalkMapSpecialBuildingCommandPreparer({resolveCurrentEntity:()=>structuredClone(base),topology:topology(),inventory:inventory(),protectedEntityIds:[base.id],authorizeProtected:approve,bindFullRebuild:plan=>({accepted:true,mode:'full',visualOnly:false,executorId:'fixture-full-rebuild',dependencies:plan.dependencies})}),result=await prepare([raw]);
 assert.equal(result.commands.length,1);const command=result.commands[0];assert.equal(command.patch.metadata.fullRebuild,true);assert.equal(command.patch.metadata.visualOnly,false);assert.equal(command.patch.metadata.requiresProtectionPolicy,true);assert.equal(command.patch.metadata.executor.id,'fixture-full-rebuild');assert.deepEqual(command.patch.metadata.dependencies,result.dependencies);assert.ok(WALK_MAP_SPECIAL_BUILDING_DEPENDENCIES.every(value=>result.dependencies.includes(value)));assert.equal(result.rebuildPlans[0].visualOnly,false);
 const document=createWalkMapEditorDocument({map:{rows:20,cols:20,worldUnitsPerCell:M}}),session=createWalkMapEditorSession(document);
 assert.throws(()=>executeWalkMapEditorCommand(session,command,{resolveBaseEntity:()=>({status:'found',entity:base})}),/PROTECTION_POLICY_REQUIRED/);
});

test('stale preview cannot request authorization or bind a rebuild',async()=>{
 let authorizations=0,bindings=0;const current={...structuredClone(base),unknownFuture:{nested:['changed']}},raw=makeWalkMapObjectTransformCommand({source:{dataset:'buildings',id:base.id},before:base,after:{...structuredClone(base),transform:{...base.transform,positionM:[16.4,0,12.3]}}}),prepare=createWalkMapSpecialBuildingCommandPreparer({resolveCurrentEntity:()=>current,topology:topology(),inventory:inventory(),authorizeProtected:async request=>{authorizations++;return approve(request)},bindFullRebuild:plan=>{bindings++;return {accepted:true,mode:'full',visualOnly:false,executorId:'never',dependencies:plan.dependencies}}});
 await expectCode(prepare([raw]),'STALE_SPECIAL_BUILDING_PREVIEW');assert.equal(authorizations,0);assert.equal(bindings,0);
});
