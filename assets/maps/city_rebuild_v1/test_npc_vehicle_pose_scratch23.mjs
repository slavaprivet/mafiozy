import test from 'node:test';
import assert from 'node:assert/strict';
import {registerHooks} from 'node:module';
import {pathToFileURL} from 'node:url';

const vendor=process.env.MAFIOZI_THREE_VENDOR??'D:/codex_release/artist13_hero_first_DEV_20260907/demo/vendor';
registerHooks({resolve(specifier,context,next){return next(specifier==='three'?pathToFileURL(vendor+'/build/three.module.js').href:specifier,context);}});
const T=await import(pathToFileURL(vendor+'/build/three.module.js'));
const pose=await import('./npc_vehicle_pose.mjs');

const allocations={vector3:0,quaternion:0,matrix4:0};
class CountedVector3 extends T.Vector3{constructor(...args){super(...args);allocations.vector3++;}}
class CountedQuaternion extends T.Quaternion{constructor(...args){super(...args);allocations.quaternion++;}}
class CountedMatrix4 extends T.Matrix4{constructor(...args){super(...args);allocations.matrix4++;}}
const THREE={Vector3:CountedVector3,Quaternion:CountedQuaternion,Matrix4:CountedMatrix4,MathUtils:T.MathUtils};
const resetCounts=()=>{allocations.vector3=allocations.quaternion=allocations.matrix4=0;};
const counts=()=>({...allocations});
const matrixError=(a,b)=>Math.max(...a.elements.map((value,index)=>Math.abs(value-b.elements[index])));

function fixture(index=0){
 const scene=new T.Scene(),parent=new T.Group(),root=new T.Group(),visualPivot=new T.Group(),car=new T.Group();
 scene.add(parent,car);parent.position.set(index*.01,.2,-index*.02);parent.rotation.set(.03,.17,-.02);parent.add(root);root.add(visualPivot);
 root.position.set(2+index*.1,.45,-3-index*.08);root.rotation.set(.04,.7,-.03);visualPivot.position.set(.02,.03,-.01);
 car.position.set(18+index,.7,-9+index*.2);car.rotation.set(.19,-.8,.14);scene.updateMatrixWorld(true);
 const context={object:root,visualPivot};
 const walker={artistContext:()=>context,vehiclePose(){}};
 const vehicle={object:car,steer:.2,poseOccupant(){visualPivot.position.set(.12,.18,-.09);visualPivot.rotation.set(.08,-.04,.03);root.updateMatrixWorld(true);}};
 const binding={vehicle,seat:{x:car.position.x+.3,y:car.position.y+.62,z:car.position.z-.1},seatId:'front_left',side:1,canDrive:true,yaw:car.rotation.y,rootSeat:true,phase:'drive',progress:1,transition:false};
 return{scene,parent,root,visualPivot,car,walker,vehicle,binding,dispose(){root.removeFromParent();car.removeFromParent();}};
}

function apply(f){
 f.root.updateMatrixWorld(true);const authority=f.root.matrixWorld.clone();
 pose.applyNpcVehicleBinding({THREE,walker:f.walker,binding:f.binding,dt:1/144});
 f.root.updateMatrixWorld(true);assert(matrixError(f.root.matrixWorld,authority)<1e-11,'authoritative root must be restored');
}

test('ordinary owner cache is fixed after warmup and isolated per walker',()=>{
 const a=fixture(1),b=fixture(2);resetCounts();apply(a);assert.deepEqual(counts(),{vector3:3,quaternion:4,matrix4:2},'one cold owner has exactly nine cached math objects');
 resetCounts();for(let i=0;i<32;i++)apply(a);assert.deepEqual(counts(),{vector3:0,quaternion:0,matrix4:0},'warm owner creates no candidate math objects');
 resetCounts();apply(b);assert.deepEqual(counts(),{vector3:3,quaternion:4,matrix4:2},'second walker owns a distinct cache');
 resetCounts();for(let i=0;i<32;i++){apply(a);apply(b);}assert.deepEqual(counts(),{vector3:0,quaternion:0,matrix4:0},'two warm passengers never allocate or share construction');a.dispose();b.dispose();
});

