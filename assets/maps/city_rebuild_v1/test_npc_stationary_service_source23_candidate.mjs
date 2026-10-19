import assert from 'node:assert/strict';
import fs from 'node:fs';
import vm from 'node:vm';
import {gunzipSync} from 'node:zlib';
import {createCivilianNativeFixture,sourceFunction} from './test_civilian_native_fixture.mjs';
import {createPrintShopServiceStation} from './native_print_shop_service_station.mjs';
import {createStationaryServiceSource23} from '../../../npc_stationary_service_source23_candidate.mjs';
import {stationaryServiceWorldCandidate} from '../../../npc_stationary_service_world23_patch_candidate.mjs';
const snapshot=JSON.parse(gunzipSync(fs.readFileSync(new URL('test_fixtures/native_static_collision19.json.gz',import.meta.url))));
const f=await createCivilianNativeFixture({assetId:'print_shop',snapshot}),world=stationaryServiceWorldCandidate(f.source),box=f.box;
new vm.Script(sourceFunction(world,'updateNpcs'));
let now=1000,randomSeed=193,deathRoll=null,hidden=false,spawnClear=true,guardFloor=true,incidents=0;
box.Math=Object.create(Math);box.Math.random=()=>deathRoll??((randomSeed=Math.imul(randomSeed,1664525)+1013904223>>>0)/4294967296);
box.performance.now=()=>now;box.getGameHour=()=>12;
const archStart=world.indexOf('const NPC_ARCHETYPES ='),archEnd=world.indexOf('// Взвешенная выборка архетипа',archStart);
vm.runInContext(world.slice(archStart,archEnd)+'\nlet _residentSerial=0;',box);
for(const name of ['_pickArchetype','_initNpcEmotions','spawnNpc','_npcLifeEligible','_npcWitnessAble','_npcCanWitnessEvent','_threeNpcEntityId','_residentCanSocialize','pickNpcWaypoint'])vm.runInContext(sourceFunction(world,name),box);
const respawnEligibility=sourceFunction(world,'_isRespawnableResident');
vm.runInContext(respawnEligibility+'\n'+sourceFunction(world,'_respawnResidentImmediately'),box);
const noop=()=>{};
Object.assign(box,{_threeNpcIds:new WeakMap(),_threeNpcIdSeq:0,_walkMeleeDamageContext:null,
 _markCombatBleeding:noop,_walkConfirmDamage:noop,_npcRememberAggression:noop,_npcSpreadRumor:noop,npcCivilianUnarmed:()=>false,_npcTrySurrenderAfterHit:()=>false,
 _registerMurderIncident:()=>incidents++,_capArr:noop,bloodSplats:[],_MAX_BLOOD:100,impacts:[],_MAX_IMPACTS:100,spawnFloatText:noop,
 _scheduleResidentRespawn:()=>assert.fail('seller cannot use ambient replacement'),RESIDENT_RESPAWN_BACKLOG:[]});
vm.runInContext(fs.readFileSync(new URL('npc_death_record20_source.js',import.meta.url),'utf8')+'\n'+sourceFunction(world,'hitNpc'),box);
const rc=p=>({r:p.z/f.M,c:p.x/f.M}),clear=p=>!f.pedestrian.query({mode:'sweep',from:rc(p),to:rc(p),radius:.18}).blocked;
const station=createPrintShopServiceStation({THREE:f.THREE,entry:f.entry,siteRevision:'sourcebody23',validateLayout:({layout})=>['spawn','doorInside','doorOutside','work','customer'].every(k=>clear(layout[k]))}),layout=station.layout;
const original=f.entry.getCollisionBodies.bind(f.entry);f.entry.getCollisionBodies=()=>original().concat(station.getCollisionBodies());
const refresh=()=>{f.refreshBodies();f.pedestrian.beginFrame();};refresh();
const host={npcs:f.npcs,spawnNpc:box.spawnNpc,validateLayout:l=>l===layout,isCurrentSite:l=>l.revision===layout.revision,
 groundHeight:n=>f.floor(n.c*f.M,n.r*f.M),canSpawnHidden:()=>hidden,canOccupySpawn:p=>spawnClear&&clear(p),
 verifyDeath:(n,t)=>n.dead&&n.deadAt<=t&&n._deathRecord20?.confirmed===true&&n._deathRecord20.targetId===box._threeNpcEntityId(n),
 canSweep:(a,b)=>box._residentNativeSegmentPassable(a.r,a.c,b.r,b.c),isStationFloor:(p,y)=>guardFloor&&Math.abs(f.floor(p.c*f.M,p.r*f.M)-y)<.05,
 occupants:()=>f.npcs.map(n=>({position:{x:n.c*f.M,y:f.floor(n.c*f.M,n.r*f.M),z:n.r*f.M},radius:.18*f.M,height:n.dead?.45:1.9})),ownsServiceSlot:()=>true};
