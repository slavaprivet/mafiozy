import test from 'node:test';
import assert from 'node:assert/strict';
import {pathToFileURL} from 'node:url';
import {readFileSync} from 'node:fs';
import {createVehicleFleet} from './vehicle_fleet.mjs';
import {createDemoCar,CAR} from './car_drive.mjs';
import {createVehicleImpactView} from './vehicle_impact_view.mjs';
const T=await import(pathToFileURL('D:/codex_release/artist13_hero_first_DEV_20260907/demo/vendor/build/three.module.js'));
class RoundedBox extends T.BoxGeometry{constructor(w,h,d){super(w,h,d)}}

test('real fleet contact reacts only on its owner and reset clears the spring',()=>{
 const scene=new T.Scene(),fleet=createVehicleFleet(T,{scene,RoundedBox,world:()=>()=>true});
 const add=(id,x)=>{const car=createDemoCar(T,RoundedBox);car.profile={...CAR,id,height:2.22};return fleet.addCar(car,{x,z:0,yaw:0})};
 const active=add('active',0),other=add('other',12);
 other.car.object.userData.receiveCollision({normal:{x:0,z:1,y:0},point:{x:12,y:.9,z:2.24},impactSpeed:18,eventId:'wall'});
 assert.equal(active.impactReaction.sample().impacts,0);
 fleet.update(1/60);assert.equal(other.impactReaction.sample().impacts,1);assert(other.impactReaction.sample().local.z>0);
 const old=other.impactReaction.sample().local.z;fleet.activate(other);fleet.update(1/60);
 assert.equal(other.impactReaction.sample().local.z,old,'active is advanced only by walk, never twice by fleet');
 fleet.reset();assert.equal(other.impactReaction.sample().active,false);assert.equal(other.impactReaction.sample().impacts,0);fleet.dispose();
});

test('impact camera points in car direction and restores precisely even on render failure',()=>{
 const effect=createVehicleImpactView(T),car={object:new T.Group()},camera=new T.PerspectiveCamera();car.object.rotation.y=Math.PI/2;camera.position.set(7,3,5);camera.lookAt(0,1,0);
 const beforeP=camera.position.clone(),beforeQ=camera.quaternion.clone(),reaction={active:true,local:{x:0,z:.1},camera:{x:0,y:0,z:.1}};
 for(let i=0;i<120;i++)effect.render(camera,car,reaction,()=>{assert(Math.abs(camera.position.x-7.1)<1e-8);assert(Math.abs(camera.position.z-5)<1e-8)});
 assert(camera.position.equals(beforeP));assert(camera.quaternion.equals(beforeQ));
 assert.throws(()=>effect.render(camera,car,reaction,()=>{throw Error('renderer fixture')}));
 assert(camera.position.equals(beforeP));assert(camera.quaternion.equals(beforeQ));assert.equal(effect.stats().frames,121);
 effect.reset();assert.deepEqual(effect.stats(),{peakOffset:0,frames:0});
});

test('shared walk connects wall contact, fully seated pose and final camera render',()=>{
 const s=readFileSync(new URL('./walk_preview.mjs',import.meta.url),'utf8');
 assert(s.includes('impactReaction?.impact(carState.contact,{yaw:carState.yaw})'));
 assert(s.includes('fleet?.active?.impactReaction?.update(dt)'));
 assert(s.includes('vehicleOccupantImpactPose.apply(hero,car,occupiedSeat'));
 assert(s.includes('vehicleImpactView.render(camera,car,occupiedSeat&&!transition?'));
 assert(s.includes('renderWeaponView(renderer,scene,camera'));
});
