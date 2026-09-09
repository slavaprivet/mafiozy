import fs from 'node:fs';
import assert from 'node:assert/strict';
import {registerHooks} from 'node:module';
import {pathToFileURL} from 'node:url';
import {createHeroWalker} from './hero_walk.mjs';
import {NPC_ASSETS} from './npc_actor.mjs';
import {createNpcContactRay} from './npc_contact_ray.mjs';
import {resolveNpcContactAnchor} from './npc_contact_anchor.mjs';
import {createWorldWalkCombat} from './world_walk_combat.mjs';
import {createWeaponFireState} from './hero_weapon_fire.mjs';
const deps='D:/codex_release/artist13_hero_first_DEV_20260907/demo/vendor';
registerHooks({resolve(specifier,context,next){return next(specifier==='three'?pathToFileURL(deps+'/build/three.module.js').href:specifier,context);}});
const THREE=await import(pathToFileURL(deps+'/build/three.module.js'));
const {GLTFLoader}=await import(pathToFileURL(deps+'/addons/loaders/GLTFLoader.js'));
const vector=p=>new THREE.Vector3(p.x,p.y,p.z);
for(const sex of ['male','female']){
 const data=fs.readFileSync(new URL(NPC_ASSETS[sex].url)),scene=(await new GLTFLoader().parseAsync(data.buffer.slice(data.byteOffset,data.byteOffset+data.byteLength),'')).scene;
 const walker=createHeroWalker({THREE,scene,targetHeight:1.9}),world=new THREE.Scene();world.add(walker.object);walker.update(.1);world.updateMatrixWorld(true);
 const actor={id:'npc_anchor_'+sex,object:walker.object},actors=[actor],contact=createNpcContactRay({THREE,getActors:()=>actors});
 const y=walker.artistContext().bones.chest.getWorldPosition(new THREE.Vector3()).y;
 const origin=new THREE.Vector3(0,y,5),direction=new THREE.Vector3(0,0,-1),hit=contact({origin,direction,range:10});assert(hit?.anchor,sex);
 const anchor=JSON.parse(JSON.stringify(hit.anchor)); // No live mesh/bone refs in anchor.
 let resolved=resolveNpcContactAnchor({THREE,record:actor,anchor});assert(vector(resolved.point).distanceTo(vector(hit.point))<1e-6);
 const before=walker.object.matrixWorld.clone();
 walker.object.position.set(8,1.4,-5);walker.object.rotation.y=.92;walker.object.scale.set(1.1,.9,1.05);
 walker.object.updateMatrixWorld(true);
 const expected=vector(hit.point).applyMatrix4(before.invert()).applyMatrix4(walker.object.matrixWorld);
 resolved=resolveNpcContactAnchor({THREE,record:actor,anchor});assert(vector(resolved.point).distanceTo(expected)<1e-6,sex+' rigid root transform');
 const movedPoint=vector(resolved.point);
 walker.update(.13,false,false,null,{}, {posture:{target:'crouch',value:1}});
 resolved=resolveNpcContactAnchor({THREE,record:actor,anchor});assert(resolved);assert(vector(resolved.point).distanceTo(movedPoint)>.05,sex+' skin pose changes contact');assert(vector(resolved.point).distanceTo(vector(hit.point))>3,sex+' stale original point must not be reused');
 const mesh=walker.object.getObjectByProperty('uuid',anchor.meshUuid),tri=anchor.indices.map(i=>mesh.getVertexPosition(i,new THREE.Vector3()).applyMatrix4(mesh.matrixWorld));
 const closest=new THREE.Triangle(...tri).closestPointToPoint(vector(resolved.point),new THREE.Vector3());assert(closest.distanceTo(vector(resolved.point))<1e-6,sex+' resolved point lies on current posed triangle');assert(Math.abs(vector(resolved.normal).length()-1)<1e-7);
 assert.equal(resolveNpcContactAnchor({THREE,record:{id:actor.id,object:new THREE.Group()},anchor}),null,'same ID respawn is a different body');
 assert.equal(resolveNpcContactAnchor({THREE,record:actor,anchor:{...anchor,geometryUuid:'replaced'}}),null,'changed skin rejected');
 assert.equal(resolveNpcContactAnchor({THREE,record:actor,anchor:{...anchor,weights:[2,0,0]}}),null,'invalid barycentric coordinates rejected');
 mesh.visible=false;assert.equal(resolveNpcContactAnchor({THREE,record:actor,anchor}),null);mesh.visible=true;

 // Real skinned ray + combat adapter. A source-local ACK occurs before the
 // fire function returns shotId; host microtask sees the stored anchor.
 walker.object.position.set(0,0,0);walker.object.rotation.set(0,0,0);walker.object.scale.set(1,1,1);walker.update(.1);world.updateMatrixWorld(true);
 let clock=1000,sequence=0,lastHit,accepted=true,syncListener=null;
 const bridge={getPlayerState:()=>({magazine:9,reserve:40}),fireWalkShot(request){lastHit=request.resolveContact({angle:-Math.PI/2,range:10,weapon:'pistol'});const shotId='anchor-shot-'+(++sequence);if(accepted&&lastHit)syncListener?.({detail:{confirmed:true,shotId,targetId:actor.id,npcId:actor.id,point:lastHit.point,normal:lastHit.normal,kind:'bullet'}});return {accepted,shotId,contactAccepted:!!lastHit,state:this.getPlayerState()};}};
 const combat=createWorldWalkCombat({THREE,bridge,getActors:()=>actors,now:()=>clock});
 const fire=()=>combat.step(createWeaponFireState('tt_pistol'),{triggerPressed:true},.016,{origin,forward:direction});
 let deferred;syncListener=event=>{assert.equal(combat.resolveConfirmedReceipt(event),null,'sync receipt precedes anchor store');queueMicrotask(()=>{deferred=combat.resolveConfirmedReceipt(event);});};
 const first=fire();assert.equal(first.shots.length,1);assert(lastHit?.anchor);walker.object.position.x=2;
 await new Promise(resolve=>queueMicrotask(resolve));assert(deferred);assert(Math.abs(deferred.point.x-lastHit.point.x-2)<1e-6);assert.equal(combat.resolveConfirmedReceipt(deferred),null,'one source receipt consumed once');
 syncListener=null;walker.object.position.x=0;const second=fire(),secondId=second.shots[0].shotId;
 const ack={confirmed:true,shotId:secondId,targetId:actor.id,point:lastHit.point,normal:lastHit.normal};
 assert.equal(combat.resolveConfirmedReceipt({...ack,confirmed:false}),null);assert.equal(combat.resolveConfirmedReceipt({...ack,targetId:'other'}),null);
 clock+=3000;walker.update(.2,false,false,null,{}, {posture:{target:'crouch',value:1}});walker.object.position.z=-4;
 const delayed=combat.resolveConfirmedReceipt(ack);assert(delayed);assert(vector(delayed.point).distanceTo(vector(ack.point))>3);assert.equal(delayed.shotId,secondId);
 walker.object.position.z=0;walker.update(.1);const third=fire();clock+=15001;assert.equal(combat.resolveConfirmedReceipt({...ack,shotId:third.shots[0].shotId}),null,'expired HTTP/WS acknowledgment cannot project stale geometry');
 accepted=false;const rejected=fire();assert.equal(rejected.shots.length,0);assert.equal(combat.resolveConfirmedReceipt({...ack,shotId:'anchor-shot-'+sequence}),null);
 combat.dispose();walker.dispose();
}
console.log('PASS delayed NPC contact anchors: real male/female skin, translation/rotation/nonuniform scale/crouch, triangle membership, identity/topology checks, synchronous ACK microtask, delayed ACK, expiry, rejection and dedupe');