vm.runInContext('let _stationaryServicePilot23=null;\n'+sourceFunction(world,'_installStationaryServicePilot23'),box);
const registration=box._installStationaryServicePilot23(createStationaryServiceSource23,station,host),controller=registration.controller;
const tick=(dt=1/7)=>{now+=dt*1000;refresh();return controller.tick(now,dt);};
assert.equal(tick().reason,'initial-backroom-not-ready');assert.equal(f.npcs.length,0);
hidden=true;spawnClear=false;assert.equal(tick().reason,'initial-backroom-not-ready');assert.equal(f.npcs.length,0);
spawnClear=true;let first;for(let i=0;i<15&&!controller.actor;i++)tick(.1);first=controller.actor;assert(first,'existing factory successfully creates ordinary source actor');
assert.equal(first.hp,60);assert.equal(first.max_hp,60);assert(first.id.startsWith('resident_'));
assert.equal(first._cashier,undefined);assert.equal(first._uniqueNpc,undefined);assert.equal(box._npcLifeEligible(first),true);assert.equal(box._isRespawnableResident(first),false);
assert.equal(box._npcCanWitnessEvent(first,now),true);
assert.equal(box._residentCanSocialize(first,now),false);assert.equal(box.pickNpcWaypoint(first),false,'station role keeps normal witness but excludes random wandering');
const reachWork=()=>{let result;for(let i=0;i<500;i++){result=tick();assert.notEqual(result.movement?.status,'blocked',JSON.stringify(result));if(result.status==='working')return;}assert.fail('actual source body must physically return to counter');};
reachWork();assert(Math.hypot(first.r-layout.work.z/f.M,first.c-layout.work.x/f.M)*f.M<.12);
const sourceIndex=f.npcs.indexOf(first);f.npcs.splice(sourceIndex,1);
assert.equal(controller.owns(first),false);assert.notEqual(controller.tick(now,0).status,'working');
assert.equal(controller.serviceAccess({customer:{id:'boundary-buyer',generation:1,hp:60,position:{...layout.customer}},visitId:'boundary-visit',now}).eligible,false,'missing living source cannot sell through retained reference');
f.npcs.splice(sourceIndex,0,first);assert.equal(controller.tick(now,0).status,'working');
const correctBinding=first._stationaryService;
for(const marker of [undefined,{...correctBinding,siteRevision:'old-site'},{...correctBinding,buildingId:'other-building'},{...correctBinding,generation:99},{...correctBinding,employmentId:'other-employee'}]){
 first._stationaryService=marker;assert.equal(controller.owns(first),false);assert.notEqual(controller.tick(now,0).status,'working');
 assert.equal(controller.serviceAccess({customer:{id:'boundary-buyer',generation:1,hp:60,position:{...layout.customer}},visitId:'boundary-visit',now}).eligible,false);
}
first._stationaryService=correctBinding;assert.equal(controller.tick(now,0).status,'working');
const idleCosts=[];for(let i=0;i<250;i++){now+=1;const at=performance.now();controller.tick(now,0);if(i>=50)idleCosts.push(performance.now()-at);}idleCosts.sort((a,b)=>a-b);
const footStart=world.indexOf('    if(_stationaryServicePilot23?.ownsCalmMovement'),footEnd=world.indexOf('  _stationaryServicePilot23?.tick(now,simulationFrameDt);',footStart);
const foot=world.slice(footStart,footEnd).replace(/\s*}\s*$/,'');
vm.runInContext('globalThis.actualProposedFoot=(n,dt,now)=>{for(const ignored of [0]){'+foot+'}};',box);
const atWork={r:first.r,c:first.c};first.tr=first.r+10;first.tc=first.c+10;box.actualProposedFoot(first,.2,now);assert.deepEqual({r:first.r,c:first.c},atWork,'actual proposed foot hook cannot wander an owned seller');
const before={r:first.r,c:first.c};first.panicUntil=now+1000;assert.equal(controller.ownsCalmMovement(first,now),false);assert.equal(tick().reason,'existing-crime-or-medical-owner');assert.deepEqual({r:first.r,c:first.c},before);first.panicUntil=0;
first._policeCuffed=true;assert.equal(tick().reason,'existing-crime-or-medical-owner');first._policeCuffed=false;
box.hitNpc(first,0,0,'pistol',10,{kind:'npc'});assert.equal(first.hp,50);assert(!first.dead,'ordinary nonfatal source damage');
deathRoll=.1;box.hitNpc(first,0,0,'pistol',100,{kind:'npc'});deathRoll=null;assert(first._medicalDowned);assert.equal(first.hp,1);assert.equal(tick().reason,'existing-crime-or-medical-owner');assert.equal(controller.lifecycle.death,null,'medical downing does not start replacement timer');
deathRoll=.99;box.hitNpc(first,0,0,'pistol',100,{kind:'npc'});deathRoll=null;assert(first.dead);assert.equal(first.hp,0);assert(first._deathRecord20.confirmed);assert.equal(incidents,1);
const deathAt=first.deadAt,corpseBefore=JSON.stringify(first);controller.tick(now,0);assert.equal(controller.lifecycle.death.dueAt,deathAt+60000);
now=deathAt+59999;refresh();controller.tick(now,.1);assert.equal(controller.stats.births,1);
now=deathAt+60000;hidden=false;controller.tick(now,.1);assert.equal(controller.stats.births,1);
hidden=true;spawnClear=false;controller.tick(now,.1);assert.equal(controller.stats.births,1);
spawnClear=true;for(let i=0;i<15&&controller.stats.births===1;i++)tick(.1);
const second=controller.actor;assert.notEqual(second,first);assert.notEqual(second.id,first.id);assert.equal(second.hp,60);assert.equal(second._stationaryService.generation,2);assert.equal(second._stationaryService.employmentId,first._stationaryService.employmentId);
assert(f.npcs.includes(first)&&f.npcs.includes(second));assert.equal(JSON.stringify(first),corpseBefore,'old corpse untouched during replacement');
assert.notEqual(box._threeNpcEntityId(first),box._threeNpcEntityId(second));
guardFloor=false;const stopped={r:second.r,c:second.c};assert.equal(tick().movement.status,'blocked');assert.deepEqual({r:second.r,c:second.c},stopped);guardFloor=true;
reachWork();assert.equal(controller.stats.births,2);assert.equal(controller.lifecycle.generation,2);
deathRoll=.1;box.hitNpc(second,0,0,'pistol',100,{kind:'npc'});deathRoll=null;assert(second._medicalDowned);controller.tick(now,0);assert.equal(controller.lifecycle.death,null);
const bleedStart=world.indexOf('    if(n._medicalDowned&&now>=(n._medicalBleedoutAt||0))'),bleedEnd=world.indexOf('    if(n._medicalDowned){',bleedStart);
vm.runInContext('globalThis.actualBleedout=(n,now)=>{for(const ignored of [0]){'+world.slice(bleedStart,bleedEnd)+'}};',box);
now=second._medicalBleedoutAt;box.actualBleedout(second,now);assert(second.dead);assert(second._deathRecord20.confirmed);controller.tick(now,0);assert.equal(controller.lifecycle.death.dueAt,now+60000);assert.equal(controller.stats.births,2);
const report={pass:true,sourceBodies:[first.id,second.id],employmentId:controller.stats.employmentId,factoryHp:second.max_hp,finalHp:second.hp,deathAt,replacementDelayMs:controller.lifecycle.lastSpawn.spawnedAt-deathAt,incidents,
 idleControllerCpuMs:{p50:idleCosts[100],p95:idleCosts[190]},
 limits:'Actual spawnNpc/archetypes/emotions/hitNpc/death-record/witness predicates plus actual GLB/floor/capsule/door movement. Source priority hooks still proposed; camera visibility/occupancy denial and service slot injected. No renderer/actual camera occlusion/server police dispatch/world activation/LIVE/FPS.'};
assert(registration.unregister());assert.equal(controller.owns(second),false);assert.equal(second._stationaryService.generation,2,'dead body keeps service marker to prevent ambient respawn');assert.equal(first._stationaryService.generation,1);assert.equal(registration.unregister(),false);
station.dispose();f.entry.getCollisionBodies=original;f.entry.dispose();
fs.writeFileSync(new URL('../../../outputs/npc_stationary_service_source23_candidate.json',import.meta.url),JSON.stringify(report,null,2));console.log(JSON.stringify(report,null,2));
