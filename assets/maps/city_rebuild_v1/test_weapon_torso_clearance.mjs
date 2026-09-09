import fs from 'node:fs';
import path from 'node:path';
import assert from 'node:assert/strict';
import {fileURLToPath,pathToFileURL} from 'node:url';
import {registerHooks} from 'node:module';
const here=path.dirname(fileURLToPath(import.meta.url));
const rootDir=process.env.ARTIST14_MODULE_DIR||(fs.existsSync(path.join(here,'hero_walk.mjs'))?here:path.resolve(process.cwd(),'assets/maps/city_rebuild_v1'));
const vendor=process.env.THREE_VENDOR||'D:/codex_release/artist13_hero_first_DEV_20260907/demo/vendor';
const threeURL=pathToFileURL(path.join(vendor,'build/three.module.js')).href;
registerHooks({resolve(s,c,n){return n(s==='three'?threeURL:s,c)}});
const THREE=await import(threeURL);
const {GLTFLoader}=await import(pathToFileURL(path.join(vendor,'addons/loaders/GLTFLoader.js')).href);
const {createHeroWalker}=await import(pathToFileURL(process.argv[2]?path.resolve(process.argv[2]):path.join(rootDir,'hero_walk.mjs')).href);
const {createWeaponModel,ARSENAL}=await import(pathToFileURL(path.join(rootDir,'hero_arsenal.mjs')).href);
const reports=[],failures=[];let cases=0,maxRightPalmError=0,maxLeftPalmError=0;
for(const sex of ['male','female']){
 const data=fs.readFileSync(sex==='male'?path.join(rootDir,'hero_models/player_male.8130dfb1f7eb.glb'):(process.env.ARTIST14_FEMALE_GLB||'D:/codex_release/artist13_posture_DEV_20260908/demo/player_female.glb')),{scene}=await new GLTFLoader().parseAsync(data.buffer.slice(data.byteOffset,data.byteOffset+data.byteLength),'');
 const hero=createHeroWalker({THREE,scene}),torso=[],torsoNames=new Set(['spine_01','chest','pelvis','clavicle_l','clavicle_r']);
 scene.traverse(mesh=>{if(!mesh.isSkinnedMesh||!mesh.name.includes('core_FABRIC'))return;
  const si=mesh.geometry.attributes.skinIndex,sw=mesh.geometry.attributes.skinWeight,p=mesh.geometry.attributes.position,inside=[];
  for(let i=0;i<p.count;i++){let weight=0;for(let j=0;j<4;j++)if(torsoNames.has(mesh.skeleton.bones[si.getComponent(i,j)]?.name))weight+=sw.getComponent(i,j);inside.push(weight>.98)}
  const indices=mesh.geometry.index?.array||Array.from({length:p.count},(_,i)=>i),triangles=[];
  for(let i=0;i<indices.length;i+=3){const a=indices[i],b=indices[i+1],c=indices[i+2];if(inside[a]&&inside[b]&&inside[c])triangles.push([a,b,c])}torso.push({mesh,triangles});
 });
 for(const spec of ARSENAL.filter(x=>x.twoHanded)){
  const gun=createWeaponModel(THREE,spec.id);hero.mountWeapon(gun);
  for(const posture of [0,1])for(const aimPitch of [-1.28,-.65,0,.65,1.28])for(const recoil of [0,1]){
   hero.update(0,false,false,gun,{aimPitch,recoil},{posture:{target:posture?'crouch':'stand',value:posture,blocked:false}});cases++;
   const {bones}=hero.artistContext();maxRightPalmError=Math.max(maxRightPalmError,bones.socket_hand_r.getWorldPosition(new THREE.Vector3()).distanceTo(gun.localToWorld(new THREE.Vector3(0,-.13,-.02))));maxLeftPalmError=Math.max(maxLeftPalmError,bones.socket_hand_l.getWorldPosition(new THREE.Vector3()).distanceTo(gun.localToWorld(new THREE.Vector3(...gun.userData.supportGrip))));const tris=[];for(const {mesh,triangles}of torso){mesh.skeleton.update();const positions=mesh.geometry.attributes.position;const points=Array.from({length:positions.count},(_,i)=>{const v=new THREE.Vector3().fromBufferAttribute(positions,i);mesh.applyBoneTransform(i,v);return v.applyMatrix4(mesh.matrixWorld)});for(const ids of triangles)tris.push(ids.map(i=>points[i]))}
   const ray=new THREE.Ray(new THREE.Vector3(),new THREE.Vector3(0,0,1)),hit=new THREE.Vector3(),names=['stock','stock_pad','folding_stock','shoulder_pad','rear_cone','launcher_tube'];let count=0,first=null;
   for(const name of names){const part=gun.getObjectByName(name);if(!part)continue;part.geometry.computeBoundingBox();const b=part.geometry.boundingBox;
    const positions=part.geometry.attributes.position,indices=part.geometry.index?.array||Array.from({length:positions.count},(_,i)=>i),surface=[];
    for(let i=0;i<positions.count;i++)surface.push(new THREE.Vector3().fromBufferAttribute(positions,i));
    for(let i=0;i<indices.length;i+=3){const a=new THREE.Vector3().fromBufferAttribute(positions,indices[i]),b=new THREE.Vector3().fromBufferAttribute(positions,indices[i+1]),c=new THREE.Vector3().fromBufferAttribute(positions,indices[i+2]);surface.push(a.clone().add(b).add(c).multiplyScalar(1/3),a.clone().add(b).multiplyScalar(.5),b.clone().add(c).multiplyScalar(.5),c.clone().add(a).multiplyScalar(.5));}
    const edgeRay=new THREE.Ray(),edgeHit=new THREE.Vector3(),edgeKeys=new Set();
    for(let i=0;i<indices.length;i+=3)for(const [a,b]of [[indices[i],indices[i+1]],[indices[i+1],indices[i+2]],[indices[i+2],indices[i]]]){
     const from=new THREE.Vector3().fromBufferAttribute(positions,a).applyMatrix4(part.matrixWorld),to=new THREE.Vector3().fromBufferAttribute(positions,b).applyMatrix4(part.matrixWorld),key=[from.toArray().map(x=>x.toFixed(7)).join(','),to.toArray().map(x=>x.toFixed(7)).join(',')].sort().join('|');if(edgeKeys.has(key))continue;edgeKeys.add(key);
     const length=from.distanceTo(to);if(length<1e-7)continue;edgeRay.origin.copy(from);edgeRay.direction.subVectors(to,from).normalize();
     for(const t of tris)if(edgeRay.intersectTriangle(t[0],t[1],t[2],false,edgeHit)){const distance=edgeHit.distanceTo(from);if(distance>1e-6&&distance<length-1e-6){count++;first??={name,point:edgeHit.toArray(),edgeCrossing:true};break}}
    }
    for(const local of surface){const point=local.applyMatrix4(part.matrixWorld);ray.origin.copy(point);const ds=[];
     for(const t of tris)if(ray.intersectTriangle(t[0],t[1],t[2],false,hit)){const d=hit.z-point.z;if(d>1e-6&&!ds.some(x=>Math.abs(x-d)<1e-6))ds.push(d)}
     if(ds.length%2){count++;first??={name,point:point.toArray(),depth:Math.min(...ds)}}
    }
   }
   if(count)failures.push({sex,id:spec.id,posture,aimPitch,recoil,count,first});
  }
 }
}
const result={maxRightPalmError,maxLeftPalmError,cases,failedCases:failures.length,failures};
if(process.env.ARTIST14_AUDIT_REPORT)fs.writeFileSync(process.env.ARTIST14_AUDIT_REPORT,JSON.stringify(result,null,2));
console.log(JSON.stringify(result));
assert(maxRightPalmError<.001&&maxLeftPalmError<.001,'both palms remain on authored grips');
assert.equal(failures.length,0,'rear weapon surface/edges must not enter torso skin');
