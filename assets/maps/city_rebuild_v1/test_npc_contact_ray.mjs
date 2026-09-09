import fs from 'node:fs';
import assert from 'node:assert/strict';
import {registerHooks} from 'node:module';
import {pathToFileURL} from 'node:url';
import {createHeroWalker} from './hero_walk.mjs';
import {NPC_ASSETS} from './npc_actor.mjs';
import {createNpcContactRay} from './npc_contact_ray.mjs';
const deps='D:/codex_release/artist13_hero_first_DEV_20260907/demo/vendor';
registerHooks({resolve(specifier,context,next){return next(specifier==='three'?pathToFileURL(deps+'/build/three.module.js').href:specifier,context);}});
const THREE=await import(pathToFileURL(deps+'/build/three.module.js'));
const {GLTFLoader}=await import(pathToFileURL(deps+'/addons/loaders/GLTFLoader.js'));
let cases=0;
for(const sex of ['male','female']){
 const data=fs.readFileSync(new URL(NPC_ASSETS[sex].url)),source=(await new GLTFLoader().parseAsync(data.buffer.slice(data.byteOffset,data.byteOffset+data.byteLength),'')).scene,walker=createHeroWalker({THREE,scene:source,targetHeight:1.9}),world=new THREE.Scene();world.add(walker.object);
 const id='npc_exact_'+sex+'_server_0042',actors=[{id,object:walker.object}],walls=[];
 const contact=createNpcContactRay({THREE,getActors:()=>actors,obstacles:()=>walls});
 walker.update(.1);world.updateMatrixWorld(true);const ctx=walker.artistContext(),headY=ctx.bones.head.getWorldPosition(new THREE.Vector3()).y+.4,chestY=ctx.bones.chest.getWorldPosition(new THREE.Vector3()).y;
 const shoot=y=>contact({origin:new THREE.Vector3(0,y,5),direction:new THREE.Vector3(0,0,-2),range:10});
 for(const [height,zone]of [[headY,'head'],[chestY,'body']]){const hit=shoot(height);assert(hit,sex+' stand '+zone);assert.equal(hit.npcId,id);assert.equal(hit.zone,zone);assert(Object.values(hit.point).every(Number.isFinite));assert(Object.values(hit.normal).every(Number.isFinite));assert(Math.abs(Math.hypot(...Object.values(hit.normal))-1)<1e-7);assert(hit.normal.z>=0,'normal faces incoming ray');cases++;}
 for(const target of ['crouch','prone']){walker.update(.1,false,false,null,{}, {posture:{target,value:target==='crouch'?1:2}});assert.equal(shoot(headY),null,sex+' same high ray must miss '+target);if(target==='crouch')assert(shoot(chestY),'crouched target remains hittable at its actual lower surface');cases++;}
 walker.update(.1);const wall=new THREE.Mesh(new THREE.BoxGeometry(3,3,.2),new THREE.MeshBasicMaterial());world.add(wall);wall.position.set(0,1.5,2);wall.updateWorldMatrix(true,false);walls.push(wall);assert.equal(shoot(headY),null,sex+' wall blocks');cases++;
 wall.visible=false;assert(shoot(headY),sex+' hidden wall cannot block');wall.visible=true;
 wall.position.x=8; // No renderer update: helper must honor the current obstacle transform.
 assert(shoot(headY),sex+' wall moved away must stop blocking immediately');wall.position.set(0,1.5,-2);assert(shoot(headY),'wall behind actor does not block nearer surface');cases++;
 walls.length=0;walker.object.visible=false;assert.equal(shoot(headY),null);walker.object.visible=true;world.visible=false;assert.equal(shoot(headY),null);world.visible=true;cases+=2;
 assert.equal(contact({origin:new THREE.Vector3(0,headY,5),direction:new THREE.Vector3(0,0,-1),range:1}),null,'range limit');cases++;
 assert.equal(contact({origin:new THREE.Vector3(),direction:new THREE.Vector3(),range:10}),null);assert.equal(contact({origin:new THREE.Vector3(),direction:new THREE.Vector3(0,0,1),range:NaN}),null);
 // Actual displayed skin hit point stays on its triangle after an arbitrary world transform.
 walker.object.position.set(7,2,-4);walker.object.rotation.y=.7;walker.object.updateWorldMatrix(true,true);
 const origin=walker.object.localToWorld(new THREE.Vector3(0,headY,5)),direction=new THREE.Vector3(0,0,-1).applyQuaternion(walker.object.quaternion),hit=contact({origin,direction,range:10});assert(hit);assert.equal(hit.npcId,id);assert.equal(hit.zone,'head');cases++;
 walker.dispose();wall.geometry.dispose();wall.material.dispose();
}
console.log('PASS NPC contact real male/female GLB:',cases,'standing head/body, crouch/prone high misses, wall/hidden/range/world transform, exact id and unit finite normals');
