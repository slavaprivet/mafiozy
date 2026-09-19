import assert from 'node:assert/strict';
import {readFileSync} from 'node:fs';
import {registerHooks} from 'node:module';
import {pathToFileURL} from 'node:url';
import {createArtistVehicle} from './vehicle_fleet_models.mjs';
import {createDetailedVehicleWheel,createVehicleWheelMaterialPalette,getVehicleWheelRenderBinding,updateVehicleWheelVisuals} from './vehicle_wheels.mjs';
import {createVehicleWheelRenderBatches,setVehicleWheelRenderOptimization} from './vehicle_wheel_render_batches.mjs';
import {getVehicleRenderSourceMaterial,createVehicleRenderBatches,registerVehicleRenderSourceMaterial,unregisterVehicleRenderSourceMaterial} from './vehicle_render_batches.mjs';
import {createTyreDamage} from './tyre_damage.mjs';
import {createVehicleDamage} from './vehicle_damage.mjs';
const vendor='D:/codex_release/artist13_hero_first_DEV_20260907/demo/vendor/';
registerHooks({resolve(s,c,n){return n(s==='three'?pathToFileURL(vendor+'build/three.module.js').href:s,c)}});
const T=await import('three'),{GLTFLoader}=await import(pathToFileURL(vendor+'addons/loaders/GLTFLoader.js'));
const ids=['front_left','front_right','rear_left','rear_right'];
function fixture(){
 const object=new T.Group(),palette=createVehicleWheelMaterialPalette(T,{owner:object}),wheels=[];
 for(const [i,id]of ids.entries()){
  const pivot=new T.Group();pivot.userData.vehicleWheelId=id;pivot.name='Wheel_attachment_'+id;pivot.position.set(i%2?-1:1,.45,i<2?1.5:-1.5);object.add(pivot);
  const detail=createDetailedVehicleWheel(T,{id,materialPalette:palette});pivot.add(detail.wheel);wheels.push({id,pivot,...detail,front:i<2,rollingRadius:.4,restPosition:pivot.position.clone()});
 }
 object.updateMatrixWorld(true);const meshes=[];object.traverse(n=>{if(n.isMesh)meshes.push(n)});return {object,wheels,meshes,palette};
}
function parity(car){
 car.object.updateMatrixWorld(true);const batches=car.object.children.filter(n=>n.userData.vehicleWheelRenderBatch),sources=car.meshes.filter(m=>m.material!==getVehicleRenderSourceMaterial(m)),local=new T.Matrix4(),world=new T.Matrix4();
 for(const b of batches)for(let id=0;id<b.instanceCount;id++){
  if(!b.getVisibleAt(id))continue;b.getMatrixAt(id,local);world.multiplyMatrices(b.matrixWorld,local);
  const candidates=sources.filter(m=>getVehicleRenderSourceMaterial(m)===b.material&&m.matrixWorld.elements.every((x,i)=>Math.abs(x-world.elements[i])<2e-5));assert(candidates.length,'every visible batch instance matches a live source world matrix');
  const source=candidates[0],range=b.getGeometryRangeAt(b._instanceInfo[id].geometryIndex),a=source.geometry.attributes.position,c=b.geometry.attributes.position;
  for(let i=0;i<a.count;i++)for(let j=0;j<3;j++)assert.equal(c.array[(range.vertexStart+i)*3+j],a.array[i*3+j],'exact authored vertices are copied');
 }
 return batches;
}
{
 const car=fixture(),originals=new Map(car.meshes.map(m=>[m,{material:m.material,geometry:m.geometry,parent:m.parent,raycast:m.raycast,visible:m.visible,castShadow:m.castShadow,id:m.userData.vehicleWheelId}]));
 const ray=new T.Raycaster(new T.Vector3(3,.45,1.5),new T.Vector3(-1,0,0));const hits=()=>ray.intersectObject(car.object,true).map(h=>[h.object.id,h.distance]);const before=hits();assert(before.length);
 const disabled=createVehicleWheelRenderBatches({THREE:T,car,multiDraw:false});assert.equal(disabled.stats.batches,0);assert.equal(disabled.setEnabled(true),false);disabled.dispose();
 const api=createVehicleWheelRenderBatches({THREE:T,car,multiDraw:true});assert.equal(api.stats.batches,5);assert.equal(api.stats.members,20);assert.deepEqual(hits(),before,'source raycast results remain exact');
 for(const[m,s]of originals){assert.equal(getVehicleRenderSourceMaterial(m),s.material);assert.equal(m.geometry,s.geometry);assert.equal(m.parent,s.parent);assert.equal(m.raycast,s.raycast);assert.equal(m.visible,s.visible);assert.equal(m.castShadow,s.castShadow);assert.equal(m.userData.vehicleWheelId,s.id);}
 car.object.position.set(12,3,-8);car.object.rotation.set(.04,.7,.01);car.object.scale.set(1.1,.9,1.2);
 for(let i=0;i<4;i++){updateVehicleWheelVisuals(car.wheels,{steer:i*.11,distance:.3,handbrake:i===3});api.update();parity(car);}
 const scene=new T.Scene();scene.add(car.object);const tyres=createTyreDamage(T,car);tyres.hit({object:car.wheels[0].tire});tyres.update({distance:0,speed:0},2);api.update();parity(car);assert.equal(api.stats.activeMembers,20);
 tyres.update({distance:61,speed:8},.1);api.update();assert.equal(api.stats.activeMembers,18,'hidden tyre also hides its tread child, not hub/lips/rotor');parity(car);
 tyres.reset();api.update();assert.equal(api.stats.activeMembers,20);
 car.wheels[1].pivot.visible=false;api.update();assert.equal(api.stats.activeMembers,15);car.wheels[1].pivot.visible=true;
 for(const enabled of [false,true,false,true]){assert.equal(setVehicleWheelRenderOptimization(car.object,enabled),enabled);api.update();if(enabled)parity(car);for(const[m,s]of originals)assert.equal(m.material,enabled?api.stats.enabled&&m.material:s.material);}
 const canonical=car.palette.materials.rubber;canonical.color.set('#100f0e');canonical.roughness=.99;api.update();assert.equal(api.stats.fallbackMembers,0,'canonical burn remains one material shared with its batch');
 api.dispose();api.dispose();for(const[m,s]of originals)assert.equal(m.material,s.material);assert.equal(setVehicleWheelRenderOptimization(car.object,true),null);tyres.dispose();
}
for(const destination of ['foreign','same-car-sibling']){
 const car=fixture(),api=createVehicleWheelRenderBatches({THREE:T,car,multiDraw:true}),tire=car.wheels[0].tire,tread=tire.children[0],originals=[getVehicleRenderSourceMaterial(tire),getVehicleRenderSourceMaterial(tread)],other=new T.Group();
 if(destination==='same-car-sibling')car.object.add(other);other.add(tire);api.update();assert.equal(api.stats.fallbackMembers,2,destination+' tyre and nested tread both lose exact ancestry');assert.equal(tire.material,originals[0]);assert.equal(tread.material,originals[1]);api.setEnabled(false);api.setEnabled(true);assert.equal(api.stats.fallbackMembers,2);api.dispose();
}
{
 const car=fixture(),api=createVehicleWheelRenderBatches({THREE:T,car,multiDraw:true});api.setEnabled(false);
 const cases=[
  ['position version',m=>{m.geometry.attributes.position.needsUpdate=true}],['geometry replacement',m=>{m.geometry=new T.BoxGeometry()}],['material replacement',m=>{m.material=new T.MeshStandardMaterial({color:'red'})}],
  ['negative determinant',m=>{m.scale.x=-1}],['cast shadow',m=>{m.castShadow=false}],['receive shadow',m=>{m.receiveShadow=false}],['layers',m=>m.layers.set(3)],['render order',m=>{m.renderOrder=99}],
  ...['onBeforeRender','onAfterRender','onBeforeShadow','onAfterShadow'].map(k=>[k,m=>{m[k]=()=>{}}]),['custom depth',m=>{m.customDepthMaterial=new T.MeshDepthMaterial()}],['damage marker',m=>{m.userData.damagePart=true}],['wheel ID',m=>{m.userData.vehicleWheelId='other'}],
 ];
 // Non-parent parts avoid a tyre mutation intentionally invalidating its tread too.
 const selected=car.meshes.filter(m=>!m.children.length);assert(selected.length>=cases.length);
 for(let i=0;i<cases.length;i++){cases[i][1](selected[i]);api.update();assert.equal(api.stats.fallbackMembers,i+1,cases[i][0]+' falls back while disabled');}
 api.setEnabled(true);assert.equal(api.stats.fallbackMembers,cases.length);api.dispose();
}
{
 const car=fixture(),api=createVehicleWheelRenderBatches({THREE:T,car,multiDraw:true}),hidden=car.wheels[0].tire.material;hidden.color.set('#ef1234');api.update();assert.equal(api.stats.fallbackMembers,4);assert(hidden.visible);api.dispose();assert.equal(car.wheels[0].tire.material,hidden,'external edited replacement remains owned by caller');
}
{
 const car=fixture(),originals=car.meshes.map(m=>m.material),occupied=car.wheels[3].tire,foreign=occupied.material.clone();foreign.visible=false;
 registerVehicleRenderSourceMaterial(occupied,foreign,occupied.material);
 assert.throws(()=>createVehicleWheelRenderBatches({THREE:T,car,multiDraw:true}),/already has a batch owner/);
 car.meshes.forEach((m,i)=>assert.equal(m.material,originals[i]));assert(!car.object.children.some(n=>n.userData.vehicleWheelRenderBatch),'failed construction releases partial batches');
 occupied.material=foreign;assert.equal(getVehicleRenderSourceMaterial(occupied),originals[car.meshes.indexOf(occupied)],'foreign registration survives rollback');occupied.material=originals[car.meshes.indexOf(occupied)];unregisterVehicleRenderSourceMaterial(occupied,foreign);foreign.dispose();
 const retry=createVehicleWheelRenderBatches({THREE:T,car,multiDraw:true});assert.equal(retry.stats.members,20);retry.dispose();
}
{
 const bytes=readFileSync(new URL('models/artist_vehicle_pack/compact_sedan.glb',import.meta.url)),loader=new GLTFLoader(),source=(await loader.parseAsync(bytes.buffer.slice(bytes.byteOffset,bytes.byteOffset+bytes.byteLength),'')).scene;
 class Box extends T.BoxGeometry{constructor(w,h,d){super(w,h,d)}}
 const legacy=createArtistVehicle(T,Box,source,'compact_sedan'),enabled=createArtistVehicle(T,Box,source,'compact_sedan',{wheelRenderOptimization:true}),separate=createArtistVehicle(T,Box,source,'compact_sedan',{wheelRenderOptimization:true});
 const wheelMeshes=car=>car.wheels.flatMap(w=>{const list=[];w.wheel.traverse(n=>{if(n.isMesh)list.push(n)});return list;});
 const old=wheelMeshes(legacy),next=wheelMeshes(enabled),other=wheelMeshes(separate);
 assert.equal(new Set(old.map(m=>m.material)).size,20,'production factory default unchanged');assert.equal(new Set(next.map(m=>m.material)).size,5);
 const materialProperties=m=>[m.type,m.color.getHex(),m.roughness,m.metalness,m.side,m.opacity,m.transparent,m.depthTest,m.depthWrite,m.flatShading,m.vertexColors,m.emissive.getHex(),m.emissiveIntensity];
 for(let i=0;i<old.length;i++){assert.deepEqual(materialProperties(old[i].material),materialProperties(next[i].material));assert.deepEqual(old[i].geometry.attributes.position.array,next[i].geometry.attributes.position.array);assert.deepEqual(old[i].geometry.index?.array,next[i].geometry.index?.array);assert(!getVehicleWheelRenderBinding(old[i]));assert.notEqual(next[i].material,other[i].material);}
 next[0].material.color.set('#040506');assert.notEqual(next[0].material.color.getHex(),other[0].material.color.getHex(),'separate car never inherits tint/burn');
 const scene=new T.Scene();scene.add(enabled.object);const damage=createVehicleDamage(T,enabled,{scene}),body=createVehicleRenderBatches({THREE:T,root:enabled.object,includeDoors:true,includeBody:true}),wheels=createVehicleWheelRenderBatches({THREE:T,car:enabled,multiDraw:true});assert.equal(wheels.stats.members,20);body.update();assert.equal(body.stats.fallbackMembers,0);
 const baseColor=next[0].material===getVehicleRenderSourceMaterial(next[0])?next[0].material.color.clone():getVehicleRenderSourceMaterial(next[0]).color.clone();
 enabled.object.updateMatrixWorld(true);const target=enabled.shell.find(m=>m.geometry&&m.visible),point=target.getWorldPosition(new T.Vector3());
 damage.impact({object:target,point,normal:new T.Vector3(0,1,0),damage:99999,shotId:'wheel-batch-explosion'});damage.update(1.56);wheels.update();
 assert(damage.state.wrecked);assert.equal(wheels.stats.activeMembers,0);const looseWheel=damage.debrisObject.children.find(n=>n.name==='Wheel_attachment_front_left');assert(looseWheel,'real wheel assembly copied');let copied=0;looseWheel.traverse(n=>{assert(!n.userData.vehicleRenderBatch);if(n.isMesh){copied++;assert(n.material.visible);assert(!next.some(source=>getVehicleRenderSourceMaterial(source)===n.material));}});assert.equal(copied,5,'debris contains five real meshes and no extra batches');
 damage.reset();wheels.update();assert.equal(wheels.stats.activeMembers,20);assert(getVehicleRenderSourceMaterial(next[0]).color.equals(baseColor));assert.notEqual(getVehicleRenderSourceMaterial(next[0]),other[0].material);wheels.dispose();body.dispose();damage.dispose();
}
console.log('PASS wheel palette default-off/property/geometry parity, 5 role batches, capability gate, source raycasts, spin/steer/puncture/tyre-child visibility, exact ancestry reparent, deformation/material/callback fallback, canonical burn, per-car isolation and disposal; CPU only');
