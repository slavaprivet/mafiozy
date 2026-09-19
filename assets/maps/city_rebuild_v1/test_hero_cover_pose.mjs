import assert from 'node:assert/strict';
import fs from 'node:fs';
import path from 'node:path';
import {fileURLToPath,pathToFileURL} from 'node:url';
import {registerHooks} from 'node:module';
import {createHeroWalker} from './hero_walk.mjs';
import {HERO_POSTURES} from './hero_posture.mjs';
import {applyCoverPose,COVER_MODE_TRANSITION_DURATION} from './hero_cover_pose.mjs';
import {createHeroCover} from './hero_cover_host.mjs';
import {createWeaponModel} from './hero_arsenal.mjs';
const here=path.dirname(fileURLToPath(import.meta.url));
const vendor=process.env.MAFIOZI_THREE_VENDOR??'D:/codex_release/artist13_hero_first_DEV_20260907/demo/vendor';
registerHooks({resolve(s,c,n){return n(s==='three'?pathToFileURL(path.join(vendor,'build/three.module.js')).href:s,c);}});
const THREE=await import(pathToFileURL(path.join(vendor,'build/three.module.js')));
const {GLTFLoader}=await import(pathToFileURL(path.join(vendor,'addons/loaders/GLTFLoader.js')));
let cases=0,maxGripError=0,minFloor=Infinity,maxStep=0,maxTuckStep=0,maxCrouchSkinY=-Infinity,maxBaseCrouchSkinY=-Infinity,maxBlindHeadY=-Infinity,transitionFrames=0,maxTransitionGunStep=0;
for(const model of ['player_male.8130dfb1f7eb.glb','player_female.298d50e6244a.glb']){
  const bytes=fs.readFileSync(path.join(here,'hero_models',model));
  const source=(await new GLTFLoader().parseAsync(bytes.buffer.slice(bytes.byteOffset,bytes.byteOffset+bytes.byteLength),'')).scene;
  const hero=createHeroWalker({THREE,scene:source}),c=hero.artistContext(),meshes=[];
  source.traverse(n=>{if(n.isSkinnedMesh)meshes.push(n);});
  const tuckedIndices=[];let skinOffset=0;
  for(const mesh of meshes){const a=mesh.geometry.attributes;
    for(let i=0;i<a.position.count;i++){let weight=0;for(let j=0;j<4;j++)if(['head','neck'].includes(mesh.skeleton.bones[a.skinIndex.getComponent(i,j)].name))weight+=a.skinWeight.getComponent(i,j);if(weight>.5)tuckedIndices.push((skinOffset+i)*3);}
    skinOffset+=a.position.count;
  }
  function skin(){
    c.object.updateMatrixWorld(true);const out=[],v=new THREE.Vector3();
    for(const mesh of meshes){mesh.skeleton.update();for(let i=0;i<mesh.geometry.attributes.position.count;i++){
      v.fromBufferAttribute(mesh.geometry.attributes.position,i);mesh.applyBoneTransform(i,v);v.applyMatrix4(mesh.matrixWorld);
      assert.ok([v.x,v.y,v.z].every(Number.isFinite));minFloor=Math.min(minFloor,v.y-hero.object.position.y);out.push(v.x,v.y,v.z);
    }}return out;
  }
  // Exercise ordinary C crouch with no cover or weapon, including locomotion.
  for(const moving of [false,true]){
    hero.reset();hero.object.position.set(0,0,0);
    for(let i=0;i<=60;i++){
      hero.update(1/60,moving,false,null,{aimYaw:0,aimPitch:0},{posture:{target:'crouch',value:Math.min(1,i/30)}});
      const current=skin();
      if(i>=30)for(let j=1;j<current.length;j+=3)maxBaseCrouchSkinY=Math.max(maxBaseCrouchSkinY,current[j]);
    }
  }
  for(const id of ['tt_pistol','uzi','ak74','rpg']){
    const weapon=createWeaponModel(THREE,id);hero.mountWeapon(weapon);
    for(const low of [false,true])for(const yaw of [0,.71,-2])for(const side of [-1,1])for(const mode of ['hidden','blind','blocked','aimed']){
      let previous=null;
      for(const blend of Array.from({length:17},(_,i)=>i/16)){
        hero.reset();hero.object.position.set(13,.8,-7);hero.object.rotation.y=yaw;
        const threatYaw=yaw+Math.PI,crouched=low&&mode!=='aimed';
        hero.update(0,false,false,weapon,{aimYaw:yaw,aimPitch:0},{posture:{target:crouched?'crouch':'stand',value:crouched?1:0}});
        const root=hero.object.position.clone(),q=hero.object.quaternion.clone(),feet=['foot_l','foot_r'].map(n=>c.worldPosition(n));
        const baseBones=Object.fromEntries(Object.entries(c.bones).map(([n,b])=>{const p=new THREE.Vector3(),q=new THREE.Quaternion(),s=new THREE.Vector3();b.matrix.decompose(p,q,s);return [n,{p,s}];}));
        const normal=new THREE.Vector3(Math.sin(yaw),0,Math.cos(yaw)),tangent=new THREE.Vector3(-normal.z,0,normal.x);
        const muzzle=hero.object.position.clone().addScaledVector(normal,low?-.3:-.15).addScaledVector(tangent,low?0:side*.36);muzzle.y+=low?1.32:1.50;
        const aimQ=new THREE.Quaternion().setFromEuler(new THREE.Euler(-.1,threatYaw,0,'YXZ'));
        const origin=muzzle.sub(new THREE.Vector3(...weapon.userData.muzzle).multiply(weapon.getWorldScale(new THREE.Vector3())).applyQuaternion(aimQ));
        const output=applyCoverPose(THREE,c,{mode,low,normal:{x:normal.x,z:normal.z},side,blend,weapon,gunPosition:origin,aimYaw:threatYaw,aimPitch:.1});
        assert.equal(output.applied,true);assert.ok(hero.object.position.distanceTo(root)<1e-9);assert.ok(hero.object.quaternion.angleTo(q)<1e-7);
        for(const [i,name]of ['foot_l','foot_r'].entries())assert.ok(Math.abs(c.worldPosition(name).y-feet[i].y)<1e-8,'turn preserves grounded foot height');
        for(const [name,bone]of Object.entries(c.bones)){
          const p=new THREE.Vector3(),q=new THREE.Quaternion(),s=new THREE.Vector3();bone.matrix.decompose(p,q,s);
          assert.ok(p.distanceTo(baseBones[name].p)<1e-8&&s.distanceTo(baseBones[name].s)<1e-6,`bones cannot stretch or move: ${name}`);
        }
        const grips=[['r',[0,-.13,-.02]],...(weapon.userData.twoHanded?[['l',weapon.userData.supportGrip]]:[])];
        for(const [s,point]of grips){const error=c.worldPosition('socket_hand_'+s).distanceTo(weapon.localToWorld(new THREE.Vector3(...point)));maxGripError=Math.max(maxGripError,error);assert.ok(error<.002,`${model} ${id} ${mode} ${blend} ${s} grip ${error}`);}
        const current=skin();
        // Stateless blend snapshots test the duck itself. Weapon clearance can
        // select different valid mounts; continuity of that stateful motion is
        // checked below through the real controller at 30/60/144 fps.
        if(previous){let step=0,tuckStep=0;for(let i=0;i<current.length;i+=3)step=Math.max(step,Math.hypot(current[i]-previous[i],current[i+1]-previous[i+1],current[i+2]-previous[i+2]));for(const i of tuckedIndices)tuckStep=Math.max(tuckStep,Math.hypot(current[i]-previous[i],current[i+1]-previous[i+1],current[i+2]-previous[i+2]));maxStep=Math.max(maxStep,step);maxTuckStep=Math.max(maxTuckStep,tuckStep);assert.ok(tuckStep<.18,`${mode} ${id} head/neck tuck step ${tuckStep}`);}
        if(low&&mode==='hidden'&&blend===1)for(let i=1;i<current.length;i+=3)maxCrouchSkinY=Math.max(maxCrouchSkinY,current[i]-.8);
        previous=current;cases++;
      }
    }
    // Real over-cover target supplied by the host: muzzle clears a 1.1 m top.
    hero.reset();hero.object.position.set(3,0,-.48);hero.object.rotation.y=Math.PI;
    hero.update(0,false,false,weapon,{aimYaw:0,aimPitch:0},{posture:{target:'crouch',value:1}});
    const muzzle=new THREE.Vector3(3,1.32,-.18),mount=muzzle.clone().sub(new THREE.Vector3(...weapon.userData.muzzle).multiply(weapon.getWorldScale(new THREE.Vector3())));
    const over=applyCoverPose(THREE,c,{mode:'blind',low:true,normal:{x:0,z:-1},coverHeight:1.1,blend:1,weapon,gunPosition:mount,aimYaw:0,aimPitch:0});
    assert.ok(over.requestedReachable,`${model} ${id} blind over-cover reach: ${over.reachCorrection}`);
    assert.ok(Math.abs(c.visualPivot.rotation.y)<1e-8,'concealed torso keeps back against wall');
    const actualMuzzle=weapon.localToWorld(new THREE.Vector3(...weapon.userData.muzzle));
    assert.ok(actualMuzzle.y>1.1+.05,`${model} ${id} real muzzle remains over the solid cover top: ${actualMuzzle.y}`);
    for(const [s,p]of [['r',[0,-.13,-.02]],...(weapon.userData.twoHanded?[['l',weapon.userData.supportGrip]]:[])]){
      assert.ok(c.worldPosition('socket_hand_'+s).distanceTo(weapon.localToWorld(new THREE.Vector3(...p)))<.002,'raised gun retains both authored grips');
    }
    skin();
    for(const mesh of meshes){
      const indices=mesh.geometry.attributes.skinIndex,weights=mesh.geometry.attributes.skinWeight;
      for(let i=0;i<indices.count;i++){
        let head=0;for(let j=0;j<4;j++)if(['head','neck'].includes(mesh.skeleton.bones[indices.getComponent(i,j)].name))head+=weights.getComponent(i,j);
        if(head<.5)continue;
        const v=new THREE.Vector3().fromBufferAttribute(mesh.geometry.attributes.position,i);mesh.applyBoneTransform(i,v);v.applyMatrix4(mesh.matrixWorld);maxBlindHeadY=Math.max(maxBlindHeadY,v.y);
      }
    }
    hero.update(0,false,false,weapon,{},{});
    const far=applyCoverPose(THREE,c,{mode:'blind',blend:1,weapon,gunPosition:{x:90,y:90,z:90}});
    assert.equal(far.requestedReachable,false,'unreachable muzzle cannot authorize firing');assert.ok(far.reachCorrection>100);
    for(const fps of [30,60,144]){
      const document={body:{dataset:{},append(){}},createElement:()=>({style:{},setAttribute(){}})};
      const posture={target:'crouch',value:1};
      const body={id:'mode-transition-cover',minY:0,maxY:1.1,vehicle:true,valid:true,polygon:[{x:0,z:0},{x:6,z:0},{x:6,z:2},{x:0,z:2}]};
      hero.reset();hero.object.position.set(3,0,-.6);
      const cover=createHeroCover({THREE,document,getHero:()=>hero,getWeapon:()=>weapon,getBodies:()=>[body],canOccupy:()=>true,allowed:()=>true,
        requestPosture(target){posture.target=target;},getPosture:()=>posture,onMove(){},onEnter(){},obstacles:()=>[],groundHeight:()=>0});
      assert.equal(cover.toggle({x:0,z:1}),true);
      const basePose=()=>hero.update(0,false,false,weapon,{aimYaw:hero.object.rotation.y,aimPitch:0},{posture});
      let previous=null,lastMode=null,modeElapsed=0;
      for(const mode of ['hidden','blind','aimed','blind','hidden']){
        for(let i=0;i<=Math.ceil(fps*.90);i++){
          const dt=i===0?0:1/fps;
          cover.update(dt,{direction:{x:0,z:1},aiming:mode==='aimed',firing:mode==='blind'});
          const changed=cover.mode!==lastMode;modeElapsed=changed?0:modeElapsed+dt;
          posture.value+=Math.max(-2.1*dt,Math.min(2.1*dt,(posture.target==='crouch'?1:0)-posture.value));
          basePose();const output=cover.pose({aimYaw:0,aimPitch:0}),origin=weapon.getWorldPosition(new THREE.Vector3());
          if(changed)assert.equal(output.transitionReady,false,'new mode waits for transition');
          if(modeElapsed>=(mode==='hidden'?.85:.60))assert.equal(output.transitionReady,true,`safe transition must settle, not freeze: ${id} ${fps} ${mode} ${i} ${JSON.stringify(output)}`);
          if(modeElapsed>=.60&&['aimed','blind'].includes(mode)&&['tt_pistol','uzi'].includes(id))assert.ok(cover.canFire,`actual low cover fires ${model} ${id} ${fps} ${mode} ${JSON.stringify(output)}`);
          if(previous){const step=origin.distanceTo(previous);maxTransitionGunStep=Math.max(maxTransitionGunStep,step);assert.ok(step<.5*30/fps,`weapon mode transition step ${id} ${fps} ${mode} ${i}: ${step}`);if(changed&&dt===0)assert.ok(step<.015,'mode change starts at previous gun position');}
          previous=origin;
          lastMode=cover.mode;
          for(const [s,p]of [[output.shootingHand||'r',[0,-.13,-.02]],...(weapon.userData.twoHanded?[['l',weapon.userData.supportGrip]]:[])])assert.ok(c.worldPosition('socket_hand_'+s).distanceTo(weapon.localToWorld(new THREE.Vector3(...p)))<.003,`${id} transition grips remain exact`);
          // The actual host resets its base animation before the second pass.
          const before=origin.clone();basePose();
          const repeated=cover.pose({aimYaw:0,aimPitch:0});
          assert.equal(repeated.transitionReady,output.transitionReady,'zero dt does not advance readiness');
          assert.ok(weapon.getWorldPosition(new THREE.Vector3()).distanceTo(before)<1e-6,'zero dt render pass is idempotent');
          transitionFrames++;
        }
      }
      cover.leave();assert.equal(cover.toggle({x:0,z:1}),true);cover.update(0,{direction:{x:0,z:1},aiming:false,firing:false});basePose();
      const restarted=cover.pose({aimYaw:0,aimPitch:0});
      assert.equal(restarted.transitionReady,false,'new attachment has independent transition');
      cover.leave();
    }
  }
}
assert.ok(maxCrouchSkinY<=HERO_POSTURES.crouch.height,`hidden crouch fits its capsule: ${maxCrouchSkinY}`);
assert.ok(maxBaseCrouchSkinY<=HERO_POSTURES.crouch.height,`ordinary C crouch fits its capsule: ${maxBaseCrouchSkinY}`);
assert.ok(maxBlindHeadY<=1.1,`blind-fire head stays behind 1.1 m cover: ${maxBlindHeadY}`);
assert.ok(minFloor>-.012,`skin cannot sink under floor: ${minFloor}`);
assert.equal(applyCoverPose(THREE,null,{}).applied,false);
console.log(JSON.stringify({passed:true,cases,maxGripError,minFloor,maxStep,maxTuckStep,maxCrouchSkinY,maxBaseCrouchSkinY,maxBlindHeadY,transitionFrames,maxTransitionGunStep,checks:['male_and_female_actual_GLB','pistol_uzi_rifle_rpg','standing_and_crouched','all_cover_modes','pose_blends','head_neck_tuck_continuity','both_authored_weapon_grips','root_and_grounded_foot_height_preserved','bone_length_scale_preserved','unreachable_mount_rejected','ordinary_crouch_capsule_and_gait','blind_over_1.1m_cover','concealed_head_during_blind_fire','actual_host_mode_transitions_30_60_144fps','zero_dt_second_pass','attachment_reset']}));
