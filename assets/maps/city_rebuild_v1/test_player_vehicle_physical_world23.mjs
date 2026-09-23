import test from 'node:test';
import assert from 'node:assert/strict';
import fs from 'node:fs';
import vm from 'node:vm';
import {createPlayerVehiclePhysicalResolver} from './player_vehicle_physical_resolver.mjs';
import {createNpcVehicleNavigation} from './npc_vehicle_navigation.mjs';
import {CAR} from './car_drive.mjs';
import {collisionPolygon} from './vehicle_collision_shape.mjs';
import {polygonVehicleContact} from './vehicle_contact.mjs';

// Execute the deployed World ownership/caller and the deployed Walk bridge
// registration. There is no candidate transform, patch overlay, browser, vendor
// checkout or working-directory assumption. Geometry uses actual body polygons.
const world=fs.readFileSync(new URL('../../../world.html',import.meta.url),'utf8');
const walk=fs.readFileSync(new URL('./walk_preview.mjs',import.meta.url),'utf8');
function section(source,start,end){
 const first=source.indexOf(start),last=source.indexOf(end,first+start.length);
 assert(first>=0&&last>first,`Missing production source section: ${start}`);
 return source.slice(first,last);
}
const stateSource=section(world,'function _getWalkVehicleState(){','function _setWalkVehicleInput(');
const footprintSource=section(world,'function _playerVehicleFootprintClear(','function _isRaceWaterEdgeBlockedForPed(');
const physicalBinding=section(walk,'const playerVehiclePhysical=','\n');
const registration=section(walk,'npcBridge?.registerWalkTrafficNavigationResolver?.(request=>','addEventListener(\'pagehide\',()=>npcBridge?.registerWalkTrafficNavigationResolver?.(null)');

function fixture({block=null,water=null,otherCars=[],ready=true}={}){
 const car={id:'42',x:0,y:0,ang:0,vx:0,vy:0};
 const actor={profile:{...CAR},object:{scale:{x:1,y:1,z:1},position:{x:0,y:0,z:0},rotation:{y:Math.PI/2},visible:true,userData:{sourceVehicleId:'quest_42'}}};
 const nav=createNpcVehicleNavigation({
  ready:()=>ready,worldScale:4.1,getVehicle:id=>id==='quest_42'?actor:null,
  getVehicles:()=>[{id:'quest_42',actor},...otherCars],isRoad:()=>false,
  groundHeight:()=>0,waterAt:(x,z)=>water?.(x,z),
  poseAllowed:(x,z,yaw,shape)=>!block||!polygonVehicleContact(collisionPolygon(x,z,yaw,shape),block),
 });
 const physicalRequests=[],physicalQuery=nav.queryPhysical;
 nav.queryPhysical=request=>{physicalRequests.push(request);return physicalQuery(request);};
 const ctx={
  myDrivingCarId:'42',questCars:new Map([['42',car]]),_threeVehicleEntrySequence:null,
  myIsPassenger:false,_walkVehicleSeatId:'front_left',player:{r:99,c:99,ang:0},
  _walkVehicleLastAction:null,_walkRendererActive:()=>true,
  _walkNpcVehicleAccessResolver:()=>({ready:true}),
  createPlayerVehiclePhysicalResolver,npcVehicleNavigation:nav,
  npcBridge:{
   getWalkVehicleState:()=>ctx.getState(),
   registerWalkTrafficNavigationResolver:resolver=>{ctx._walkTrafficNavigationResolver=resolver;},
  },
 };
 vm.createContext(ctx);
 vm.runInContext(stateSource+footprintSource+physicalBinding+registration+
  ';globalThis.getState=_getWalkVehicleState;globalThis.clear=_playerVehicleFootprintClear;',ctx);
 const request={mode:'player-physical',carId:'quest_42',from:{r:0,c:0,angle:0},to:{r:0,c:2,angle:0}};
 return {nav,ctx,car,actor,physicalRequests,request,resolve:request=>ctx._walkTrafficNavigationResolver(request)};
}

test('actual World caller permits the active source driver on physically clear non-road',()=>{
 const f=fixture();assert.equal(f.ctx.clear(f.car,0,2,0),true);
 assert.equal(f.physicalRequests.length,1);
 assert.equal(f.ctx.getState().x,0);assert.equal(f.ctx.getState().c,99,'source car position owns the sweep, not the player avatar');
 assert.equal(f.nav.query({...f.request,roadsOnly:false}).reason,'vehicle_surface_forbidden');
});

