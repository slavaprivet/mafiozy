import fs from 'node:fs';
import path from 'node:path';
import assert from 'node:assert/strict';
import {createHash} from 'node:crypto';
import {registerHooks} from 'node:module';
import {pathToFileURL,fileURLToPath} from 'node:url';
const root=path.resolve(path.dirname(fileURLToPath(import.meta.url)),'../..');
const vendor=process.env.MAFIOZI_THREE_VENDOR??'D:/codex_release/artist13_hero_first_DEV_20260907/demo/vendor';
const sourcePath=path.join(root,'assets/maps/city_rebuild_v1/hero_walk.mjs');
const original=fs.readFileSync(sourcePath,'utf8');
let observed=original;
for(const [needle,replacement] of [
 ['function posturePose(posture,moving){','function posturePose(posture,moving){globalThis.__weaponPostureObserver?.("base",posture);'],
 ['posturePose(posture,moving);const landingBlend','posturePose(posture,moving);globalThis.__weaponPostureObserver?.("posture",posture);const landingBlend'],
 ['function groundPose(){','function groundPose(){globalThis.__weaponPostureObserver?.("pre_ground");']]){
 assert.equal(observed.split(needle).length,2);observed=observed.replace(needle,replacement);
}
registerHooks({resolve(s,c,n){return n(s==='three'?pathToFileURL(path.join(vendor,'build/three.module.js')).href:s,c)},
 load(url,c,n){return url===pathToFileURL(sourcePath).href?{format:'module',source:observed,shortCircuit:true}:n(url,c)}});
