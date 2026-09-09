import assert from 'node:assert/strict';
import {readFile} from 'node:fs/promises';
import {pathToFileURL} from 'node:url';
import {registerHooks} from 'node:module';
import {createDemoCar,CAR} from './car_drive.mjs';
import {ARTIST_VEHICLE_PROFILES,createArtistVehicle} from './vehicle_fleet_models.mjs';
import {createVehicleCrash} from './vehicle_crash.mjs';
import {createTyreDamage} from './tyre_damage.mjs';
const vendor=process.env.MAFIOZY_THREE_VENDOR||'D:/codex_release/artist13_hero_first_DEV_20260907/demo/vendor/';
registerHooks({resolve(s,c,next){return next(s==='three'?pathToFileURL(vendor+'build/three.module.js').href:s,c)}});
const T=await import(pathToFileURL(vendor+'build/three.module.js')),{GLTFLoader}=await import(pathToFileURL(vendor+'addons/loaders/GLTFLoader.js')),{RoundedBoxGeometry}=await import('../../../tools/vehicle_fleet_qa/RoundedBoxGeometry.mjs');
const fixtures=[{id:'red_demo',create:async()=>{const car=createDemoCar(T,RoundedBoxGeometry);car.wheelSourceBudget={meshes:28,triangles:816};return car}},...ARTIST_VEHICLE_PROFILES.map(p=>({id:p.id,create:async()=>{const bytes=await readFile(new URL('./models/artist_vehicle_pack/'+p.modelFile,import.meta.url)),source=await new GLTFLoader().parseAsync(bytes.buffer.slice(bytes.byteOffset,bytes.byteOffset+bytes.byteLength),'');const wheelSourceBudget={meshes:0,triangles:0};source.scene.getObjectByName('LOD0_'+p.id).traverse(n=>{if(n.isMesh&&/_Wheel_/.test(n.name)){wheelSourceBudget.meshes++;wheelSourceBudget.triangles+=(n.geometry.index?.count||n.geometry.attributes.position.count)/3}});const car=createArtistVehicle(T,RoundedBoxGeometry,source,p);car.wheelSourceBudget=wheelSourceBudget;return car}}))];
const approx=(a,b,eps=1e-6)=>assert.ok(Math.abs(a-b)<=eps,`${a} != ${b}`),issues=[],types=new Set(),budget={beforeMeshes:0,beforeTriangles:0,wheelMeshes:0,wheelTriangles:0,archMeshes:0,archTriangles:0};
function clipX(poly,limit,sign){const out=[];for(let i=0;i<poly.length;i++){const a=poly[i],b=poly[(i+1)%poly.length],da=(a.x-limit)*sign,db=(b.x-limit)*sign;if(da>=0)out.push(a);if((da>=0)!==(db>=0))out.push(a.clone().lerp(b,da/(da-db)))}return out}
function radialMin(poly){
 let min=Infinity,positive=false,negative=false,area=0;
 for(let i=0;i<poly.length;i++){const a=poly[i],b=poly[(i+1)%poly.length],dy=b.y-a.y,dz=b.z-a.z,t=Math.max(0,Math.min(1,-(a.y*dy+a.z*dz)/(dy*dy+dz*dz||1)));min=Math.min(min,Math.hypot(a.y+t*dy,a.z+t*dz));const cross=a.y*b.z-a.z*b.y;area+=cross;positive||=cross>1e-9;negative||=cross< -1e-9}
 return Math.abs(area)<1e-9||positive&&negative?min:0;
}
for(const fixture of fixtures){
 const car=await fixture.create(),scene=new T.Scene();scene.add(car.object);car.object.updateMatrixWorld(true);
 const fail=message=>issues.push({id:fixture.id,message});
 try{
  assert.equal(car.wheels.length,4);const neutral=car.wheels.map(w=>w.pivot.position.clone());
  types.add(car.wheels[0].wheel.userData.wheelType);
  budget.beforeMeshes+=car.wheelSourceBudget.meshes;budget.beforeTriangles+=car.wheelSourceBudget.triangles;
  car.object.traverse(n=>{if(!n.isMesh)return;const triangles=(n.geometry.index?.count||n.geometry.attributes.position.count)/3;if(n.userData.vehicleWheelId){budget.wheelMeshes++;budget.wheelTriangles+=triangles}else if(n.userData.wheelArchFor){budget.archMeshes++;budget.archTriangles+=triangles}});
  for(const w of car.wheels){
   assert(w.hub&&w.tire.parent===w.wheel);assert(w.wheel.parent===w.pivot);assert(w.nominalWidth>0);approx(w.nominalRollingRadius,car.profile?.wheelRadius||CAR.wheelRadius);
   const arch=car.object.getObjectByName('Wheel_arch_'+w.id),archBox=new T.Box3().setFromObject(arch),side=Math.sign(w.pivot.position.x),lip=arch.getObjectByName('Wheel_arch_lip_'+w.id),archRay=new T.Raycaster(new T.Vector3(side*(Math.max(Math.abs(archBox.min.x),Math.abs(archBox.max.x))+.2),w.pivot.position.y+arch.userData.wheelArchEnvelope.radius+.012,w.pivot.position.z),new T.Vector3(-side,0,0),0,2);
   assert(archRay.intersectObject(lip).length,'both mirrored painted arch lips have outward-facing surfaces');
   const radius=w.nominalRollingRadius,half=w.nominalWidth*.5,inverse=w.wheel.matrixWorld.clone().invert(),v=new T.Vector3();let radialMax=0,axialMax=0;
   w.wheel.traverse(n=>{if(!n.isMesh)return;assert(n.userData.vehicleWheelId===w.id);const p=n.geometry.attributes.position;for(let i=0;i<p.count;i++){v.fromBufferAttribute(p,i).applyMatrix4(n.matrixWorld).applyMatrix4(inverse);assert(v.toArray().every(Number.isFinite));radialMax=Math.max(radialMax,Math.hypot(v.y,v.z));axialMax=Math.max(axialMax,Math.abs(v.x))}});
   approx(radialMax,radius,.002);assert(axialMax<=half+.002,'new rims/tyres retain the authored width');
   let solid=0,gaps=0;for(let i=0;i<80;i++){const a=i*Math.PI/40,aperture=w.nominalRimRadius*w.wheel.userData.apertureRatio,local=new T.Vector3(Math.sign(w.pivot.position.x)*(half+.1),Math.sin(a)*aperture,Math.cos(a)*aperture),dir=new T.Vector3(-Math.sign(w.pivot.position.x),0,0);const hits=new T.Raycaster(w.wheel.localToWorld(local),dir.transformDirection(w.wheel.matrixWorld),0,w.nominalWidth+.2).intersectObject(w.wheel,true);if(hits.length)solid++;else gaps++}assert(solid>=8&&gaps>=8,'metal and genuinely open rim apertures are both present');
   const grounded=new T.Box3().setFromObject(w.tire);assert(grounded.min.y>=-.003&&grounded.min.y<=.010,`${w.id} tyre must visibly touch flat road, bottom ${grounded.min.y}`);
   const initial=w.wheel.rotation.x;car.update({distance:radius*.5,steer:0});approx(w.wheel.rotation.x-initial,.5);car.update({distance:-radius*.5,steer:0});approx(w.wheel.rotation.x,initial);
  }
  const spin=car.wheels.map(w=>w.wheel.rotation.x);car.update({distance:.4,steer:.56,handbrake:true});for(const [i,w]of car.wheels.entries()){approx(w.pivot.rotation.y,w.front?.56:0);approx(w.wheel.rotation.x-spin[i],w.front?.4/w.rollingRadius:0)}car.update({distance:0,steer:0});
  const solids=[];car.object.traverse(n=>{if(!n.isMesh||n.material?.transparent)return;for(let p=n;p;p=p.parent)if(p.userData.vehicleWheelId||!p.visible)return;solids.push(n)});
  // Exact triangle clipping to the actual steered wheel axle slab, then the
  // nearest point in its YZ projection. The radius is 8mm inside the tyre skin
  // so harmless rounded-edge numerical contacts are not reported as intrusion.
  for(const steer of [-.56,0,.56]){
   car.update({distance:0,steer});car.object.updateMatrixWorld(true);
   for(const w of car.wheels){const inverse=w.pivot.matrixWorld.clone().invert(),r=w.nominalRollingRadius-.008,half=w.nominalWidth*.5-.008,broad=new T.Box3(new T.Vector3(-half,-r,-r),new T.Vector3(half,r,r));
    for(const mesh of solids){const matrix=inverse.clone().multiply(mesh.matrixWorld),g=mesh.geometry;g.computeBoundingBox();if(!broad.intersectsBox(g.boundingBox.clone().applyMatrix4(matrix)))continue;const a=g.attributes.position,index=g.index;let intrusion=false;
     for(let j=0;j<(index?.count||a.count);j+=3){let poly=Array.from({length:3},(_,k)=>new T.Vector3().fromBufferAttribute(a,index?index.getX(j+k):j+k).applyMatrix4(matrix));poly=clipX(clipX(poly,-half,1),half,-1);if(poly.length>=3&&radialMin(poly)<r){intrusion=true;break}}
     if(intrusion)fail(`${w.id} steer ${steer}: tyre envelope intersects ${mesh.name||mesh.uuid}`);
    }
   }
  }
  car.update({distance:0,steer:0});
  const tyre=createTyreDamage(T,car);for(const w of car.wheels)assert(tyre.hit({object:w.tire}));tyre.update({distance:0,yaw:0,speed:0},2);tyre.update({distance:61,yaw:0,speed:10},.1);for(const w of car.wheels){assert(!w.tire.visible);approx(w.rollingRadius,w.nominalRimRadius)}tyre.reset();for(const [i,w]of car.wheels.entries()){approx(w.rollingRadius,w.nominalRollingRadius);assert(w.tire.visible);approx(w.pivot.position.distanceTo(neutral[i]),0)}tyre.dispose();
  const crash=createVehicleCrash(T,car,{scene});for(const w of car.wheels){const names=[];w.pivot.traverse(n=>{if(n.isMesh)names.push(n.name)});assert(crash.detach('wheel_'+w.id,{impactSpeed:18,normal:{x:1,y:0,z:0}}));const copy=crash.root.children.at(-1),copied=[];copy.traverse(n=>{if(n.isMesh)copied.push(n.name)});assert.deepEqual(copied,names,'the entire physical rim/tyre/bolts detach together');assert(!w.pivot.visible)}crash.reset();assert.equal(crash.root.children.length,0);for(const [i,w]of car.wheels.entries()){assert(w.pivot.visible&&w.tire.visible);approx(w.pivot.position.distanceTo(neutral[i]),0)}crash.dispose();
  console.log(JSON.stringify({id:fixture.id,wheels:4,issues:[...new Set(issues.filter(i=>i.id===fixture.id).map(i=>i.message.replace(/ steer [-.\d]+:/,':')))]}));
 }catch(error){fail(error.message)}
}
console.log(JSON.stringify({budget,types:[...types]}));assert.equal(types.size,13,'every vehicle has a distinct actual rim type');assert.equal(issues.length,0,JSON.stringify(issues));console.log('PASS all13: 52 recessed rims, real tyre geometry, authored radii/track, forward/reverse/steering/handbrake, wheel-arch sweep and complete detach/reset');
