import test from 'node:test';
import assert from 'node:assert/strict';
import {pathToFileURL} from 'node:url';
import {createNpcCashOfferVisual,createNpcCashOfferVisualPool,isNpcCashOffering} from './npc_cash_offer_visual.mjs';

const vendor=process.env.MAFIOZI_THREE_VENDOR||'D:/codex_release/artist13_hero_first_DEV_20260907/demo/vendor';
const THREE=await import(pathToFileURL(vendor+'/build/three.module.js'));

function rig({hands=true,scale=1}={}){
 const object=new THREE.Group(),scene=new THREE.Group(),bones={};object.scale.setScalar(scale);object.add(scene);
 if(hands)for(const side of ['l','r']){const hand=new THREE.Group(),socket=new THREE.Group();hand.name='hand_'+side;socket.name='socket_hand_'+side;socket.position.set(side==='l'?-.18:.18,1.48,.02);hand.add(socket);scene.add(hand);bones['hand_'+side]=hand;bones['socket_hand_'+side]=socket;}
 const reaches=[],rotations=[],context={object,scene,bones,offset:scene,targetHeight:1.9,sourceHeight:5.12,rotateAdd:(name,x,y,z)=>rotations.push({name,x,y,z}),reachPalm:(side,target)=>{const socket=bones['socket_hand_'+side];socket.parent.worldToLocal(target);socket.position.copy(target);object.updateMatrixWorld(true);reaches.push({side,point:socket.getWorldPosition(new THREE.Vector3())});}};
 const walker={object,height:1.9,artistContext:()=>context};object.updateMatrixWorld(true);return {object,scene,bones,reaches,rotations,walker};
}

test('recognises only the explicit cash offering contract',()=>{
 assert.equal(isNpcCashOffering({cashOffering:true}),true);assert.equal(isNpcCashOffering({life:{cashOffering:true}}),true);
 for(const value of [{},{cashOffering:false},{state:'robbing'},{cashOfferStartedAt:1000}])assert.equal(isNpcCashOffering(value),false);
});

test('pool shares and reuses one lightweight non-pickable cash bundle',()=>{
 const pool=createNpcCashOfferVisualPool({THREE}),a=createNpcCashOfferVisual({THREE,walker:rig().walker,pool}),b=createNpcCashOfferVisual({THREE,walker:rig().walker,pool});assert.equal(a.object,null);
 a.update({cashOffering:true});b.update({life:{cashOffering:true}});const one=a.object,two=b.object;assert.equal(one.geometry,two.geometry);assert.equal(one.material,two.material);assert.equal(one.castShadow,false);assert.equal(one.receiveShadow,false);assert.equal(one.userData.npcPickIgnore,true);assert.equal(one.raycast(),undefined);
 a.update({cashOffering:false});assert.equal(a.object,null);assert.equal(one.parent,null);b.update({cashOffering:false});const c=createNpcCashOfferVisual({THREE,walker:rig().walker,pool});c.update({cashOffering:true});assert([one,two].includes(c.object));assert.equal(pool.stats().created,2);
 a.dispose();b.dispose();c.dispose();pool.dispose();assert.equal(pool.stats().disposed,true);
});

