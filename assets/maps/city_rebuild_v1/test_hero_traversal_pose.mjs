import assert from 'node:assert/strict';
import fs from 'node:fs';
import path from 'node:path';
import {fileURLToPath,pathToFileURL} from 'node:url';
import {registerHooks} from 'node:module';
import {createHeroWalker} from './hero_walk.mjs';
import {applyTraversalPose} from './hero_traversal_pose.mjs';
import {sampleTraversal} from './hero_traversal.mjs';
const here=path.dirname(fileURLToPath(import.meta.url));
const vendor=process.env.MAFIOZI_THREE_VENDOR ?? 'D:/codex_release/artist13_hero_first_DEV_20260907/demo/vendor';
registerHooks({resolve(s,c,n){return n(s==='three'?pathToFileURL(path.join(vendor,'build/three.module.js')).href:s,c);}});
const THREE=await import(pathToFileURL(path.join(vendor,'build/three.module.js')));
const {GLTFLoader}=await import(pathToFileURL(path.join(vendor,'addons/loaders/GLTFLoader.js')));
const bytes=fs.readFileSync(path.join(here,'hero_models/player_male.8130dfb1f7eb.glb'));
const source=(await new GLTFLoader().parseAsync(bytes.buffer.slice(bytes.byteOffset,bytes.byteOffset+bytes.byteLength),'')).scene;
const hero=createHeroWalker({THREE,scene:source}), c=hero.artistContext(), meshes=[];
source.traverse(n=>{if(n.isSkinnedMesh) meshes.push(n);});
assert.ok(meshes.length, 'exercise the authored GLB skin');
hero.object.position.set(13, .8, -7); hero.object.rotation.y=.71;
let snapshots=0,maxSkinStep=0;
function snapshot(){
  const vertices=[],v=new THREE.Vector3();hero.object.updateMatrixWorld(true);
  for(const mesh of meshes){mesh.skeleton.update();for(let i=0;i<mesh.geometry.attributes.position.count;i++){
    v.fromBufferAttribute(mesh.geometry.attributes.position,i);mesh.applyBoneTransform(i,v);v.applyMatrix4(mesh.matrixWorld);
    assert.ok([v.x,v.y,v.z].every(Number.isFinite),'finite skin');vertices.push(v.x,v.y,v.z);
  }}
  snapshots++;return vertices;
}
function distance(a,b){let max=0;for(let i=0;i<a.length;i+=3)max=Math.max(max,Math.hypot(a[i]-b[i],a[i+1]-b[i+1],a[i+2]-b[i+2]));return max;}
function pose(progress,kind,height,contacts=false){
  hero.reset();
  const direction={x:Math.sin(.71),z:Math.cos(.71)},sample={progress,kind,height,direction};
  if(contacts){for(const [key,side]of [['handL',-1],['handR',1]]) sample[key]={x:13+direction.x*.4+direction.z*.27*side,y:1.95,z:-7+direction.z*.4-direction.x*.27*side};}
  assert.equal(applyTraversalPose(THREE,c,sample),true);
  if(contacts && progress>=.22 && progress<=.68) for(const [key,side]of [['handL','l'],['handR','r']]) {
    const target=new THREE.Vector3(sample[key].x,sample[key].y,sample[key].z);
    assert.ok(c.worldPosition('socket_hand_'+side).distanceTo(target)<.035,'support palm remains planted on reachable ledge');
  }
  assert.deepEqual(hero.object.position.toArray(),[13,.8,-7]);assert.equal(hero.object.rotation.y,.71);
  for(const [name,bone]of Object.entries(c.bones)){
    const p=new THREE.Vector3(),q=new THREE.Quaternion(),s=new THREE.Vector3();bone.matrix.decompose(p,q,s);
    assert.ok(p.distanceTo(c.rest[name].p)<1e-8,`${name} bone length unchanged`);
    assert.ok(s.distanceTo(c.rest[name].s)<1e-6,`${name} bone scale unchanged: ${s.distanceTo(c.rest[name].s)}`);
  }
  return snapshot();
}
hero.reset();const rest=snapshot();
for(const kind of ['vault','mantle','shore'])for(const height of [.4,1.1,1.7])for(const contacts of [false,true]){
  assert.ok(distance(rest,pose(0,kind,height,contacts))<1e-8,'entry matches base');
  assert.ok(distance(rest,pose(1,kind,height,contacts))<1e-8,'exit matches standing base');
  let previous=pose(0,kind,height,contacts),peak=0;
  for(let i=1;i<=80;i++){
    const current=pose(i/80,kind,height,contacts),step=distance(previous,current);
    maxSkinStep=Math.max(maxSkinStep,step);peak=Math.max(peak,distance(rest,current));
    assert.ok(step<.18,`${kind} skin continuity at ${i/80}: ${step}`);previous=current;
  }
  assert.ok(peak>.3,'visibly articulated traversal');
}
let trajectorySnapshots=0,minSkinAboveRoot=Infinity,maxTrajectorySkinStep=0,maxContactImprovement=0;
for(const [kind,obstacleHeight,edgeDistance,destinationY] of [
  ['vault',.45,.45,0],['vault',1.1,.75,0],['mantle',.8,.45,.8],
  ['mantle',1.65,.8,1.65],['shore',.5,.7,.5],['shore',1.8,2.1,1.8],
  ['mantle',1.2,.35,1.2],
]) {
  const direction={x:Math.sin(.71),z:Math.cos(.71)},start={x:13,y:.8,z:-7};
  const point=(d,y)=>({x:start.x+direction.x*d,y:start.y+y,z:start.z+direction.z*d});
  const plan={kind,start,direction,edge:point(edgeDistance,obstacleHeight),destination:point(edgeDistance+.7,destinationY),clearanceY:start.y+obstacleHeight+.14};
  let previous=null;
  for(let i=0;i<=120;i++) {
    const sample={...plan,...sampleTraversal(plan,i/120)};
    hero.reset();hero.object.position.set(sample.x,sample.y,sample.z);
    applyTraversalPose(THREE,c,sample);
    assert.deepEqual(hero.object.position.toArray(),[sample.x,sample.y,sample.z],'trajectory root preserved');
    assert.equal(hero.object.rotation.y,.71);
    const skin=snapshot();trajectorySnapshots++;
    for(let v=1;v<skin.length;v+=3) minSkinAboveRoot=Math.min(minSkinAboveRoot,skin[v]-sample.y);
    assert.ok(minSkinAboveRoot>=-.012,`${kind}: skin below physical support plane ${minSkinAboveRoot}`);
    if(previous) maxTrajectorySkinStep=Math.max(maxTrajectorySkinStep,distance(previous,skin));
    assert.ok(maxTrajectorySkinStep<.18,`${kind} ${obstacleHeight} at ${i/120}: trajectory skin pop ${maxTrajectorySkinStep}`);
    previous=skin;
    for(const [name,bone]of Object.entries(c.bones)) {
      const pos=new THREE.Vector3(),q=new THREE.Quaternion(),scale=new THREE.Vector3();bone.matrix.decompose(pos,q,scale);
      assert.ok(pos.distanceTo(c.rest[name].p)<1e-8 && scale.distanceTo(c.rest[name].s)<1e-6,'trajectory bones neither stretch nor translate');
    }
    if(i===60) {
      hero.reset();applyTraversalPose(THREE,c,{...sample,edge:null,obstacleHeight});
      assert.ok(distance(skin,snapshot())<1e-7,'hands release the now unreachable ledge during carry');
    }
    if(i>0 && i<24 && i%6===0) {
      const contact=new THREE.Vector3(plan.edge.x-direction.z*.27+direction.x*.025,plan.edge.y+.025,plan.edge.z+direction.x*.27+direction.z*.025);
      const plantedDistance=c.worldPosition('socket_hand_l').distanceTo(contact);
      hero.reset();applyTraversalPose(THREE,c,{...sample,obstacleHeight,edge:{...sample.edge,x:sample.edge.x+100}});
      maxContactImprovement=Math.max(maxContactImprovement,c.worldPosition('socket_hand_l').distanceTo(contact)-plantedDistance);
    }
  }
}
assert.equal(applyTraversalPose(THREE,c,{progress:NaN}),false);
assert.ok(maxContactImprovement>.015,'reachable edge attracts the hands during early lift');
console.log(JSON.stringify({passed:true,source:'actual player_male GLB skin',snapshots,trajectorySnapshots,maxSkinStep,maxTrajectorySkinStep,minSkinAboveRoot,maxContactImprovement,checks:['vault_mantle_shore','fixed_world_hand_contacts','smooth_entry_exit','finite_skin','root_and_yaw_preserved','bone_length_and_scale_preserved','real_sampleTraversal_trajectory','skin_above_root_floor','reachable_edge_grip','unreachable_edge_released']}));
