import test from 'node:test';
import assert from 'node:assert/strict';
import {readFileSync} from 'node:fs';
import {pathToFileURL} from 'node:url';
import vm from 'node:vm';
import {mergeWaterDriveEffects} from './vehicle_water_state.mjs';
const shared=new URL('./',import.meta.url);
const source=()=>readFileSync(new URL('walk_preview.mjs',shared),'utf8').replaceAll('\r','');
const T=await import(pathToFileURL('D:/codex_release/artist13_hero_first_DEV_20260907/demo/vendor/build/three.module.js'));
const {CAR,createDemoCar,carOverlapsCircle,stepCar}=await import('./car_drive.mjs');
const {createVehicleFleet}=await import('./vehicle_fleet.mjs');
const {vehicleDoorPoint,planVehicleSeatExit}=await import('./vehicle_seats.mjs');
const {EXIT}=await import('./car_exit.mjs');
class RoundedBox extends T.BoxGeometry{constructor(w,h,d){super(w,h,d)}}
const open=()=>true;

test('actual key listeners consume hood repair R before weapon reload',()=>{
 const src=source(),keyRegistry=src.indexOf('const keys=new Set()'),firstKeyListener=src.indexOf("addEventListener('keydown',e=>{",keyRegistry),start=src.indexOf("addEventListener('keydown',e=>{",firstKeyListener+1),end=src.indexOf('\nfunction beginJump(',start);
 assert.ok(start>=0&&end>start);
 const reload=src.split('\n').find(line=>line.startsWith("addEventListener('keydown',e=>{if(")&&line.includes('reloadPressed=true'));
 assert.ok(reload);
 const listeners=[],context={hudInputBlocked:()=>false,arsenalOpen:()=>false,occupiedSeat:null,interactWithVehiclePanel:()=>{context.repairs++;return true},combatAllowed:()=>true,repairs:0,reloadPressed:false,addEventListener:(type,fn)=>listeners.push(fn)};
 vm.runInNewContext(src.slice(start,end)+'\n'+reload,context);
 const event={code:'KeyR',repeat:false,target:{tagName:'DIV'},defaultPrevented:false,preventDefault(){this.defaultPrevented=true},stopImmediatePropagation(){this.stopped=true}};
 for(const listener of listeners){listener(event);if(event.stopped)break;}
 assert.equal(context.repairs,1);assert.equal(context.reloadPressed,false,'repair and reload must not fire on the same keypress');
});

test('actual carLocal honors raised rail-deck body transform outside landscape',()=>{
 const src=source(),start=src.indexOf('function carLocal('),end=src.indexOf('\nfunction pedestrianAllowed(',start);
 const car={object:new T.Group()};car.object.position.set(5,2.7,8);car.object.rotation.y=.4;
 const context={THREE:T,car,carState:{x:5,z:8,yaw:.4},landscape:{contains:()=>false},explorationSurface:{contains:()=>true}};
 vm.runInNewContext(src.slice(start,end)+'\nresult=carLocal(0,2,1)',context);
 assert.ok(Math.abs(context.result.y-3.7)<1e-8,'world-space support height must be present');
});

test('moving exit plan avoids parked car alongside the release trajectory',()=>{
 const car={x:0,z:0,yaw:0,speed:4,travelYaw:0,vehicleProfile:CAR},other={x:2.8,z:2.8,yaw:0,speed:0,vehicleProfile:CAR};
 const excluded=(x,z)=>!carOverlapsCircle(other,x,z,0);
 const plan=planVehicleSeatExit(car,'front_left',open,open);assert.ok(plan);
 const landing=vehicleDoorPoint(plan.predictedCar,'front_left',plan.distance);
 assert.ok(carOverlapsCircle(other,landing.x,landing.z,EXIT.radius),'fixture exposes the unchecked neighboring body');
 assert.equal(planVehicleSeatExit(car,'front_left',open,excluded),null,'fleet-aware predicate rejects unsafe exit');
 const src=source(),call=src.match(/planVehicleSeatExit\(carState,occupiedSeat,[^\n]+/)[0];
 assert.ok(!call.endsWith(',canWalk);'),'walk must actually pass fleet-aware exit occupancy');
});

test('inactive cars release throttle after switching and idle simulation remains bounded',()=>{
 const scene=new T.Scene(),fleet=createVehicleFleet(T,{scene,RoundedBox,world:()=>open});
 for(let i=0;i<13;i++){const car=createDemoCar(T,RoundedBox);car.profile={...CAR,id:'fixture_'+i,height:2.14};fleet.addCar(car,{x:i*9,z:0,yaw:0});}
 const old=fleet.active;old.state.throttle=1;fleet.activate(fleet.records[1]);fleet.update(1/60);
 const retainedThrottle=old.state.throttle;
 for(let i=0;i<15;i++)fleet.update(1/60);
 const start=performance.now();for(let i=0;i<240;i++)fleet.update(1/60);const averageMs=(performance.now()-start)/240;
 assert.equal(fleet.stats().contacts,0);assert.ok(averageMs<15,'parked fleet CPU time '+averageMs.toFixed(3)+' ms/frame');
 assert.ok(fleet.records.every(r=>r.damage.crash.state.impacts===0));
 console.log('Idle fleet CPU: '+averageMs.toFixed(3)+' ms/frame for 12 inactive cars (no renderer).');
 fleet.dispose();
 assert.equal(retainedThrottle,0,'no retained engine load on a parked abandoned car');
});

test('an overturned or destroyed active car loses speed through ground drag, not teleporting velocity to zero',()=>{
 const setup=source().split('\n').find(line=>line.includes('const crashEffects=carDamage?.crashEffects||{}'));
 assert.ok(setup);
 for(const destroyed of [false,true]){
  const context={mergeWaterDriveEffects,carState:{x:0,z:0,yaw:0,travelYaw:0,speed:12},tyres:{effects:{}},carDamage:{disabled:destroyed,crashEffects:{}},carRollover:{unstable:!destroyed},input:{}};
  vm.runInNewContext(setup,context);
  assert.equal(context.carState.speed,12);
  const after=stepCar(context.carState,{},1/60,open);
  assert.ok(after.speed<12&&after.speed>10,'body should retain sliding inertia');
  assert.ok(after.z>0,'overturned body advances along its momentum');
 }
});
