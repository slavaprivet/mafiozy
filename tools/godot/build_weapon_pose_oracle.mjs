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
const marker='reset();return{artistContext,sampleMeleeContactPose';
assert.equal(original.split(marker).length,2);
// Expose original private functions in memory only. Their bodies are untouched.
const exposed=original.replace(marker,'reset();return{__weapon:weaponPose,__reload:applyReloadPose,__look:lookAlongAim,__state:(p,g)=>{phase=p;gait=g},__handRest:handRest,__headRest:headRest,artistContext,sampleMeleeContactPose');
registerHooks({resolve(s,c,n){return n(s==='three'?pathToFileURL(path.join(vendor,'build/three.module.js')).href:s,c)},
  load(url,c,n){return url===pathToFileURL(sourcePath).href?{format:'module',source:exposed,shortCircuit:true}:n(url,c)}});
const THREE=await import(pathToFileURL(path.join(vendor,'build/three.module.js')));
const {GLTFLoader}=await import(pathToFileURL(path.join(vendor,'addons/loaders/GLTFLoader.js')));
const {createHeroWalker}=await import(pathToFileURL(sourcePath));
const {ARSENAL,createWeaponModel}=await import(pathToFileURL(path.join(root,'assets/maps/city_rebuild_v1/hero_arsenal.mjs')));
const asset=fs.readFileSync(path.join(root,'godot/mafiozi_walk/assets/hero.glb'));
const scene=(await new GLTFLoader().parseAsync(asset.buffer.slice(asset.byteOffset,asset.byteOffset+asset.byteLength),'')).scene;
const hero=createHeroWalker({THREE,scene});const c=hero.artistContext();c.object.updateMatrixWorld(true);
const names=Object.keys(c.bones),parents=names.map(n=>names.indexOf(c.bones[n].parent.name));
assert.equal(names.length,28);assert(parents.every((p,i)=>p<i));
const rest=names.map(n=>c.rest[n].matrix.toArray());
const rootBone=c.bones[names[parents.indexOf(-1)]];
const restRigToActor=c.object.matrixWorld.clone().invert().multiply(rootBone.parent.matrixWorld).toArray();
const restOffsetToActor=c.object.matrixWorld.clone().invert().multiply(c.offset.matrixWorld).toArray();
const poses=()=>names.map(n=>c.bones[n].matrix.toArray());
const cases=[];
const modes=['stand','running','crouch','prone','jump','dive','landing','affine_stand','affine_prone','affine_landing'];
for(const spec of ARSENAL.filter(x=>x.id!=='none')){
  const weapon=createWeaponModel({THREE,id:spec.id});
  const magazine=weapon.children.find(n=>/^(magazine|drum_magazine)$/.test(n.name));
  const weaponData={id:spec.id,two_handed:spec.twoHanded,source_metadata:structuredClone(weapon.userData),reload_magazine_local:magazine?.position.toArray()??null};
  for(const mode of modes)for(const [aimPitch,reloadProgress,recoil] of [[0,0,0],[-1.28,.5,.7],[.9,.83,.4]]){
    const baseMode=mode.replace(/^affine_/,'');
    hero.reset();hero.mountWeapon(weapon);c.object.position.set(4,2,-3);c.object.rotation.y=-.67;
    const posture={crouch:baseMode==='crouch'?.7:0,prone:baseMode==='prone'?.85:0};
    const moving=['running','prone','landing'].includes(baseMode),aimYaw=.6;
    if(baseMode==='jump'||baseMode==='dive')hero.jumpPose(.38,baseMode==='dive',null,{aimYaw,aimPitch,travelYaw:-.3});
    else hero.update(.08,moving,baseMode==='running',null,{aimYaw,aimPitch},{posture:{target:baseMode==='crouch'?'crouch':baseMode==='prone'?'prone':'stand',value:baseMode==='crouch'?.7:baseMode==='prone'?.85:0},motionSpeed:baseMode==='running'?5.8:3.2});
    if(mode.startsWith('affine_')){
      // Stress supplied affine base frames through the actual original functions.
      c.bones.chest.matrix.scale(new THREE.Vector3(1.04,.98,1.01));
      c.bones.forearm_r.matrix.elements[4]+=.07;
      c.bones.chest.matrixWorldNeedsUpdate=true;c.bones.forearm_r.matrixWorldNeedsUpdate=true;
    }
    const phase=1.17,gait=moving?.72:0;hero.__state(phase,gait);
    c.object.updateMatrixWorld(true);
    const frame={actor_world:c.object.matrixWorld.toArray(),actor_yaw:c.object.rotation.y,
      visual_pivot_world:c.visualPivot.matrixWorld.toArray(),skeleton_world:rootBone.parent.matrixWorld.toArray(),offset_world:c.offset.matrixWorld.toArray(),
      scaled_y:c.scaled.position.y,target_height:c.targetHeight,source_height:c.sourceHeight};
    const baseVisual={visual_offset:c.scaled.position.clone().applyQuaternion(c.visualPivot.quaternion).add(c.visualPivot.position).toArray(),visual_rotation:c.visualPivot.quaternion.toArray(),scaled_offset:c.scaled.position.toArray()};
    const aim={aimPitch,reloadProgress,recoil,recoilYaw:recoil?-.3:0,aimYaw,airborne:baseMode==='jump'||baseMode==='dive',airBlend:.65,landingAirBlend:baseMode==='landing'?.4:0};
    const base=poses();hero.__weapon(weapon,{...aim,posture});hero.__reload(weapon,reloadProgress,posture);hero.__look(aimYaw,aimPitch);
    c.object.updateMatrixWorld(true);
    cases.push({id:spec.id,mode,weapon:weaponData,frame,base_visual:baseVisual,aim,posture,phase,gait,base,selected:poses(),weapon_local:weapon.matrix.toArray(),weapon_world:weapon.matrixWorld.toArray(),
      palms:Object.fromEntries(['socket_hand_l','socket_hand_r'].map(name=>[name,c.bones[name].getWorldPosition(new THREE.Vector3()).toArray()]))});
  }
  hero.mountWeapon(null);weapon.traverse(n=>n.geometry?.dispose());
}
const hash=v=>createHash('sha256').update(v).digest('hex');
const inputs=['hero_walk.mjs','hero_arsenal.mjs','hero_motion_presentation.mjs'].map(file=>({path:'assets/maps/city_rebuild_v1/'+file,sha256:hash(fs.readFileSync(path.join(root,'assets/maps/city_rebuild_v1',file),'utf8').replaceAll('\r\n','\n'))}));
const data={schema:'mafiozi.weapon-pose-oracle/v1',source_hash_normalization:'crlf_to_lf',source_inputs:inputs,asset_sha256:hash(asset),
  instrumentation:'Private source functions exposed by return-property injection only; function bodies unchanged, source file immutable',
  names,parents,rest,rest_rig_to_actor:restRigToActor,rest_offset_to_actor:restOffsetToActor,hand_rest:Object.fromEntries(Object.entries(hero.__handRest).map(([name,q])=>[name,q.toArray()])),head_rest:hero.__headRest.toArray(),cases,
  scope:'Pure original weaponPose + applyReloadPose + lookAlongAim from supplied base pose; caller final groundPose excluded explicitly'};
const out=path.join(root,'outputs/coordinator22_weapon_pose');fs.mkdirSync(out,{recursive:true});fs.writeFileSync(path.join(out,'oracle.json'),JSON.stringify(data));
assert.equal(fs.readFileSync(sourcePath,'utf8'),original);hero.dispose();
console.log(JSON.stringify({cases:cases.length,source_inputs:inputs,oracle_sha256:hash(fs.readFileSync(path.join(out,'oracle.json')))}));
