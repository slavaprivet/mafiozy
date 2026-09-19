import test from 'node:test';
import assert from 'node:assert/strict';
import {pathToFileURL,fileURLToPath} from 'node:url';

const ROOT=fileURLToPath(new URL('../../../',import.meta.url));
const asset=name=>new URL(name,import.meta.url);
const THREE=await import(pathToFileURL(process.env.MAFIOZY_THREE||'D:/codex_release/artist13_hero_first_DEV_20260907/demo/vendor/build/three.module.js'));
const {createDemoCar}=await import(asset('car_drive.mjs'));
const {createVehicleCrash,subdivideVehicleGeometry}=await import(asset('vehicle_crash.mjs'));
const {sampleCrashDeformation}=await import(asset('vehicle_crash_mechanics.mjs'));
const {createVehicleDamage}=await import(asset('vehicle_damage.mjs'));
const {createTyreDamage}=await import(asset('tyre_damage.mjs'));
const {createVehicleTrunk}=await import('./vehicle_trunk.mjs');
class TestBox extends THREE.BoxGeometry{constructor(w,h,d){super(w,h,d)}}
const close=(a,b,tol=1e-7)=>assert(Math.abs(a-b)<tol,`${a} != ${b}`);
const state={x:0,y:0,z:0,yaw:0,travelYaw:0,speed:0,steer:0,distance:0};

test('sleeping geometry does not freeze cooling-system temperature under engine load',()=>{
 const car=createDemoCar(THREE,TestBox),drive={...state,throttle:1},crash=createVehicleCrash(THREE,car,{scene:new THREE.Scene(),getState:()=>drive});
 assert.equal(crash.isIdle,true);
 assert.throws(()=>crash.update(NaN));
 crash.state.radiator=0;crash.state.engine=.7;crash.state.active=false;
 assert.equal(crash.isIdle,false);
 for(let i=0;i<300;i++)crash.update(1/60);
 assert.ok(crash.state.temperature>.25,'damaged radiator must keep heating after visual settling');
 crash.state.radiator=1;const hot=crash.state.temperature;
 for(let i=0;i<60;i++)crash.update(1/60);
 assert.ok(crash.state.temperature<hot,'cooling also continues without moving geometry');
 crash.dispose();
});
const front=(speed=12)=>({point:{x:0,y:.9,z:2.15},normal:{x:0,y:0,z:1},impactSpeed:speed,slideSpeed:0});
function fixture({damage=false,tyres=false,trunk=false}={}){
  const scene=new THREE.Scene(),car=createDemoCar(THREE,TestBox);scene.add(car.object);
  const trunkController=trunk?createVehicleTrunk(THREE,TestBox,car,{scene}):null;
  const geometry=new Map(),materials=new Map();car.object.traverse(mesh=>{if(mesh.isMesh){geometry.set(mesh,mesh.geometry);materials.set(mesh,mesh.material)}});
  const damageController=damage?createVehicleDamage(THREE,car,{scene,getState:()=>state,trunk:trunkController}):null;
  const tyreController=tyres?createTyreDamage(THREE,car):null;
  const crash=damageController?.crash||createVehicleCrash(THREE,car,{scene,getState:()=>state,trunk:trunkController});
  return{scene,car,geometry,materials,damage:damageController,tyres:tyreController,trunk:trunkController,crash,dispose(){damageController?.dispose();crash.dispose();trunkController?.dispose();tyreController?.dispose()}};
}

test('subdivision preserves UVs, normals, vertex colours and per-face material groups',()=>{
  const source=new THREE.BoxGeometry(2,.3,1),p=source.attributes.position;
  const colors=new Float32Array(p.count*3);for(let i=0;i<p.count;i++)colors.set([.2,.4,.6],i*3);source.setAttribute('color',new THREE.Float32BufferAttribute(colors,3));
  const result=subdivideVehicleGeometry(THREE,source,.24,18000);
  assert(result.attributes.position.count>p.count);assert.equal(result.attributes.uv.count,result.attributes.position.count);assert.equal(result.attributes.normal.count,result.attributes.position.count);assert.equal(result.attributes.color.count,result.attributes.position.count);
  let next=0;for(const group of result.groups){assert.equal(group.start,next);assert(group.count>0);assert.equal(group.count%3,0);next+=group.count;assert(group.materialIndex>=0&&group.materialIndex<=5)}assert.equal(next,result.attributes.position.count);
  assert.deepEqual(new Set(result.groups.map(g=>g.materialIndex)),new Set(source.groups.map(g=>g.materialIndex)));
  for(let i=0;i<result.attributes.uv.count;i++){assert(result.attributes.uv.getX(i)>=0&&result.attributes.uv.getX(i)<=1);assert(result.attributes.uv.getY(i)>=0&&result.attributes.uv.getY(i)<=1);close(result.attributes.color.getX(i),.2);close(result.attributes.color.getY(i),.4);close(result.attributes.color.getZ(i),.6)}
  source.dispose();result.dispose();
});

