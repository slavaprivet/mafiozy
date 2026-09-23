// Bounded CPU-only correctness/census. No renderer, GPU or timing loops.
import assert from 'node:assert/strict';
import fs from 'node:fs';
import {registerHooks} from 'node:module';
import {pathToFileURL} from 'node:url';
import {createVehicleRenderBatches,getVehicleRenderSourceMaterial} from './vehicle_render_batches.mjs';
import {ARTIST_VEHICLE_PROFILES,createArtistVehicle} from './vehicle_fleet_models.mjs';
const vendor=process.env.THREE_VENDOR_ROOT||'D:/codex_release/artist13_hero_first_DEV_20260907/demo/vendor';
registerHooks({resolve(s,c,next){return next(s==='three'?pathToFileURL(vendor+'/build/three.module.js').href:s,c);}});
const T=await import(pathToFileURL(vendor+'/build/three.module.js'));
const {GLTFLoader}=await import(pathToFileURL(vendor+'/addons/loaders/GLTFLoader.js'));
const {RoundedBoxGeometry}=await import('../../../tools/vehicle_fleet_qa/RoundedBoxGeometry.mjs');
const whitelist=/^(?:(?:Headlamp_housing|Front_bumper_bracket|Rear_bumper_bracket|Rear_corner_lamp_mount|Engine_bay_sidewall)_(?:-1|1)|Engine_bay_firewall)$/;
const names=['Headlamp_housing_-1','Headlamp_housing_1','Front_bumper_bracket_-1'];
const fixtureMesh=(root,material,name)=>{const mesh=new T.Mesh(new T.BoxGeometry(.3,.2,.1),material);mesh.name=name;mesh.userData.assembledBody=true;mesh.castShadow=mesh.receiveShadow=true;root.add(mesh);return mesh;};
function setup(){const root=new T.Group(),material=new T.MeshStandardMaterial(),meshes=names.map((name,i)=>{const mesh=fixtureMesh(root,material,name);mesh.position.x=i;return mesh;});return{root,material,meshes};}
const make=f=>createVehicleRenderBatches({THREE:T,root:f.root,includeBody:true});
const fixtureBatches=root=>root.children.filter(n=>n.userData.vehicleFixtureRenderBatch);
let tests=0,vertices=0;const reports=[];
function test(name,body){body();tests++;console.log('PASS '+name);}
test('fixture lane keeps legacy same-material batch independent; capability and runtime toggle restore sources',()=>{
 const f=setup();for(let i=0;i<2;i++)fixtureMesh(f.root,f.material,'Static_body_'+i);
 const helper=make(f),batches=fixtureBatches(f.root);assert.equal(helper.stats.fixtureMembers,3);assert.equal(helper.stats.fixtureBatches,1);assert.equal(batches.length,1);assert.equal(batches[0].instanceCount,3);assert.equal(helper.stats.batches,2);
 for(const mesh of f.meshes){assert.equal(getVehicleRenderSourceMaterial(mesh),f.material);assert.equal(mesh.material.visible,false);}
 helper.setDetailOptimizationEnabled(false);assert.equal(batches[0].visible,false);for(const mesh of f.meshes)assert.equal(mesh.material,f.material);
 helper.setDetailOptimizationEnabled(true);assert.equal(batches[0].visible,true);assert.equal(helper.stats.fallbackMembers,0);helper.dispose();helper.dispose();for(const mesh of f.meshes)assert.equal(mesh.material,f.material);
 const disabled=createVehicleRenderBatches({THREE:T,root:f.root,includeBody:true,detailOptimization:false});assert.equal(disabled.stats.fixtureBatches,0);assert.equal(disabled.stats.fixtureMembers,0);assert.equal(disabled.setDetailOptimizationEnabled(true),false);for(const mesh of f.meshes)assert.equal(mesh.material,f.material);disabled.dispose();
 const noBody=createVehicleRenderBatches({THREE:T,root:f.root});assert.equal(noBody.stats.fixtureBatches,0);noBody.dispose();
});
const initialGuards=[
 ['missing assembledBody',m=>{delete m.userData.assembledBody;}],['nonboolean assembledBody',m=>{m.userData.assembledBody=1;}],
 ['unlisted suffix',m=>{m.name='Headlamp_housing_2';}],['generic lamp',m=>{m.name='Headlamp';}],
 ...['damagePart','detached','vehicleDoorId','vehicleWheelId'].map(key=>[key,m=>{m.userData[key]=true;}]),
 ['nested in otherwise-static owner',(m,f)=>{const group=new T.Group();f.root.add(group);group.add(m);}],
 ['transparent',m=>{m.material=m.material.clone();m.material.transparent=true;}],
 ['transmissive',m=>{m.material=m.material.clone();m.material.transmission=.5;}],
 ['material array',m=>{m.material=[m.material];}],['different material identity',m=>{m.material=m.material.clone();}],
 ['layout mismatch',m=>{m.geometry.setAttribute('color',new T.Float32BufferAttribute(new Float32Array(m.geometry.attributes.position.count*3),3));}],
 ['morph geometry',m=>{m.geometry.morphAttributes.position=[m.geometry.attributes.position.clone()];}],
 ['draw range',m=>{m.geometry.setDrawRange(0,3);}],['negative determinant',m=>{m.scale.x=-1;}],
 ['breakable glass',m=>{m.userData.breakableGlass=true;}]
];
for(const [label,mutate]of initialGuards)test('creation exclusion: '+label,()=>{const f=setup();mutate(f.meshes[0],f);const before=f.meshes[0].material,helper=make(f);assert.equal(helper.stats.fixtureMembers,2);assert.equal(f.meshes[0].material,before);helper.dispose();});
for(const [label,mutate]of [
 ...initialGuards.filter(([name])=>!['transparent','transmissive','material array','different material identity','morph geometry','breakable glass'].includes(name)),
 ['rename to benign nonfixture',m=>{m.name='Static_body';}],
 ['material replacement',m=>{m.material=getVehicleRenderSourceMaterial(m).clone();}],
 ['geometry replacement',m=>{m.geometry=m.geometry.clone();}],
 ['buffer version',m=>{m.geometry.attributes.position.needsUpdate=true;}],
 ...['castShadow','receiveShadow'].map(key=>[key,m=>{m[key]=!m[key];}]),
 ['layers',m=>m.layers.set(2)],['renderOrder',m=>{m.renderOrder++;}]
])test('runtime fallback: '+label,()=>{
 const f=setup(),helper=make(f);mutate(f.meshes[0],f);helper.update();assert.equal(helper.stats.fallbackMembers,1);assert.equal(helper.stats.activeMembers,2);assert.equal(f.meshes[0].material.visible,true);helper.dispose();
});
test('visibility and transforms remain live without losing ownership; off-toggle mutations also fall back',()=>{
 const f=setup(),helper=make(f),batch=fixtureBatches(f.root)[0],mesh=f.meshes[0],sourceGeometry=mesh.geometry,sourceRaycast=mesh.raycast;
 mesh.visible=false;helper.update();assert.equal(helper.stats.activeMembers,2);mesh.visible=true;mesh.position.z=.5;helper.update();assert.equal(helper.stats.activeMembers,3);assert.equal(helper.stats.fallbackMembers,0);assert.equal(mesh.geometry,sourceGeometry);assert.equal(mesh.raycast,sourceRaycast);
 const matrix=new T.Matrix4();batch.getMatrixAt(0,matrix);assert.equal(matrix.elements[14],.5);
 helper.setDetailOptimizationEnabled(false);mesh.userData.damagePart=true;helper.setDetailOptimizationEnabled(true);assert.equal(helper.stats.fallbackMembers,1);assert.equal(mesh.material,f.material);helper.dispose();
});
test('canonical material changes remain live; hidden-proxy changes preserve existing fallback semantics',()=>{
 const f=setup(),helper=make(f),batch=fixtureBatches(f.root)[0];f.material.color.set('#426193');helper.update();assert.equal(batch.material,f.material);assert.equal(helper.stats.fallbackMembers,0);
 f.root.updateMatrixWorld(true);const hits=new T.Raycaster(new T.Vector3(0,0,2),new T.Vector3(0,0,-1)).intersectObject(f.meshes[0],false);assert(hits.length>0,'original hidden-material mesh retains raycast');
 const hidden=f.meshes[0].material;hidden.color.set('#813254');helper.update();assert.equal(helper.stats.fallbackMembers,3);assert(f.meshes.every(m=>m.material===hidden&&m.material.visible));helper.dispose();
});
// Disable only this whitelist in memory to reproduce the preceding draw path;
// all legacy and arch batching remains enabled. No production files are edited.
const moduleSource=fs.readFileSync(new URL('./vehicle_render_batches.mjs',import.meta.url),'utf8');
assert.equal(moduleSource.split('const fixedFixture=mesh=>').length,2);
const baselineSource=moduleSource
  .replace(/^import \{stampBatchedShadowBounds\} from '\.\/shadow_bounds_stamp\.mjs';\r?\n/,'const stampBatchedShadowBounds=()=>{};\n')
  .replace('const fixedFixture=mesh=>','const fixedFixture=mesh=>false&&');
