import assert from 'node:assert/strict';
import {readFileSync} from 'node:fs';
import vm from 'node:vm';
import {createWorldVehiclePlayerAccess} from './world_vehicle_player_access.mjs';
import {VEHICLE_SEATS,vehicleDoorPoint,canControlVehicle} from './vehicle_seats.mjs';
import {advanceEntryHold,HOLD_SECONDS,EXIT_HOLD_SECONDS} from './car_entry.mjs';

// Audit actual runtime source without loading the application or its backend.
const world=readFileSync(new URL('../../../world.html',import.meta.url),'utf8');
const source=world.slice(world.indexOf('// NPC_VEHICLE_HIJACK_START'),world.indexOf('// NPC_VEHICLE_HIJACK_END'));
const walk=readFileSync(new URL('./walk_preview.mjs',import.meta.url),'utf8');
const host=walk.slice(walk.indexOf('function updateCarInteraction('),walk.indexOf('function setWalkPromptHidden('));
assert(source.includes('function _performWalkVehicleAction('));
assert(host.includes('sourceVehicleAccess?.poll()'));
const candidate=host.replace(/function updateCarInteraction\(dt\)\{\s*if\(sourceVehicleActive\(\)\)\{\s*sourceVehicleAccess\?\.poll\(\);/,
 'function updateCarInteraction(dt){ sourceVehicleAccess?.poll(); if(sourceVehicleActive()){');

async function run(mode,hostCode){
 let now=1000;
 const car={id:'fixture',x:10,y:10,ang:0,vx:0,vy:0,owner_uid:'me',driver_uid:'me',passenger_uids:[]};
 const ctx={CARS:[],NPCS:[],player:{r:10,c:10,ang:0},questCars:new Map([['fixture',car]]),QP:{uid:'me'},performance:{now:()=>now},
  _walkRendererActive:()=>true,_threeVehicleEntrySequence:null,_threeVehicleEntryBypass:false,myDrivingCarId:'fixture',myIsPassenger:false,myDead:false,
  _civilianTrip:null,_ambientTrafficDrivers:new Map(),_keyState:{},joyL:{},_handbrakeActive:false,ws:mode==='online-exit'?{readyState:1}:null,
  _threeVehicleEntityId:c=>'traffic_'+c.id,_threeVehicleEntryId:(c,k)=>k==='quest'?'quest_'+c.id:'traffic_'+c.id,
  _vehicleCanBeEntered:()=>true,_vehicleIsWrecked:()=>false,_civilianTripDoorPath:()=>true,_npcPathPassable:()=>true,npcPassableForSnitch:()=>true,
  _walkNpcVehicleAccessResolver:()=>({outside:{r:9.3,c:10},seat:{r:10,c:10}}),showToast:()=>{}};
 vm.createContext(ctx);
 vm.runInContext(source+';globalThis.api={action:_performWalkVehicleAction,state:_getWalkVehicleState,access:_getWalkVehicleAccess,exit:_beginNativeVehicleExit,entry:_beginNativeVehicleEntry,tick:_npcVehicleHijackTick,reply:_npcVehicleHijackExitReply,end:_nativeVehicleActionEnd};',ctx);
 const api=ctx.api;
 ctx.exitCar=()=>{ctx.myDrivingCarId=null;car.driver_uid=null;};
 ctx.activateNearbyVehicleFrom3D=()=>{if(mode==='interrupted-entry')api.entry(car,'quest',()=>{});else api.exit(car);return {ok:true};};
 const actor={object:{parent:{},visible:true,position:{x:41,y:0,z:41},rotation:{y:Math.PI/2}},seats:VEHICLE_SEATS,profile:{halfWidth:1.2,halfLength:2.4,label:'Fixture'}};
 const traffic={getActor:id=>id==='quest_fixture'?actor:null,getActors:()=>[{id:'quest_fixture',actor}]};
 const adapter=createWorldVehiclePlayerAccess({traffic,bridge:{getWalkVehicleAccess:api.access,performWalkVehicleAction:api.action}});
 if(mode==='interrupted-entry'){ctx.myDrivingCarId=null;car.driver_uid=null;ctx.player.r=9.3;}
 const reply=await adapter.request(mode==='interrupted-entry'?'enter':'exit',{carId:'quest_fixture',seatId:'front_left',player:{x:41,z:ctx.player.r*4.1,yaw:Math.PI/2}});
 assert.equal(reply.pending,true,'actual source creates a pending operation');
 if(mode==='interrupted-entry')api.end('interrupted');
 else for(let i=0;i<100&&ctx._threeVehicleEntrySequence;i++){now+=50;api.tick(.05,now);}
 assert.equal(api.state().active,false,'source has transitioned back to walking');
 if(mode==='online-exit')api.reply({car_id:'fixture',ok:true});
 const point=vehicleDoorPoint(adapter.getRecord('quest_fixture').state,'front_left');
 assert.equal(adapter.findEntry(point,()=>true),null,'adapter waits for receipt, rather than granting authority');
 let finds=0;
 const hostCtx={sourceVehicleActive:()=>api.state().active,sourceVehicleAccess:adapter,sourceVehicleState:api.state(),
  car:{profile:actor.profile},hero:{},transition:null,occupiedSeat:null,keys:new Set(),buildingKeyConsumed:false,pointerHeld:false,entryArmed:true,entryHeld:0,
  entrySpot:()=>{finds++;return adapter.findEntry(point,()=>true);},nearestInteraction:()=>({kind:'car'}),setCarInteractionText:()=>{},
  advanceEntryHold,HOLD_SECONDS,EXIT_HOLD_SECONDS,canControlVehicle,carState:{speed:0},carDamage:null,exitNoticeUntil:0,performance:{now:()=>now},carDriveDiagnosticsAt:now};
 vm.createContext(hostCtx);vm.runInContext(hostCode+';globalThis.step=updateCarInteraction;',hostCtx);
 for(let i=0;i<30;i++)hostCtx.step(1/60);
 assert.equal(finds,30);
 const result={mode,pending:adapter.operation.pending,canFindDoor:!!adapter.findEntry(point,()=>true)};
 // Polling the authoritative receipt is sufficient; no synthetic permission,
 // seat fallback, timer reset, or occupancy mutation is needed.
 adapter.poll();
 assert.equal(adapter.operation.pending,false);
 assert.ok(adapter.findEntry(point,()=>true));
 adapter.dispose();return result;
}

const requireFixed=process.argv.includes('--require-fixed');
const rows=[];
for(const mode of ['offline-exit','online-exit','interrupted-entry']){
 const current=await run(mode,host),proposed=await run(mode,candidate);
 assert.equal(proposed.pending,false);assert.equal(proposed.canFindDoor,true);
 if(requireFixed){assert.equal(current.pending,false,mode+' must consume the terminal receipt while on foot');assert.equal(current.canFindDoor,true);}
 rows.push({mode,current,proposed});
}
console.log(JSON.stringify({status:requireFixed?'PASS':'AUDIT',rows},null,2));
