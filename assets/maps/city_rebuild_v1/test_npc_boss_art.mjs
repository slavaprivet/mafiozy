import fs from 'node:fs';
import path from 'node:path';
import assert from 'node:assert/strict';
import {createHash} from 'node:crypto';
import {fileURLToPath,pathToFileURL} from 'node:url';
import {registerHooks} from 'node:module';
import {NPC_BOSS_ART_DIRECTION,bossArtDirectionForId} from './npc_boss_art_direction.mjs';
import {NPC_NAMED_BOSSES} from './npc_role_catalogue.mjs';
import {npcAppearanceFromWorld} from './npc_population.mjs';
import {createNpcEmpirePortraits} from './npc_empire_portraits.mjs';
import {applyNpcAppearance} from './npc_appearance.mjs';
import {NPC_ASSETS} from './npc_actor.mjs';

const vendor=process.env.THREE_VENDOR||'D:/codex_release/artist13_hero_first_DEV_20260907/demo/vendor';
const url=pathToFileURL(path.join(vendor,'build/three.module.js')).href;
registerHooks({resolve(s,c,n){return n(s==='three'?url:s,c)}});
const THREE=await import(url);
const {GLTFLoader}=await import(pathToFileURL(path.join(vendor,'addons/loaders/GLTFLoader.js')).href);
function clone(source){
 const output=source.clone(true),a=[],b=[];source.traverse(o=>a.push(o));output.traverse(o=>b.push(o));
 const mapping=new Map(a.map((o,i)=>[o,b[i]]));
 for(let i=0;i<a.length;i++)if(a[i].isSkinnedMesh){b[i].skeleton=a[i].skeleton.clone();b[i].skeleton.bones=a[i].skeleton.bones.map(bone=>mapping.get(bone));b[i].bindMatrix.copy(a[i].bindMatrix);b[i].bindMatrixInverse.copy(a[i].bindMatrixInverse)}
 return output;
}
const hash=array=>createHash('sha256').update(Buffer.from(array.buffer,array.byteOffset,array.byteLength)).digest('hex');
function snapshot(scene){
 const meshes=new Map(),bones=new Map();scene.updateMatrixWorld(true);
 scene.traverse(o=>{if(o.isBone)bones.set(o.name,o.matrix.toArray());if(o.isMesh)meshes.set(o.name,{geometry:o.geometry,material:o.material,attributes:Object.fromEntries(Object.entries(o.geometry.attributes).map(([k,v])=>[k,hash(v.array)])),bind:o.bindMatrix?.toArray(),inverse:o.bindMatrixInverse?.toArray()})});
 return {meshes,bones};
}
const templates={};
for(const sex of ['male','female']){
 const asset=NPC_ASSETS[sex],bytes=fs.readFileSync(fileURLToPath(asset.url));
 assert.equal(bytes.length,asset.bytes);assert.equal(createHash('sha256').update(bytes).digest('hex'),asset.sha256);
 const {scene}=await new GLTFLoader().parseAsync(bytes.buffer.slice(bytes.byteOffset,bytes.byteOffset+bytes.byteLength),'');
 templates[sex]={scene,before:snapshot(scene)};
}
assert.equal(NPC_NAMED_BOSSES.length,19);assert.equal(Object.keys(NPC_BOSS_ART_DIRECTION).length,19);
assert.equal(bossArtDirectionForId('npc_crew_rustam_1'),null);
assert.equal(bossArtDirectionForId('npc_unique_rustam_bodyguard'),null);
const captures=[],records=[],geometries=new Set(),materials=new Set();let released=0;
const portraits=createNpcEmpirePortraits({THREE,portraits:{renderNpc:()=> 'data:image/png;base64,test'},appearanceLoader:async args=>{
 captures.push(args);return {hero:{object:{},artistContext:()=>({rest:{}})},dispose(){released++}};
}});
for(const row of NPC_NAMED_BOSSES){
 const descriptor=npcAppearanceFromWorld({id:row.bridgeId,look:row.look,role:row.role,empireBoss:true});
 const authored=NPC_BOSS_ART_DIRECTION[row.leaderId];
 assert(authored,row.bridgeId+' is authored');
 assert.equal(bossArtDirectionForId(row.id),authored);assert.equal(bossArtDirectionForId(row.bridgeId),authored);
 for(const [key,value] of Object.entries(authored))assert.deepEqual(descriptor[key],value,row.bridgeId+' keeps authored '+key);
 await portraits.get({renderId:row.bridgeId,look:row.look,renderRole:row.role});
 assert.deepEqual(captures.at(-1).appearance,descriptor,row.bridgeId+' street and portrait appearance agree');
 assert.equal(captures.at(-1).targetHeight,descriptor.height,row.bridgeId+' portrait preserves actor height');
 const {scene:template,before}=templates[descriptor.sex],scene=clone(template),applied=applyNpcAppearance({THREE,scene,descriptor,cloneTextures:true});
 const metrics={id:row.leaderId,sex:descriptor.sex,height:descriptor.height,bodyShape:descriptor.bodyShape,torso:[],face:[],waistWidth:0,waistDepth:0,faceWidth:0,changedTorso:0,changedFace:0,added:0};
 scene.traverse(o=>{
  if(o.isBone)assert.deepEqual(o.matrix.toArray(),before.bones.get(o.name),'rest skeleton unchanged');
  if(o.userData.npcAppearance){metrics.added++;return}
  if(!o.isMesh)return;
  const original=before.meshes.get(o.name);assert(original);
  assert.notEqual(o.geometry,original.geometry);assert(!geometries.has(o.geometry),'different actors own different geometry');geometries.add(o.geometry);
  for(const m of Array.isArray(o.material)?o.material:[o.material]){assert(!(Array.isArray(original.material)?original.material:[original.material]).includes(m));assert(!materials.has(m),'different actors own different materials');materials.add(m)}
  for(const key of ['skinWeight','skinIndex'])if(o.geometry.attributes[key])assert.equal(hash(o.geometry.attributes[key].array),original.attributes[key],key+' unchanged');
  if(o.isSkinnedMesh){assert.deepEqual(o.bindMatrix.toArray(),original.bind);assert.deepEqual(o.bindMatrixInverse.toArray(),original.inverse);assert(o.skeleton.bones.every(b=>scene.getObjectByName(b.name)===b))}
  const p=o.geometry.attributes.position,old=original.geometry.attributes.position;
  assert([...p.array].every(Number.isFinite),'all geometry finite');
  for(let i=0;i<p.count;i++){
   const y=old.getY(i),x=p.getX(i),z=p.getZ(i),changed=x!==old.getX(i)||p.getY(i)!==y||z!==old.getZ(i);
   let torsoWeight=0;for(let j=0;j<4;j++)if(['chest','spine_01','pelvis'].includes(o.skeleton?.bones[o.geometry.attributes.skinIndex?.getComponent(i,j)]?.name))torsoWeight+=o.geometry.attributes.skinWeight.getComponent(i,j);
   if(/FABRIC/.test(o.name)&&y>1.9&&y<2.4&&torsoWeight>.8){metrics.torso.push(x,p.getY(i),z);metrics.waistWidth=Math.max(metrics.waistWidth,Math.abs(x)*2);metrics.waistDepth=Math.max(metrics.waistDepth,z);if(changed)metrics.changedTorso++}
   if(/SKIN/.test(o.name)&&y>3.85&&y<4.50){metrics.face.push(x,p.getY(i),z);metrics.faceWidth=Math.max(metrics.faceWidth,Math.abs(x)*2);if(changed)metrics.changedFace++}
  }
 });
 assert(metrics.changedTorso>20,row.bridgeId+' has actual body deformation');assert(metrics.changedFace>20,row.bridgeId+' has actual face deformation');
 assert(scene.getObjectByName('npc_boss_accent'),'authored accent visible');
 const accessory={chain:'npc_neck_chain',scarf:'npc_scarf_collar',bowtie:'npc_bowtie_knot',glasses:'npc_glasses_bridge',earrings:'npc_earring_-1'}[descriptor.accessory];
 if(accessory)assert(scene.getObjectByName(accessory),row.bridgeId+' has '+descriptor.accessory);
 if(descriptor.wardrobe==='doublebreasted')assert(scene.getObjectByName('npc_jacket_button_-1_0'));
 if(descriptor.facialHair!=='none')assert(scene.getObjectByName('npc_moustache_-1'));
 if(['pinstripe','colorblock','brocade','doublebreasted','leather'].includes(descriptor.wardrobe)){
  const plain=clone(template),plainApplied=applyNpcAppearance({THREE,scene:plain,descriptor:{...descriptor,wardrobe:null}});let decoratedVertices=0;
  scene.traverse(o=>{if(!o.isMesh||!/FABRIC/.test(o.name))return;const c=o.geometry.attributes.color,other=plain.getObjectByName(o.name).geometry.attributes.color;for(let i=0;i<c.count;i++)if(c.getX(i)!==other.getX(i)||c.getY(i)!==other.getY(i)||c.getZ(i)!==other.getZ(i))decoratedVertices++});
  assert(decoratedVertices>10,row.bridgeId+' wardrobe changes visible fabric vertices');plainApplied.dispose();
 }
 metrics.torso=hash(new Float32Array(metrics.torso));metrics.face=hash(new Float32Array(metrics.face));records.push(metrics);
 applied.dispose();applied.dispose();
 for(const [name,old] of before.meshes){const original=template.getObjectByName(name);assert.equal(original.geometry,old.geometry);assert.equal(original.material,old.material);for(const [key,value] of Object.entries(old.attributes))assert.equal(hash(original.geometry.attributes[key].array),value,'template '+key+' unchanged')}
}
assert.equal(released,19);portraits.dispose();
assert.equal(new Set(records.map(r=>r.torso)).size,19,'nineteen distinct body meshes');assert.equal(new Set(records.map(r=>r.face)).size,19,'nineteen distinct face meshes');
const heavy=records.find(r=>r.id==='rustam'),slim=records.find(r=>r.id==='niko');
assert(heavy.waistWidth>slim.waistWidth*1.12,'heavy silhouette visibly wider than slim '+JSON.stringify({heavy,slim}));assert(heavy.waistDepth>slim.waistDepth+.2,'heavy belly protrudes visibly');assert(heavy.faceWidth>slim.faceWidth*1.12,'heavy face is visibly wider');
assert(Math.max(...records.map(r=>r.height))-Math.min(...records.map(r=>r.height))>=.39,'short and tall bosses differ in height');
assert.equal(NPC_BOSS_ART_DIRECTION.inga.hairColor,'#f05baf');assert.equal(NPC_BOSS_ART_DIRECTION.timur.heritage,'Chinese');
console.log(JSON.stringify({passed:true,bosses:records.length,sexes:Object.keys(templates),checks:['real-GLB-integrity','all-authored-fields','independent-resources','source-template-unmodified','rig-and-weights-preserved','nineteen-distinct-body-and-face-meshes','heavy-versus-slim-silhouette','accessories','portrait-city-descriptor-and-height'],heavy:{waistWidth:heavy.waistWidth,waistDepth:heavy.waistDepth,faceWidth:heavy.faceWidth},slim:{waistWidth:slim.waistWidth,waistDepth:slim.waistDepth,faceWidth:slim.faceWidth}}));
