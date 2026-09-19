import assert from 'node:assert/strict';
import {pathToFileURL} from 'node:url';
import {createMercenaryTargets} from './mercenary_targets.mjs';
const THREE=await import(pathToFileURL((process.env.THREE_VENDOR||'D:/codex_release/artist13_hero_first_DEV_20260907/demo/vendor')+'/build/three.module.js'));
const scene=new THREE.Scene(),camera=new THREE.PerspectiveCamera(50,1,.1,200);camera.position.set(0,1,8);camera.lookAt(0,1,0);camera.updateMatrixWorld();
function mesh(name,z=0){const m=new THREE.Mesh(new THREE.BoxGeometry(2,2,2),new THREE.MeshBasicMaterial());m.name=name;m.position.set(0,1,z);scene.add(m);scene.updateMatrixWorld(true);return m;}
const car=mesh('Car'),fleet={records:[{id:'v1',car:{object:car}}]};let blasts=0;
const targets=createMercenaryTargets({THREE,camera,getRoots:()=>[scene],getFleet:()=>fleet,onVehicleBlast(){blasts++;return true;}});
assert.equal(targets.pick().id,'fleet:v1');const a=targets.get('fleet:v1');assert(a.position.x!==a.center.x,'approach outside vehicle centre');
assert.equal(a.workRange,.08);assert.equal(Math.abs(a.workPoint.x-a.center.x),1);assert.equal(Math.abs(a.workNormal.x),1);assert.equal(a.workPoint.y,a.center.y+.65,'contact is on bodywork, not the approach floor');
car.position.z=-40;scene.updateMatrixWorld(true);assert.equal(targets.pick().id,'fleet:v1','orders remain available from 48 metres without requiring player approach');car.position.z=0;scene.updateMatrixWorld(true);
car.position.x=5;const b=targets.get(a.id);assert.equal(b.center.x,5,'moving vehicle live pose');assert(Math.abs(Math.abs(b.position.x-b.center.x)-1.84)<1e-9,'approach follows vehicle without changing its chosen side');const chosenSide=b.position.x-b.center.x;camera.position.x=-12;assert(Math.sign(targets.get(a.id).position.x-b.center.x)===Math.sign(chosenSide),'turning camera never sends working crew around to the other side');camera.position.x=0;camera.updateMatrixWorld();car.position.x=0;
const wall=mesh('Wall',3);assert.equal(targets.pick(),null,'opaque nearer wall occludes vehicle');wall.visible=false;assert.equal(targets.pick().kind,'vehicle');
assert.equal(targets.performEffect({kind:'explode',targetId:a.id,id:'e1'}).ok,true);assert.equal(targets.performEffect({kind:'explode',targetId:a.id,id:'e1'}).duplicate,true);assert.equal(blasts,1,'same effect id only once');
car.removeFromParent();fleet.records=[];assert.equal(targets.get(a.id),null,'removed vehicle no longer valid');
const safe=mesh('Safe');safe.userData.mercenaryTarget={id:'safe:1',kind:'safe'};safe.userData.locked=true;
let opened=0,cut=0;const t=createMercenaryTargets({THREE,camera,getRoots:()=>[scene],onUnlock(){opened++;return true;},onFenceCut(){cut++;return false;}});
assert.equal(t.pick().id,'safe:1');assert.equal(t.performEffect({kind:'unlock_safe',targetId:'safe:1'}).ok,true);assert.equal(safe.userData.locked,false);assert.equal(t.performEffect({kind:'unlock_safe',targetId:'safe:1'}).ok,false);assert.equal(opened,1);
safe.name='Decorative_Safe';delete safe.userData.mercenaryTarget;delete safe.userData.locked;assert.equal(t.pick().locked,false,'name never invents lock state');safe.removeFromParent();
const fence=mesh('Fence_panel');const f=t.pick();assert.equal(f.kind,'fence');assert.equal(t.performEffect({kind:'cut_fence',targetId:f.id}).ok,false);assert.equal(fence.visible,true,'rejected collision callback never hides fence');assert.equal(fence.userData.mercenaryCut,undefined);assert.equal(cut,1);
const unsupported=createMercenaryTargets({THREE,camera,getRoots:()=>[scene]});const uf=unsupported.pick();assert.equal(unsupported.performEffect({kind:'cut_fence',targetId:uf.id}).reason,'effect_not_connected');
t.dispose();assert.equal(t.pick(),null);assert.equal(t.get(f.id),null);
fence.removeFromParent();
const asyncDoor=mesh('Door_async');asyncDoor.userData.locked=true;asyncDoor.userData.mercenaryTarget={id:'door:async',kind:'door'};
let resolveReceipt,asyncCalls=0;
const asyncTargets=createMercenaryTargets({THREE,camera,getRoots:()=>[scene],onUnlock(){asyncCalls++;return new Promise(resolve=>{resolveReceipt=resolve;});}});
asyncTargets.pick();const effect={kind:'unlock_door',targetId:'door:async',actionId:'async-1'},receipt=asyncTargets.performEffect(effect);
assert(receipt instanceof Promise);assert.equal(asyncTargets.performEffect(effect),receipt,'pending actionId shares same promise');assert.equal(asyncCalls,1);assert.equal(asyncDoor.userData.locked,true,'pending never unlocks');
resolveReceipt({ok:true,opened:true});assert.equal((await receipt).ok,true);assert.equal(asyncDoor.userData.locked,false);assert.equal(asyncTargets.performEffect(effect).duplicate,true);
asyncDoor.userData.locked=true;delete asyncDoor.userData.mercenaryOpened;
const rejected=createMercenaryTargets({THREE,camera,getRoots:()=>[scene],onUnlock:()=>Promise.reject(Error('owner rejection'))});rejected.pick();assert.equal((await rejected.performEffect({...effect,actionId:'reject'})).ok,false);assert.equal(asyncDoor.userData.locked,true,'rejected promise keeps lock');
asyncTargets.pick();const removedReceipt=asyncTargets.performEffect({...effect,actionId:'removed'});asyncDoor.removeFromParent();resolveReceipt({ok:true,opened:true});const removedResult=await removedReceipt;
assert.equal(removedResult.ok,true,'authority success survives target removal');assert.equal(removedResult.presentationUnavailable,true);assert.equal(asyncDoor.userData.locked,true,'stale object not mutated');
console.log('PASS targets: centre ray occlusion, stable fleet ID/live side approach, stale removal, callback-backed blast idempotence, actual lock state, one-time unlock, fence collision rejection, async receipt/pending dedup/rejection/removal');
// Numeric transport IDs and string-normalized receipt keys share one transaction.
const numericCar=mesh('NumericCar');let numericCalls=0;const numericTargets=createMercenaryTargets({THREE,camera,getRoots:()=>[scene],getTraffic:()=>({getActors:()=>[{id:0,object:numericCar}]}),onVehicleBlast:()=>{numericCalls++;return true;}});
assert.equal(numericTargets.get('traffic:0').sourceId,0);assert(numericTargets.performEffect({kind:'plant_bomb',targetId:'traffic:0',actionId:901}).ok);assert(numericTargets.performEffect({kind:'plant_bomb',targetId:'traffic:0',actionId:'901'}).duplicate);assert.equal(numericCalls,1);assert.equal(numericTargets.performEffect({kind:'plant_bomb',targetId:'traffic:other',actionId:'901'}).reason,'request_conflict');numericTargets.dispose();
console.log('PASS numeric zero vehicle identity and normalized transaction receipts/conflict rejection');

