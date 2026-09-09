import test from 'node:test';
import assert from 'node:assert/strict';
import {pathToFileURL} from 'node:url';
import {createDemoCar} from './car_drive.mjs';
import {createVehicleHood} from './vehicle_hood.mjs';
import {createVehicleDamage} from './vehicle_damage.mjs';
import {sampleCrashDeformation} from './vehicle_crash_mechanics.mjs';
const T=await import(pathToFileURL(process.env.MAFIOZY_THREE||'D:/codex_release/artist13_hero_first_DEV_20260907/demo/vendor/build/three.module.js'));
class Box extends T.BoxGeometry{constructor(w,h,d){super(w,h,d)}}
const vehicle={x:0,y:0,z:0,yaw:0,speed:0};
function fixture(){
 const scene=new T.Scene(),car=createDemoCar(T,Box);scene.add(car.object);
 const hood=createVehicleHood(T,Box,car,{scene});car.hood=hood;
 const damage=createVehicleDamage(T,car,{scene,getState:()=>vehicle});
 const update=dt=>hood.update(dt,{vehicleState:vehicle,damageState:damage.state,crashState:damage.crash.state});
 return{car,hood,damage,update,context:{hero:{x:0,y:0,z:hood.profile.accessZ+.65},vehicleState:vehicle,damage},dispose(){damage.dispose();hood.dispose()}};
}
const close=(a,b,message)=>assert(a.distanceTo(b)<1e-7,message+': '+a.toArray()+' vs '+b.toArray());
const world=node=>node.getWorldPosition(new T.Vector3());
function sample(f){const b=f.hood.bay.userData.engineBounds;return new T.Vector3(...Object.values(sampleCrashDeformation(f.damage.crash.state,{x:(b.min[0]+b.max[0])/2,y:(b.min[1]+b.max[1])/2,z:(b.min[2]+b.max[2])/2})))}

test('front18 moves rigid engine, radiator, hoses, cavity and smoke with the actual crushed cage, without drift or vertex edits',()=>{
 const f=fixture();try{
  const parts=f.hood.bay.children.filter(mesh=>!mesh.name.startsWith('Engine_smoke')&&!mesh.name.startsWith('Hood_support'));
  const before=new Map(parts.map(mesh=>[mesh,{position:world(mesh),geometry:mesh.geometry,vertices:[...mesh.geometry.attributes.position.array]}]));
  const hinge=f.hood.hinge.position.clone();assert.equal(f.hood.stats().engineParts,49);
  assert(f.damage.crash.contactImpact({point:{x:0,y:.9,z:2.15},normal:{x:0,y:0,z:1},impactSpeed:18}));
  f.update(1/60);const offset=sample(f);assert(offset.z<-.05,'front crash pushes engine rearward');close(f.hood.bay.position,offset,'mount follows cage');
  for(const [mesh,rest]of before){close(world(mesh),rest.position.clone().add(offset),mesh.name+' rigid displacement');assert.equal(mesh.geometry,rest.geometry);assert.deepEqual([...mesh.geometry.attributes.position.array],rest.vertices)}
  close(f.hood.hinge.position,hinge,'hood hinge is independent');assert(f.hood.stats().smokeParticles>0);
  const smoke=f.hood.bay.getObjectByName('Engine_smoke_0');close(world(smoke).sub(smoke.position),offset,'smoke emitter inherits same offset');
  for(let i=0;i<600;i++)f.update(1/60);close(f.hood.bay.position,offset,'no accumulated translation');
  const damagedNodes=JSON.stringify(f.damage.crash.state.nodes);assert(f.hood.repair(f.context).accepted);f.update(1/60);
  close(f.hood.bay.position,offset,'roadside engine repair retains crushed mount');assert.equal(JSON.stringify(f.damage.crash.state.nodes),damagedNodes);assert.equal(f.hood.stats().smokeParticles,0);
  f.update(1/60);close(f.hood.bay.position,offset,'cooled detached hood idle retains mount');
  f.damage.reset();f.update(1/60);close(f.hood.bay.position,new T.Vector3(),'full reset restores mount');
  for(const [mesh,rest]of before)close(world(mesh),rest.position,mesh.name+' reset position');
 }finally{f.dispose()}
});

test('healthy idle preserves pristine pose and mesh ownership for 600 frames',()=>{
 const f=fixture();try{
  const before=f.hood.bay.children.map(mesh=>({mesh,position:mesh.position.clone(),geometry:mesh.geometry,scale:mesh.scale.clone()}));
  for(let i=0;i<600;i++)f.update(1/60);
  close(f.hood.bay.position,new T.Vector3(),'healthy mount');assert.equal(f.hood.stats().idleUpdates,600);assert.equal(f.hood.stats().engineParts,49);
  for(const {mesh,position,geometry,scale}of before){close(mesh.position,position,mesh.name+' position');close(mesh.scale,scale,mesh.name+' scale');assert.equal(mesh.geometry,geometry)}
 }finally{f.dispose()}
});

test('open support struts retain lid endpoints while engine-bay mounting bases move in a translated rotated car',()=>{
 const f=fixture();try{
  assert(f.hood.toggle(f.context).accepted);for(let i=0;i<60;i++)f.update(1/60);
  f.car.object.position.set(13,2,-7);f.car.object.rotation.y=.8;f.car.object.updateMatrixWorld(true);
  const struts=f.hood.bay.children.filter(mesh=>mesh.name==='Hood_support_strut');
  const ends=mesh=>[-.5,.5].map(y=>mesh.localToWorld(new T.Vector3(0,y,0)));
  const before=struts.map(ends),hingeQ=f.hood.hinge.quaternion.clone();
  // Uniform finite cage displacement isolates attachment coordinates from rupture.
  for(const node of f.damage.crash.state.nodes){node.position.x+=.08;node.position.y-=.03;node.position.z-=.20}
  f.update(0);f.car.object.updateMatrixWorld(true);const delta=new T.Vector3(.08,-.03,-.20).applyQuaternion(f.car.object.quaternion);
  for(let i=0;i<struts.length;i++){const after=ends(struts[i]);close(after[0],before[i][0].clone().add(delta),'strut base follows mount');close(after[1],before[i][1],'strut tip stays on hood')}
  assert(f.hood.hinge.quaternion.equals(hingeQ));
 }finally{f.dispose()}
});
