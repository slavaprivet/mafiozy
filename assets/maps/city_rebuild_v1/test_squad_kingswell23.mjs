// Actual Kingswell geometry + complete source host + native queries, CPU only.
import assert from 'node:assert/strict';
import fs from 'node:fs';
import vm from 'node:vm';
import {pathToFileURL} from 'node:url';
import {registerHooks} from 'node:module';
import * as module from './mercenary_core.mjs';
import {CAR,createDemoCar} from './car_drive.mjs';
import {VEHICLE_SEATS,vehicleDoorPoint} from './vehicle_seats.mjs';
import {createMercenaryVehicleBridge} from './mercenary_vehicle_bridge.mjs';
import {createNpcVehicleAccessResolver} from './npc_vehicle_access.mjs';
import {createNpcNativeNavigation} from './npc_native_navigation.mjs';
import {npcVehicleBlocks} from './world_traffic_presentation.mjs';
import {createMercenarySafePlacement} from './mercenary_catchup.mjs';
import {createNpcTrafficVehicleBinding} from './npc_vehicle_pose.mjs';
import {createNpcActor} from './npc_actor.mjs';
import {clone} from './test_npc_death_offline_setup.mjs';
const vendor=process.env.MAFIOZI_THREE_VENDOR||'D:/codex_release/artist13_hero_first_DEV_20260907/demo/vendor';
const threeUrl=pathToFileURL(vendor+'/build/three.module.js').href;
registerHooks({resolve(s,c,next){return next(s==='three'?threeUrl:s,c);}});
const THREE=await import(threeUrl),{RoundedBoxGeometry}=await import('../../../tools/vehicle_fleet_qa/RoundedBoxGeometry.mjs'),{GLTFLoader}=await import(pathToFileURL(vendor+'/addons/loaders/GLTFLoader.js'));
const car=createDemoCar(THREE,RoundedBoxGeometry),scene=new THREE.Scene();scene.add(car.object);car.object.position.set(612.95,0,59.45);car.object.rotation.y=0;
car.profile={...CAR,id:'red_sedan',label:'Kingswell',height:2.22,massKg:1500};car.seats=VEHICLE_SEATS;
const fleet={records:[{id:'red_sedan',car,state:{speed:0}}]};let playerVehicle={id:'fleet:red_sedan',seatId:'front_left',ready:true};
const nav=createNpcNativeNavigation({groundHeight:()=>0,waterAt:()=>null,bodiesAt:()=>[],bodiesInBounds:()=>[],containsBody:()=>false,surfaceAt:()=> 'road',blocksDynamic:(x,z,b)=>b.ignoreId!=='fleet:red_sedan'&&npcVehicleBlocks(car,x,z,0,b)});
const bridge=createMercenaryVehicleBridge({getFleet:()=>fleet,getPlayer:()=>playerVehicle,canCross:(id,from,to)=>{const q=nav.query({mode:'sweep',from,to,radius:.18});return q.swept===true&&q.blocked===false;}});
const oldAccess=createNpcVehicleAccessResolver({traffic:{getActor:()=>car}}),geometry=[];
for(const seat of VEHICLE_SEATS){
 const old=oldAccess({carId:'fleet:red_sedan',seatId:seat.id});assert.ok(Number.isNaN(old.outside.r)&&Number.isNaN(old.outside.c));
 const access=bridge.access({carId:'fleet:red_sedan',seatId:seat.id});assert.ok([access.outside.r,access.outside.c,access.seat.r,access.seat.c].every(Number.isFinite));
 const distance=Math.max(1.9,CAR.halfWidth+4.1*.18+.1),expected=vehicleDoorPoint({x:612.95,z:59.45,yaw:0,seats:VEHICLE_SEATS},seat.id,distance);
 assert.ok(Math.abs(access.outside.c*4.1-expected.x)<1e-9&&Math.abs(access.outside.r*4.1-expected.z)<1e-9);
 assert.equal(seat.doorDistance,undefined);assert.equal(seat.doorFront,undefined);geometry.push({seatId:seat.id,outside:{...access.outside},seat:{...access.seat}});
}
const original=car.seats;car.seats=[{...VEHICLE_SEATS[0],doorDistance:NaN}];assert.equal(bridge.access({carId:'fleet:red_sedan',seatId:'front_left'}),null);car.seats=original;
const read=name=>fs.readFileSync(new URL(name,import.meta.url),'utf8');
const source=read('./mercenary_world.js'),script=source.replace("import(new URL('./mercenary_core.mjs',scriptUrl).href)",'Promise.resolve(module)');
const fixtureText=read('./test_mercenary_rally_actions.mjs'),fixtureBody=fixtureText.slice(fixtureText.indexOf('async function fixture('),fixtureText.indexOf('\nfor(const [profession'));
const make=Function('vm','module','script','assert',fixtureBody+';return fixture;')(vm,module,script,assert),f=await make({qa:true});
const members=['engineer','bruiser','safecracker'].map(p=>f.recruit(p));
const livePositions=[[13.986334303859891,150.34223701290904],[14.806700359242402,150.3960554182617],[13.362758848392296,150.3715274771345]];
members.forEach((m,i)=>Object.assign(m,{r:livePositions[i][0],c:livePositions[i][1]}));Object.assign(f.ctx.player,{r:59.45/4.1,c:612.95/4.1,ang:Math.PI/2});
Object.assign(f.ctx,{_walkNpcNavigationResolver:nav.query,npcPassable:(r,c)=>{const q=nav.query({r,c});return !q.blocked&&q.depth<=.025;},MAP:Array.from({length:200},()=>Array(200).fill(0)),_civilianDoorBody:[[0,0],[-.18,-.18],[-.18,.18],[.18,-.18],[.18,.18]],_civilianTripDebugEnabled:()=>false});f.ctx.npcPassableForSnitch=f.ctx.npcPassable;
const world=read('../../../world.html'),doorSource=read('./civilian_parking_trip_source.js');
const physics=['_npcBodyPassable','_npcPathPassable'].map(name=>world.match(new RegExp('^function '+name+'\\([^]*?^}','m'))[0]).join('\n');
vm.runInContext(physics+'\n'+doorSource.slice(doorSource.indexOf('function _civilianTripDoorPath('),doorSource.indexOf('function _civilianTripDoorStep(')),f.ctx);
const canMove=(a,b)=>f.ctx._npcPathPassable(a.z/4.1,a.x/4.1,b.z/4.1,b.x/4.1);
const placement=createMercenarySafePlacement({ready:()=>true,queryPoint:p=>nav.query({r:p.z/4.1,c:p.x/4.1}),bodyClear:p=>f.ctx._npcBodyPassable(p.z/4.1,p.x/4.1),groundHeight:()=>0,isInsideBuilding:()=>false,blocksVehicle:(p,b)=>npcVehicleBlocks(car,p.x,p.z,b.radius,{y:p.y,height:b.height})});
f.api.bindTargets({squadTransport:bridge,canMove,groundHeight:()=>0,safeCatchupPoint:(p,id)=>placement.check(p,{id})});f.api.follow();
let boardFrames=0,movingBoard=null;for(;boardFrames<700&&!members.every(m=>m._mercenaryVehiclePhase==='drive');boardFrames++){
 nav.beginFrame();f.tick(.05);assert.ok(members.every(m=>[m.r,m.c].every(Number.isFinite)));
 const partial=!movingBoard&&members.find(m=>m._mercenaryVehiclePhase==='board'&&m._mercenaryVehicleProgress>0&&m._mercenaryVehicleProgress<1);
 if(partial){
  const before={r:partial.r,c:partial.c,progress:partial._mercenaryVehicleProgress};car.object.position.x+=4;fleet.records[0].state.speed=2;nav.beginFrame();f.tick(.05);
  const moved=Math.hypot(partial.r-before.r,partial.c-before.c)*4.1;assert.ok(moved<=.300001,'departure permits only ordinary bounded foot approach');assert.ok(!partial._mercenaryVehicleSeat||partial._mercenaryVehicleProgress===before.progress);assert.equal(partial._mercenaryVehicleReservedId,'fleet:red_sedan');
  movingBoard={progressBefore:before.progress,footMovementMeters:moved,reservationRetained:true};fleet.records[0].state.speed=0;
 }
}
assert.ok(movingBoard);
assert.ok(members.every(m=>m._mercenaryVehiclePhase==='drive'),JSON.stringify(members.map(m=>({r:m.r,c:m.c,phase:m._mercenaryVehiclePhase,reason:m._mercenaryMoveReason}))));assert.equal(new Set(members.map(m=>m._mercenaryVehicleSeat)).size,3);
car.object.position.x+=4;nav.beginFrame();f.tick(.05);for(const m of members){const a=bridge.access({carId:'fleet:red_sedan',seatId:m._mercenaryVehicleSeat});assert.ok(Math.hypot(m.r-a.seat.r,m.c-a.seat.c)<1e-8);}
playerVehicle=null;f.ctx.player.c=(car.object.position.x+4)/4.1;let exitFrames=0;
for(;exitFrames<700&&members.some(m=>m._mercenaryVehicleSeat);exitFrames++){nav.beginFrame();f.tick(.05);}
assert.ok(members.every(m=>!m._mercenaryVehicleSeat),'every passenger completes physical exit');
const binding=createNpcTrafficVehicleBinding({THREE,actor:car}),poses=[];assert.equal(typeof car.poseOccupant,'undefined');
for(const [sex,file]of [['male','player_male.8130dfb1f7eb.glb'],['female','player_female.298d50e6244a.glb']]){
 const bytes=fs.readFileSync(new URL('hero_models/'+file,import.meta.url)),model=(await new GLTFLoader().parseAsync(bytes.buffer.slice(bytes.byteOffset,bytes.byteOffset+bytes.byteLength),'')).scene;
 for(const seat of VEHICLE_SEATS){const actor=createNpcActor({THREE,scene,source:model,cloneSkeleton:clone,id:sex+'-'+seat.id,sex,getVehicle:()=>binding});
  for(const phase of ['board','drive'])for(let i=0;i<12;i++){
   const point=binding.getSeatRootWorld(seat.id);actor.update(.05,{time:i*.05,position:{x:point.x,y:0,z:point.z},yaw:0,moving:false,posture:{target:'stand',value:0},life:{civilianTripRiding:phase==='drive',civilianTripPhase:phase,civilianTripProgress:phase==='drive'?1:i/11,civilianTripCarId:'fleet:red_sedan',vehicleSeatId:seat.id}});
   actor.object.updateMatrixWorld(true);for(const bone of Object.values(actor.walker.artistContext().bones))if(bone?.matrixWorld)assert.ok(bone.matrixWorld.elements.every(Number.isFinite));
  }
  poses.push({sex,seatId:seat.id,board:true,drive:true});actor.dispose();
 }
}
const result={pass:true,geometry,sourceHost:{boardSeconds:boardFrames*.05,exitSeconds:exitFrames*.05,seated:3,exited:3,movingBoard,actualLiveStartingPositions:livePositions},poses,limits:'Actual createDemoCar, frozen VEHICLE_SEATS, full source host, native sweep/body and GLB actors. Open road fixture, not captured full LIVE city/static collisions/FPS.'};
fs.writeFileSync(new URL('../../../outputs/squad_kingswell23_results.json',import.meta.url),JSON.stringify(result,null,2));console.log(JSON.stringify(result,null,2));
