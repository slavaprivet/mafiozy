import test from 'node:test';
import assert from 'node:assert/strict';
import {pathToFileURL} from 'node:url';
import {createNpcPhoneVisual,createNpcPhoneVisualPool,isNpcPhoneCalling} from './npc_phone_visual.mjs';

const vendor=process.env.MAFIOZI_THREE_VENDOR||'D:/codex_release/artist13_hero_first_DEV_20260907/demo/vendor';
const THREE=await import(pathToFileURL(vendor+'/build/three.module.js'));

function rig({hand=true,head=true,scale=1}={}){
 const object=new THREE.Group();object.name='actor';object.scale.setScalar(scale);
 const scene=new THREE.Group();object.add(scene);const bones={};
 if(head){bones.head=new THREE.Group();bones.head.name='head';bones.head.position.set(0,1.62,0);scene.add(bones.head);}
 if(hand){bones.socket_hand_r=new THREE.Group();bones.socket_hand_r.name='socket_hand_r';bones.socket_hand_r.position.set(.18,1.53,.015);bones.hand_r=new THREE.Group();bones.hand_r.name='hand_r';bones.hand_r.add(bones.socket_hand_r);scene.add(bones.hand_r);}
 bones.hand_l=new THREE.Group();bones.hand_l.name='hand_l';bones.socket_hand_l=new THREE.Group();bones.socket_hand_l.name='socket_hand_l';bones.socket_hand_l.position.set(-.18,1.53,.015);bones.hand_l.add(bones.socket_hand_l);scene.add(bones.hand_l);
 const rotations=[],reaches=[],offset=scene,reachPalm=(side,target)=>{const socket=bones['socket_hand_'+side];socket.parent.worldToLocal(target);socket.position.copy(target);object.updateMatrixWorld(true);reaches.push({side,point:socket.getWorldPosition(new THREE.Vector3())});};
 const context={object,scene,bones,targetHeight:1.9,sourceHeight:5.12,offset,rotateAdd:(name,x,y,z)=>rotations.push({name,x,y,z}),reachPalm};
 const walker={object,height:1.9,artistContext:()=>context};object.updateMatrixWorld(true);return {object,scene,bones,walker,rotations,reaches};
}

test('recognises real phone call snapshots without matching unrelated states',()=>{
 for(const value of [{phoneCalling:true},{callingPolice:true},{state:'phoneCalling'},{lifeState:'calling_police'},{gesture:'phone'}])assert.equal(isNpcPhoneCalling(value),true);
 for(const value of [{},{phoneCalling:false},{state:'talking'},{state:'recalled'},{activity:{kind:'read'}}])assert.equal(isNpcPhoneCalling(value),false);
 assert.equal(isNpcPhoneCalling({life:{state:'calling'}}),false);
});

test('shares one geometry/material, follows the right-hand socket and has no pick or shadow cost',()=>{
 const pool=createNpcPhoneVisualPool({THREE}),a=rig(),b=rig();b.object.position.set(4,0,2);b.object.rotation.y=.7;b.object.updateMatrixWorld(true);
 const first=createNpcPhoneVisual({THREE,walker:a.walker,pool}),second=createNpcPhoneVisual({THREE,walker:b.walker,pool});
 assert.equal(first.object,null);assert.equal(first.update({life:{phoneCalling:true}}),true);assert.equal(second.update({life:{state:'calling_police'}}),true);
 const one=first.object,two=second.object;assert.equal(one.geometry,two.geometry);assert.equal(one.material,two.material);assert.equal(pool.stats().created,2);assert.equal(pool.stats().active,2);
 assert.equal(one.geometry.parameters.width,.105);assert.equal(one.geometry.parameters.height,.215);assert.equal(one.geometry.parameters.depth,.021);assert.equal(one.material.color.getHex(),0x6f9fa6);assert.equal(one.material.toneMapped,false);assert.equal(one.material.transparent,false);
 assert.equal(one.castShadow,false);assert.equal(one.receiveShadow,false);assert.equal(one.userData.npcPickIgnore,true);assert.equal(one.userData.visualOnly,true);assert.deepEqual(one.raycast(),undefined);
 assert.equal(first.anchorKind,'rightHand');const handWorld=a.bones.socket_hand_r.getWorldPosition(new THREE.Vector3()),phoneWorld=one.getWorldPosition(new THREE.Vector3());assert(phoneWorld.distanceTo(handWorld)<.06,'phone remains in the raised right hand');
 assert.equal(first.update({life:{state:'talking'}}),false);assert.equal(first.object,null);assert.equal(one.visible,false);assert.equal(one.parent,null);assert.equal(pool.stats().idle,1);
 first.dispose();second.dispose();assert.equal(pool.stats().active,0);pool.dispose();assert.equal(pool.stats().disposed,true);
});

