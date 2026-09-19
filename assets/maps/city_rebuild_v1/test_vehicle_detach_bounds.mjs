import assert from 'node:assert/strict';
import fs from 'node:fs';
import {pathToFileURL} from 'node:url';
import {registerHooks} from 'node:module';
import {measureVehicleDetachedBounds,createVehicleDamage} from './vehicle_damage.mjs';
import {ARTIST_VEHICLE_PROFILES,createArtistVehicle} from './vehicle_fleet_models.mjs';
const vendor='D:/codex_release/artist13_hero_first_DEV_20260907/demo/vendor/';
registerHooks({resolve(specifier,context,nextResolve){return nextResolve(specifier==='three'?pathToFileURL(vendor+'build/three.module.js').href:specifier,context)}});
const T=await import(pathToFileURL(vendor+'build/three.module.js'));
const {GLTFLoader}=await import(pathToFileURL(vendor+'addons/loaders/GLTFLoader.js'));
const {RoundedBoxGeometry}=await import('../../../tools/vehicle_fleet_qa/RoundedBoxGeometry.mjs');
function legacyBounds(mesh){
 mesh.updateWorldMatrix(true,true);const inverse=mesh.matrixWorld.clone().invert(),bounds=new T.Box3(),vertex=new T.Vector3();
 mesh.traverse(node=>{const positions=node.geometry?.attributes?.position;if(positions)for(let i=0;i<positions.count;i++)bounds.expandByPoint(vertex.fromBufferAttribute(positions,i).applyMatrix4(node.matrixWorld).applyMatrix4(inverse))});
 return bounds;
}
function thinAxis(bounds){const size=bounds.getSize(new T.Vector3());return size.x<=size.y&&size.x<=size.z?new T.Vector3(1,0,0):size.y<=size.z?new T.Vector3(0,1,0):new T.Vector3(0,0,1)}
function landingFor(thin){return new T.Quaternion().setFromAxisAngle(new T.Vector3(0,1,0),1.923).multiply(new T.Quaternion().setFromUnitVectors(thin,new T.Vector3(0,1,0)))}
let assemblies=0,vertices=0;
for(const profile of ARTIST_VEHICLE_PROFILES){
 const bytes=fs.readFileSync(new URL('./models/artist_vehicle_pack/'+profile.modelFile,import.meta.url));
 const gltf=await new GLTFLoader().parseAsync(bytes.buffer.slice(bytes.byteOffset,bytes.byteOffset+bytes.byteLength),'');
 const car=createArtistVehicle(T,RoundedBoxGeometry,gltf.scene,profile),scene=new T.Scene();scene.add(car.object);scene.updateMatrixWorld(true);
 const sources=[...car.doors.values(),...car.shell.filter(mesh=>['Hood_lid','Trunk_lid'].includes(mesh.name)),...car.wheels.map(wheel=>wheel.pivot)].slice(0,10);
 for(const source of sources){
  const before=legacyBounds(source),scratch={bounds:new T.Box3(),inverse:new T.Matrix4(),nodeMatrix:new T.Matrix4(),vertex:new T.Vector3()},after=measureVehicleDetachedBounds(T,source,scratch);
  assert.ok(before.min.distanceTo(after.min)<1e-10,profile.id+' '+source.name+' exact local minimum');
  assert.ok(before.max.distanceTo(after.max)<1e-10,profile.id+' '+source.name+' exact local maximum');
  assert.deepEqual(thinAxis(after).toArray(),thinAxis(before).toArray(),profile.id+' '+source.name+' same thin axis');
  assert.deepEqual(landingFor(thinAxis(after)).toArray(),landingFor(thinAxis(before)).toArray(),profile.id+' '+source.name+' same landing quaternion');
  source.traverse(node=>vertices+=node.geometry?.attributes.position?.count||0);assemblies++;
 }
 const damage=createVehicleDamage(T,car,{scene});damage.blastImpact({damage:1000});damage.update(1.56);
 assert.equal(damage.debrisObject.children.length,sources.length,profile.id+' retains every selected real assembly');
 for(const source of sources)assert.equal(source.visible,false,profile.id+' originals remain hidden after cloned detach');
 damage.dispose();
}
console.log('PASS '+ARTIST_VEHICLE_PROFILES.length+' authored GLB families, '+assemblies+' released assemblies, '+vertices+' exact support vertices; local bounds/thin axes/landing quaternions parity and real cloned detach retained');
