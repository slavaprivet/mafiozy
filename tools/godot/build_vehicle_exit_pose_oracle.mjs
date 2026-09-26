import fs from 'node:fs';
import path from 'node:path';
import crypto from 'node:crypto';
import {fileURLToPath,pathToFileURL} from 'node:url';
import {registerHooks} from 'node:module';
const root=path.resolve(path.dirname(fileURLToPath(import.meta.url)),'../..'),source=path.join(root,'assets/maps/city_rebuild_v1');
const vendor=process.env.MAFIOZI_THREE_VENDOR??'D:/codex_release/artist13_hero_first_DEV_20260907/demo/vendor';
registerHooks({resolve(s,c,n){return n(s==='three'?pathToFileURL(path.join(vendor,'build/three.module.js')).href:s,c)}});
const T=await import(pathToFileURL(path.join(vendor,'build/three.module.js')));
const {GLTFLoader}=await import(pathToFileURL(path.join(vendor,'addons/loaders/GLTFLoader.js')));
const {createHeroWalker}=await import(pathToFileURL(path.join(source,'hero_walk.mjs')));
const {createExitPoseFloorSampler}=await import(pathToFileURL(path.join(source,'vehicle_exit_surface.mjs')));
const {EXIT,launchExitBody,stepExitBody}=await import(pathToFileURL(path.join(source,'car_exit.mjs')));
const bytes=fs.readFileSync(path.join(source,'hero_models/player_male.8130dfb1f7eb.glb'));
const scene=(await new GLTFLoader().parseAsync(bytes.buffer.slice(bytes.byteOffset,bytes.byteOffset+bytes.byteLength),'')).scene;
const hero=createHeroWalker({THREE:T,scene}),frames=[];
const floors={none:()=>0,flat:()=>0,slope:(x,z)=>.3*x+.18*z,step:(x,z)=>x>13.17?.23:0};
for(const [floor_id,floor]of Object.entries(floors))for(const rolls of [1,2])for(const p of [0,.06,.16,.3,.46,.64,.72,.85,1]){
 hero.reset();hero.object.position.set(13,floor(13,-7)+(p<.3?.15:0),-7);hero.object.rotation.set(0,.7,0);
 const sampler=createExitPoseFloorSampler(hero.object.position,floor);
 hero.tumblePose(p,rolls,floor_id==='none'?{}:{floorHeight:sampler});
 const c=hero.artistContext(),rotations={};for(const [name,b]of Object.entries(c.bones)){const q=new T.Quaternion();b.matrix.decompose(new T.Vector3(),q,new T.Vector3());rotations[name]=q.toArray();}
 const combined=c.visualPivot.position.clone().add(c.scaled.position.clone().applyQuaternion(c.visualPivot.quaternion));
 const point=new T.Vector3();let min=Infinity,max=-Infinity,clearance=Infinity;
 scene.traverse(mesh=>{if(!mesh.isMesh)return;if(mesh.isSkinnedMesh)mesh.skeleton.update();const a=mesh.geometry.attributes.position;for(let i=0;i<a.count;i++){point.fromBufferAttribute(a,i);if(mesh.isSkinnedMesh)mesh.applyBoneTransform(i,point);point.applyMatrix4(mesh.matrixWorld);min=Math.min(min,point.y);max=Math.max(max,point.y);clearance=Math.min(clearance,point.y-floor(point.x,point.z));}});
 frames.push({progress:p,rolls,floor_id,root_position:hero.object.position.toArray(),root_yaw:.7,rotations,visual_offset:combined.toArray(),visual_rotation:c.visualPivot.quaternion.toArray(),skin_height:max-min,clearance,floor_stats:sampler.stats});
}
const timelines=[];for(const speed of [8,22]){let body=launchExitBody({x:0,z:0},{speed,yaw:.7},1,'tumble');const rows=[];while(!body.done){body=stepExitBody(body,.1,()=>true);rows.push({elapsed:body.elapsed,progress:body.progress,rolls:body.rolls,heading:body.heading,y:body.y,done:body.done});}timelines.push({speed,rows});}
const receipts={};for(const name of ['hero_walk.mjs','car_exit.mjs','vehicle_exit_surface.mjs','hero_models/player_male.8130dfb1f7eb.glb']){const b=fs.readFileSync(path.join(source,name));receipts[name]={bytes:b.length,sha256:crypto.createHash('sha256').update(b).digest('hex')};}
const file=path.join(root,'godot/mafiozi_walk/scripts/tests/fixtures/vehicle_exit_pose_oracle.json');fs.writeFileSync(file,JSON.stringify({source:'Unmodified actual hero.tumblePose + exit floor sampler + car_exit timeline, actual hero GLB',receipts,constants:EXIT,frames,timelines}));
hero.dispose();console.log(JSON.stringify({frames:frames.length,file,constants:EXIT}));
