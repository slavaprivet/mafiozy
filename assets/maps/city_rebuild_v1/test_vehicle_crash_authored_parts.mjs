import assert from 'node:assert/strict';
import {test} from 'node:test';
import {readFile} from 'node:fs/promises';
import {pathToFileURL} from 'node:url';
import {registerHooks} from 'node:module';
import {ARTIST_VEHICLE_PROFILES,createArtistVehicle} from './vehicle_fleet_models.mjs';
import {createVehicleCrash} from './vehicle_crash.mjs';

const vendor=process.env.MAFIOZY_THREE_VENDOR||'D:/codex_release/artist13_hero_first_DEV_20260907/demo/vendor/';
registerHooks({resolve(s,c,next){return next(s==='three'?pathToFileURL(vendor+'build/three.module.js').href:s,c)}});
const T=await import(pathToFileURL(vendor+'build/three.module.js'));
const {GLTFLoader}=await import(pathToFileURL(vendor+'addons/loaders/GLTFLoader.js'));
class Box extends T.BoxGeometry{constructor(w,h,d){super(w,h,d)}}

for(const profile of ARTIST_VEHICLE_PROFILES)test(profile.id+': failed bumper mounts release the real authored parts once',async()=>{
 const bytes=await readFile(new URL('./models/artist_vehicle_pack/'+profile.modelFile,import.meta.url));
 const gltf=await new GLTFLoader().parseAsync(bytes.buffer.slice(bytes.byteOffset,bytes.byteOffset+bytes.byteLength),'');
 const car=createArtistVehicle(T,Box,gltf,profile),scene=new T.Scene();scene.add(car.object);
 const crash=createVehicleCrash(T,car,{scene});
 const originals=['Front','Rear'].map(end=>{
  const part=car.object.getObjectByName('LOD0_'+profile.id+'_'+end+'Bumper');assert(part,'authored bumper must exist');
  return {part,geometry:part.geometry,material:part.material};
 });
 try{
  for(const [end,sign] of [['Front',1],['Rear',-1]]){
   const part=car.object.getObjectByName('LOD0_'+profile.id+'_'+end+'Bumper');assert(part,'authored bumper must exist');
   car.object.updateWorldMatrix(true,true);const point=new T.Box3().setFromObject(part).getCenter(new T.Vector3());
   assert(crash.contactImpact({point,normal:{x:0,y:0,z:sign},impactSpeed:30}));
   assert(crash.state.parts['bumper_'+end.toLowerCase()].detached);
   assert.equal(part.visible,false,'a failed mount must detach visibly, not just in statistics');
   const copies=crash.root.children.filter(n=>n.name===part.name);assert.equal(copies.length,1);
   assert.notEqual(copies[0].geometry,part.geometry);assert.notEqual(copies[0].material,part.material);
   assert.equal(crash.detach('bumper_'+end.toLowerCase()),false,'cannot duplicate an already detached bumper');
  }
  crash.reset();assert.equal(crash.root.children.length,0);
  for(const {part,geometry,material}of originals){assert(part.visible);assert.equal(part.geometry,geometry);assert.equal(part.material,material)}
 }finally{crash.dispose()}
});
