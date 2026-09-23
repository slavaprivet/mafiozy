// Permanent regression for fatal squad passengers. The squad-transport owner
// retains the corpse until hospital ownership begins, then releases the seat.
// The explosion owner only validates and applies receipts.
import test from 'node:test';
import assert from 'node:assert/strict';
import vm from 'node:vm';
import {readFile} from 'node:fs/promises';
import * as coreModule from './mercenary_core.mjs';
import {createWalkVehicleExplosionLocalAuthority} from './walk_vehicle_explosion_local_authority.mjs';

const host=await readFile(new URL('./mercenary_world.js',import.meta.url),'utf8');
assert.equal((host.match(/import\(new URL\(/g)||[]).length,1,'host must retain one intercepted core import');

async function fixture({storage=new Map(),clockStart=1000000}={}){
 let clock=clockStart;
 const ctx={module:coreModule,URL,Promise,console,Date:{now:()=>clock*1000},performance:{now:()=>clock*1000},document:{addEventListener(){},hidden:false,getElementById:()=>null,documentElement:{dataset:{}},currentScript:{src:'http://localhost/assets/maps/city_rebuild_v1/mercenary_world.js'}},location:{origin:'http://localhost',hostname:'localhost',href:'http://localhost/world.html'},window:{MAFIOZI_RENDERER_CONFIG:{worldScale:4.1}},localStorage:{getItem:key=>storage.get(key)||null,setItem:(key,value)=>storage.set(key,value)},_LOCAL_PREVIEW:true,_serverAuthoritativeAmmo:false,_customGang:null,_myGang:[],NPCS:Array.from({length:12},(_,i)=>({id:'civilian'+i,r:10,c:10+i*.1,hp:80,max_hp:80,name:'NPC '+i,look:{hair:i}})),player:{r:10,c:10},myHp:100,myDead:false,GANG_MAX:7,_hiredBotIds:new Set(),_inventoryItems:[{id:'pistol',type:'weapon',qty:8,name:'Pistol'}],currentWeapon:'pistol',QP:{cash:500},_syncMyWeaponsFromInventory(){},_saveCurrentWeaponChoice(){},renderWeaponHud(){},_saveGang(){},_npcBodyPassable:()=>true,_npcPathPassable:()=>true,_hospitalDoor:()=>({r:10,c:11})};
 ctx._dismissGangMember=id=>{const index=ctx._myGang.findIndex(row=>row.id===id);if(index<0)return false;ctx._myGang.splice(index,1);return true;};
 vm.createContext(ctx);vm.runInContext(host.replace("import(new URL('./mercenary_core.mjs',scriptUrl).href)",'Promise.resolve(module)'),ctx);await new Promise(resolve=>setImmediate(resolve));
 const api=ctx.window.MafioziMercenaries;assert.equal(api.ready,true);
 const recruit=profession=>{const row=api.getRoster().candidates.find(candidate=>candidate.profession===profession);assert(row,profession);assert(api.recruit(row.id,'pistol').ok);return ctx._myGang.at(-1);};
 return{ctx,api,recruit,storage,tick:(seconds=.05)=>{clock+=seconds;api.tick(seconds);}};
}

function seat(member,seatId,vehicleId='fleet:red'){
 Object.assign(member,{_mercenaryVehicleId:vehicleId,_mercenaryVehicleSeat:seatId,_mercenaryVehiclePhase:'drive',_mercenaryVehicleExitPlan:null,_mercenaryVehicleProgress:1,_mercenaryVehicleReservedId:vehicleId,_mercenaryVehicleReservedSeat:seatId,_mercenaryLifeGeneration:0,dead:false,deathConfirmed:false,hp:member.max_hp||100});
}

function transportFixture(){
 const released=[],history=[];let reservations=[];
 const vehicle={id:'fleet:red',seats:['front_right','rear_left','rear_right'],occupied:[],blocked:true,r:10,c:10,ang:0,speed:0};
 const transport={getPlayerVehicle:()=>null,getVehicle:id=>id===vehicle.id?vehicle:null,canCross:()=>true,access(request={}){if(request.phase==='release'){released.push({...request});return true}return{outside:{r:10,c:10.25},seat:{r:10,c:10}}},setReservations(rows){reservations=rows.map(row=>({...row}));history.push(reservations)}};
 return{transport,released,history,get reservations(){return reservations}};
}

function controller(api,record){return createWalkVehicleExplosionLocalAuthority({sessionId:'transport3-acceptance',canUseLocalEffects:()=>api.canUseLocalEffects(),getHeroState:()=>null,getCrewState:vehicleId=>api.snapshotVehicleExplosionOccupants(vehicleId),applyHeroReceipt:()=>({accepted:false}),applyCrewReceipt:receipt=>api.applyVehicleExplosionOccupantReceipt(receipt)});}
const vehicleFields=['_mercenaryVehicleSeat','_mercenaryVehicleId','_mercenaryVehicleChaseAt','_mercenaryVehiclePhase','_mercenaryVehicleProgress','_mercenaryVehicleExitPending','_mercenaryVehicleDropState','_mercenaryVehicleExitPlan','_mercenaryVehicleMove','_mercenaryVehicleReservedSeat','_mercenaryVehicleReservedId'];
function assertReleased(member,api,transport){
 for(const field of vehicleFields)assert.equal(Object.hasOwn(member,field),false,field+' must be cleared');
 assert.equal(api.snapshotVehicleExplosionOccupants('fleet:red').length,0,'hospital/returning member is not a remote car occupant');
 assert(transport.released.some(row=>row.carId==='fleet:red'&&row.seatId==='rear_left'),'physical reservation receives release');
 assert.equal(transport.reservations.some(row=>row.vehicleId==='fleet:red'&&row.seatId==='rear_left'),false,'published reservations omit released seat');
}

async function fatal(f,patient,record,owner){
 seat(patient,'rear_left');const result=owner.handle({record,vehicle:record.car,state:{explosions:1}});assert.equal(result.targets,1);assert.equal(result.delivered,1);assert.equal(patient._mercenaryVehicleExplosionFatal,true);assert.equal(patient.hp,0);
}

test('same-session fatal -> hospitalize -> discharge -> repair -> second blast has no ghost occupant',async()=>{
 const f=await fixture(),transport=transportFixture();f.api.bindTargets({squadTransport:transport.transport});const patient=f.recruit('bruiser'),record={id:'red',car:{}},owner=controller(f.api,record);await fatal(f,patient,record,owner);
 for(let i=0;i<22;i++)f.tick(1);assert.equal(f.api.getRoster().members.find(row=>row.id===patient.id).status,'hospital');assertReleased(patient,f.api,transport);
 f.tick(300);assert(['returning','active'].includes(f.api.getRoster().members.find(row=>row.id===patient.id).status));assert(patient.hp>0);assert.equal(patient._mercenaryLifeGeneration,1);assertReleased(patient,f.api,transport);
 const hp=patient.hp;assert.equal(owner.noteReset(record),true);const second=owner.handle({record,vehicle:record.car,state:{explosions:1}});assert.equal(second.targets,0);assert.equal(second.delivered,0);assert.equal(patient.hp,hp,'second repaired-car blast cannot kill a discharged remote member');
});

test('save/reload has identical cleanup, generation and second-blast behavior',async()=>{
 const first=await fixture(),patient=first.recruit('bruiser'),record={id:'red',car:{}},firstOwner=controller(first.api,record);await fatal(first,patient,record,firstOwner);
 const loaded=await fixture({storage:first.storage,clockStart:1000001}),transport=transportFixture();loaded.api.bindTargets({squadTransport:transport.transport});const restored=loaded.ctx._myGang.find(member=>member.id===patient.id);assert(restored);for(let i=0;i<22;i++)loaded.tick(1);assert.equal(loaded.api.getRoster().members.find(row=>row.id===restored.id).status,'hospital');
 // Reloaded legacy rows may have no live reservation to release, but they must
 // converge to the same field/snapshot state.
 for(const field of vehicleFields)assert.equal(Object.hasOwn(restored,field),false,field+' reload parity');assert.equal(loaded.api.snapshotVehicleExplosionOccupants('fleet:red').length,0);
 loaded.tick(300);assert(restored.hp>0);assert.equal(restored._mercenaryLifeGeneration,1);for(const field of vehicleFields)assert.equal(Object.hasOwn(restored,field),false,field+' discharge parity');
 const secondRecord={id:'red',car:{}},secondOwner=controller(loaded.api,secondRecord),hp=restored.hp;assert.equal(secondOwner.noteReset(secondRecord),true);const second=secondOwner.handle({record:secondRecord,vehicle:secondRecord.car,state:{explosions:1}});assert.equal(second.targets,0);assert.equal(restored.hp,hp);
});

test('seat release follows successful authoritative dismissal and leaves failed dismissal untouched',async()=>{
 const f=await fixture(),transport=transportFixture();f.api.bindTargets({squadTransport:transport.transport});const member=f.recruit('bruiser');seat(member,'rear_left');
 f.ctx._dismissGangMember=()=>false;assert.equal(f.api.dismiss(member.id).ok,false);assert.equal(member._mercenaryVehicleSeat,'rear_left');assert.equal(transport.released.length,0);
 f.ctx._dismissGangMember=id=>{const index=f.ctx._myGang.findIndex(row=>row.id===id);if(index<0)return false;f.ctx._myGang.splice(index,1);return true;};
 assert.equal(f.api.dismiss(member.id).ok,true);assert.equal(member._mercenaryVehicleSeat,undefined);assert(transport.released.some(row=>row.carId==='fleet:red'&&row.seatId==='rear_left'));
});
