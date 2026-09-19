import test from 'node:test';
import assert from 'node:assert/strict';
import {pathToFileURL} from 'node:url';
import {createMercenaryPowerPanel} from './mercenary_power_panel.mjs';
import {createMercenaryFences} from './mercenary_fences.mjs';
import {createMercenaryPose} from './mercenary_pose.mjs';
import {createMercenaryChargeView} from './mercenary_charge_view.mjs';
const THREE=await import(pathToFileURL((process.env.THREE_VENDOR||'D:/codex_release/artist13_hero_first_DEV_20260907/demo/vendor')+'/build/three.module.js'));
test('power switch and actual yard lights wait for authority, then change once',async()=>{
 let resolve,calls=0,persisted=0;const p=createMercenaryPowerPanel({THREE,onPowerChange:()=>{calls++;return new Promise(r=>resolve=r);},persistPower:()=>persisted++});
 const lights=[];p.object.traverse(o=>{if(o.isPointLight)lights.push(o);});assert.equal(lights.length,2);assert(lights.every(l=>l.visible));
 const lever=p.object.getObjectByName('Main_Isolation_Lever'),angle=lever.rotation.x,a=p.disablePower(),b=p.disablePower();assert.equal(a,b);assert.equal(calls,1);assert.equal(lever.rotation.x,angle);assert.equal(p.getState().powered,true);
 resolve({ok:true});assert.equal((await a).ok,true);assert.equal(p.getState().powered,false);assert.equal(p.getTargets()[0].object.userData.mercenaryTarget.powered,false);assert(lights.every(l=>!l.visible));assert.notEqual(lever.rotation.x,angle);assert.equal(p.disablePower().alreadyOff,true);assert.equal(persisted,1);p.dispose();p.dispose();
});
test('missing/rejected electrical receipt cannot extinguish lights',async()=>{
 for(const callback of[undefined,()=>false,()=>Promise.reject(new Error('offline'))]){const p=createMercenaryPowerPanel({THREE,onPowerChange:callback});assert.equal((await p.disablePower()).ok,false);assert.equal(p.getState().powered,true);p.dispose();}
});
test('distant electrical lights are culled and returning cannot relight a disabled circuit',()=>{
 const p=createMercenaryPowerPanel({THREE,onPowerChange:()=>true}),near=p.object.position.clone();assert.equal(p.updateVisibility({x:0,z:0}),false);assert.equal(p.getState().powered,true);assert.equal(p.updateVisibility(near),true);p.disablePower();assert.equal(p.updateVisibility(near),false);p.dispose();
});
test('armed charge stays attached while demolition operator is still unsafe after fuse',()=>{
 const car=new THREE.Group(),charge={actionId:1,targetId:'car',detonateAt:10,phase:'retreat',armed:true,waitingForSafety:true},view=createMercenaryChargeView({THREE,getTarget:()=>({object:car,kind:'vehicle',valid:true}),getCharges:()=>[charge]});view.update(12);assert.equal(view.stats().active,1);charge.waitingForSafety=false;view.update(13);assert.equal(view.stats().active,0);view.dispose();
});
test('restored circuit is off, pending completion after disposal stays inert',async()=>{
 const restored=createMercenaryPowerPanel({THREE,powered:false});assert.equal(restored.getState().powered,false);assert.equal(restored.disablePower().alreadyOff,true);restored.dispose();
 let resolve,persisted=0;const p=createMercenaryPowerPanel({THREE,onPowerChange:()=>new Promise(r=>resolve=r),persistPower:()=>persisted++}),pending=p.disablePower();p.dispose();resolve(true);assert.equal((await pending).reason,'disposed');assert.equal(persisted,0);assert.deepEqual(p.getTargets(),[]);
});
test('cage retains physical roof while front is cut clear for a standing person',()=>{
 const cage=createMercenaryFences({THREE,onCollisionChange:()=>true}),roof=cage.colliders.find(c=>c.id.endsWith(':roof'));assert(roof);assert(roof.minYM>1.9);assert(cage.object.getObjectByName('Cage_Roof_Mesh').isInstancedMesh);const count=cage.colliders.length;assert.equal(cage.cut().ok,true);assert.equal(cage.colliders.length,count-1);assert(cage.colliders.includes(roof));cage.dispose();
});
test('specialist action beats differ and retreat preserves source position',()=>{
 const object=new THREE.Group(),visualPivot=new THREE.Group();object.add(visualPivot);const bones={};for(const name of['hand_r','foot_l','foot_r']){bones[name]=new THREE.Group();visualPivot.add(bones[name]);}const rotations=[],walker={height:1.9,artistContext:()=>({object,visualPivot,bones,rotate:(...args)=>rotations.push(args)})},pose=createMercenaryPose({THREE,walker});
 const signature=(kind,progress,phase='working')=>{rotations.length=0;visualPivot.position.set(0,0,0);pose.apply({kind,progress,phase},1.3);return JSON.stringify(rotations);};
 for(const kind of['revive','unlock_safe','cut_fence','plant_bomb','disable_power'])assert.notEqual(signature(kind,.2),signature(kind,.76),kind+' has multiple work beats');
 const root=object.position.toArray();assert(pose.apply({kind:'plant_bomb',phase:'retreat',progress:.5},2));assert.deepEqual(object.position.toArray(),root);assert.equal(bones.hand_r.getObjectByName('Mercenary_Tools').visible,false);assert.equal(pose.apply({kind:'plant_bomb',phase:'approach',progress:0},2),false);pose.dispose();
});