test('normalized artist vertex colours retain their decoded 0..1 values',()=>{
  const source=new THREE.BoxGeometry(.4,.3,.5),p=source.attributes.position,colors=new Uint8Array(p.count*3);for(let i=0;i<p.count;i++)colors.set([51,102,153],i*3);source.setAttribute('color',new THREE.Uint8BufferAttribute(colors,3,true));
  const result=subdivideVehicleGeometry(THREE,source,.24,18000);for(let i=0;i<result.attributes.color.count;i++){close(result.attributes.color.getX(i),.2);close(result.attributes.color.getY(i),.4);close(result.attributes.color.getZ(i),.6)}source.dispose();result.dispose();
});

test('subdivision obeys its bounded triangle budget without dropping any original face',()=>{
  const source=new THREE.BoxGeometry(4,3,5),result=subdivideVehicleGeometry(THREE,source,.01,100);
  assert(result.attributes.position.count/3<=100,'triangle budget cannot be exceeded by queued recursion');assert(result.groups.length>=6);source.dispose();result.dispose();
});

test('real red car crushes visibly, preserves material handles and resets authored geometry',()=>{
  const f=fixture();try{
    const hood=f.car.object.getObjectByName('Hood_lid'),before=new THREE.Box3().setFromObject(hood);assert(f.crash.contactImpact(front(12)));
    const after=new THREE.Box3().setFromObject(hood);assert(after.max.z<before.max.z-.025,'front hood edge compresses in actual geometry');assert.notEqual(hood.geometry,f.geometry.get(hood));
    for(const [mesh,material]of f.materials)assert.equal(mesh.material,material,'undestroyed materials keep exact references');
    assert.equal(f.car.doors.size,4);assert.equal(f.car.interior.parts.seats.length,4);f.crash.reset();
    for(const [mesh,original]of f.geometry)assert(mesh.geometry===original,'repair restores exact authored BufferGeometry: '+mesh.name);
    assert.equal(f.crash.stats().impacts,0);assert.equal(f.crash.stats().debris,0);
  }finally{f.dispose()}
});

test('cached structural cells retain the exact trilinear panel deformation after repeated impacts',()=>{
 const f=fixture();try{
  const hood=f.car.object.getObjectByName('Hood_lid'),source=f.geometry.get(hood).clone();
  assert(f.crash.contactImpact(front(14)));
  assert(f.crash.contactImpact({point:{x:.48,y:.78,z:2.08},normal:{x:.24,y:0,z:.97},impactSpeed:11,slideSpeed:0}));
  const support=subdivideVehicleGeometry(THREE,source,.15,9000),actual=hood.geometry.attributes.position,base=support.attributes.position;
  assert.equal(actual.count,base.count,'cached binding keeps every authored support vertex');
  f.car.object.updateWorldMatrix(true,true);
  const toCar=new THREE.Matrix4().copy(f.car.object.matrixWorld).invert().multiply(hood.matrixWorld),toMesh=new THREE.Matrix3().setFromMatrix4(toCar).invert(),point=new THREE.Vector3(),offset=new THREE.Vector3();
  for(const index of [0,Math.floor(actual.count/3),actual.count-1]){
   point.fromBufferAttribute(base,index).applyMatrix4(toCar);
   const d=sampleCrashDeformation(f.crash.state,point);
   offset.set(d.x,d.y,d.z).applyMatrix3(toMesh);
   close(actual.getX(index),base.getX(index)+offset.x,2e-6);
   close(actual.getY(index),base.getY(index)+offset.y,2e-6);
   close(actual.getZ(index),base.getZ(index)+offset.z,2e-6);
  }
  support.dispose();
 }finally{f.dispose()}
});

test('pristine crash adapters skip the structural solver without changing state',()=>{
  const f=fixture();try{
    const before=structuredClone(f.crash.state);for(let i=0;i<600;i++)f.crash.update(1/60);
    assert.deepEqual(f.crash.state,before);assert.equal(f.crash.stats().idleUpdates,600);
  }finally{f.dispose()}
});