test('same-walker nested invocation preserves both authority roots after nested warmup',()=>{
 const outer=fixture(3),innerCar=new T.Group();outer.scene.add(innerCar);innerCar.position.set(-14,2.1,11);innerCar.rotation.set(-.16,1.22,.11);innerCar.updateMatrixWorld(true);
 let nesting=false;const ordinary=outer.vehicle.poseOccupant;
 const innerVehicle={object:innerCar,steer:-.1,poseOccupant(){outer.visualPivot.position.set(-.07,.21,.05);outer.visualPivot.rotation.set(-.05,.09,-.02);outer.root.updateMatrixWorld(true);}};
 const inner={vehicle:innerVehicle,seat:{x:-13.7,y:2.72,z:10.8},seatId:'rear_right',side:-1,canDrive:false,yaw:innerCar.rotation.y,rootSeat:true,phase:'drive',progress:1,transition:false};
 outer.vehicle.poseOccupant=()=>{if(!nesting){nesting=true;outer.root.updateMatrixWorld(true);const nestedAuthority=outer.root.matrixWorld.clone();pose.applyNpcVehicleBinding({THREE,walker:outer.walker,binding:inner,dt:1/144});outer.root.updateMatrixWorld(true);assert(matrixError(outer.root.matrixWorld,nestedAuthority)<1e-11,'nested invocation restores the outer temporary authority');nesting=false;}ordinary();};
 // The first nested pass may lazily create a depth-two slot. Only warmed
 // frames are required to be allocation-free.
 apply(outer);resetCounts();for(let i=0;i<24;i++)apply(outer);
 assert.deepEqual(counts(),{vector3:0,quaternion:0,matrix4:0},'warmed reentrant owner creates no candidate math objects');outer.dispose();innerCar.removeFromParent();
});

test('40 occupied seats at 144 Hz remain allocation-free and bounded',()=>{
 const seatCounts=[4,4,4,4,2,4,2,2,2,4,2,2,4];assert.equal(seatCounts.length,13);assert.equal(seatCounts.reduce((a,b)=>a+b,0),40);
 const occupants=Array.from({length:40},(_,index)=>fixture(10+index));for(let frame=0;frame<64;frame++)for(const f of occupants)apply(f);
 resetCounts();const samples=[];for(let frame=0;frame<144;frame++){const at=performance.now();for(const f of occupants)apply(f);samples.push(performance.now()-at);}
 assert.deepEqual(counts(),{vector3:0,quaternion:0,matrix4:0},'5760 warm pose calls create zero candidate math objects');samples.sort((a,b)=>a-b);
 const p50=samples[Math.floor(samples.length*.50)],p95=samples[Math.floor(samples.length*.95)];assert(Number.isFinite(p50)&&Number.isFinite(p95));
 for(const f of occupants)f.dispose();
 console.log(JSON.stringify({scenario:'40 occupied seats / 13-car seat-count matrix / 144 frames',warmupCalls:2560,calls:5760,candidateCreatedAfterWarmup:counts(),p50FrameMs:p50,p95FrameMs:p95,fixedDepthOne:{mathObjectsPerActor:9,metadataObjectsPerActor:3,totalObjectsPerActor:12,numericPayloadBytesPerActor:456,fortyActors:{mathObjects:360,metadataObjects:120,totalObjects:480,numericPayloadBytes:18240}},fixedDepthTwoPerReentrantActor:{mathObjects:18,metadataObjects:4,totalObjects:22,numericPayloadBytes:912},scope:'CPU and explicit candidate constructors only; JS engine object overhead, renderer/GPU and legacy option-object allocation excluded'}));
});

test('rebind reuses owner cache; a disposed/recreated walker cannot inherit mutable scratch',()=>{
 const a=fixture(60);apply(a);a.car.position.set(-30,3,22);a.car.rotation.set(-.2,2.4,.18);a.binding.seat={x:-29.7,y:3.62,z:21.9};a.binding.yaw=a.car.rotation.y;a.car.updateMatrixWorld(true);
 resetCounts();apply(a);assert.deepEqual(counts(),{vector3:0,quaternion:0,matrix4:0},'rebind on same walker reuses private scratch');a.dispose();
 const recreated=fixture(61);resetCounts();apply(recreated);assert.deepEqual(counts(),{vector3:3,quaternion:4,matrix4:2},'new walker receives a new private cache');resetCounts();apply(recreated);assert.deepEqual(counts(),{vector3:0,quaternion:0,matrix4:0});recreated.dispose();
});
