import assert from 'node:assert/strict';
import fs from 'node:fs';
import {pathToFileURL} from 'node:url';
import {registerHooks} from 'node:module';
import {createHeroWalker} from './hero_walk.mjs';
import {ARSENAL,createWeaponModel} from './hero_arsenal.mjs';
import {weaponHeadClearance,findClearWeaponMount} from './hero_weapon_clearance.mjs';
const vendor=process.env.MAFIOZI_THREE_VENDOR??'D:/codex_release/artist13_hero_first_DEV_20260907/demo/vendor';
registerHooks({resolve(s,c,n){return n(s==='three'?pathToFileURL(vendor+'/build/three.module.js').href:s,c);}});
const T=await import(pathToFileURL(vendor+'/build/three.module.js'));
const {GLTFLoader}=await import(pathToFileURL(vendor+'/addons/loaders/GLTFLoader.js'));
let cases=0,solved=0,maxCorrection=0,maxCandidates=0;
for(const model of ['player_male.8130dfb1f7eb.glb','player_female.298d50e6244a.glb']){
  const bytes=fs.readFileSync(new URL('./hero_models/'+model,import.meta.url));
  const hero=createHeroWalker({THREE:T,scene:(await new GLTFLoader().parseAsync(bytes.buffer.slice(bytes.byteOffset,bytes.byteOffset+bytes.byteLength),'')).scene}),c=hero.artistContext();
  for(const item of ARSENAL.filter(w=>w.id!=='none')){
    const weapon=createWeaponModel(T,item.id);hero.mountWeapon(weapon);
    for(const pitch of [-.45,0,.45]){
      hero.reset();hero.object.position.set(3,.7,-8);hero.object.rotation.y=.71;
      hero.update(0,false,false,weapon,{aimYaw:.71,aimPitch:pitch},{posture:{value:0,target:'stand'}});
      const quaternion=new T.Quaternion().setFromEuler(new T.Euler(-pitch,.71,0,'YXZ'));
      const origin=c.worldPosition('head').add(new T.Vector3(0,.08,0));
      const root=hero.object.position.clone(),boneMatrices=Object.values(c.bones).map(b=>b.matrix.clone()),weaponPosition=weapon.position.clone();
      const unsafe=weaponHeadClearance(T,c,weapon,{origin,quaternion});assert.equal(unsafe.clear,false,`${model} ${item.id}: own-head mount must be rejected`);
      assert.equal(weaponHeadClearance(T,c,weapon,{origin:origin.clone().add(new T.Vector3(4,0,0)),quaternion}).clear,true,'a distant clear gun must remain clear');
      const scale=hero.scale,grips=[['r',[0,-.13,-.02]],...(item.twoHanded?[['l',weapon.userData.supportGrip]]:[])];
      const constraints=grips.map(([side,grip])=>{
        const shoulder=c.worldPosition('upperarm_'+side),radius=shoulder.distanceTo(c.worldPosition('forearm_'+side))+c.worldPosition('forearm_'+side).distanceTo(c.worldPosition('hand_'+side))-.04;
        return {center:shoulder.sub(new T.Vector3(...grip).multiplyScalar(scale).applyQuaternion(quaternion)),radius};
      });
      const result=findClearWeaponMount(T,c,weapon,{origin,quaternion,constraints,preferredSide:-1});
      assert.ok(result.clear,`${model} ${item.id} pitch${pitch}: reachable clear position required`);
      assert.ok(weaponHeadClearance(T,c,weapon,{origin:result.origin,quaternion}).clear);
      for(const {center,radius}of constraints)assert.ok(result.origin.distanceTo(center)<=radius+.001,'solution cannot stretch either arm');
      assert.ok(hero.object.position.equals(root)&&weapon.position.equals(weaponPosition),'solver cannot mutate root or weapon');
      Object.values(c.bones).forEach((bone,i)=>assert.deepEqual(bone.matrix.elements,boneMatrices[i].elements,'solver cannot change bone pose'));
      maxCorrection=Math.max(maxCorrection,result.correction);maxCandidates=Math.max(maxCandidates,result.candidates);cases++;solved++;
    }
  }
}
console.log(JSON.stringify({passed:true,cases,solved,maxCorrection,maxCandidates}));
