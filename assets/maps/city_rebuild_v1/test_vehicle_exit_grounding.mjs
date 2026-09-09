import assert from 'node:assert/strict';
import fs from 'node:fs';
import path from 'node:path';
import {fileURLToPath,pathToFileURL} from 'node:url';
import {registerHooks} from 'node:module';
import {createHeroWalker} from './hero_walk.mjs';
import {launchExitBody,stepExitBody} from './car_exit.mjs';
import {createExitPoseFloorSampler} from './vehicle_exit_surface.mjs';

const here=path.dirname(fileURLToPath(import.meta.url));
const vendor=process.env.MAFIOZI_THREE_VENDOR??'D:/codex_release/artist13_hero_first_DEV_20260907/demo/vendor';
registerHooks({resolve(s,c,n){return n(s==='three'?pathToFileURL(path.join(vendor,'build/three.module.js')).href:s,c);}});
const THREE=await import(pathToFileURL(path.join(vendor,'build/three.module.js')));
const {GLTFLoader}=await import(pathToFileURL(path.join(vendor,'addons/loaders/GLTFLoader.js')));
const bytes=fs.readFileSync(path.join(here,'hero_models/player_male.8130dfb1f7eb.glb'));
const source=(await new GLTFLoader().parseAsync(bytes.buffer.slice(bytes.byteOffset,bytes.byteOffset+bytes.byteLength),'')).scene;
const hero=createHeroWalker({THREE,scene:source}),meshes=[];
source.traverse(n=>{if(n.isSkinnedMesh)meshes.push(n);});
assert.ok(meshes.length,'measure the production GLB skin');
const vertex=new THREE.Vector3();let frames=0,lowestClearance=Infinity,maxFloorSamples=0;
function assertClear(floor,label){
  hero.object.updateMatrixWorld(true);let min=Infinity;
  for(const mesh of meshes){mesh.skeleton.update();const positions=mesh.geometry.attributes.position;
    for(let i=0;i<positions.count;i++){
      vertex.fromBufferAttribute(positions,i);mesh.applyBoneTransform(i,vertex);vertex.applyMatrix4(mesh.matrixWorld);
      assert.ok([vertex.x,vertex.y,vertex.z].every(Number.isFinite),`${label}: finite skin`);
      min=Math.min(min,vertex.y-floor(vertex.x,vertex.z));
    }
  }
  assert.ok(min>=-1e-5,`${label}: actual skin penetrated support by ${-min} m`);
  lowestClearance=Math.min(lowestClearance,min);frames++;
}
const surfaces=[
  ['flat',()=>0],
  ['raised road',()=>2.4],
  ['uphill',(x,z)=>.3*x+.18*z],
  ['downhill',(x,z)=>-.27*x-.21*z],
  ['sloped bridge',(x,z)=>4.1+.22*x-.18*z],
];
for(const [name,floor]of surfaces)for(const speed of [-8,8,22])for(const side of [-1,1]){
  hero.reset();hero.object.rotation.set(0,0,0);
  let body=launchExitBody({x:13,z:-7},{speed,yaw:.7},side,'tumble');
  while(!body.done){
    body=stepExitBody(body,1/60,()=>true);
    hero.object.position.set(body.x,floor(body.x,body.z)+body.y,body.z);hero.object.rotation.y=body.heading;
    const root=hero.object.position.toArray();
    const floorSample=createExitPoseFloorSampler(hero.object.position,floor);
    hero.tumblePose(body.progress,body.rolls,{floorHeight:floorSample});
    assert.equal(floorSample.stats.outside,0,'production tumble skin fits inside bounded surface sampler');
    maxFloorSamples=Math.max(maxFloorSamples,floorSample.stats.samples);
    assert.deepEqual(hero.object.position.toArray(),root,'visual grounding must preserve physics root');
    assertClear(floor,`${name}, speed ${speed}, side ${side}, progress ${body.progress}`);
  }
  hero.reset();assertClear(()=>floor(body.x,body.z),`${name} recovery`);
}
console.log(`PASS ${frames} actual GLB exit frames: flat/raised/uphill/downhill/bridge, reverse/forward, one/two rolls, both sides; lowest clearance ${lowestClearance.toFixed(6)} m; max floor queries/frame ${maxFloorSamples}`);
