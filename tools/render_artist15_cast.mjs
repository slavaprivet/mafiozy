// Offline geometry inspection only. Uses actual deformed game meshes, no WebGL/live claim.
import fs from 'node:fs';
import {registerHooks} from 'node:module';
import {pathToFileURL} from 'node:url';
import {NPC_NAMED_BOSSES} from '../assets/maps/city_rebuild_v1/npc_role_catalogue.mjs';
import {npcAppearanceFromWorld} from '../assets/maps/city_rebuild_v1/npc_population.mjs';
import {applyNpcAppearance} from '../assets/maps/city_rebuild_v1/npc_appearance.mjs';
import {createNpcActor,NPC_ASSETS} from '../assets/maps/city_rebuild_v1/npc_actor.mjs';
const vendor='D:/codex_release/artist13_hero_first_DEV_20260907/demo/vendor';
registerHooks({resolve(s,c,n){return n(s==='three'?pathToFileURL(vendor+'/build/three.module.js').href:s,c)}});
const THREE=await import(pathToFileURL(vendor+'/build/three.module.js').href),{GLTFLoader}=await import(pathToFileURL(vendor+'/addons/loaders/GLTFLoader.js').href);
function clone(source){const output=source.clone(true),a=[],b=[];source.traverse(o=>a.push(o));output.traverse(o=>b.push(o));const mapping=new Map(a.map((o,i)=>[o,b[i]]));for(let i=0;i<a.length;i++)if(a[i].isSkinnedMesh){b[i].skeleton=a[i].skeleton.clone();b[i].skeleton.bones=a[i].skeleton.bones.map(bone=>mapping.get(bone));b[i].bindMatrix.copy(a[i].bindMatrix);b[i].bindMatrixInverse.copy(a[i].bindMatrixInverse)}return output}
const sources={};for(const [sex,asset]of Object.entries(NPC_ASSETS)){const b=fs.readFileSync(new URL(asset.url));sources[sex]=(await new GLTFLoader().parseAsync(b.buffer.slice(b.byteOffset,b.byteOffset+b.byteLength),'')).scene;}
const output=[];
for(const row of NPC_NAMED_BOSSES){
 const descriptor=npcAppearanceFromWorld({id:row.bridgeId,look:row.look,role:row.role,empireBoss:true});
 const scene=new THREE.Scene(),actor=createNpcActor({THREE,scene,source:sources[descriptor.sex],cloneSkeleton:clone,id:row.bridgeId,sex:descriptor.sex,height:descriptor.height,appearanceOwnsResources:true,applyAppearance:scene=>applyNpcAppearance({THREE,scene,descriptor})});
 actor.update(0,{position:{x:0,y:0,z:0},yaw:0,time:0});actor.object.updateMatrixWorld(true);
 const vertices=[],colors=[],triangles=[];const p=new THREE.Vector3(),c=new THREE.Color();
 actor.object.traverseVisible(mesh=>{
  if(!mesh.isMesh||!mesh.geometry?.attributes.position)return;
  const g=mesh.geometry,m=Array.isArray(mesh.material)?mesh.material[0]:mesh.material,base=vertices.length/3;
  for(let i=0;i<g.attributes.position.count;i++){
   mesh.getVertexPosition(i,p);p.applyMatrix4(mesh.matrixWorld);vertices.push(p.x,p.y,p.z);
   c.copy(m.color||new THREE.Color('white'));if(g.attributes.color){const a=g.attributes.color;c.r*=a.getX(i);c.g*=a.getY(i);c.b*=a.getZ(i);}c.convertLinearToSRGB();colors.push(c.r,c.g,c.b);
  }
  const ix=g.index?.array||Array.from({length:g.attributes.position.count},(_,i)=>i);for(let i=0;i<ix.length;i+=3)triangles.push(base+ix[i],base+ix[i+1],base+ix[i+2]);
 });
 output.push({name:row.name,leaderId:row.leaderId,height:descriptor.height,descriptor,vertices,colors,triangles});actor.dispose();
}
fs.mkdirSync('docs/city-rebuild/artist15-cast-qa',{recursive:true});
fs.writeFileSync('docs/city-rebuild/artist15-cast-qa/meshes.json',JSON.stringify(output));
console.log('Exported actual posed meshes for '+output.length+' bosses');