test('reuses released meshes and disposes shared GPU resources exactly once',()=>{
 const pool=createNpcPhoneVisualPool({THREE}),a=createNpcPhoneVisual({THREE,walker:rig().walker,pool}),b=createNpcPhoneVisual({THREE,walker:rig().walker,pool});
 a.update({phoneCalling:true});const recycled=a.object,geometry=recycled.geometry,material=recycled.material;let geometryDisposals=0,materialDisposals=0;geometry.addEventListener('dispose',()=>geometryDisposals++);material.addEventListener('dispose',()=>materialDisposals++);
 a.update({state:'idle'});b.update({state:'phoneCalling'});assert.equal(b.object,recycled);assert.equal(pool.stats().created,1);a.dispose();b.dispose();assert.equal(geometryDisposals,0);assert.equal(materialDisposals,0);
 pool.dispose();pool.dispose();assert.equal(geometryDisposals,1);assert.equal(materialDisposals,1);
});

test('supports head and root fallbacks while keeping phone dimensions in world metres',()=>{
 const pool=createNpcPhoneVisualPool({THREE});
 const headRig=rig({hand:false,head:true,scale:.42}),headVisual=createNpcPhoneVisual({THREE,walker:headRig.walker,pool});headVisual.update({state:'phone_calling'});assert.equal(headVisual.anchorKind,'head');
 const worldScale=headVisual.object.getWorldScale(new THREE.Vector3());assert(Math.abs(worldScale.x-1)<1e-6&&Math.abs(worldScale.y-1)<1e-6&&Math.abs(worldScale.z-1)<1e-6,'parent rig scale is cancelled');
 const head=headRig.bones.head.getWorldPosition(new THREE.Vector3()),phone=headVisual.object.getWorldPosition(new THREE.Vector3());assert(phone.x>head.x&&phone.distanceTo(head)<.2,'head fallback places phone by the right ear');
 const rootRig=rig({hand:false,head:false}),rootVisual=createNpcPhoneVisual({THREE,root:rootRig.object,pool,height:1.8});rootVisual.update({phoneCalling:true});assert.equal(rootVisual.anchorKind,'root');assert(rootVisual.object.getWorldPosition(new THREE.Vector3()).y>1.4);
 headVisual.dispose();rootVisual.dispose();pool.dispose();
});

test('plays draw, raise, two-hand hold and smooth stow phases through the actor hook',()=>{
 const source=rig(),pool=createNpcPhoneVisualPool({THREE}),visual=createNpcPhoneVisual({THREE,walker:source.walker,pool}),right=[];
 for(let i=0;i<10;i++){visual.update(.1,{time:i*.1,life:{phoneCalling:true}});right.push(source.bones.socket_hand_r.getWorldPosition(new THREE.Vector3()));}
 assert.equal(visual.phase,'hold');assert(source.reaches.some(entry=>entry.side==='l'),'off hand shields or gestures during hold');assert(source.rotations.some(entry=>entry.name==='head'&&Math.abs(entry.y)>.01));assert(source.rotations.some(entry=>entry.name==='chest'&&Math.abs(entry.y)>.01));
 const heldObject=visual.object;for(let i=0;i<20;i++){visual.update(.1,{time:1+i*.1,life:{phoneCalling:true}});assert.equal(visual.phase,'hold');assert.equal(visual.object,heldObject,'continuous call never redraws the phone');}
 for(let i=1;i<right.length;i++)assert(right[i].distanceTo(right[i-1])<1.2,'bounded right-hand movement between sampled frames');
 const held=right.at(-1),firstStowStart=source.reaches.length;assert.equal(visual.update(.1,{time:1.1,life:{state:'idle'}}),true);assert.equal(visual.phase,'stow');const stowPoint=source.reaches.slice(firstStowStart).find(entry=>entry.side==='r').point;assert(stowPoint.distanceTo(held)<.35,'stow begins continuously from the ear');
 for(let i=0;i<6;i++)visual.update(.1,{time:1.2+i*.1,life:{state:'idle'}});assert.equal(visual.phase,'idle');assert.equal(visual.object,null);assert(visual.diagnostics().poseApplications>=10);
 visual.dispose();pool.dispose();
});

test('default pool is shared by controllers and released only after their disposal',()=>{
 const a=createNpcPhoneVisual({THREE,walker:rig().walker}),b=createNpcPhoneVisual({THREE,walker:rig().walker});a.update({phoneCalling:true});b.update({phoneCalling:true});
 const geometry=a.object.geometry,material=a.object.material;let gd=0,md=0;geometry.addEventListener('dispose',()=>gd++);material.addEventListener('dispose',()=>md++);assert.equal(geometry,b.object.geometry);assert.equal(material,b.object.material);
 a.dispose();assert.equal(gd,0);b.dispose();assert.equal(gd,1);assert.equal(md,1);
});

console.log('PASS NPC phone visual: call states, hand/head/root anchors, shared pool, mesh reuse, no ray/shadow/light cost, disposal');