test('offers cash with the right hand while the left stays raised, then returns the empty hand up',()=>{
 const source=rig();source.bones.socket_hand_l.position.set(-.78,4.06,.50);source.bones.socket_hand_r.position.set(.77,4.13,.49);source.object.updateMatrixWorld(true);
 const pool=createNpcCashOfferVisualPool({THREE}),visual=createNpcCashOfferVisual({THREE,walker:source.walker,pool}),rightPoints=[],leftPoints=[];
 const frame=sourceNowMs=>{visual.update(.1,{sourceNowMs,time:sourceNowMs/1000,life:{cashOffering:true,cashOfferStartedAt:1000}});rightPoints.push(source.bones.socket_hand_r.getWorldPosition(new THREE.Vector3()));leftPoints.push(source.bones.socket_hand_l.getWorldPosition(new THREE.Vector3()));};
 frame(1100);assert.equal(visual.phase,'draw');frame(1350);assert.equal(visual.phase,'extend');frame(1700);assert.equal(visual.phase,'extend');frame(2050);assert.equal(visual.phase,'offer');
 assert.equal(visual.diagnostics().offerSide,'r');assert.equal(visual.diagnostics().raisedPoseReady,true);assert(source.reaches.some(entry=>entry.side==='r'),'right hand supports the offered cash');assert(source.rotations.some(entry=>entry.name==='chest'&&entry.x>0));
 assert(leftPoints.every(point=>point.y>4),'free left hand remains visibly raised');assert(rightPoints.at(-1).z>rightPoints[0].z+.45,'right hand extends the bundle toward the player');
 for(let i=1;i<rightPoints.length;i++)assert(rightPoints[i].distanceTo(rightPoints[i-1])<1.35,'cash hand target stays bounded across source phases');
 for(let i=1;i<leftPoints.length;i++)assert(leftPoints[i].distanceTo(leftPoints[i-1])<.2,'raised hand has only subtle natural motion');
 const held=rightPoints.at(-1),before=source.reaches.length;assert.equal(visual.update(.1,{sourceNowMs:2150,life:{cashOffering:false,cashOfferStartedAt:1000}}),true);assert.equal(visual.phase,'return');assert.equal(visual.object,null,'taken bundle disappears instead of returning to the NPC pocket');const returnEntries=source.reaches.slice(before),firstReturn=returnEntries.find(entry=>entry.side==='r'),raisedDuringReturn=returnEntries.find(entry=>entry.side==='l');assert(firstReturn.point.distanceTo(held)<.65,'empty hand returns continuously from offered pose');assert(raisedDuringReturn.point.y>4,'left hand remains raised while the empty hand returns');
 for(let i=0;i<3;i++)visual.update(.1,{life:{cashOffering:false}});const returned=source.bones.socket_hand_r.getWorldPosition(new THREE.Vector3());assert(returned.x>.70&&returned.y>4,'empty right hand reaches the raised surrender pose');visual.update(.1,{life:{cashOffering:false}});assert.equal(visual.phase,'idle');assert.equal(visual.object,null);visual.dispose();pool.dispose();
});

test('resolves anchors once, supports root fallback and performs no update scans',()=>{
 const source=rig(),originalTraverse=source.scene.traverse.bind(source.scene);let scans=0;source.scene.traverse=callback=>{scans++;return originalTraverse(callback);};
 const pool=createNpcCashOfferVisualPool({THREE}),visual=createNpcCashOfferVisual({THREE,walker:source.walker,pool}),constructionScans=scans;for(let i=0;i<20;i++)visual.update(.05,{sourceNowMs:1000+i*50,life:{cashOffering:true,cashOfferStartedAt:1000}});assert.equal(scans,constructionScans);
 const fallback=rig({hands:false,scale:.5}),rootVisual=createNpcCashOfferVisual({THREE,root:fallback.object,pool,height:1.8});rootVisual.update({cashOffering:true});assert(rootVisual.object.getWorldPosition(new THREE.Vector3()).y>1);const worldScale=rootVisual.object.getWorldScale(new THREE.Vector3());assert(Math.abs(worldScale.x-1)<1e-6);
 visual.dispose();rootVisual.dispose();pool.dispose();
});

test('default pool is ref-counted and disposes geometry/material once',()=>{
 const a=createNpcCashOfferVisual({THREE,walker:rig().walker}),b=createNpcCashOfferVisual({THREE,walker:rig().walker});a.update({cashOffering:true});b.update({cashOffering:true});const geometry=a.object.geometry,material=a.object.material;let gd=0,md=0;geometry.addEventListener('dispose',()=>gd++);material.addEventListener('dispose',()=>md++);a.dispose();assert.equal(gd,0);b.dispose();assert.equal(gd,1);assert.equal(md,1);
});

console.log('PASS NPC cash offer visual: pooled bundle, right-hand offer, raised free hand, immediate take, empty hand returns up, no update scans, disposal');
