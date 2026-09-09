import assert from 'node:assert/strict';
import fs from 'node:fs';
import path from 'node:path';
import {fileURLToPath,pathToFileURL} from 'node:url';
import {registerHooks} from 'node:module';
import {createHeroWalker} from './hero_walk.mjs';
import {ARSENAL,createWeaponModel} from './hero_arsenal.mjs';
import {createHeroCover} from './hero_cover_host.mjs';
import {resolveWeaponShotTransforms} from './weapon_effects.mjs';

const here=path.dirname(fileURLToPath(import.meta.url));
const vendor=process.env.MAFIOZI_THREE_VENDOR??'D:/codex_release/artist13_hero_first_DEV_20260907/demo/vendor';
registerHooks({resolve(s,c,n){return n(s==='three'?pathToFileURL(path.join(vendor,'build/three.module.js')).href:s,c);}});
const THREE=await import(pathToFileURL(path.join(vendor,'build/three.module.js')));
const {GLTFLoader}=await import(pathToFileURL(path.join(vendor,'addons/loaders/GLTFLoader.js')));
const quick=process.env.COVER_CLEARANCE_QUICK==='1';
const fps=Number(process.env.COVER_CLEARANCE_FPS)||30,modeFrames=Math.ceil(fps*.8);
const failures=[],failureKinds=new Map();let frames=0,scenarios=0,clearFireFrames=0,maxGunStep=0;
const ray=new THREE.Raycaster(),v=new THREE.Vector3();
const bodyParts=new Set(['head','neck','chest']);
function record(kind,context,detail){
  const entry={kind,...context,...detail};
  failureKinds.set(kind,(failureKinds.get(kind)||0)+1);
  if(failures.length<24){failures.push(entry);console.log('CLEARANCE_FAILURE '+JSON.stringify(entry));}
}

