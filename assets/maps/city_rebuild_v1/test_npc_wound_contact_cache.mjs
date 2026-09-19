import fs from 'node:fs';
import assert from 'node:assert/strict';
import {registerHooks} from 'node:module';
import {pathToFileURL} from 'node:url';
import {createHeroWalker} from './hero_walk.mjs';
import {NPC_ASSETS} from './npc_actor.mjs';
import {createNpcContactRay} from './npc_contact_ray.mjs';
import {createBulletWounds} from './artist14/bullet_wounds.mjs';
const deps='D:/codex_release/artist13_hero_first_DEV_20260907/demo/vendor';
registerHooks({resolve(s,c,next){return next(s==='three'?pathToFileURL(deps+'/build/three.module.js').href:s,c);},load(url,c,next){
 if(!url.endsWith('bullet_wounds.mjs?original-contact'))return next(url,c);
 const result=next(url.split('?')[0],c),source=String(result.source).replace('const query=contactQuery(state);','const query={surfaces:state.surfaces,dispose(){}};').replace('if(contactAnchors.has(key))return contactAnchors.get(key);','');
 return {...result,source};
}});
const THREE=await import(pathToFileURL(deps+'/build/three.module.js'));
const {GLTFLoader}=await import(pathToFileURL(deps+'/addons/loaders/GLTFLoader.js'));
const {createBulletWounds:oldWounds}=await import('./artist14/bullet_wounds.mjs?original-contact');
let compared=0;
for(const sex of ['male','female'])for(const stance of ['stand','crouch','prone']){
 const bytes=fs.readFileSync(new URL(NPC_ASSETS[sex].url)),source=(await new GLTFLoader().parseAsync(bytes.buffer.slice(bytes.byteOffset,bytes.byteOffset+bytes.byteLength),'')).scene;
 const walker=createHeroWalker({THREE,scene:source,targetHeight:1.9}),ctx=walker.artistContext();new THREE.Scene().add(walker.object);
 walker.object.position.set(2,.8,-3);walker.object.rotation.y=.42;walker.object.scale.set(1.07,.93,1.02);
 walker.update(.1,false,false,null,{}, {posture:{target:stance,value:stance==='prone'?2:stance==='crouch'?1:0}});
 const center=ctx.bones.chest.getWorldPosition(new THREE.Vector3()),direction=stance==='prone'?new THREE.Vector3(0,-1,0):new THREE.Vector3(0,0,-1).applyQuaternion(walker.object.quaternion);
 const contact=createNpcContactRay({THREE,getActors:()=>[{id:'wound-'+sex,object:walker.object}]}),hit=contact({origin:center.clone().addScaledVector(direction,-3),direction,range:6});assert(hit,sex+' '+stance);
 const event={...hit,point:new THREE.Vector3(hit.point.x,hit.point.y,hit.point.z),normal:new THREE.Vector3(hit.normal.x,hit.normal.y,hit.normal.z),confirmed:true,id:'same-seed',clothing:true};
 let expected;
 for(const create of [oldWounds,createBulletWounds]){
  const model={root:ctx.scene,bones:ctx.bones},wounds=create(THREE,{worldScale:walker.scale});wounds.attach(model);assert(wounds.add(model,event));
  const state=wounds.snapshot(model),group=ctx.scene.getObjectByName('PersistentBulletWounds');
  const output={state,positions:group.children.map(m=>Array.from(m.geometry.attributes.position.array))};
  if(expected){assert.deepEqual(output,expected,sex+' '+stance+' exact triangles, skin weights, materials and geometry');compared+=output.positions.reduce((n,p)=>n+p.length,0);}
  else expected=output;
  wounds.reset(model);group.removeFromParent();
 }
 walker.dispose();
}
console.log('PASS wound receipt CPU cache: exact original GLB standing/crouch/prone transformed geometry and anchors;',compared,'position components');
