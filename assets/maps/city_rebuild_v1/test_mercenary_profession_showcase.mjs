import test from 'node:test';
import assert from 'node:assert/strict';
import {registerHooks} from 'node:module';
import {pathToFileURL} from 'node:url';
import {createMercenaryProfessionShowcase,findMercenaryShowcaseAnchor,findMercenaryShowcaseAnchorAsync,mercenaryShowcaseLayout} from './mercenary_profession_showcase.mjs';
import {interiorSafeTargets} from './interior_safe_registry.mjs';
import {createInteriorSafeSource} from './interior_safe_source.mjs';
const vendor=process.env.THREE_VENDOR||'D:/codex_release/artist13_hero_first_DEV_20260907/demo/vendor',threeUrl=pathToFileURL(vendor+'/build/three.module.js').href;
registerHooks({resolve(s,c,n){return n(s==='three'?threeUrl:s,c)}});
const THREE=await import(threeUrl),{RoundedBoxGeometry}=await import('../../../tools/vehicle_fleet_qa/RoundedBoxGeometry.mjs');
const focus={x:170,z:160};
function fixture(options={}){const scene=new THREE.Scene();let bodies=[],explosions=0;const stand=createMercenaryProfessionShowcase({THREE,RoundedBox:RoundedBoxGeometry,scene,enabled:()=>true,canPlace:()=>true,onCollisionChange:({removed,added})=>{bodies=bodies.filter(b=>!removed.includes(b)).concat(added);return true;},onPowerChange:()=>true,onExplosion:()=>explosions++,sessionId:'test'+Math.random().toString(36).slice(2),...options});return {scene,stand,get bodies(){return bodies},get explosions(){return explosions}};}
test('ground search is bounded, rejects solids and steep ground, and exposes safely separated stations',()=>{
 let checks=0;assert.equal(findMercenaryShowcaseAnchor({focus,canPlace:()=>{checks++;return false}}),null);assert(checks<=61);
 assert.equal(findMercenaryShowcaseAnchor({focus,canPlace:()=>true,maxChecks:10}),null);
 const anchor=findMercenaryShowcaseAnchor({focus,canPlace:(x,z,radius)=>{assert.equal(radius,1.5);return true}}),layout=mercenaryShowcaseLayout(anchor);assert(anchor.checks<=180);assert.equal(layout.recruits.length,5);assert.equal(new Set(layout.recruits.map(r=>r.profession)).size,5);
 for(const p of[layout.cage,layout.safe,layout.patient,layout.door,...layout.recruits])assert(Math.hypot(p.x-layout.vehicle.x,p.z-layout.vehicle.z)>12,'car separated from each non-demolition station');
 assert.equal(findMercenaryShowcaseAnchor({focus,canPlace:()=>true,groundHeight:(x,z)=>x*.5}),null);
});
test('async site search yields in bounded slices and cancellation creates no props',async()=>{
 let checks=0,yields=0,last=0;const anchor=await findMercenaryShowcaseAnchorAsync({focus,canPlace:()=>{checks++;return true}},{checksPerSlice:24,yieldTask:async()=>{assert(checks-last<=24);last=checks;yields++;}});assert(anchor);assert(yields>=7);
 let enabled=true;const f=fixture({enabled:()=>enabled});const pending=f.stand.show(focus);assert.equal(f.stand.show(focus),pending,'double click shares active search');enabled=false;assert.equal((await pending).reason,'qa_not_enabled');assert.equal(f.scene.children.length,0);f.stand.dispose();
});
test('safe visual animation runs every frame while collision updates stay bounded and finish exactly',async()=>{
 let doorChanges=0,lastBodies;const f=fixture({onCollisionChange:({context,added})=>{if(context.kind==='safe_door'){doorChanges++;lastBodies=added;}return true;}});try{await f.stand.show(focus);f.stand.safe.applySourceState({opened:true});for(let i=0;i<60;i++)f.stand.update(1/60,focus);assert(f.stand.safe.stats().animationUpdates>40);assert(doorChanges>0&&doorChanges<=10);assert.equal(f.stand.safe.getState().openFraction,1);assert.equal(lastBodies,f.stand.safe.getCollisionBodies(),'last collider set is exact final open door geometry');}finally{f.stand.dispose()}
});
test('QA guard prevents scene changes; blocked collision hookup leaves no orphan visuals',async()=>{
 const f=fixture({enabled:()=>false});assert.equal((await f.stand.show(focus)).reason,'qa_not_enabled');assert.equal(f.scene.children.length,0);f.stand.dispose();
 const blocked=fixture({onCollisionChange:()=>false});assert.equal((await blocked.stand.show(focus)).reason,'collision_not_connected');assert.equal(blocked.scene.children.length,0);assert.equal(blocked.stand.colliders.length,0);blocked.stand.dispose();
});
test('show creates real uniquely identified objects once, cuts physics and disconnects lighting',async()=>{
 const f=fixture();try{const result=await f.stand.show(focus);assert.equal(result.ok,true);assert.equal(f.stand.getTargets().length,4);assert.equal(f.stand.getVehicles().length,1);assert.equal(f.stand.getPickRoots().length,1);const before=f.bodies.length;assert(before>=15);assert(f.bodies.every(b=>b.polygonCR.flat().every(Number.isFinite)));
 const next=await f.stand.show({x:500,z:500});assert.equal(next.existing,true);assert.equal(next.layout,result.layout);assert.equal(f.bodies.length,before);
 const fence=f.stand.getTargets().find(t=>t.kind==='fence'),power=f.stand.getTargets().find(t=>t.kind==='power_panel');assert(fence.id.startsWith('QA-MERCENARY-'));assert.equal(fence.object.userData.mercenaryTarget.cut().ok,true);assert.equal(f.bodies.length,before-1);assert.equal(power.object.userData.mercenaryTarget.disablePower().ok,true);assert.equal(power.object.userData.mercenaryTarget.powered,false);
 }finally{f.stand.dispose()}assert.equal(f.bodies.length,0);assert.equal(f.scene.children.length,0);assert.deepEqual(f.stand.getTargets(),[]);
});
test('showcase vehicle uses normal damage progression and generates a real explosion receipt',async()=>{
 const f=fixture();try{await f.stand.show(focus);const vehicle=f.stand.getVehicles()[0];assert(vehicle.car.shell.length>0);assert.equal(vehicle.damage.blastImpact({damage:1000,eventId:'test-plant'}),true);for(let i=0;i<20;i++)f.stand.update(.1,focus);assert.equal(vehicle.damage.state.wrecked,true);assert.equal(f.explosions,1);assert.equal(vehicle.damage.blastImpact({damage:1000,eventId:'test-plant'}),false);assert.equal(f.explosions,1);}finally{f.stand.dispose()}
});
test('showcase safe delegates to normal ledger: confirmed opening drops a bag and collection pays once',async()=>{
 const f=fixture(),data=new Map();let source;try{const shown=await f.stand.show(focus);const safe=f.stand.safe;assert.equal((await safe.unlock({memberId:'intruder'})).ok,false,'no fabricated QA unlock');
 source=createInteriorSafeSource({localPreview:true,allowLocal:()=>true,dropLoot:true,userId:'local-player',registry:interiorSafeTargets.getTargets(),storage:{getItem:k=>data.get(k)??null,setItem:(k,v)=>data.set(k,v)},location:'http://127.0.0.1:18538/world.html?mercenaryqa=1',authorize:({context,action})=>({ok:action==='collect'||context?.memberId==='safecracker'})});await interiorSafeTargets.setSource(source);
 assert.equal((await safe.unlock({memberId:'safecracker'})).ok,true);assert.equal(safe.getState().collected,false);for(let i=0;i<20;i++)f.stand.update(.1,focus);assert.equal(safe.lootBag.visible,true);assert.equal(safe.getState().openFraction,1);assert.equal(source.getLocalLedger().balance,0);assert(interiorSafeTargets.getLootTargets().some(t=>t.id===shown.safeId));
 const collected=await safe.collect();assert(collected.gained>0);assert.equal(safe.lootBag.visible,false);assert.equal((await safe.collect()).duplicate,true);assert.equal(source.getLocalLedger().entries.length,1);
 }finally{await interiorSafeTargets.setSource(null);source?.dispose();f.stand.dispose()}
});