const modelFiles={male:'player_male.8130dfb1f7eb.glb',female:'player_female.298d50e6244a.glb'};
const models=process.env.COVER_CLEARANCE_MODELS?.split(',').map(name=>modelFiles[name]||name)||(quick?[modelFiles.male]:Object.values(modelFiles));
for(const model of models){
  const bytes=fs.readFileSync(path.join(here,'hero_models',model));
  const source=(await new GLTFLoader().parseAsync(bytes.buffer.slice(bytes.byteOffset,bytes.byteOffset+bytes.byteLength),'')).scene;
  const hero=createHeroWalker({THREE,scene:source}),context=hero.artistContext(),meshes=[],posedMeshes=[];
  source.traverse(mesh=>{if(!mesh.isSkinnedMesh)return;
    const materials=Array.isArray(mesh.material)?mesh.material:[mesh.material];for(const mat of materials)mat.side=THREE.DoubleSide;
    const {skinIndex,skinWeight}=mesh.geometry.attributes;
    const influence=[];
    for(let i=0;i<skinIndex.count;i++){
      const weights={head:0,neck:0,chest:0};
      for(let j=0;j<4;j++){const bone=mesh.skeleton.bones[skinIndex.getComponent(i,j)]?.name;if(bodyParts.has(bone))weights[bone]+=skinWeight.getComponent(i,j);}
      influence.push(weights);
    }
    const indices=[],used=new Set(),index=mesh.geometry.index;
    for(let i=0;i<(index?.count||skinIndex.count);i+=3){
      const tri=[0,1,2].map(j=>index?index.getX(i+j):i+j);
      if([...bodyParts].some(name=>tri.reduce((s,n)=>s+influence[n][name],0)>.9))for(const n of tri){indices.push(n);used.add(n);}
    }
    const geometry=new THREE.BufferGeometry();geometry.setAttribute('position',new THREE.BufferAttribute(new Float32Array(skinIndex.count*3),3));geometry.setIndex(indices);
    const posed=new THREE.Mesh(geometry,new THREE.MeshBasicMaterial({side:THREE.DoubleSide}));posed.matrixAutoUpdate=false;
    posed.userData.clearanceInfluence=influence;
    mesh.userData.clearanceInfluence=influence;mesh.userData.clearanceSnapshot={posed,used:[...used]};meshes.push(mesh);posedMeshes.push(posed);
  });
  function part(hit){
    const weights=hit.object.userData.clearanceInfluence;
    for(const name of ['head','neck','chest'])if([hit.face.a,hit.face.b,hit.face.c].reduce((s,i)=>s+weights[i][name],0)>.9)return name;
    return null;
  }
  const headBounds=new THREE.Box3();
  function prepareSkin(){
    hero.object.updateMatrixWorld(true);headBounds.makeEmpty();
    for(const mesh of meshes){
      mesh.skeleton.update();
      // Snapshot actual skinned vertices once per frame. Repeated raycasts use
      // these deformed triangles and freshly computed bounds, avoiding THREE's
      // stale rest-pose broadphase and redundant skinning for every gun vertex.
      const {posed,used}=mesh.userData.clearanceSnapshot,positions=posed.geometry.attributes.position;
      posed.matrixWorld.copy(mesh.matrixWorld);
      const weights=mesh.userData.clearanceInfluence;
      for(const i of used){mesh.getVertexPosition(i,v);positions.setXYZ(i,v.x,v.y,v.z);if(weights[i].head>.5){v.applyMatrix4(mesh.matrixWorld);headBounds.expandByPoint(v);}}
      posed.geometry.computeBoundingBox();posed.geometry.computeBoundingSphere();
    }
    assert.ok(!headBounds.isEmpty());
  }
  function cast(origin,direction,length){
    ray.set(origin,direction);ray.near=.002;ray.far=length;
    return ray.intersectObjects(posedMeshes,false).filter(hit=>part(hit));
  }
  function segment(from,to){const d=to.clone().sub(from),length=d.length();return length>.002?cast(from,d.divideScalar(length),length):[];}
  function insideHead(point){
    if(!headBounds.containsPoint(point))return false;
    // A point must be enclosed by actual posed head triangles along all three
    // axes, rather than merely lying in its generously sized AABB.
    for(const axis of [new THREE.Vector3(1,0,0),new THREE.Vector3(0,1,0),new THREE.Vector3(0,0,1)]){
      const a=cast(point,axis,2).find(hit=>part(hit)==='head');
      const b=cast(point,axis.clone().negate(),2).find(hit=>part(hit)==='head');
      if(!a||!b||a.distance<.008||b.distance<.008)return false;
    }
    return true;
  }
  let weapon,body,posture={target:'stand',value:0};
  const document={body:{dataset:{},append(){}},createElement:()=>({style:{},setAttribute(){}})};
  const scene=new THREE.Scene();scene.add(hero.object);
  const controller=createHeroCover({THREE,document,getHero:()=>hero,getWeapon:()=>weapon,getBodies:()=>[body],canOccupy:()=>true,allowed:()=>true,
    requestPosture(target){posture.target=target;},getPosture:()=>posture,onMove(){},onEnter(){},obstacles:()=>[],groundHeight:()=>0});
  const ids=process.env.COVER_CLEARANCE_WEAPONS?.split(',')||(quick?['shotgun']:ARSENAL.filter(w=>w.id!=='none').map(w=>w.id));
  for(const id of ids){
    const beforeFireFrames=clearFireFrames;
    weapon=createWeaponModel(THREE,id);hero.mountWeapon(weapon);
    const weaponSamples=[];
    weapon.traverse(mesh=>{if(!mesh.isMesh)return;mesh.geometry.computeBoundingBox();const box=mesh.geometry.boundingBox;
      const points=[box.getCenter(new THREE.Vector3())];
      // Authored vertices (not bounding-box corners) detect a receiver, stock or
      // barrel penetrating the head, including when the muzzle already cleared.
      const attr=mesh.geometry.attributes.position,stride=Math.max(1,Math.floor(attr.count/16));
      for(let i=0;i<attr.count;i+=stride)points.push(new THREE.Vector3().fromBufferAttribute(attr,i));
      weaponSamples.push({mesh,points});
    });
    for(const low of [false,true])for(const side of [-1,1])for(const yaw of (quick?[0]:[0,.73,-1.9]))for(const pitch of (quick?[0,.3,.7]:[-.7,-.3,0,.3,.7])){
      if(low&&side>0)continue; // Low cover uses its midpoint; do not duplicate it.
      controller.leave();hero.reset();posture={target:'stand',value:0};
      const rotate=p=>({x:p.x*Math.cos(yaw)+p.z*Math.sin(yaw)+20,z:-p.x*Math.sin(yaw)+p.z*Math.cos(yaw)-7});
      const polygon=[{x:0,z:0},{x:6,z:0},{x:6,z:2},{x:0,z:2}].map(rotate);
      body={id:'clearance-fixture',polygon,minY:0,maxY:low?1.1:3,vehicle:low,valid:true};
      const start=rotate({x:low?3:side<0?.14:5.86,z:-1});hero.object.position.set(start.x,0,start.z);
      const direction={x:Math.sin(yaw),z:Math.cos(yaw)};
      assert.equal(controller.toggle(direction),true);
      scenarios++;
      let previousGun=null;
      // Retain the preceding mode's real state to include pose transitions and
      // posture interpolation, rather than resetting to isolated snapshots.
      for(const mode of ['hidden','aimed','blind','hidden'])for(let frame=0;frame<modeFrames;frame++){
        const dt=1/fps;
        controller.update(dt,{direction,aiming:mode==='aimed',firing:mode==='blind'});
        const target=posture.target==='crouch'?1:0;posture.value+=Math.max(-2.1*dt,Math.min(2.1*dt,target-posture.value));
        const baseAim=controller.mode==='aimed'?{aimYaw:yaw,aimPitch:pitch}:{aimYaw:hero.object.rotation.y,aimPitch:0};
        // Match /walk's pre-shot pass and its dt=0 cover reapplication after
        // the regular animated update. Concealed base poses face outward.
        hero.update(0,false,false,weapon,baseAim,{posture});
        controller.pose({aimYaw:yaw,aimPitch:pitch});
        hero.update(dt,false,false,weapon,baseAim,{posture});
        controller.pose({aimYaw:yaw,aimPitch:pitch});
        const ctx={model,id,low,side,yaw,pitch,mode,frame,fps,canFire:controller.canFire};
        const gunNow=weapon.getWorldPosition(new THREE.Vector3());
        if(previousGun){const step=gunNow.distanceTo(previousGun);maxGunStep=Math.max(maxGunStep,step);if(step>=.5*30/fps)record('weapon_motion_jump',ctx,{step,limit:.5*30/fps});}
        previousGun=gunNow;
        // Settled pose and samples throughout both entering and leaving cover.
        const sampleFrames=[0,Math.round(fps*.1),Math.round(fps*8/30),Math.round(fps*16/30),modeFrames-1];
        const auditFrames=process.env.COVER_CLEARANCE_STEADY==='1'?[modeFrames-1]:quick||yaw===0&&pitch===0?sampleFrames:[sampleFrames[1],modeFrames-1];
        if(!auditFrames.includes(frame))continue;
        frames++;prepareSkin();
        const transforms=resolveWeaponShotTransforms(THREE,weapon),mount=weapon.getWorldPosition(new THREE.Vector3());
        if(['aimed','blind'].includes(mode)){
          const forward=new THREE.Vector3(0,0,1).applyQuaternion(weapon.getWorldQuaternion(new THREE.Quaternion())).normalize();
          const hits=cast(transforms.origin,forward,1.5);
          if(hits.length)record('muzzle_points_into_body',ctx,{part:part(hits[0]),distance:hits[0].distance,muzzle:transforms.origin.toArray()});
          else if(controller.canFire)clearFireFrames++;
        }
        const barrel=segment(mount,transforms.origin);
        if(barrel.some(hit=>part(hit)==='head'||part(hit)==='neck'))record('barrel_through_head_or_neck',ctx,{part:part(barrel[0]),mount:mount.toArray(),muzzle:transforms.origin.toArray()});
        let embedded=null;
        for(const {mesh,points}of weaponSamples){
          for(const point of points){const world=mesh.localToWorld(point.clone());if(insideHead(world)){embedded={mesh:mesh.name,point:world.toArray()};break;}}
          if(embedded)break;
        }
        if(embedded)record('weapon_inside_head',ctx,embedded);
      }
    }
    console.log(`AUDITED ${model} ${id}: ${frames} frames; clearFireFrames ${clearFireFrames-beforeFireFrames}; failures ${[...failureKinds.values()].reduce((a,b)=>a+b,0)}`);
  }
  controller.leave();
}
console.log(JSON.stringify({scenarios,frames,fps,maxGunStep,clearFireFrames,failures:Object.fromEntries(failureKinds),examples:failures}));
assert.equal([...failureKinds.values()].reduce((a,b)=>a+b,0),0,'Cover weapons must clear the posed head/neck and never aim into the body');