test('generic NPC query flags cannot select private physical navigation',()=>{
 const f=fixture();
 for(const flags of [{mode:'player-physical'},{mode:'sweep',physical:true},{mode:'sweep',manualDrive:true},{mode:'sweep',semantic:false},{mode:'sweep',driver:true}]){
  assert.equal(f.nav.query({...f.request,...flags,roadsOnly:false}).reason,'vehicle_surface_forbidden');
 }
 assert.equal(f.physicalRequests.length,0);
});

test('building between individually clear endpoints blocks the complete player sweep',()=>{
 const block=collisionPolygon(4.1,0,0,{halfLength:3,halfWidth:.3}),f=fixture({block});
 assert.equal(f.nav.queryPhysical({...f.request,to:f.request.from}).clear,true);
 assert.equal(f.nav.queryPhysical({...f.request,from:f.request.to}).clear,true);
 assert.equal(f.resolve(f.request).reason,'solid-or-surface');
 assert.equal(f.ctx.clear(f.car,0,2,0),false);
});

test('water under body corners remains forbidden despite a dry center',()=>{
 const f=fixture({water:(x,z)=>z>1?{depth:.5}:null});
 assert.equal(f.resolve(f.request).reason,'water');assert.equal(f.ctx.clear(f.car,0,2,0),false);
});

test('other vehicle polygon still blocks the active source car',()=>{
 const other={id:'quest_43',actor:{profile:{...CAR},object:{scale:{x:1,z:1},position:{x:4.1,y:0,z:0},rotation:{y:Math.PI/2},visible:true,userData:{sourceVehicleId:'quest_43'}}}};
 const f=fixture({otherCars:[other]}),result=f.resolve(f.request);
 assert.equal(result.reason,'vehicle');assert.equal(result.blockerId,'quest_43');
 assert.equal(f.ctx.clear(f.car,0,2,0),false);
});

test('actual source state denies passengers, transitions, lost cars and foreign car IDs',()=>{
 const f=fixture();f.ctx.myIsPassenger=true;assert.equal(f.ctx.clear(f.car,0,2,0),false);
 f.ctx.myIsPassenger=false;
 for(const phase of ['enter','exit']){
  f.ctx._threeVehicleEntrySequence={phase,seatId:'front_left'};assert.equal(f.ctx.clear(f.car,0,2,0),false);
 }
 f.ctx._threeVehicleEntrySequence=null;f.ctx.myDrivingCarId=null;assert.equal(f.ctx.clear(f.car,0,2,0),false);
 f.ctx.myDrivingCarId='42';assert.equal(f.resolve({...f.request,carId:'quest_43'}).reason,'player_vehicle_mismatch');
 assert.equal(f.physicalRequests.length,0);
});

test('World supplies its exact frame origin, preserves turn sweep and rejects a stale translated origin',()=>{
 const f=fixture();f.car._nativeDriveFrameFrom={r:0,c:0,angle:0};f.car.ang=.08;
 assert.equal(f.ctx.clear(f.car,.01,.15,f.car.ang),true);
 assert.equal(f.physicalRequests[0].from,f.car._nativeDriveFrameFrom,'do not replace the actual pre-turn source anchor');
 assert.equal(f.physicalRequests[0].to.angle,.08);
 f.car.x=1;assert.equal(f.ctx.clear(f.car,.01,1.15,f.car.ang),false);
 assert.equal(f.physicalRequests.length,1,'stale origin never reaches geometry');
});

test('missing access, loading geometry, malformed poses and oversized sweeps fail closed',()=>{
 const f=fixture();f.ctx._walkNpcVehicleAccessResolver=()=>null;assert.equal(f.ctx.clear(f.car,0,2,0),false);
 const pending=fixture({ready:false});assert.equal(pending.ctx.clear(pending.car,0,2,0),false);
 assert.equal(f.resolve({...f.request,to:{r:0,c:2,angle:NaN}}).reason,'invalid-pose');
 assert.equal(f.resolve({...f.request,to:{r:0,c:1000,angle:0}}).reason,'segment-too-long');
});

test('actual Walk registration separates physical player requests from ordinary NPC sweeps',()=>{
 const f=fixture();assert.equal(f.resolve({...f.request,mode:'sweep',roadsOnly:false,physical:true}).reason,'vehicle_surface_forbidden');
 assert.equal(f.physicalRequests.length,0);assert.equal(f.resolve(f.request).clear,true);assert.equal(f.physicalRequests.length,1);
 f.ctx.myIsPassenger=true;assert.equal(f.resolve(f.request).reason,'player_vehicle_unbound');assert.equal(f.physicalRequests.length,1);
});
