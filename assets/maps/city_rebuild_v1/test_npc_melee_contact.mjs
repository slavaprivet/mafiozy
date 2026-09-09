import {resolveNpcContactAnchor} from './npc_contact_anchor.mjs';
import fs from 'node:fs';import assert from 'node:assert/strict';import {registerHooks} from 'node:module';import {pathToFileURL} from 'node:url';
import {createHeroWalker} from './hero_walk.mjs';import {NPC_ASSETS} from './npc_actor.mjs';import {createNpcContactRay} from './npc_contact_ray.mjs';import {createNpcMeleeContact} from './npc_melee_contact.mjs';
const deps='D:/codex_release/artist13_hero_first_DEV_20260907/demo/vendor';registerHooks({resolve(specifier,context,next){return next(specifier==='three'?pathToFileURL(deps+'/build/three.module.js').href:specifier,context);}});const THREE=await import(pathToFileURL(deps+'/build/three.module.js'));const {GLTFLoader}=await import(pathToFileURL(deps+'/addons/loaders/GLTFLoader.js'));
let count=0;
for(const sex of ['male','female']){
 const bytes=fs.readFileSync(new URL(NPC_ASSETS[sex].url)),source=(await new GLTFLoader().parseAsync(bytes.buffer.slice(bytes.byteOffset,bytes.byteOffset+bytes.byteLength),'')).scene,walker=createHeroWalker({THREE,scene:source,targetHeight:1.9}),world=new THREE.Scene();world.add(walker.object);walker.update(.1);
 const actors=[{id:'npc_sweep_'+sex,object:walker.object}],walls=[],contact=createNpcMeleeContact({THREE,getActors:()=>actors,obstacles:()=>walls}),shoot=createNpcContactRay({THREE,getActors:()=>actors});
 const ctx=walker.artistContext(),chestY=ctx.bones.chest.getWorldPosition(new THREE.Vector3()).y,highY=ctx.bones.head.getWorldPosition(new THREE.Vector3()).y+.5;
 const surface=shoot({origin:new THREE.Vector3(0,chestY,3),direction:new THREE.Vector3(0,0,-1)});assert(surface);
 const point=new THREE.Vector3(...['x','y','z'].map(k=>surface.point[k])),normal=new THREE.Vector3(...['x','y','z'].map(k=>surface.normal[k])),near=point.clone().addScaledVector(normal,.09),far=point.clone().addScaledVector(normal,.16);
 let hit=contact({previous:near,current:near,radius:.1});assert(hit,sex+' static sphere endcap contact');assert.equal(hit.npcId,actors[0].id);assert(Object.values(hit.normal).every(Number.isFinite));assert(Math.abs(Math.hypot(...Object.values(hit.normal))-1)<1e-7);count++;
 assert.equal(contact({previous:far,current:far,radius:.1}),null,sex+' near range alone cannot hit');count++;
 hit=contact({previous:point.clone().addScaledVector(normal,.7),current:point.clone().addScaledVector(normal,-.3),radius:.1});assert(hit,sex+' fast crossing cannot tunnel');count++;
 const high={previous:new THREE.Vector3(0,highY,1),current:new THREE.Vector3(0,highY,.05),radius:.14,attackType:'kick'};hit=contact(high);assert(hit,sex+' high foot contact standing');assert.equal(hit.zone,'head');count++;
 for(const target of ['crouch','prone']){walker.update(.1,false,false,null,{}, {posture:{target,value:target==='crouch'?1:2}});assert.equal(contact(high),null,sex+' high foot misses '+target);count++;}
 walker.update(.1);const wall=new THREE.Mesh(new THREE.BoxGeometry(2,3,.1),new THREE.MeshBasicMaterial());wall.position.set(0,1.5,.65);world.add(wall);walls.push(wall);assert.equal(contact(high),null,sex+' wall blocks limb sweep');wall.position.x=5;assert(contact(high),'moved wall updates without render');count++;
 walker.object.visible=false;assert.equal(contact(high),null);walker.object.visible=true;assert.equal(contact({...high,active:false}),null);assert.equal(contact({...high,excludeId:actors[0].id}),null);count++;
 assert.equal(contact({previous:{x:2,y:chestY,z:.2},current:{x:2,y:chestY,z:-.2},radius:.14}),null,'same broad range without surface contact misses');count++;
 const distant=new THREE.Group();distant.position.x=100;distant.traverse=()=>{throw Error('broad phase must not skin distant actor');};actors.push({id:'far',object:distant});
 const dual=contact({attackType:'dropkick',contacts:[{previous:{x:2,y:highY,z:1},current:{x:2,y:highY,z:.05},radius:.14},high]});assert(dual);assert.equal(dual.npcId,actors[0].id);assert(dual.anchor);count++;
 const anchoredBefore=resolveNpcContactAnchor({THREE,record:actors[0],anchor:dual.anchor});assert(anchoredBefore);walker.object.position.set(6,1,-4);walker.object.rotation.y=.55;
 const moved=resolveNpcContactAnchor({THREE,record:actors[0],anchor:dual.anchor});assert(moved);const expected=new THREE.Vector3(anchoredBefore.point.x,anchoredBefore.point.y,anchoredBefore.point.z).applyAxisAngle(new THREE.Vector3(0,1,0),.55).add(new THREE.Vector3(6,1,-4));assert(expected.distanceTo(new THREE.Vector3(moved.point.x,moved.point.y,moved.point.z))<1e-6,'pending ACK anchor follows moved actor');
 walker.update(.1,false,false,null,{}, {posture:{target:'crouch',value:1}});const crouched=resolveNpcContactAnchor({THREE,record:actors[0],anchor:dual.anchor});assert(crouched);assert(crouched.point.y<moved.point.y-.05,'anchor follows current skin posture');walker.object.visible=false;assert.equal(resolveNpcContactAnchor({THREE,record:actors[0],anchor:dual.anchor}),null);

 walker.dispose();wall.geometry.dispose();wall.material.dispose();
}
console.log('PASS actual male/female swept posed-skin melee',count,'cases: endcaps, near-miss, crossing, high kick stance dodge, walls, visibility, dual feet, finite unit normal/exact id');
