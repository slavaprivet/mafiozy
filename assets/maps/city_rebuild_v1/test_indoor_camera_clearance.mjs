import test from 'node:test';
import assert from 'node:assert/strict';
import {pathToFileURL} from 'node:url';
import {readFileSync} from 'node:fs';
import {createIndoorCamera} from './indoor_camera.mjs';
import {createIndoorCameraClearance} from './indoor_camera_clearance.mjs';
import {resolveBuildingCameraPosition as resolvePosition} from './building_entry.mjs';
const T=await import(pathToFileURL((process.env.MAFIOZY_THREE_VENDOR||'D:/codex_release/artist13_hero_first_DEV_20260907/demo/vendor/')+'build/three.module.js'));
const material=new T.MeshBasicMaterial({side:T.DoubleSide});
function box(root,size,position){const mesh=new T.Mesh(new T.BoxGeometry(...size),material);mesh.position.fromArray(position);root.add(mesh);return mesh}
const origin=new T.Vector3(0,1.45,0),eye=new T.Vector3(0,1.64,0),desired=new T.Vector3(0,2,-5);
function args(objects){return{origin,eye,desired,objects,position:resolvePosition({THREE:T,from:origin,desired,objects}),ceilingY:2.7,dt:1/60}}
function assertSafe(position,objects,from=origin){assert(resolvePosition({THREE:T,from,desired:position,objects}).distanceTo(position)<1e-6,'full camera volume remains on a clear segment')}

test('a close rear wall gives a real shoulder position outside the head, not only a body mask',()=>{
 const room=new T.Group();box(room,[8,3,.2],[0,1.5,-.5]);room.updateMatrixWorld(true);
 const helper=createIndoorCameraClearance({THREE:T,resolvePosition}),input=args([room]);
 assert(input.position.distanceTo(eye)<.3,'reproduces the old boom entering the head');
 for(let i=0;i<100;i++){
  const result=helper.solve(input);assert(result.active&&!result.blocked);assert(result.position.distanceTo(eye)>=.85);assertSafe(result.position,[room]);
  assert(result.probes<=2,'accepted shoulder costs one probe plus a recovery check');
 }
 const camera=createIndoorCamera({THREE:T,resolvePosition});
 for(const aiming of [false,true]){
  const view=camera.solve({feet:new T.Vector3(),target:eye,desired,objects:[room],inside:true,ceilingY:2.7,aiming});
  assert(view.bodyClearanceActive);assert(view.headDistance>=.85);assertSafe(view.position,[room]);
  assert(view.target.clone().sub(view.position).distanceTo(eye.clone().sub(desired))<1e-8,'lateral escape preserves view and aim direction');
 }
});

test('a blocked preferred shoulder uses the opposite side and never crosses the side wall',()=>{
 const room=new T.Group();box(room,[8,3,.2],[0,1.5,-.5]);box(room,[.2,3,5],[.4,1.5,0]);room.updateMatrixWorld(true);
 const helper=createIndoorCameraClearance({THREE:T,resolvePosition});
 const result=helper.solve(args([room]));assert(result.active);assert(result.position.x<-.85);assertSafe(result.position,[room]);
});

test('fully boxed-in space fails closed instead of forcing a minimum distance through geometry',()=>{
 const room=new T.Group();
 for(const [size,p]of [[[.1,3,1],[.3,1.5,0]],[[.1,3,1],[-.3,1.5,0]],[[1,3,.1],[0,1.5,.3]],[[1,3,.1],[0,1.5,-.3]],[[1,.1,1],[0,1.95,0]]])box(room,size,p);
 room.updateMatrixWorld(true);const input=args([room]),helper=createIndoorCameraClearance({THREE:T,resolvePosition});
 const result=helper.solve({...input,ceilingY:1.9});assert(result.blocked);assert.equal(result.position,input.position);assert(result.probes<=4);assertSafe(result.position,[room]);
});

