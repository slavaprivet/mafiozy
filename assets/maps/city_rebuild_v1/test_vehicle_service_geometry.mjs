import assert from 'node:assert/strict';
import {readFile} from 'node:fs/promises';
import {pathToFileURL} from 'node:url';
import {registerHooks} from 'node:module';
import {createDemoCar} from './car_drive.mjs';
import {createVehicleHood} from './vehicle_hood.mjs';
import {createVehicleTrunk,stepVehiclePanelMotion} from './vehicle_trunk.mjs';
const vendor=process.env.MAFIOZY_THREE_VENDOR||'D:/codex_release/artist13_hero_first_DEV_20260907/demo/vendor/';
const factoryURL=process.env.MAFIOZY_FLEET_FACTORY?pathToFileURL(process.env.MAFIOZY_FLEET_FACTORY):new URL('./vehicle_fleet_models.mjs',import.meta.url);
const {ARTIST_VEHICLE_PROFILES,createArtistVehicle}=await import(factoryURL);
registerHooks({resolve(s,c,next){return next(s==='three'?pathToFileURL(vendor+'build/three.module.js').href:s,c)}});
const T=await import(pathToFileURL(vendor+'build/three.module.js')),{GLTFLoader}=await import(pathToFileURL(vendor+'addons/loaders/GLTFLoader.js'));
class Box extends T.BoxGeometry{constructor(w,h,d){super(w,h,d)}}
const vehicle={x:0,y:0,z:0,yaw:0,speed:0},failures=[];
for(const fps of [30,60,120,144]){let motion={amount:0,velocity:0};for(let i=0;i<fps;i++)motion=stepVehiclePanelMotion(motion.amount,motion.velocity,1,1/fps);assert.equal(motion.amount,1);assert.equal(motion.velocity,0);for(let i=0;i<fps;i++)motion=stepVehiclePanelMotion(motion.amount,motion.velocity,0,1/fps);assert.equal(motion.amount,0);assert.equal(motion.velocity,0)}
const moving=stepVehiclePanelMotion(0,0,1,.08),reversing=stepVehiclePanelMotion(moving.amount,moving.velocity,0,.001);
assert(reversing.amount>moving.amount&&reversing.velocity>0,'reversal retains momentum instead of snapping the hinge velocity');
let settling=reversing;for(let i=0;i<120;i++){settling=stepVehiclePanelMotion(settling.amount,settling.velocity,0,1/120);assert(settling.amount>=0&&settling.amount<=1)}assert.equal(settling.amount,0);
const fixtures=[{id:'red_demo',create:async()=>createDemoCar(T,Box)},...ARTIST_VEHICLE_PROFILES.map(profile=>({id:profile.id,create:async()=>{const b=await readFile(new URL('./models/artist_vehicle_pack/'+profile.modelFile,import.meta.url)),g=await new GLTFLoader().parseAsync(b.buffer.slice(b.byteOffset,b.byteOffset+b.byteLength),'');return createArtistVehicle(T,Box,g,profile)}}))];
for(const fixture of fixtures){
 const car=await fixture.create(),scene=new T.Scene();scene.add(car.object);const trunk=createVehicleTrunk(T,Box,car,{scene}),hood=createVehicleHood(T,Box,car,{scene});
 const fail=message=>{if(!failures.some(f=>f.id===fixture.id&&f.message===message))failures.push({id:fixture.id,message})};
 try{
  car.object.updateWorldMatrix(true,true);
  for(const part of hood.bay.children.filter(n=>n.isMesh&&!/Engine_smoke|Hood_support/.test(n.name))){
   const name=part.name,bounds=new T.Box3().setFromObject(part),point=bounds.getCenter(new T.Vector3());point.y=bounds.max.y;
   if(hood.profile.front){const origin=point.clone();origin.y=Math.max(bounds.max.y,hood.profile.handleY)+2;const cover=new T.Raycaster(origin,new T.Vector3(0,-1,0),0,5).intersectObject(hood.lid,true)[0];if(cover&&point.y>cover.point.y-.005)fail('closed hood clearance '+name+' protrudes '+(point.y-cover.point.y).toFixed(4)+'m')}
   else{const origin=bounds.getCenter(new T.Vector3());origin.z=hood.profile.accessZ-1;const cover=new T.Raycaster(origin,new T.Vector3(0,0,1),0,5).intersectObject(hood.lid,true)[0];if(cover&&bounds.min.z<cover.point.z+.005)fail('closed rear hatch clearance '+name+' protrudes '+(cover.point.z-bounds.min.z).toFixed(4)+'m')}
   for(const seat of car.interior.parts.seats){const seatBox=new T.Box3().setFromObject(seat);if(bounds.intersectsBox(seatBox))fail(name+' overlaps seat '+seat.name)}
  }
  const b=trunk.cargoBounds;if(!b){fail('no cargoBounds');continue}
  const size=b.max.map((v,i)=>v-b.min[i]);if(size.some(v=>v<.32)){fail('cargo cannot accept .30m cube with clearance: '+JSON.stringify(size));continue}
  const closedSolids=[];car.object.traverse(mesh=>{if(!mesh.isMesh||mesh.material?.transparent)return;for(let n=mesh;n;n=n.parent)if(!n.visible)return;const geometry=mesh.geometry,index=geometry.index,p=geometry.attributes.position,positions=[],v=new T.Vector3();for(let i=0;i<(index?.count||p.count);i++){v.fromBufferAttribute(p,index?index.getX(i):i).applyMatrix4(mesh.matrixWorld);positions.push(v.x,v.y,v.z)}closedSolids.push({name:mesh.name,bounds:new T.Box3().setFromObject(mesh),positions})});
  const samples=b.min.map((v,i)=>[v+.165,(v+b.max[i])*.5,b.max[i]-.165]),triangle=new T.Triangle(),aVertex=new T.Vector3(),bVertex=new T.Vector3(),cVertex=new T.Vector3();let closedBlocker=null;
  const freeVolume=new T.Box3(new T.Vector3(...b.min).addScalar(.003),new T.Vector3(...b.max).subScalar(.003));
  volume:for(const mesh of closedSolids){if(!freeVolume.intersectsBox(mesh.bounds))continue;for(let i=0;i<mesh.positions.length;i+=9){triangle.set(aVertex.fromArray(mesh.positions,i),bVertex.fromArray(mesh.positions,i+3),cVertex.fromArray(mesh.positions,i+6));if(freeVolume.intersectsTriangle(triangle)){fail('declared CLOSED free volume intersects '+mesh.name);break volume}}}
  outer:for(const x of samples[0])for(const y of samples[1])for(const z of samples[2]){const cube=new T.Box3(new T.Vector3(x-.15,y-.15,z-.15),new T.Vector3(x+.15,y+.15,z+.15));for(const mesh of closedSolids){if(!cube.intersectsBox(mesh.bounds))continue;for(let i=0;i<mesh.positions.length;i+=9){triangle.set(aVertex.fromArray(mesh.positions,i),bVertex.fromArray(mesh.positions,i+3),cVertex.fromArray(mesh.positions,i+6));if(cube.intersectsTriangle(triangle)){closedBlocker=mesh.name+' at '+JSON.stringify([x,y,z]);break outer}}}}
  if(closedBlocker)fail('declared CLOSED cargo cube intersects '+closedBlocker);
  const position=[(b.min[0]+b.max[0])/2,b.min[1]+.17,(b.min[2]+b.max[2])/2],half=[.15,.15,.15];
  if(!trunk.containsItem(position,half))fail('cube rejected by containment');if(trunk.acceptsItem(position,half))fail('closed cargo accepts insertion');
  const hero={x:0,y:0,z:trunk.profile.rearZ-.65},hoodHero={x:hood.profile.accessSide||0,y:0,z:hood.profile.accessZ+(hood.profile.front?1:-1)*.65};
  assert(trunk.toggle({hero,vehicleState:vehicle}).accepted);assert(hood.toggle({hero:hoodHero,vehicleState:vehicle}).accepted);
  for(let i=0;i<60;i++){trunk.update(1/60,{vehicleState:vehicle});hood.update(1/60,{vehicleState:vehicle})}
  for(const controller of [trunk,hood])assert(Math.abs(controller.hinge.rotation.x)>=Math.PI*79.9/180&&Math.abs(controller.hinge.rotation.x)<=Math.PI*85.1/180,'service panel opens through 80–85 degrees');
  if(!trunk.acceptsItem(position,half))fail('open cargo rejects cube');if(trunk.containsItem(position,[5,5,5]))fail('oversized cargo accepted');
  car.object.updateWorldMatrix(true,true);const solids=[];car.object.traverse(mesh=>{if(!mesh.isMesh||mesh.material?.transparent)return;for(let n=mesh;n;n=n.parent)if(!n.visible)return;solids.push(mesh)});
  let obstruction=null;
  for(let axis=0;axis<3&&!obstruction;axis++)for(const a of [-.12,0,.12])for(const c of [-.12,0,.12]){const values=[...position];values[axis]-=.15;values[(axis+1)%3]+=a;values[(axis+2)%3]+=c;const direction=new T.Vector3();direction.setComponent(axis,1);const hit=new T.Raycaster(new T.Vector3(...values),direction,.002,.298).intersectObjects(solids,false)[0];if(hit){obstruction=hit.object.name;break}}
  if(obstruction)fail('cargo .30m cube intersects '+obstruction);
  const floorStart=new T.Vector3(position[0],position[1],position[2]),floor=new T.Raycaster(floorStart,new T.Vector3(0,-1,0),0,.35).intersectObjects(solids,false)[0];
  if(!floor||Math.abs(floor.point.y-b.min[1])>.07)fail('missing physical cargo floor: '+floor?.object.name+' at '+floor?.point.y+' expected '+b.min[1]);
  const entranceHits=new Set();
  const raisedLid=new T.Box3().setFromObject(trunk.lid);
  for(const a of [-.15,0,.15])for(const c of [-.15,0,.15]){
   const top=trunk.profile.mode==='trunk',start=top?new T.Vector3(position[0]+a,Math.max(b.max[1],raisedLid.max.y)+.22,b.min[2]+.155+c):new T.Vector3(position[0]+a,position[1]+c,trunk.profile.rearZ-.25),direction=top?new T.Vector3(0,-1,0):new T.Vector3(0,0,1),distance=top?start.y-(position[1]+.15):position[2]-.15-start.z;
   if(distance<=0)continue;const hit=new T.Raycaster(start,direction,.002,distance).intersectObjects(solids,false)[0];if(hit){if(process.env.MAFIOZY_SERVICE_DEBUG&&!entranceHits.has(hit.object.name)){const parents=[];for(let n=hit.object.parent;n;n=n.parent)parents.push(n.name);console.error(JSON.stringify({id:fixture.id,apertureBlocker:hit.object.name,point:hit.point,parents}))}entranceHits.add(hit.object.name)}
  }
  if(entranceHits.size)fail('cargo aperture blocked for .30m cube by '+[...entranceHits].join(','));
  const cubeBox=new T.Box3(new T.Vector3(...position).subScalar(.15),new T.Vector3(...position).addScalar(.15));for(const seat of car.interior.parts.seats)if(cubeBox.intersectsBox(new T.Box3().setFromObject(seat)))fail('cargo overlaps seat '+seat.name);
  assert(trunk.cargoColliders.some(c=>c.role==='floor'));assert(trunk.cargoColliders.filter(c=>c.role==='wall').length>=3);
  car.object.position.set(25,2,-17);car.object.rotation.y=Math.PI*.5;car.object.updateWorldMatrix(true,true);const local=new T.Vector3(...position),world=trunk.toCargoWorld(local),roundTrip=trunk.toCargoLocal(world);assert(roundTrip.distanceTo(local)<1e-6);assert(trunk.containsItem(world,half,{world:true}));assert.equal(trunk.worldCargoBounds().corners.length,8);assert(trunk.worldCargoColliders().every(c=>c.quaternion.length===4&&c.center.every(Number.isFinite)));
  console.log(JSON.stringify({id:fixture.id,cargoSize:size,hoodDegrees:Math.abs(hood.hinge.rotation.x)*180/Math.PI,trunkDegrees:Math.abs(trunk.hinge.rotation.x)*180/Math.PI,issues:failures.filter(f=>f.id===fixture.id)}));
 }catch(error){fail(error.message)}finally{hood.dispose();trunk.dispose()}
}
assert.equal(failures.length,0,JSON.stringify(failures));console.log('PASS all13 true cargo .30m placement/aperture/floor, seats separation, OBB transforms, closed-hood clearance and damped access animation');