const THREE=await import(pathToFileURL(path.join(vendor,'build/three.module.js')));
const {GLTFLoader}=await import(pathToFileURL(path.join(vendor,'addons/loaders/GLTFLoader.js')));
const {createHeroWalker}=await import(pathToFileURL(sourcePath));
const {ARSENAL,createWeaponModel}=await import(pathToFileURL(path.join(root,'assets/maps/city_rebuild_v1/hero_arsenal.mjs')));
const {createHeroPosture,requestHeroPosture,stepHeroPosture,posturePresentation}=await import(pathToFileURL(path.join(root,'assets/maps/city_rebuild_v1/hero_posture.mjs')));
const asset=fs.readFileSync(path.join(root,'godot/mafiozi_walk/assets/hero.glb'));
const scene=(await new GLTFLoader().parseAsync(asset.buffer.slice(asset.byteOffset,asset.byteOffset+asset.byteLength),'')).scene;
const hero=createHeroWalker({THREE,scene}),c=hero.artistContext();c.object.updateMatrixWorld(true);
const names=Object.keys(c.bones),parents=names.map(n=>names.indexOf(c.bones[n].parent.name));
const rootBone=c.bones[names[parents.indexOf(-1)]];
const rest=names.map(n=>c.rest[n].matrix.toArray());
const restRigToActor=c.object.matrixWorld.clone().invert().multiply(rootBone.parent.matrixWorld).toArray();
const restOffsetToActor=c.object.matrixWorld.clone().invert().multiply(c.offset.matrixWorld).toArray();
const poses=()=>names.map(n=>c.bones[n].matrix.toArray());
const visual=()=>({visual_offset:c.scaled.position.clone().applyQuaternion(c.visualPivot.quaternion).add(c.visualPivot.position).toArray(),visual_rotation:c.visualPivot.quaternion.toArray(),scaled_offset:c.scaled.position.toArray()});
const frame=()=>({actor_world:c.object.matrixWorld.toArray(),actor_yaw:c.object.rotation.y,visual_pivot_world:c.visualPivot.matrixWorld.toArray(),skeleton_world:rootBone.parent.matrixWorld.toArray(),offset_world:c.offset.matrixWorld.toArray(),scaled_y:c.scaled.position.y,target_height:c.targetHeight,source_height:c.sourceHeight});
const cases=[];
for(const spec of ARSENAL.filter(x=>x.id!=='none')){
 const weapon=createWeaponModel({THREE,id:spec.id}),magazine=weapon.children.find(n=>/^(magazine|drum_magazine)$/.test(n.name));
 for(const value of [.5,1,1.5,2])for(const variant of [0,1,2]){
  hero.reset();hero.mountWeapon(weapon);c.object.position.set(4,2,-3);c.object.rotation.y=-.67;
  const aim={aimYaw:.6,aimPitch:variant===0?0:variant===1?-.8:.55,recoil:variant===1?.3:0,recoilYaw:variant===1?-.2:0};
  const presentation={posture:{target:value>1?'prone':'crouch',value,blocked:false},motionSpeed:value>1?.8:1.55,reloadProgress:variant===2?.5:0,gaitOutput:{}};
  if(variant===1)presentation.gaitDistance=.07;
  const snapshots={};
  globalThis.__weaponPostureObserver=(stage,posture)=>{c.object.updateMatrixWorld(true);snapshots[stage]={poses:poses(),visual:visual(),frame:frame(),posture,weapon_local:weapon.matrix.toArray(),weapon_world:weapon.matrixWorld.toArray()}};
  hero.update(.08,variant!==0,false,weapon,aim,presentation);c.object.updateMatrixWorld(true);
  delete globalThis.__weaponPostureObserver;
  const final={poses:poses(),visual:visual(),frame:frame(),weapon_local:weapon.matrix.toArray(),weapon_world:weapon.matrixWorld.toArray()};
  cases.push({id:spec.id,value,variant,motion:{delta:.08,moving:variant!==0,speed:presentation.motionSpeed,distance:presentation.gaitDistance??null},phase:presentation.gaitOutput.phase,gait:presentation.gaitOutput.gait,aim:{...aim,reloadProgress:presentation.reloadProgress},posture:snapshots.base.posture,weapon:{id:spec.id,two_handed:spec.twoHanded,source_metadata:structuredClone(weapon.userData),reload_magazine_local:magazine?.userData?.restPosition??magazine?.position.toArray()??null},snapshots,final});
  // The sampler needs the original magazine position, not the final pulled node.
  if(magazine){const fresh=createWeaponModel({THREE,id:spec.id});cases.at(-1).weapon.reload_magazine_local=fresh.children.find(n=>/^(magazine|drum_magazine)$/.test(n.name)).position.toArray();fresh.traverse(n=>n.geometry?.dispose());}
 }
 hero.mountWeapon(null);weapon.traverse(n=>n.geometry?.dispose());
}
const hash=v=>createHash('sha256').update(v).digest('hex');
const inputs=['hero_walk.mjs','hero_arsenal.mjs','hero_posture.mjs','hero_motion_presentation.mjs'].map(file=>({path:'assets/maps/city_rebuild_v1/'+file,sha256:hash(fs.readFileSync(path.join(root,'assets/maps/city_rebuild_v1',file),'utf8').replaceAll('\r\n','\n'))}));
const controller=[];const state=createHeroPosture();
for(const input of [{target:'prone',dt:.2},{dt:.2},{dt:.2},{dt:.2},{dt:.2},{target:'stand',dt:.1,ceiling:.9},{target:'crouch',dt:.1,ceiling:1.7},{dt:.1,ceiling:.8},{dt:.15,ceiling:1.7},{dt:.2,ceiling:1.7},{dt:.2,ceiling:1.7},{target:'stand',dt:.3},{dt:0},{target:'prone',dt:3}]){
 const queried=[];const allowed=(height,target)=>{queried.push({height,target});return height<=(input.ceiling??3)};
 const accepted=input.target?requestHeroPosture(state,input.target,{canOccupyHeight:allowed}):null;
 const output=stepHeroPosture(state,input.dt,{canOccupyHeight:allowed});controller.push({input,accepted,queried,output});
}
const data={schema:'mafiozi.weapon-posture-oracle/v1',source_hash_normalization:'crlf_to_lf',source_inputs:inputs,asset_sha256:hash(asset),instrumentation:'Read-only stage callbacks injected in memory; all original pose function statements unchanged; full original hero.update executes weapon/reload/head/floor.',names,parents,rest,rest_rig_to_actor:restRigToActor,rest_offset_to_actor:restOffsetToActor,cases,controller};
const out=path.join(root,'outputs/coordinator22_weapon_posture');fs.mkdirSync(out,{recursive:true});fs.writeFileSync(path.join(out,'oracle.json'),JSON.stringify(data));assert.equal(fs.readFileSync(sourcePath,'utf8'),original);hero.dispose();
console.log(JSON.stringify({cases:cases.length,oracle_sha256:hash(fs.readFileSync(path.join(out,'oracle.json'))),source_inputs:inputs}));