const baselineModule=await import('data:text/javascript;base64,'+Buffer.from(baselineSource).toString('base64'));
function submissions(root){let main=0,shadow=0;root.traverse(n=>{if(!n.isMesh)return;for(let p=n;p;p=p.parent)if(!p.visible)return;for(const m of Array.isArray(n.material)?n.material:[n.material])if(m?.visible){main+=m.transparent&&m.side===T.DoubleSide&&!m.forceSinglePass?2:1;shadow+=Number(n.castShadow);}});return {main,shadow};}
for(const profile of ARTIST_VEHICLE_PROFILES){
 const bytes=fs.readFileSync(new URL('./models/artist_vehicle_pack/'+profile.modelFile,import.meta.url)),gltf=await new GLTFLoader().parseAsync(bytes.buffer.slice(bytes.byteOffset,bytes.byteOffset+bytes.byteLength),'');
 test(profile.id+' actual geometry, pose, material, ownership, raycast and draw parity',()=>{
  const car=createArtistVehicle(T,RoundedBoxGeometry,gltf.scene,profile),oldCar=createArtistVehicle(T,RoundedBoxGeometry,gltf.scene,profile),parent=new T.Group();parent.position.set(11,2,-5);parent.rotation.set(.09,.31,-.12);parent.add(car.object);
  const before=new Map();car.object.traverse(n=>{if(n.isMesh)before.set(n,{geometry:n.geometry,material:n.material,parent:n.parent,raycast:n.raycast});});
  const old=baselineModule.createVehicleRenderBatches({THREE:T,root:oldCar.object,includeBody:true,includeDoors:true}),helper=createVehicleRenderBatches({THREE:T,root:car.object,includeBody:true,includeDoors:true});
  const batches=fixtureBatches(car.object);assert(helper.stats.fixtureMembers>=8);assert(batches.every(b=>b.userData.vehicleDetailRenderBatch));
  const available=[...before].filter(([n,s])=>n.material!==s.material&&n.userData.assembledBody===true&&whitelist.test(n.name)&&n.parent===car.object);
  assert.equal(available.length,helper.stats.fixtureMembers);
  for(const pose of [0,1]){
   car.object.position.set(2*pose,.4*pose,-3*pose);car.object.rotation.set(.05*pose,.7*pose,-.03*pose);car.update({distance:pose*3,steer:pose*.4});for(const id of car.doors.keys())car.setDoorById(pose*.8,id);helper.update();parent.updateMatrixWorld(true);
   const used=new Set(),matrix=new T.Matrix4(),world=new T.Matrix4(),actual=new T.Vector3(),expected=new T.Vector3();
   for(const batch of batches)for(let index=0;index<batch.instanceCount;index++){
    batch.getMatrixAt(index,matrix);world.multiplyMatrices(batch.matrixWorld,matrix);const range=batch.getGeometryRangeAt(batch.getGeometryIdAt(index));
    const match=available.find(([n,s])=>!used.has(n)&&s.material===batch.material&&n.geometry.attributes.position.count===range.vertexCount&&world.elements.every((v,i)=>Math.abs(v-n.matrixWorld.elements[i])<3e-5));assert(match,profile.id+' exact material/transform match');
    const [mesh,saved]=match;used.add(mesh);assert.equal(mesh.geometry,saved.geometry);assert.equal(mesh.parent,saved.parent);assert.equal(mesh.raycast,saved.raycast);assert.equal(getVehicleRenderSourceMaterial(mesh),saved.material);assert.equal(batch.castShadow,mesh.castShadow);assert.equal(batch.receiveShadow,mesh.receiveShadow);
    for(let v=0;v<range.vertexCount;v++){actual.fromBufferAttribute(batch.geometry.attributes.position,range.vertexStart+v).applyMatrix4(world);expected.fromBufferAttribute(mesh.geometry.attributes.position,v).applyMatrix4(mesh.matrixWorld);assert(actual.distanceTo(expected)<3e-5);vertices++;}
   }
  }
  const previous=submissions(oldCar.object),current=submissions(car.object),saved=helper.stats.fixtureMembers-helper.stats.fixtureBatches;
  assert.equal(previous.main-current.main,saved);assert.equal(previous.shadow-current.shadow,saved);assert.equal(helper.stats.fallbackMembers,0);
  helper.setDetailOptimizationEnabled(false);for(const [mesh,snapshot]of available)assert.equal(mesh.material,snapshot.material);assert(batches.every(b=>!b.visible));helper.setDetailOptimizationEnabled(true);
  let sourceDisposed=0;for(const [mesh]of available)mesh.geometry.addEventListener('dispose',()=>sourceDisposed++);helper.dispose();helper.dispose();assert.equal(sourceDisposed,0);for(const [mesh,snapshot]of available)assert.equal(mesh.material,snapshot.material);old.dispose();
  reports.push({id:profile.id,fixtureMembers:available.length,fixtureBatches:batches.length,previous,current,savedPerPass:saved});
 });
}
console.log(JSON.stringify({tests,vertices,reports,scope:'CPU structural census and parity only; no GPU, frame timing or FPS'},null,2));