test('real assemblies detach once, move independently of car, persist and reset',()=>{
  const f=fixture();try{
    const hood=f.car.object.getObjectByName('Hood_lid');assert(f.crash.contactImpact(front(24)));assert.equal(hood.visible,false);assert(f.crash.stats().detached.includes('hood'));assert(f.crash.stats().debris>=1);
    const fragment=f.crash.root.children.find(node=>node.name==='Hood_lid');assert(fragment);assert.notEqual(fragment.geometry,hood.geometry);assert.notEqual(fragment.material,hood.material);
    const count=f.crash.stats().debris;assert.equal(f.crash.detach('hood',front(24)),false);assert.equal(f.crash.stats().debris,count);
    const before=fragment.getWorldPosition(new THREE.Vector3());f.car.object.position.set(200,0,120);f.crash.update(1/60);assert(fragment.getWorldPosition(new THREE.Vector3()).distanceTo(before)<1);
    for(let i=0;i<1000;i++)f.crash.update(1/60);assert.equal(f.crash.stats().debris,count);const minY=new THREE.Box3().setFromObject(fragment).min.y;assert(minY>=.014,'settled debris lowest vertex: '+minY);
    f.crash.reset();assert.equal(hood.visible,true);assert.equal(f.crash.root.children.length,0);assert.equal(hood.geometry,f.geometry.get(hood));
  }finally{f.dispose()}
});

test('wheel sag is idempotent over 600 frames and composes with puncture drop',()=>{
  const f=fixture({tyres:true});try{
    const wheel=f.car.wheels.find(w=>w.id==='front_left'),restY=wheel.pivot.position.y;
    assert(f.crash.contactImpact({point:{x:.96,y:.43,z:1.3},normal:{x:1,y:0,z:0},impactSpeed:7.5}));
    assert(!f.crash.effects.wheels.front_left.detached);const sag=f.crash.effects.wheels.front_left.sag;assert(sag>.01);
    for(let i=0;i<600;i++){f.car.update(state);f.tyres.update(state,1/60);f.crash.applyWheels({tyres:f.tyres.state})}close(wheel.pivot.position.y,restY-sag);
    assert(f.tyres.hit({object:wheel.tire}));for(let i=0;i<120;i++){f.tyres.update(state,1/60);f.crash.applyWheels({tyres:f.tyres.state})}close(wheel.pivot.position.y,restY-.1-sag);
    f.tyres.reset();f.crash.applyWheels({tyres:f.tyres.state});close(wheel.pivot.position.y,restY-sag);f.crash.reset();close(wheel.pivot.position.y,restY);
  }finally{f.dispose()}
});

test('crash and independent trunk adapters produce one lid, then repair restores it',()=>{
  const f=fixture({trunk:true});try{
    const hit={point:{x:0,y:.9,z:-2.15},normal:{x:0,y:0,z:-1},impactSpeed:24};assert(f.crash.contactImpact(hit));f.trunk.contactImpact(hit,state);f.trunk.update(1/60,{vehicleState:state});
    assert.equal(f.trunk.stats().debris,1);assert.equal(f.crash.root.children.filter(n=>n.name==='Trunk_lid').length,0);assert.equal(f.scene.children.filter(n=>n.name==='Trunk_detached_lid').length,1);
    f.crash.reset();f.trunk.reset();assert.equal(f.trunk.lid.visible,true);assert.equal(f.trunk.stats().debris,0);
  }finally{f.dispose()}
});

function bullet(f,mesh){mesh.updateWorldMatrix(true,true);return f.damage.impact({object:mesh,point:mesh.localToWorld(new THREE.Vector3(0,0,.655)),normal:new THREE.Vector3(0,0,1),damage:40,shotId:'visual-bullet'})}
test('bullet then crash reset restores pristine authored geometry handles',()=>{
  const f=fixture({damage:true});try{
    const hood=f.car.object.getObjectByName('Hood_lid');assert(bullet(f,hood));assert(f.crash.contactImpact(front(10)));f.damage.reset();f.crash.reset();
    for(const [mesh,original]of f.geometry)assert(mesh.geometry===original,'mixed damage repair restores exact authored geometry: '+mesh.name);
  }finally{f.dispose()}
});

test('crash then bullet does not double the structural displacement on rebind',()=>{
  const f=fixture({damage:true});try{
    const hood=f.car.object.getObjectByName('Hood_lid');assert(f.crash.contactImpact(front(10)));for(let i=0;i<240;i++)f.crash.update(1/60);
    const before=new THREE.Box3().setFromObject(hood);assert(bullet(f,hood));const afterBullet=new THREE.Box3().setFromObject(hood);f.crash.state.revision++;f.crash.update(0);
    const afterRebind=new THREE.Box3().setFromObject(hood);assert(afterRebind.min.distanceTo(afterBullet.min)<.012&&afterRebind.max.distanceTo(afterBullet.max)<.012,'geometry replacement must not add the same cage displacement twice');assert(before.max.z<2.14);
  }finally{f.dispose()}
});
