import fs from 'node:fs';
import path from 'node:path';
import {pathToFileURL,fileURLToPath} from 'node:url';
import {registerHooks} from 'node:module';
import crypto from 'node:crypto';
const root=path.resolve(path.dirname(fileURLToPath(import.meta.url)),'../..'), dir=path.join(root,'assets/maps/city_rebuild_v1');
const vendor=process.env.MAFIOZI_THREE_VENDOR??'D:/codex_release/artist13_hero_first_DEV_20260907/demo/vendor';
registerHooks({resolve(s,c,n){return n(s==='three'?pathToFileURL(path.join(vendor,'build/three.module.js')).href:s,c)}});
const THREE=await import(pathToFileURL(path.join(vendor,'build/three.module.js')));
const {GLTFLoader}=await import(pathToFileURL(path.join(vendor,'addons/loaders/GLTFLoader.js')));
const {createHeroWalker}=await import(pathToFileURL(path.join(dir,'hero_walk.mjs')));
const {createArtist14Melee,ARTIST14_MELEE_DURATIONS}=await import(pathToFileURL(path.join(dir,'hero_artist14_melee.mjs')));
const bytes=fs.readFileSync(path.join(dir,'hero_models/player_male.8130dfb1f7eb.glb'));
const source=(await new GLTFLoader().parseAsync(bytes.buffer.slice(bytes.byteOffset,bytes.byteOffset+bytes.byteLength),'')).scene;
const hero=createHeroWalker({THREE,scene:source});
const c=hero.artistContext(), melee=createArtist14Melee({...c,THREE});
// Same actor-relative bind-frame arithmetic used by createArtist14Melee.
// Keep JS doubles in JSON, without an intervening float32 vector conversion.
c.object.updateMatrixWorld(true);
const invRest=c.offset.matrixWorld.clone().invert(), restWorld={};
for(const [name,bone] of Object.entries(c.bones))restWorld[name]=bone.getWorldPosition(new THREE.Vector3()).applyMatrix4(invRest).toArray();
const restLengths={};
for(const side of ['l','r'])for(const [a,b] of [['upperarm_','forearm_'],['forearm_','hand_'],['thigh_','shin_'],['shin_','foot_']])restLengths[a+side]=new THREE.Vector3(...restWorld[a+side]).distanceTo(new THREE.Vector3(...restWorld[b+side]));
const matrices=()=>Object.fromEntries(Object.entries(c.bones).map(([name,bone])=>[name,bone.matrix.toArray()]));
const frames=()=>({poses:matrices(),visual_offset:c.scaled.position.clone().applyQuaternion(c.visualPivot.quaternion).add(c.visualPivot.position).toArray(),visual_rotation:c.visualPivot.quaternion.toArray(),scaled_offset:c.scaled.position.toArray()});
const cases=[];
const skinCases=new Set([112,113,174,175,450,461,490,501,530,541,570,581]);
const skinSamples=[],skinLayout=[];
source.traverse(mesh=>{if(mesh.isMesh){const a=mesh.geometry.attributes,keys=[];for(let i=0;i<a.position.count;i++){const influences=[];for(let j=0;j<4;j++){const w=a.skinWeight.getComponent(i,j);if(w>0)influences.push([mesh.skeleton.bones[a.skinIndex.getComponent(i,j)].name,w])}influences.sort((x,y)=>x[0].localeCompare(y[0]));keys.push({p:[a.position.getX(i),a.position.getY(i),a.position.getZ(i)],influences})}skinLayout.push({name:mesh.name,material:mesh.material?.name,vertices:a.position.count,first:Array.from(a.position.array.slice(0,3)),keys})}});
function test(action,phase=0,gait=0,posture={crouch:0,prone:0},yaw=0){
 hero.reset();c.object.position.set(4,0,-3);c.object.rotation.y=-.67;c.visualPivot.rotation.y=yaw;
 if(gait){c.rotate('chest',0,0,Math.sin(phase)*gait*.018);for(const[side,sign]of[['l',1],['r',-1]]){const step=Math.sin(phase)*sign*gait;c.rotate('thigh_'+side,step*.56);c.rotate('shin_'+side,Math.max(0,-step)*.52);c.rotate('foot_'+side,-step*.22);c.rotate('upperarm_'+side,-step*.38);c.rotate('forearm_'+side,-Math.max(0,step)*.12);}}
 c.scaled.position.y=Math.abs(Math.sin(phase))*gait*.026;c.object.updateMatrixWorld(true);
 const base=frames(), result=melee.apply(action,posture,phase,gait), selected=frames();
 let minSkin=Infinity;
 if(action?.type==='dropkick'&&result?.active){const inv=c.object.matrixWorld.clone().invert(),v=new THREE.Vector3();source.traverse(mesh=>{if(!mesh.isMesh)return;if(mesh.isSkinnedMesh)mesh.skeleton.update();for(let i=0;i<mesh.geometry.attributes.position.count;i++){v.fromBufferAttribute(mesh.geometry.attributes.position,i);if(mesh.isSkinnedMesh)mesh.applyBoneTransform(i,v);v.applyMatrix4(mesh.matrixWorld).applyMatrix4(inv);minSkin=Math.min(minSkin,v.y)}})}
 cases.push({action,phase,gait,posture,base,selected,result,min_skin:Number.isFinite(minSkin)?minSkin:null});
 if(skinCases.has(cases.length-1)){
  const points=[],inv=c.object.matrixWorld.clone().invert(),v=new THREE.Vector3();
  source.traverse(mesh=>{if(!mesh.isMesh)return;if(mesh.isSkinnedMesh)mesh.skeleton.update();for(let i=0;i<mesh.geometry.attributes.position.count;i++){v.fromBufferAttribute(mesh.geometry.attributes.position,i);if(mesh.isSkinnedMesh)mesh.applyBoneTransform(i,v);v.applyMatrix4(mesh.matrixWorld).applyMatrix4(inv);points.push(v.x,v.y,v.z)}});
  skinSamples.push({index:cases.length-1,points});
 }
}
for(const type of ['punch','kick','heavy','backfist','dropkick']){
 const duration=ARTIST14_MELEE_DURATIONS[type];
 const times=[0,.016,.025,.035,.055,.07,.08,.09,.10,.12,.13,.14,.16,.18,.19,.22,.25,.28,.30,.32,.34,.36,.38,.40,.46,.49,.50,.55,.58,.60,.62,.64,.68,.70,.72,.78,1,1.20,1.249999,1.25].filter(t=>t<=duration);
 for(const side of [-1,1])for(const gait of [0,.75])for(const time of times)test({type,progress:time/duration,side,charge:.65},1.17,gait,{crouch:0,prone:0},gait?.53:0);
}
for(const action of [null,{}, {type:'none'}, {type:'punch',progress:1}, {type:'kick',progress:.5,armed:true}, {type:'heavy',progress:.4,weaponId:'pistol'}, {type:'none',blocking:true}, {type:'none',charge:.7,side:-1}, {type:'heavy',progress:1,blocking:true}, {type:'dropkick',progress:1,charge:.3}])test(action,.6,.8,{crouch:0,prone:0},-.32);
for(const posture of [{crouch:.02,prone:0},{crouch:0,prone:.5},{crouch:.01,prone:0}])test({type:'kick',progress:.3,side:-1},.3,.9,posture,.4);
const hashes={};for(const name of ['hero_artist14_melee.mjs','hero_walk.mjs','hero_contact_ground_bound.mjs']){const b=fs.readFileSync(path.join(dir,name));hashes[name]={sha256:crypto.createHash('sha256').update(b).digest('hex'),bytes:b.length}}
const out={source:'Actual original createArtist14Melee.apply, real authored GLB and createHeroWalker hierarchy. No local authority/contacts/movement applied.',hashes,asset_sha:crypto.createHash('sha256').update(bytes).digest('hex'),sourceHeight:c.sourceHeight,targetHeight:c.targetHeight,unit:c.targetHeight/c.sourceHeight,source_offset:c.offset.position.toArray(),restWorld,restLengths,rest:Object.fromEntries(Object.entries(c.rest).map(([n,r])=>[n,r.matrix.toArray()])),cases};
const dest=path.join(root,'godot/mafiozi_walk/scripts/tests/fixtures/melee_pose_oracle.json');fs.mkdirSync(path.dirname(dest),{recursive:true});fs.writeFileSync(dest,JSON.stringify(out));hero.dispose();console.log(JSON.stringify({cases:cases.length,hashes,unit:out.unit,dest}));
const packed=new Float64Array(skinSamples.flatMap(x=>x.points));fs.writeFileSync(path.join(path.dirname(dest),'melee_pose_skin.bin'),Buffer.from(packed.buffer));
fs.writeFileSync(path.join(path.dirname(dest),'melee_pose_skin.json'),JSON.stringify({format:'Float64 little-endian XYZ, root-local native metres',cases:skinSamples.map(x=>x.index),layout:skinLayout,vertices:skinSamples[0].points.length/3,sha256:crypto.createHash('sha256').update(Buffer.from(packed.buffer)).digest('hex')}));
console.log(JSON.stringify({skinMeshes:skinLayout.length,skinCases:skinSamples.map(x=>x.index),skinBytes:packed.byteLength}));