test('clear space needs no extra rays; shoulder recovery is bounded and frame-rate independent',()=>{
 const clear={origin,eye,desired,objects:[],position:desired.clone(),ceilingY:3,dt:1/60};
 const empty=createIndoorCameraClearance({THREE:T,resolvePosition});assert.equal(empty.solve(clear).probes,0);
 function recover(dt,count){
  const room=new T.Group();box(room,[8,3,.2],[0,1.5,-.5]);room.updateMatrixWorld(true);
  const helper=createIndoorCameraClearance({THREE:T,resolvePosition});let previous=helper.solve(args([room])),result;
  for(let i=0;i<count;i++){result=helper.solve({...clear,dt});assert(result.position.distanceTo(previous.position)<=6*dt+1e-6,'no large recovery step');assert(result.position.distanceTo(eye)>=.85);previous={position:result.position.clone()}}
  return result.position;
 }
 assert(recover(1/60,30).distanceTo(recover(1/30,15))<1e-8);
});

test('stair ascent with treads, side walls and upper landing preserves camera volume and head clearance',()=>{
 const stairs=new T.Group();
 for(let i=0;i<12;i++)box(stairs,[1.8,.2*(i+1),.36],[0,.1*(i+1),i*.35]);
 box(stairs,[.15,6,7],[-1.3,3,2]);box(stairs,[.15,6,7],[1.3,3,2]);box(stairs,[2.6,.15,2],[0,4.55,3.5]);box(stairs,[2.6,6,.15],[0,3,4.3]);
 stairs.updateMatrixWorld(true);let escaped=0,checked=0;
 for(const angle of [0,Math.PI/2,Math.PI,Math.PI*1.5]){
  const camera=createIndoorCamera({THREE:T,resolvePosition});
  for(let step=0;step<120;step++){
   const index=Math.min(11,step/10),feet=new T.Vector3(0,.2*(Math.floor(index)+1),index*.35),target=feet.clone().add(new T.Vector3(0,1.64,0)),from=feet.clone().add(new T.Vector3(0,1.45,0));
   const desired=target.clone().add(new T.Vector3(Math.sin(angle)*5,2,Math.cos(angle)*5));
   const view=camera.solve({feet,target,desired,objects:[stairs],ceilingY:4.475,inside:true,dt:1/60});
   assertSafe(view.position,[stairs],from);assert(view.position.y<=4.475-.28+1e-6);
   if(view.bodyClearanceActive){escaped++;assert(view.headDistance>=.85)}
   if(view.headDistance<.85)assert(view.bodyClearanceBlocked&&view.hideHead,'only physically boxed-in cases may use the render mask fallback');
   checked++;
  }
 }
 assert(escaped>0,'exercise the actual shoulder escape, not merely ordinary orbit');
 console.log({stairFrames:checked,shoulderFrames:escaped});
});

test('the production host no longer bypasses camera protection during ladder climbing',()=>{
 const source=readFileSync(new URL('./walk_preview.mjs',import.meta.url),'utf8'),body=source.slice(source.indexOf('function clampBuildingCamera('),source.indexOf('function initBuildingQa('));
 assert(!/if\(verticalNavigation.active\|\|/.test(body));
 assert(body.includes('inside:!!current||verticalNavigation.active'));
});

test('walking toward a rear wall blends into the shoulder without an entry snap',()=>{
 const room=new T.Group();box(room,[8,3,.2],[0,1.5,-.5]);room.updateMatrixWorld(true);
 const camera=createIndoorCamera({THREE:T,resolvePosition});let previous=null,largestStep=0,escaped=0;
 for(let frame=0;frame<=240;frame++){
  const feet=new T.Vector3(0,0,2-frame/120),target=feet.clone().add(new T.Vector3(0,1.64,0)),desired=target.clone().add(new T.Vector3(0,.36,-5));
  const view=camera.solve({feet,target,desired,objects:[room],ceilingY:2.7,inside:true,dt:1/60});
  if(previous)largestStep=Math.max(largestStep,view.position.distanceTo(previous));previous=view.position.clone();
  if(view.bodyClearanceActive){escaped++;assert(view.headDistance>=.85)}
  assertSafe(view.position,[room],feet.clone().add(new T.Vector3(0,1.45,0)));
 }
 assert(escaped>0);assert(largestStep<.15,`entry step ${largestStep} must stay smooth`);
 console.log({wallApproachMaxStep:largestStep});
});
