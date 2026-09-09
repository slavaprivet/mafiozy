import fs from 'node:fs';
import path from 'node:path';
import assert from 'node:assert/strict';
import {fileURLToPath,pathToFileURL} from 'node:url';
import {registerHooks} from 'node:module';
import {describeNpcAppearance,applyNpcAppearance,NPC_HAIRSTYLES} from './npc_appearance.mjs';
const vendor=process.env.THREE_VENDOR||'D:/codex_release/artist13_hero_first_DEV_20260907/demo/vendor';
const url=pathToFileURL(path.join(vendor,'build/three.module.js')).href;
registerHooks({resolve(s,c,n){return n(s==='three'?url:s,c)}});
const THREE=await import(url),{GLTFLoader}=await import(pathToFileURL(path.join(vendor,'addons/loaders/GLTFLoader.js')).href);
function clone(source){const output=source.clone(true),a=[],b=[];source.traverse(o=>a.push(o));output.traverse(o=>b.push(o));const mapping=new Map(a.map((o,i)=>[o,b[i]]));for(let i=0;i<a.length;i++)if(a[i].isSkinnedMesh){b[i].skeleton=a[i].skeleton.clone();b[i].skeleton.bones=a[i].skeleton.bones.map(bone=>mapping.get(bone));b[i].bindMatrix.copy(a[i].bindMatrix);b[i].bindMatrixInverse.copy(a[i].bindMatrixInverse)}return output}
const results=[];
assert(NPC_HAIRSTYLES.length>=12);const looks=Array.from({length:200},(_,i)=>describeNpcAppearance('existing-id-'+i));assert(new Set(looks.map(x=>x.browStyle)).size===8);assert(new Set(looks.map(x=>x.hairColor)).size===8);assert(new Set(looks.map(x=>x.skin)).size===6);assert.deepEqual(describeNpcAppearance('abc'),describeNpcAppearance('abc'));
for(const sex of ['male','female']){
 const data=fs.readFileSync(`D:/codex_release/artist13_posture_DEV_20260908/demo/player_${sex}.glb`),{scene:template}=await new GLTFLoader().parseAsync(data.buffer.slice(data.byteOffset,data.byteOffset+data.byteLength),'');
 const templateMeshes=[];template.traverse(x=>{if(x.isMesh)templateMeshes.push(x)});const originals=templateMeshes.map(m=>({geometry:m.geometry,material:m.material,positions:Array.from(m.geometry.attributes.position.array),colors:Array.from(m.geometry.attributes.color.array)}));
 for(const style of NPC_HAIRSTYLES){
  const scene=clone(template),descriptor=describeNpcAppearance('npc-'+style,{sex,hairstyle:style,role:'police',skin:'#704634',outfit:'#25394c',build:1.07}),bonesBefore={};scene.traverse(b=>{if(b.isBone)bonesBefore[b.name]=b.matrix.toArray()});
  const result=applyNpcAppearance({THREE,scene,descriptor});let added=0,changedColor=0,changedShape=0,eyeColorsPreserved=0;
  scene.traverse(o=>{if(o.isBone)assert.deepEqual(o.matrix.toArray(),bonesBefore[o.name],'rig rest matrices unchanged');if(o.userData.npcAppearance)added++;if(!o.isMesh||o.userData.npcAppearance)return;
   const source=templateMeshes.find(m=>m.name===o.name);assert.notEqual(o.geometry,source.geometry,'independent geometry even hidden');assert.notEqual(o.material,source.material,'independent material');
   assert(Array.from(o.geometry.attributes.position.array).every(Number.isFinite));assert(o.geometry.attributes.skinIndex.count===source.geometry.attributes.skinIndex.count);assert.deepEqual(Array.from(o.geometry.attributes.skinWeight.array),Array.from(source.geometry.attributes.skinWeight.array),'weights untouched');
   const c=o.geometry.attributes.color,old=source.geometry.attributes.color,p=o.geometry.attributes.position,oldp=source.geometry.attributes.position;
   for(let i=0;i<c.count;i++){if(c.getX(i)!==old.getX(i)||c.getY(i)!==old.getY(i)||c.getZ(i)!==old.getZ(i))changedColor++;if(p.getX(i)!==oldp.getX(i)||p.getY(i)!==oldp.getY(i)||p.getZ(i)!==oldp.getZ(i))changedShape++;
    if(o.name.includes('SKIN')&&Math.min(old.getX(i),old.getY(i),old.getZ(i))>.45){assert.equal(c.getX(i),old.getX(i),'eye white/glints preserved');eyeColorsPreserved++}
   }
  });
  assert(changedColor>100,'visible palette customization');assert(changedShape>20,'modest torso build visible');assert(eyeColorsPreserved>20);assert(added<40);assert(scene.getObjectByName('npc_brow_-1'));assert(scene.getObjectByName('npc_cap_badge'));assert(scene.getObjectByName('npc_chest_badge'));
  assert.throws(()=>applyNpcAppearance({THREE,scene,descriptor}),/already applied/);result.dispose();result.dispose();
  templateMeshes.forEach((m,i)=>{assert.equal(m.geometry,originals[i].geometry);assert.equal(m.material,originals[i].material);assert.deepEqual(Array.from(m.geometry.attributes.position.array),originals[i].positions);assert.deepEqual(Array.from(m.geometry.attributes.color.array),originals[i].colors)});
  results.push({sex,style,added,changedColor,changedShape,eyeColorsPreserved});
 }
}
console.log(JSON.stringify({passed:true,cases:results.length,hairstyles:NPC_HAIRSTYLES.length,brows:8,skinPalettes:6,hairColors:8,maxAdded:Math.max(...results.map(x=>x.added)),samples:results.filter(x=>x.style==='short')}));

// Role accessories follow their actual attachment bones; none grants gameplay protection.
for(const options of [{role:'prison_guard',prisonGear:'riot_helmet_shield',shield:true},{role:'prison_tactical',prisonGear:'tactical_helmet'},{role:'medic'},{role:'boss',accent:'#a6346b',trousers:'#451123'}]){
 const data=fs.readFileSync('D:/codex_release/artist13_posture_DEV_20260908/demo/player_male.glb'),{scene}=await new GLTFLoader().parseAsync(data.buffer.slice(data.byteOffset,data.byteOffset+data.byteLength),'');
 const descriptor=describeNpcAppearance('role:'+options.role,{...options,sex:'male'}),applied=applyNpcAppearance({THREE,scene,descriptor});
 if(options.prisonGear)assert(scene.getObjectByName('npc_tactical_helmet'));
 if(options.shield){const shield=scene.getObjectByName('npc_riot_shield');assert.equal(shield.parent.name,'forearm_l');assert.equal(scene.getObjectByName('npc_riot_visor').material.opacity,.25)}
 if(options.role==='medic')assert.equal(scene.getObjectByName('npc_medical_cross_v').parent.name,'chest');
 if(options.accent)assert.equal(scene.getObjectByName('npc_boss_accent').material.color.getHexString(),'a6346b');
 if(options.trousers){const fabric=scene.getObjectByName('player_male_DEMO_core_FABRIC'),p=fabric.geometry.attributes.position,c=fabric.geometry.attributes.color;let changed=0;for(let i=0;i<p.count;i++)if(p.getY(i)>.4&&p.getY(i)<1.3&&c.getX(i)>c.getY(i)*2)changed++;assert(changed>30,'source trousers palette honored');}
 assert(!('damage'in descriptor)&&!('armor'in descriptor));applied.dispose();
}
console.log('NPC role accessories: 4 cases passed');

