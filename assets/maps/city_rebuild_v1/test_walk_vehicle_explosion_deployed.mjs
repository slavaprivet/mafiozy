import test from 'node:test';
import assert from 'node:assert/strict';
import vm from 'node:vm';
import {readFile} from 'node:fs/promises';
import * as module from './mercenary_core.mjs';
import {createWalkVehicleExplosionLocalAuthority} from './walk_vehicle_explosion_local_authority.mjs';

const hostSource=await readFile(new URL('./mercenary_world.js',import.meta.url),'utf8');
const hostScript=hostSource.replace("import(new URL('./mercenary_core.mjs',scriptUrl).href)",'Promise.resolve(module)');
assert.notEqual(hostScript,hostSource);assert.equal((hostScript.match(/import\(new URL\(/g)||[]).length,0);

async function mercenaryFixture({storage=new Map(),clockStart=1000000}={}){
 let clock=clockStart;
 const ctx={module,URL,Promise,console,Date:{now:()=>clock*1000},performance:{now:()=>clock*1000},document:{addEventListener(){},hidden:false,getElementById:()=>null,documentElement:{dataset:{}},currentScript:{src:'http://localhost/assets/maps/city_rebuild_v1/mercenary_world.js'}},location:{origin:'http://localhost',hostname:'localhost',href:'http://localhost/world.html'},window:{MAFIOZI_RENDERER_CONFIG:{worldScale:4.1}},localStorage:{getItem:key=>storage.get(key)||null,setItem:(key,value)=>storage.set(key,value)},_LOCAL_PREVIEW:true,_serverAuthoritativeAmmo:false,_customGang:null,_myGang:[],NPCS:Array.from({length:12},(_,i)=>({id:'civilian'+i,r:10,c:10+i*.1,hp:80,max_hp:80,name:'NPC '+i,look:{hair:i}})),player:{r:10,c:10},myHp:100,myDead:false,GANG_MAX:7,_hiredBotIds:new Set(),_inventoryItems:[{id:'pistol',type:'weapon',qty:8,name:'Pistol'}],currentWeapon:'pistol',QP:{cash:500},_syncMyWeaponsFromInventory(){},_saveCurrentWeaponChoice(){},renderWeaponHud(){},_saveGang(){},_npcBodyPassable:()=>true,_npcPathPassable:()=>true,_hospitalDoor:()=>({r:10,c:11})};
 ctx._dismissGangMember=id=>{const index=ctx._myGang.findIndex(row=>row.id===id);if(index<0)return false;ctx._myGang.splice(index,1);return true;};
 vm.createContext(ctx);vm.runInContext(hostScript,ctx);await new Promise(resolve=>setImmediate(resolve));const api=ctx.window.MafioziMercenaries;assert.equal(api.ready,true);
 const recruit=profession=>{const row=api.getRoster().candidates.find(candidate=>candidate.profession===profession);assert(row,profession);assert(api.recruit(row.id,'pistol').ok);return ctx._myGang.at(-1);};
 return{ctx,api,recruit,storage,tick:(seconds=.05)=>{clock+=seconds;api.tick(seconds);}};
}

const seat=(member,seatId,vehicleId='fleet:red')=>Object.assign(member,{_mercenaryVehicleId:vehicleId,_mercenaryVehicleSeat:seatId,_mercenaryVehiclePhase:'drive',_mercenaryVehicleExitPlan:null,_mercenaryLifeGeneration:Number(member._mercenaryLifeGeneration)||0,dead:false,deathConfirmed:false,hp:member.max_hp||100});

test('deployed controller snapshots hero plus three crew once and repair opens only a new vehicle epoch',()=>{
 const crew=[
  {actorId:'a',vehicleId:'fleet:red',seatId:'front_right',phase:'drive',hp:100,dead:false,lifeGeneration:0},
  {actorId:'b',vehicleId:'fleet:red',seatId:'rear_left',phase:'drive',hp:100,dead:false,lifeGeneration:0},
  {actorId:'c',vehicleId:'fleet:red',seatId:'rear_right',phase:'drive',hp:100,dead:false,lifeGeneration:0},
  {actorId:'entry',vehicleId:'fleet:red',seatId:'rear_left',phase:'board',hp:100,dead:false,lifeGeneration:0},
 ];
 let heroGeneration=-1,heroHits=0,crewHits=0;const record={id:'red',car:{}};
 const owner=createWalkVehicleExplosionLocalAuthority({sessionId:'deployed',canUseLocalEffects:()=>true,getHeroState:()=>({vehicleId:'fleet:red',occupiedSeat:'front_left',hp:100,dead:false,lifeGeneration:heroGeneration}),getCrewState:()=>crew,applyHeroReceipt:()=>{heroHits++;return{accepted:true}},applyCrewReceipt:()=>{crewHits++;return{accepted:true}}});
 const first=owner.handle({record,vehicle:record.car,state:{explosions:1}});assert.equal(first.targets,4);assert.equal(first.delivered,4);assert.equal(first.snapshot.occupants[0].lifeGeneration,0,'preview -1 sentinel is normalized');assert.equal(heroHits,1);assert.equal(crewHits,3);
 assert.equal(owner.handle({record,vehicle:record.car,state:{explosions:1}}).duplicate,true);assert.equal(heroHits,1);assert.equal(crewHits,3);
 assert.equal(owner.noteReset(record),true);heroGeneration=1;const second=owner.handle({record,vehicle:record.car,state:{explosions:1}});assert.equal(second.duplicate,false);assert.notEqual(second.eventId,first.eventId);assert.equal(heroHits,2);assert.equal(crewHits,6);
 const replacement={id:'red',car:{}};const replay=owner.handle({record:replacement,vehicle:replacement.car,state:{explosions:1}});assert.notEqual(replay.eventId,first.eventId,'replacement record cannot restart vehicle generation one');
});

test('deployed full mercenary host persists fatal crew and blocks revive until discharge starts a new life',async()=>{
 const first=await mercenaryFixture(),patient=first.recruit('bruiser');seat(patient,'rear_left');const [row]=first.api.snapshotVehicleExplosionOccupants('fleet:red');assert.equal(row.actorId,patient.id);
 const receipt={id:'fatal:persist',eventId:'blast:persist',vehicleId:'fleet:red',actorId:patient.id,seatId:'rear_left',lifeGeneration:row.lifeGeneration,kind:'vehicle_explosion',lethal:true,confirmed:true};assert.equal(first.api.applyVehicleExplosionOccupantReceipt(receipt).accepted,true);
 const loaded=await mercenaryFixture({storage:first.storage,clockStart:1000001}),restored=loaded.ctx._myGang.find(member=>member.id===patient.id);assert(restored);assert.equal(restored.hp,0);assert.equal(restored.dead,true);assert.equal(restored.deathConfirmed,true);assert.equal(restored._mercenaryVehicleExplosionFatal,true);assert.equal(restored._mercenaryLifeGeneration,0);
 const medic=loaded.recruit('medic');medic.r=restored.r;medic.c=restored.c;for(let i=0;i<12;i++)loaded.tick(1);assert.equal(restored.hp,0);assert.equal(restored._mercenaryVehicleExplosionFatal,true);
 loaded.tick(10);assert.equal(loaded.api.getRoster().members.find(item=>item.id===restored.id).status,'hospital');loaded.tick(300);assert(restored.hp>0);assert.equal(restored._mercenaryVehicleExplosionFatal,undefined);assert.equal(restored.deathConfirmed,undefined);assert.equal(restored._mercenaryLifeGeneration,1);
});

test('deployed world hero owner accepts preview generation zero then rejects it after recovery',async()=>{
 const world=await readFile(new URL('../../../world.html',import.meta.url),'utf8'),start=world.indexOf('let _walkVehicleOccupantLifeGeneration='),end=world.indexOf('\nfunction _applyWalkLocalBlast19',start);assert(start>=0&&end>start);
 let hurt=0;const context={_walkBlastReceipts:new Set(),_walkVehicleOccupantLethalReceipts:new Set(),_walkRendererActive:()=>true,_localHostileCanResolveHit:()=>true,_combatState:{combat_version:-1},myDead:false,myHp:100,_hurtLocal:()=>{hurt++;context.myHp=0;context.myDead=true;}};
 vm.runInNewContext(world.slice(start,end)+'\nthis.applyReceipt=_applyWalkLocalVehicleOccupantLethal;this.lifeGeneration=_walkLocalVehicleOccupantLifeGeneration;',context);assert.equal(context.lifeGeneration(),0);
 const base={id:'hero:0',eventId:'blast:0',vehicleId:'fleet:red',actorId:'player',seatId:'front_left',lifeGeneration:0,kind:'vehicle_explosion',confirmed:true,lethal:true};assert.equal(context.applyReceipt(base).accepted,true);assert.equal(hurt,1);
 context.myDead=false;context.myHp=100;assert.equal(context.lifeGeneration(),1);assert.equal(context.applyReceipt({...base,id:'hero:stale',eventId:'blast:stale'}).reason,'stale-life');assert.equal(hurt,1);assert.equal(context.applyReceipt({...base,id:'hero:1',eventId:'blast:1',lifeGeneration:1}).accepted,true);assert.equal(hurt,2);
});
