import fs from 'node:fs';
import path from 'node:path';
import {pathToFileURL,fileURLToPath} from 'node:url';
import {registerHooks} from 'node:module';
import crypto from 'node:crypto';
const root = path.resolve(path.dirname(fileURLToPath(import.meta.url)),'../..'), sourceDir = path.join(root,'assets/maps/city_rebuild_v1');
const vendor = process.env.MAFIOZI_THREE_VENDOR ?? 'D:/codex_release/artist13_hero_first_DEV_20260907/demo/vendor';
registerHooks({resolve(s,c,n){return n(s==='three'?pathToFileURL(path.join(vendor,'build/three.module.js')).href:s,c)}});
const THREE = await import(pathToFileURL(path.join(vendor,'build/three.module.js')));
const {GLTFLoader} = await import(pathToFileURL(path.join(vendor,'addons/loaders/GLTFLoader.js')));
const {createHeroWalker} = await import(pathToFileURL(path.join(sourceDir,'hero_walk.mjs')));
const {launchJump, tryDiveJump, stepJump, JUMP} = await import(pathToFileURL(path.join(sourceDir,'hero_jump.mjs')));
const bytes=fs.readFileSync(path.join(sourceDir,'hero_models/player_male.8130dfb1f7eb.glb'));
const source=(await new GLTFLoader().parseAsync(bytes.buffer.slice(bytes.byteOffset,bytes.byteOffset+bytes.byteLength),'')).scene;
const hero=createHeroWalker({THREE,scene:source});
const {bones,visualPivot}=hero.artistContext();
const poses=[];
for(const p of [0,.1,.32,.64,.72,.85,1])for(let direction=0;direction<8;direction++)for(const blend of [0,.5,1]){
 const rootYaw=-.67, aimYaw=1.13, aimPitch=.24, travelYaw=aimYaw+direction*Math.PI/4;
 hero.object.rotation.y=rootYaw;
 hero.jumpPose(p,true,null,{aimYaw,aimPitch,travelYaw,diveBlend:blend});
 const rotations={};
 for(const [name,bone] of Object.entries(bones)){
  const pos=new THREE.Vector3(), q=new THREE.Quaternion(), scale=new THREE.Vector3();
  bone.matrix.decompose(pos,q,scale); rotations[name]=q.toArray();
 }
 poses.push({p,blend,rootYaw,aimYaw,aimPitch,travelYaw,rotations,visualRotation:visualPivot.quaternion.toArray(),visualOffset:visualPivot.position.toArray()});
}
const traces=[];
for(const upgradeElapsed of [0,.2,.5]){
 let state=launchJump({x:0,z:0},{x:1,z:0},{startedAt:0});
 while(state.elapsed<upgradeElapsed-1e-8)state=stepJump(state,Math.min(.04,upgradeElapsed-state.elapsed),()=>true);
 state=tryDiveJump(state,{x:1,z:0},upgradeElapsed*1000);
 const steps=[];
 while(!state.done){const prior=state,dt=.04;state=stepJump(state,dt,()=>true);steps.push({dt,elapsed:state.elapsed,progress:state.progress,diveBlend:state.diveBlend,y:state.y,travel:state.x-prior.x,done:state.done});}
 traces.push({upgradeElapsed,steps});
}
const receipts={};for(const name of ['hero_walk.mjs','hero_jump.mjs','hero_pose_transition.mjs','walk_preview.mjs','surface_motion.mjs']){const source=fs.readFileSync(path.join(sourceDir,name));receipts[name]={sha256:crypto.createHash('sha256').update(source).digest('hex'),bytes:source.length};}
const asset={path:'hero_models/player_male.8130dfb1f7eb.glb',bytes:bytes.length,sha256:crypto.createHash('sha256').update(bytes).digest('hex')};
const output={source:'actual createHeroWalker.jumpPose and hero_jump functions, actual authored GLB, unarmed',receipts,asset,constants:JUMP,poses,traces};
const destination=path.join(root,'godot/mafiozi_walk/scripts/tests/fixtures/preview_dive_oracle.json');
fs.mkdirSync(path.dirname(destination),{recursive:true});
fs.writeFileSync(destination,JSON.stringify(output));
hero.dispose();
console.log(JSON.stringify({passed:true,poses:poses.length,traces:traces.length,receipts,asset,constants:JUMP,destination}));
