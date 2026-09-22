import fs from 'node:fs';import vm from 'node:vm';import assert from 'node:assert/strict';
import {createWorldVehiclePlayerAccess} from './world_vehicle_player_access.mjs';
import {VEHICLE_SEATS} from './vehicle_seats.mjs';
const source=fs.readFileSync(new URL('./npc_vehicle_hijack_source.js',import.meta.url),'utf8');
function fixture(dead=false){
 let now=1000,done=0,released=0,blocked=false;const car={id:'sedan',r:10,c:10,ang:0,parked:false,model:{name:'sedan'}},npc={id:'resident-original',r:10,c:10,ang:0,hp:dead?0:100,dead,deadAt:dead?321:0,look:{hair:3,skin:2}},player={r:9.3,c:10,ang:0};
 const ctx={CARS:[car],NPCS:[npc],player,questCars:new Map(),QP:{uid:'me'},performance:{now:()=>now},_walkRendererActive:()=>true,_threeVehicleEntrySequence:null,_threeVehicleEntryBypass:false,myDrivingCarId:null,myIsPassenger:false,myDead:false,_civilianTrip:null,_ambientTrafficDrivers:new Map(),_keyState:{},joyL:{},_handbrakeActive:false,ws:null,MAP_COLS:260,MAP_ROWS:180,_lastDriveSentAt:0,
 _threeVehicleEntityId:c=>'traffic_'+c.id,_threeVehicleEntryId:(c,k)=>k==='quest'?'quest_'+c.id:'traffic_'+c.id,_threeNpcEntityId:n=>n.id,_vehicleCanBeEntered:()=>true,_vehicleIsWrecked:()=>false,_clearNpcRoute:n=>n._route=null,showToast:()=>{},npcPassableForSnitch:()=>true,_npcPathPassable:()=>!blocked,_civilianTripDoorPath:()=>!blocked,
 _walkNpcVehicleAccessResolver:()=>({outside:{r:9.3,c:10},seat:{r:10,c:10}}),_ambientTrafficRelease:t=>ctx._ambientTrafficDrivers.delete(t.car),_civilianTripRelease:()=>{},_npcVehicleHijackReleased(n){assert.equal(n,npc);released++;},activateNearbyVehicleFrom3D:()=>({ok:true}),exitCar(){ctx.myDrivingCarId=null;}};
 vm.createContext(ctx);vm.runInContext(source+`;globalThis.api={remember:_npcRememberVehicleOccupant,occupant:_npcVehicleOccupant,begin:_beginNativeVehicleEntry,beginExit:_beginNativeVehicleExit,tick:_npcVehicleHijackTick,state:_getWalkVehicleState,input:_setWalkVehicleInput,access:_getWalkVehicleAccess,action:_performWalkVehicleAction,retake:_npcVehicleHijackRetake,reply:_npcVehicleHijackExitReply,claim:_npcVehicleHijackClaimed,end:_nativeVehicleActionEnd};`,ctx);
 return {ctx,api:ctx.api,car,npc,player,get now(){return now;},get done(){return done;},get released(){return released;},block(){blocked=true;},unblock(){blocked=false;},start(){ctx.api.remember(car,npc);ctx.api.begin(car,'traffic',()=>done++);},step(){now+=50;ctx.api.tick(.05,now);}};
}
for(const dead of [false,true]){
 const f=fixture(dead),{api,npc,car,ctx}=f,identity=npc,look=npc.look,deathAt=npc.deadAt;f.start();let prev={r:npc.r,c:npc.c},phases=new Set();
 for(let i=0;i<160&&ctx._threeVehicleEntrySequence;i++){phases.add(ctx._threeVehicleEntrySequence.phase);f.step();assert(Math.hypot(npc.r-prev.r,npc.c-prev.c)<=.043,'victim has continuous physical displacement');prev={r:npc.r,c:npc.c};}
 assert.equal(f.done,1);assert.equal(f.released,1);assert.equal(ctx.NPCS.length,1);assert.equal(ctx.NPCS[0],identity);assert.equal(npc.look,look);assert.equal(npc.hp,dead?0:100);assert.equal(npc.deadAt,deathAt);assert.equal(api.occupant(car),null);assert(phases.has('pull_driver'));assert(phases.has('enter'));assert.equal(car.vr,0);assert(!npc._vehicleCorpseSeat);
 if(dead){assert.equal(npc._deathR,npc.r);assert.equal(npc._deathC,npc.c);}
}
const blocked=fixture(true);blocked.start();while(blocked.ctx._threeVehicleEntrySequence.phase!=='pull_driver')blocked.step();blocked.block();const anchor={r:blocked.npc.r,c:blocked.npc.c};for(let i=0;i<35;i++)blocked.step();assert.equal(blocked.done,0);assert.equal(blocked.released,0);assert.equal(blocked.npc.r,anchor.r);assert.equal(blocked.npc.c,anchor.c);blocked.unblock();for(let i=0;i<150&&blocked.ctx._threeVehicleEntrySequence;i++)blocked.step();assert.equal(blocked.done,1);
const retry=fixture();retry.api.remember(retry.car,retry.npc);retry.player.r=30;assert(retry.api.begin(retry.car,'traffic',()=>{}));assert.equal(retry.ctx._threeVehicleEntrySequence,null,'far-side rejection never teleports hero');assert.equal(retry.player.r,30);
assert.equal(retry.api.action({action:'drive',pose:{r:1,c:1}}).accepted,false,'host pose cannot replace source driving physics');assert.equal(retry.api.input({forward:true}).accepted,false);
{
 const f=fixture(),{ctx,api,car,npc}=f;ctx._civilianTrip={car,npc,carId:'traffic_sedan',phase:'board',progress:.45};npc._civilianTrip=true;
 assert.equal(api.occupant(car)?.npc,npc,'boarding resident reserves the driver seat before seated');
 assert.equal(api.access({carId:'traffic_sedan'}).occupiedSeatId,'front_left');
 assert(api.begin(car,'traffic',()=>{}));assert.equal(ctx._threeVehicleEntrySequence,null,'player cannot overlap a resident during the door transition');
 assert.equal(npc._vehicleHijack,undefined,'occupied transition is rejected without snapping resident to seated extraction');
}
for(const online of [false,true]){
 const f=fixture();f.start();while(f.ctx._threeVehicleEntrySequence)f.step();const event={eventId:f.npc._vehicleHijack.eventId,carId:'traffic_sedan'};
 const qc={id:'claim',owner_uid:'me',driver_uid:'me',x:10,y:10,ang:0,vx:0,vy:0};f.ctx.questCars.set('claim',qc);f.ctx.myDrivingCarId='claim';f.api.claim(f.car,'claim');f.ctx.ws=online?{readyState:1}:null;f.player.r=10;f.player.c=10;
 assert.equal(f.api.retake(f.npc,event,.05,f.now).status,'pending','retake first approaches actual door');f.npc.r=9.3;f.npc.c=10;
 assert.equal(f.api.retake(f.npc,event,.05,f.now).status,'pulling');let oldR=f.player.r;
 while(f.ctx._threeVehicleEntrySequence){f.step();assert(Math.abs(f.player.r-oldR)<=.043,'hero extraction is continuous');oldR=f.player.r;}
 assert.equal(f.ctx.myDrivingCarId,null);assert.equal(qc.owner_uid,'me','retaliating NPC never becomes canonical owner');
 if(online){assert.equal(f.api.retake(f.npc,event,.05,f.now).status,'pending','server ACK required before fight');assert.equal(f.api.reply({car_id:'claim',ok:false,reason:'busy'}),true);assert.equal(f.ctx.myDrivingCarId,'claim');assert.equal(f.api.retake(f.npc,event,.05,f.now).status,'unavailable');}
 else assert.equal(f.api.retake(f.npc,event,.05,f.now).status,'complete');
}
{
 const f=fixture(),{ctx,api,car,player}=f;api.remember(car,f.npc);
 Object.assign(ctx,{_buildingInt:null,_bankInt:null,_selectedVehicleEntry:null,_selectedBuildingEntry:null,_ensureThreePreviewDriveCar:()=>null,GTA_INTERACT_R:1.8,THREE_VEHICLE_DETECT_R:2.4,THREE_VEHICLE_PREFERRED_R:6.4});
 ctx._npcPathPassable=()=>false;
 const world=fs.readFileSync(new URL('../../../world.html',import.meta.url),'utf8'),start=world.indexOf('function activateNearbyVehicleFrom3D('),end=world.indexOf('function getNearbyVehicleInteractionFor3D()',start);vm.runInContext(world.slice(start,end),ctx);
 const actor={object:{parent:{},visible:true,position:{x:41,y:0,z:41},rotation:{y:Math.PI/2}},seats:VEHICLE_SEATS,profile:{halfWidth:1.2,halfLength:2.4}},actors=new Map([['traffic_sedan',actor]]);
 ctx.hijackCivilianCar=c=>api.begin(c,'traffic',()=>{const q={id:'claimed',x:c.c,y:c.r,ang:c.ang,owner_uid:'me',driver_uid:'me',passenger_uids:[],sourceVehicleId:'traffic_sedan',previousPresentationId:'traffic_sedan'};ctx.questCars.set('claimed',q);ctx.myDrivingCarId='claimed';api.claim(c,'claimed');actors.delete('traffic_sedan');actors.set('quest_claimed',actor);});
 ctx.exitCar=reason=>{const q=ctx.questCars.get(ctx.myDrivingCarId);if(api.beginExit(q,reason))return;ctx.myDrivingCarId=null;q.driver_uid=null;};
 const adapter=createWorldVehiclePlayerAccess({traffic:{getActor:id=>actors.get(id),getActors:()=>[...actors].map(([id,actor])=>({id,actor}))},bridge:{getWalkVehicleAccess:api.access,performWalkVehicleAction:api.action}}),point=()=>({x:player.c*4.1,z:player.r*4.1,yaw:Math.PI/2-player.ang});
 assert.equal(api.access({carId:'traffic_sedan'}).seats.find(s=>s.id==='rear_left').available,false,'server rear-seat limit is explicit');
 const enter=await adapter.request('enter',{carId:'traffic_sedan',seatId:'front_left',player:point()});assert(enter.accepted&&enter.pending);assert.equal(adapter.poll().pending,true);
 while(ctx._threeVehicleEntrySequence)f.step();const receipt=adapter.poll();assert(receipt.accepted&&!receipt.pending);assert.equal(receipt.sourceCarId,'traffic_sedan');assert.equal(receipt.presentationCarId,'quest_claimed');assert.equal(adapter.getRecord('traffic_sedan',receipt).car,actor);
 const state=api.state();assert.equal(state.phase,'driving');assert.equal(state.sourceCarId,'quest_claimed');assert.equal(state.canonicalCarId,'claimed');assert.equal(api.input({forward:true}).accepted,true);assert.equal(ctx._keyState.up,true);
 const native=api.input({nativePhysics:true,pose:{x:10,y:10,ang:0,vx:2,vy:3,steer:.25,braking:true,damageRatio:.4,wrecked:false,burning:false}});assert(native.accepted&&native.nativePhysics);const driven=ctx.questCars.get('claimed');assert.deepEqual([driven.x,driven.y,driven.ang,driven.vx,driven.vy,driven.steer],[10,10,0,2,3,.25]);assert.equal(api.state().vx,2);assert.equal(api.state().vy,3);assert.equal(ctx._keyState.up,false,'advanced walk pose does not feed legacy world keys');assert.equal(driven._walkDamageRatio,.4);
 driven.vx=driven.vy=0;const exit=await adapter.request('exit',{carId:state.sourceCarId,seatId:state.seatId,player:point()});assert(exit.accepted&&exit.pending);while(ctx._threeVehicleEntrySequence)f.step();assert.equal(adapter.poll().pending,false);assert.equal(api.state().active,false);assert.equal(api.input({forward:true}).accepted,false);
 adapter.dispose();
}
{
 const f=fixture(),{ctx,api,player}=f;const q={id:'passenger-car',x:10,y:10,ang:0,vx:0,vy:0,model:'sedan',owner_uid:'friend',driver_uid:'friend',passenger_uids:['me']};ctx.questCars.set(q.id,q);ctx.myDrivingCarId=q.id;ctx.myIsPassenger=true;player.r=10;
 Object.assign(ctx,{resolveCarModel:()=>({}),floatTexts:[],_exitRequested:false});vm.runInContext("_walkVehicleSeatId='front_right';",ctx);
 const world=fs.readFileSync(new URL('../../../world.html',import.meta.url),'utf8'),start=world.indexOf('function exitCar(reason)'),end=world.indexOf('// Ищет ближайший',start);vm.runInContext(world.slice(start,end),ctx);
 ctx.exitCar('manual');assert.equal(ctx._threeVehicleEntrySequence.phase,'exit');assert.equal(ctx._threeVehicleEntrySequence.seatId,'front_right');assert.equal(ctx.myDrivingCarId,q.id,'passenger remains actual occupant during physical door traversal');
 let previous=player.r;while(ctx._threeVehicleEntrySequence){f.step();assert(Math.abs(player.r-previous)<=.043);previous=player.r;}
 assert.equal(ctx.myDrivingCarId,null);assert.equal(ctx.myIsPassenger,false);assert.equal(q.driver_uid,'friend','passenger exit never removes real driver');
}
for(const dead of [false,true]){
 const f=fixture(dead),{ctx,car,npc,api}=f;ctx._ambientTrafficDriverByNpc=new WeakMap();const t={car,npc,carId:'traffic_sedan',phase:'drive',progress:1};ctx._ambientTrafficDrivers.set(car,t);ctx._ambientTrafficDriverByNpc.set(npc,t);f.start();const r=npc.r,c=npc.c;ctx.myDead=true;f.step();
 assert.equal(ctx._threeVehicleEntrySequence,null);assert.equal(npc.r,r);assert.equal(npc.c,c);assert.equal(npc.hp,dead?0:100);assert(!npc._vehicleHijackControlled);
 if(dead){assert.equal(npc._vehicleHijack.phase,'seated');assert.equal(npc.deadAt,321);}else{assert.equal(ctx._ambientTrafficDrivers.get(car),t);assert.equal(npc._ambientTrafficPhase,'drive');assert.equal(car.parked,false);}
}
{
 const f=fixture(),{ctx,api}=f,world=fs.readFileSync(new URL('../../../world.html',import.meta.url),'utf8');const start=world.indexOf('      let throttle = 0, steer = 0;'),end=world.indexOf('      // Legacy recovery guard:',start);assert(start>0&&end>start);
 vm.runInContext(`globalThis.physics=function(qc,keys,dt=.05){_keyState=keys;const CAR_TURN_RATE_BASE=3.4,CAR_BRAKE=22,CAR_ACCEL=13,CAR_MAX_SPEED=13,CAR_COAST_DRAG=.18,_isHelicopter=false,wantingExit=false,inDx=keys.right?1:keys.left?-1:0,inDy=keys.up?-1:keys.down?1:0,inMag=Math.hypot(inDx,inDy);let curVx=qc.vx||0,curVy=qc.vy||0,curSpeed=Math.hypot(curVx,curVy);${world.slice(start,end)};qc.vx=curVx;qc.vy=curVy;return {throttle,activeBrake,inReverse,angle:qc.ang};}`,ctx);
 for(const ang of [0,Math.PI/2,2.2]){const q={ang,vx:0,vy:0};ctx.physics(q,{up:true});assert.equal(q.ang,ang,'W gas preserves actual car heading');assert(q.vx*Math.cos(ang)+q.vy*Math.sin(ang)>0);}
 const rest={ang:0,vx:0,vy:0};ctx.physics(rest,{left:true});assert.equal(rest.ang,0);assert.equal(rest.vx,0,'A alone is steering, never throttle');
 const moving={ang:0,vx:3,vy:0};assert(ctx.physics(moving,{down:true}).activeBrake);assert(moving.vx>0&&moving.vx<3,'S brakes forward travel before reverse');for(let i=0;i<15;i++)ctx.physics(moving,{down:true});assert(moving.vx<0,'held S reverses after stopping');
 const turn={ang:0,vx:3,vy:0};ctx.physics(turn,{up:true,left:true});assert(turn.ang<0);const reverse={ang:0,vx:-3,vy:0};ctx.physics(reverse,{down:true,left:true});assert(reverse.ang>0,'reverse steering changes sign');
 const parked={id:'speed-test',x:10,y:10,vx:1,vy:0};ctx.questCars.set(parked.id,parked);assert.equal(api.access({carId:'quest_speed-test'}).speed,4.1,'vehicle access speed uses metres per second');
 const samples=[];for(let b=0;b<20;b++){const start=performance.now();for(let i=0;i<500;i++)ctx.physics(rest,{});samples.push((performance.now()-start)/500);}samples.sort((a,b)=>a-b);console.log(`Native input + existing velocity block CPU: p50=${samples[10].toFixed(5)} ms/update, p95=${samples[19].toFixed(5)} ms/update (VM; not whole-scene FPS)`);
}
console.log('PASS real source hijack state: same live/dead NPC and look/HP/death clock, continuous extraction/entry, blocked corridor waits, exact corpse anchor, no duplicate driver, no far-side teleport or pose-driving bypass');
