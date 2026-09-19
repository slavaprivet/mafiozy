import test from 'node:test';
import assert from 'node:assert/strict';
import {pathToFileURL} from 'node:url';
import {createIndoorCamera} from './indoor_camera.mjs';
const T=await import(pathToFileURL((process.env.MAFIOZY_THREE_VENDOR||'D:/codex_release/artist13_hero_first_DEV_20260907/demo/vendor/')+'build/three.module.js'));
const near=(a,b,message)=>assert.ok(Math.abs(a-b)<1e-8,message+': '+a+' / '+b);
function fixture(){
 let distance=1.95,lastCall;
 const camera=createIndoorCamera({THREE:T,resolvePosition:args=>{lastCall=args;return args.from.clone().add(new T.Vector3(0,0,-distance))}});
 const feet=new T.Vector3(8,3,9),desired=feet.clone().add(new T.Vector3(0,3,-5)),target=feet.clone().add(new T.Vector3(0,1.64,0));
 return{camera,args:{feet,desired,target,objects:[],inside:true,ceilingY:5.35,dt:1/60},setDistance:d=>distance=d,get call(){return lastCall}};
}

test('a 1.95m stair landing retains the real shoulder position instead of jumping to the eyes',()=>{
 const f=fixture(),view=f.camera.solve(f.args);
 assert.equal(view.mode,'shoulder');assert.equal(view.hideHead,false);
 near(view.position.z,7.05,'collision-safe position');near(view.resolvedDistance,1.95,'reported boom');
 assert.ok(view.position.distanceTo(f.args.feet.clone().add(new T.Vector3(0,1.64,0)))>1.9);
 f.setDistance(2.79);for(let i=0;i<80;i++)f.camera.solve(f.args);
 const a=f.camera.solve(f.args);f.setDistance(2.81);const b=f.camera.solve(f.args);
 assert.equal(b.mode,'shoulder');assert.equal(b.hideHead,false);assert.ok(a.position.distanceTo(b.position)<.01,'crossing old 2.8m switch is continuous');
});

test('the near-body mask has hysteresis and never relocates the camera',()=>{
 const f=fixture();f.setDistance(.95);let view=f.camera.solve(f.args);
 assert.equal(view.hideHead,true);assert.equal(view.mode,'close');near(view.position.z,8.05,'close position stays on the collision boom');
 f.setDistance(1.9);for(let i=0;i<90;i++)view=f.camera.solve(f.args);assert.equal(view.hideHead,true);
 f.setDistance(2.1);for(let i=0;i<90;i++)view=f.camera.solve(f.args);assert.equal(view.hideHead,false);
 f.setDistance(1.9);view=f.camera.solve(f.args);assert.equal(view.hideHead,false);
 f.setDistance(.2);view=f.camera.solve({...f.args,eyeHeight:.8});assert.equal(view.hideHead,true);near(view.position.y,3.8,'crouching boom origin');
 assert.ok(view.target.clone().sub(view.position).normalize().distanceTo(f.args.target.clone().sub(f.args.desired).normalize())<1e-8,'near view preserves orbit direction');
});

test('bank wall at 1.479m protects the view before the head fills the screen, without moving the boom',()=>{
 for(const inside of [true,false]){
  const f=fixture();f.setDistance(Math.sqrt(1.479**2-.19**2));
  const view=f.camera.solve({...f.args,inside});
  near(view.headDistance,1.479,'reported bank head distance');
  assert.equal(view.hideHead,true,'large head is masked before clipping into it');
  near(view.position.z,f.args.feet.z-Math.sqrt(1.479**2-.19**2),'collision position is not replaced with an eye teleport');
 }
});

test('retraction is immediately safe, recovery is damped and independent of frame frequency',()=>{
 function recovery(dt,count){const f=fixture();f.setDistance(.5);f.camera.solve({...f.args,dt});f.setDistance(5);let view;for(let i=0;i<count;i++)view=f.camera.solve({...f.args,dt});return view}
 const a=recovery(1/60,30),b=recovery(1/30,15);near(a.resolvedDistance,b.resolvedDistance,'same elapsed recovery');
 const f=fixture();f.setDistance(.5);f.camera.solve(f.args);f.setDistance(5);let view=f.camera.solve(f.args);
 assert.ok(view.resolvedDistance>.5&&view.resolvedDistance<1.1,'no jump outward through a doorway');
 f.setDistance(.12);view=f.camera.solve(f.args);near(view.resolvedDistance,.12,'inward clamp has no unsafe lag');
 assert.equal(view.occlusionReason,'wall-and-ceiling');
});

test('ceiling lowering only affects indoor non-aim and the original aim direction remains exact',()=>{
 const f=fixture(),before=[f.args.feet,f.args.desired,f.args.target].map(v=>v.toArray());
 const view=f.camera.solve(f.args);assert.ok(f.call.desired.y<=f.args.ceilingY-.44+1e-8);assert.equal(f.call.ceilingY,Infinity);
 assert.ok(view.desiredDistance>view.resolvedDistance);
 f.camera.reset();const aim=f.camera.solve({...f.args,aiming:true});
 assert.deepEqual(f.call.desired.toArray(),f.args.desired.toArray());
 assert.ok(aim.target.clone().sub(aim.position).distanceTo(f.args.target.clone().sub(f.args.desired))<1e-8);
 assert.deepEqual([f.args.feet,f.args.desired,f.args.target].map(v=>v.toArray()),before);
});

test('outside calls preserve the legacy resolver arguments and result; reset and teleport discard old compression',()=>{
 const f=fixture();f.setDistance(.2);f.camera.solve(f.args);
 const outside=f.camera.solve({...f.args,inside:false});assert.equal(outside.mode,'orbit');assert.equal(outside.hideHead,true);assert.equal(outside.occlusionReason,'exterior-wall');
 assert.equal(f.call.desired,f.args.desired);assert.equal(f.call.ceilingY,f.args.ceilingY);near(outside.position.z,8.8,'legacy exterior position');
 const aim=f.camera.solve({...f.args,inside:false,aiming:true});assert.equal(f.call.ceilingY,Infinity);
 assert.ok(aim.target.clone().sub(aim.position).distanceTo(f.args.target.clone().sub(f.args.desired))<1e-8,'exterior aim direction is unchanged');
 f.setDistance(2);assert.equal(f.camera.solve({...f.args,inside:false}).hideHead,false,'exterior mask restores at a clear distance');
 f.setDistance(.2);f.camera.solve(f.args);f.setDistance(4);f.camera.reset();near(f.camera.solve(f.args).resolvedDistance,4,'explicit reset');
 f.setDistance(.2);f.camera.solve(f.args);f.setDistance(4);
 near(f.camera.solve({...f.args,feet:f.args.feet.clone().addScalar(20)}).resolvedDistance,4,'large placement change reset');
});
