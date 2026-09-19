import assert from 'node:assert/strict';
import fs from 'node:fs';
import {pathToFileURL} from 'node:url';
import {registerHooks} from 'node:module';
import {performance} from 'node:perf_hooks';
import {createIndoorHeroVisibility} from './hero_visibility.mjs';
import {applyNpcAppearance,describeNpcAppearance} from './npc_appearance.mjs';
import {createHeroWalker} from './hero_walk.mjs';
import {createHeroPosture} from './hero_posture.mjs';
const vendor=process.env.MAFIOZY_THREE_VENDOR||'D:/codex_release/artist13_hero_first_DEV_20260907/demo/vendor/';
registerHooks({resolve(s,c,n){return n(s==='three'?pathToFileURL(vendor+'build/three.module.js').href:s,c)}});
const T=await import('three'),{GLTFLoader}=await import(pathToFileURL(vendor+'addons/loaders/GLTFLoader.js'));
const loader=new GLTFLoader().register(()=>({name:'CPU_TEXTURE_STUB',loadTexture:()=>Promise.resolve(new T.Texture())}));
let currentHero=null,weapon=null;
const visibility=createIndoorHeroVisibility({THREE:T,getHero:()=>currentHero,getWeapon:()=>weapon});
const rows=[],times=[];
for(const [sex,file]of [['male','player_male.8130dfb1f7eb.glb'],['female','player_female.298d50e6244a.glb']]){
 const bytes=fs.readFileSync(new URL('./hero_models/'+file,import.meta.url));
 const source=(await loader.parseAsync(bytes.buffer.slice(bytes.byteOffset,bytes.byteOffset+bytes.byteLength),'')).scene;
 applyNpcAppearance({THREE:T,scene:source,descriptor:describeNpcAppearance('camera-'+sex,{sex,hairstyle:'curly',hat:'fedora',accessory:'bowtie',accent:'#c0392b'})});
 const hero=createHeroWalker({THREE:T,scene:source});currentHero=hero;
 const bones={};hero.object.traverse(n=>{if(n.isBone)bones[n.name]=n});
 weapon=new T.Mesh(new T.BoxGeometry(.1,.1,.5),new T.MeshBasicMaterial());weapon.name='Mounted_Test_Weapon';bones.socket_weapon.add(weapon);
 // Both unknown attachments and props carried at an arm stay independent.
 const other=new T.Mesh(new T.BoxGeometry(.1,.1,.1),new T.MeshBasicMaterial());other.name='Unrelated';hero.object.add(other);
 const shield=new T.Mesh(new T.BoxGeometry(.1,.1,.1),new T.MeshBasicMaterial());shield.userData.npcAppearance=true;bones.forearm_l.add(shield);
 const originals=new Map(),accessories=[];
 hero.object.traverse(n=>{if(n.isMesh)originals.set(n,{geometry:n.geometry,visible:n.visible,material:n.material,skeleton:n.skeleton});if(n.isMesh&&n.userData.npcAppearance&&n!==shield)accessories.push(n)});
 assert(accessories.length>0);accessories[0].visible=false;originals.get(accessories[0]).visible=false;
 let bodyTriangles=0,handTriangles=0,forearmTriangles=0;
 for(const posture of ['stand','crouch','prone']){
  visibility.restore();hero.update(0,false,false,null,{}, {posture:createHeroPosture(posture)});
  const matrixBefore=new Map();hero.object.traverse(n=>matrixBefore.set(n,n.matrix.toArray()));
  const state=visibility.update(true);assert(state.supported&&state.hidden&&state.armsVisible);assert.equal(state.hiddenAccessories,accessories.length);
  assert.equal(weapon.visible,true);assert.equal(other.visible,true);assert.equal(shield.visible,true);
  for(const accessory of accessories)assert.equal(accessory.visible,false,'custom hair, hat, brows and chest decoration cannot float in the close view');
  hero.object.traverse(n=>assert.deepEqual(n.matrix.toArray(),matrixBefore.get(n),'mask never changes pose or sockets'));
  bodyTriangles=0;handTriangles=0;forearmTriangles=0;
  for(const [mesh,original]of originals){
   assert.equal(mesh.material,original.material);assert.equal(mesh.skeleton,original.skeleton);
   if(!mesh.isSkinnedMesh||!mesh.visible)continue;
   assert.notEqual(mesh.geometry,original.geometry,'male and female canonical meshes both get masks');
   const geometry=mesh.geometry,j=geometry.attributes.skinIndex,w=geometry.attributes.skinWeight;
   const score=(i,re)=>{let sum=0;for(let c=0;c<4;c++)if(re.test(mesh.skeleton.bones[j.getComponent(i,c)].name))sum+=w.getComponent(i,c);return sum};
   for(let i=0;i<geometry.index.count;i+=3){
    const tri=[0,1,2].map(c=>geometry.index.getX(i+c));bodyTriangles++;
    for(const v of tri){assert(score(v,/^(forearm|hand|thigh|shin|foot)_[lr]$/)>=.55-1e-6,'no upper-arm/shoulder-dominant sleeve remains');assert(score(v,/^(head|neck|socket_head)$/)<=1e-5,'head/neck removed')}
    if(tri.every(v=>score(v,/^hand_[lr]$/)>.999))handTriangles++;
    if(tri.every(v=>score(v,/^forearm_[lr]$/)>.999))forearmTriangles++;
   }
  }
  assert(handTriangles>0&&forearmTriangles>0);
  visibility.update(false);for(const [mesh,original]of originals){assert.equal(mesh.geometry,original.geometry);assert.equal(mesh.visible,original.visible)}
 }
 for(let i=0;i<200;i++){const start=performance.now();visibility.restore();visibility.update(true);times.push(performance.now()-start)}
 visibility.restore();currentHero=null;visibility.update(false);
 for(const [mesh,original]of originals){assert.equal(mesh.geometry,original.geometry);assert.equal(mesh.visible,original.visible)}
 rows.push({sex,postures:3,bodyTriangles,handTriangles,forearmTriangles,accessories:accessories.length});
 hero.dispose();weapon=null;
}
visibility.dispose();times.sort((a,b)=>a-b);
console.log(JSON.stringify({result:'PASS',rows,cachedRestoreUpdateCpu:{samples:times.length,p50Ms:times[Math.floor(times.length*.5)],p95Ms:times[Math.floor(times.length*.95)]},scope:'Actual customized male/female GLBs; CPU only, not live GPU/FPS'},null,2));