const rallyScene=new THREE.Scene(),rallyCamera=new THREE.PerspectiveCamera(50,1,.1,200);rallyCamera.position.set(0,5,8);rallyCamera.lookAt(0,0,0);rallyCamera.updateMatrixWorld();
const rallyFloor=new THREE.Mesh(new THREE.PlaneGeometry(40,40),new THREE.MeshBasicMaterial());rallyFloor.rotation.x=-Math.PI/2;rallyScene.add(rallyFloor);rallyScene.updateMatrixWorld(true);
const rallyPicker=createMercenaryTargets({THREE,camera:rallyCamera,getRoots:()=>[rallyScene]});assert(Math.abs(rallyPicker.pickGround().z)<1e-5);rallyFloor.userData.nativeTerrainKind='water';assert.equal(rallyPicker.pickGround(),null,'water cannot be rally ground');delete rallyFloor.userData.nativeTerrainKind;rallyFloor.userData.mercenaryTarget={kind:'vehicle'};assert.equal(rallyPicker.pickGround(),null,'rally never selects vehicle roof');rallyPicker.dispose();

// Small props tolerate near misses, but walls and foreground actors still win.
{
 const s=new THREE.Scene(),c=new THREE.PerspectiveCamera(50,1,.1,100);c.position.set(0,1,5);c.lookAt(0,1,0);c.updateMatrixWorld();
 const panel=new THREE.Mesh(new THREE.BoxGeometry(.5,.8,.2),new THREE.MeshBasicMaterial());panel.position.set(.45,1,0);panel.userData.mercenaryTarget={id:'assist-panel',kind:'power_panel',highlightBounds:{min:[-.25,-.4,-.1],max:[.25,.4,.1]}};s.add(panel);s.updateMatrixWorld(true);
 const p=createMercenaryTargets({THREE,camera:c,getRoots:()=>[s],getBuildings:()=>[{object:panel}]});
 assert.equal(p.pick()?.id,'assist-panel','20cm near miss selects small panel');assert.equal(p.pick()?.assisted,true);
 const fenceBehind=new THREE.Mesh(new THREE.BoxGeometry(3,3,.1),new THREE.MeshBasicMaterial());fenceBehind.name='Fence_back';fenceBehind.position.set(0,1,-1);s.add(fenceBehind);s.updateMatrixWorld(true);assert.equal(p.pick()?.id,'assist-panel','compact foreground switch wins over the fence behind it');fenceBehind.removeFromParent();
 const obstruction=new THREE.Mesh(new THREE.BoxGeometry(3,3,.2),new THREE.MeshBasicMaterial());obstruction.position.set(0,1,2);s.add(obstruction);s.updateMatrixWorld(true);assert.equal(p.pick(),null,'expanded target never selects through a wall');obstruction.removeFromParent();
 panel.position.x=1.2;s.updateMatrixWorld(true);assert.equal(p.pick(),null,'distant screen miss does not attract selection');p.dispose();
 const carGroup=new THREE.Group(),door=new THREE.Mesh(new THREE.BoxGeometry(2,2,.2),new THREE.MeshBasicMaterial());door.name='Door_front_left';door.position.y=1;carGroup.add(door);s.remove(panel);s.add(carGroup);s.updateMatrixWorld(true);
 const cars=createMercenaryTargets({THREE,camera:c,getRoots:()=>[s],getFleet:()=>[{id:'whole-car',object:carGroup}]});assert.equal(cars.pick()?.id,'fleet:whole-car','named child door selects whole vehicle');assert.equal(cars.pick()?.kind,'vehicle');cars.dispose();
}
console.log('PASS forgiving compact prop selection with real visibility, whole vehicle over child door');

// Actual demo car footprint must reach the picker; otherwise the specialist goal
// lies inside the car's authoritative .738m-expanded body and always times out.
{
 const s=new THREE.Scene(),c=new THREE.PerspectiveCamera(50,1,.1,100);c.position.set(0,1,8);c.lookAt(0,1,0);c.updateMatrixWorld();
 const car=new THREE.Group();s.add(car);s.updateMatrixWorld(true);
 const p=createMercenaryTargets({THREE,camera:c,getRoots:()=>[s],getFleet:()=>[{id:'wide-demo',car:{object:car,profile:{halfWidth:1.28}}}]});
 const t=p.get('fleet:wide-demo');assert.equal(Math.abs(t.position.x),2.12);assert.equal(Math.abs(t.workPoint.x),1.28);assert(Math.abs(t.position.x)-.08>1.28+.738,'entire arrival range clears car and crew footprint');p.dispose();
}
