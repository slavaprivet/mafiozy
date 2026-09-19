import test from 'node:test';
import assert from 'node:assert/strict';
import {pathToFileURL} from 'node:url';
import {performance} from 'node:perf_hooks';
import {createInteriorSafe,INTERIOR_SAFE_DIMENSIONS} from './interior_interactive_safe.mjs';

const THREE=await import(pathToFileURL(process.env.MAFIOZY_THREE||'D:/codex_release/artist13_hero_first_DEV_20260907/demo/vendor/build/three.module.js'));
const fixture=extra=>createInteriorSafe(THREE,{id:'safe:hotel:manager:1',buildingId:'hotel',roomId:'manager',...extra});
const deferred=()=>{let resolve,reject;const promise=new Promise((yes,no)=>{resolve=yes;reject=no});return {promise,resolve,reject}};
const pointIn=(x,z,p)=>{let sign=0;for(let i=0;i<p.length;i++){const a=p[i],b=p[(i+1)%p.length],cross=(b[0]-a[0])*(z-a[1])-(b[1]-a[1])*(x-a[0]);if(Math.abs(cross)<1e-9)continue;const current=Math.sign(cross);if(sign&&current!==sign)return false;sign=current}return true};

test('safe has a stable address, hollow body, detailed door and only two closed draws',()=>{
 const safe=fixture();try{
  const meta=safe.object.userData.mercenaryTarget;assert.equal(meta.id,'safe:hotel:manager:1');assert.equal(meta.kind,'safe');assert.equal(meta.locked,true);assert.equal(safe.object.userData.lockable,true);
  const body=safe.object.getObjectByName('Safe_Hollow_Steel_Body'),door=safe.object.getObjectByName('Safe_Hinged_Door');
  const bodyBounds=body.geometry.boundingBox;assert.equal(Math.round((bodyBounds.max.x-bodyBounds.min.x)*1000),860);assert.equal(Math.round(bodyBounds.max.y*1000),1280);
  assert.equal(door.parent,safe.doorPivot);assert.equal(safe.stats().draws,2);assert.equal(INTERIOR_SAFE_DIMENSIONS.width,.86);
  safe.object.updateMatrixWorld(true);const ray=new THREE.Raycaster(new THREE.Vector3(0,1,2),new THREE.Vector3(0,0,-1));
  const bodyHits=ray.intersectObject(body);assert(bodyHits.length);assert(bodyHits[0].point.z<-.2,'ray enters a real cavity and only hits its rear wall');
  assert(ray.intersectObject(door)[0].point.z>.35,'a separate steel door closes the front');
  const bodies=safe.getCollisionBodies();assert.equal(bodies.length,6);assert.equal(bodies.filter(b=>b.movingDoor).length,1);
  assert(!bodies.some(b=>b.minYM<1&&b.maxYM>1&&pointIn(0,0,b.polygonCR)),'empty cavity is not a monolithic collision box');
 }finally{safe.dispose()}
});

test('missing or refused authority keeps lock, door and loot intact',async()=>{
 const offline=fixture();try{assert.equal((await offline.unlock()).reason,'source_not_connected');assert.equal((await offline.collect()).reason,'locked');assert.equal(offline.getState().locked,true)}finally{offline.dispose()}
 for(const response of[{ok:false,reason:'guards_alive'},true,{ok:true},{ok:true,opened:true,targetId:'other'}]){
  const safe=fixture({onUnlock:()=>response});try{
   assert.equal((await safe.unlock()).ok,false);assert.equal(safe.getState().opened,false);assert.equal(safe.getState().locked,true);assert.equal(safe.doorPivot.rotation.y,0);assert.equal(safe.stats().draws,2);
  }finally{safe.dispose()}
 }
 const safe=fixture({onUnlock:()=>{throw Error('transport failure')}});try{assert.equal((await safe.unlock()).reason,'source_error');assert.equal(safe.getState().locked,true)}finally{safe.dispose()}
});

test('inflight commands share one authority request and never farm rewards',async()=>{
 const pending=deferred(),collectPending=deferred();let unlockCalls=0,collectCalls=0,unlockRequest,collectRequest;
 const safe=fixture({onUnlock:(id,request)=>{unlockCalls++;unlockRequest={id,...request};return pending.promise},onCollect:(id,request)=>{collectCalls++;collectRequest={id,...request};return collectPending.promise}});
 try{
  const first=safe.unlock({mercenaryId:'locksmith'}),second=safe.unlock({mercenaryId:'duplicate'});assert.equal(first,second);await Promise.resolve();
  assert.equal(unlockCalls,1);assert.equal(safe.getState().pending,'unlock');assert.equal(safe.getState().locked,true);assert.equal(safe.needsUpdate,false);
  assert.equal(unlockRequest.requestId,'safe:hotel:manager:1:unlock');assert.equal(unlockRequest.buildingId,'hotel');assert.equal(unlockRequest.roomId,'manager');assert.deepEqual(unlockRequest.context,{mercenaryId:'locksmith'});
  pending.resolve({ok:true,opened:true,revision:3});assert.equal((await first).ok,true);assert.equal(safe.getState().locked,false);assert.equal(safe.object.userData.mercenaryOpened,true);assert.equal(safe.stats().draws,3);
  assert.equal((await safe.unlock()).duplicate,true);assert.equal(unlockCalls,1);
  const a=safe.collect(),b=safe.collect();assert.equal(a,b);await Promise.resolve();assert.equal(collectCalls,1);assert.equal(collectRequest.requestId,'safe:hotel:manager:1:collect');assert.equal(safe.getState().collected,false);
  collectPending.resolve({ok:true,collected:true,revision:4});assert.equal((await a).ok,true);assert.equal(safe.getState().collected,true);assert.equal(safe.stats().draws,2);
  assert.equal((await safe.collect()).duplicate,true);assert.equal(collectCalls,1);
  safe.applySourceState({opened:false,collected:false,locked:true,revision:5});assert.equal(safe.getState().opened,true);assert.equal(safe.getState().collected,true,'source refresh cannot replenish this instance');
  assert.equal(safe.applySourceState({opened:true,revision:2}).reason,'stale_source_state');
 }finally{safe.dispose()}
});

test('confirmed major-safe payout is already collected and is not claimed twice',async()=>{
 let payouts=0,collections=0;const safe=fixture({onUnlock:()=>{payouts++;return {ok:true,opened:true,collected:true,awards:[{uid:'player',amount:500}]}},onCollect:()=>{collections++;return {ok:true,collected:true}}});
 try{
  const result=await safe.unlock();assert.equal(result.ok,true);assert.equal(result.awards[0].amount,500);assert.equal(safe.getState().collected,true);assert.equal(safe.stats().draws,2);
  await safe.unlock();await safe.collect();assert.equal(payouts,1);assert.equal(collections,0);
 }finally{safe.dispose()}
});

test('mercenary target alias retains the authoritative action context while fixing its safe request key',async()=>{
 let request;
 const safe=fixture({onUnlock:(id,value)=>{request=value;return {ok:true,opened:true,collected:true}}});
 try{
  assert.equal(typeof safe.object.userData.mercenaryTarget.unlock,'function');
  const effect={actionId:27,memberId:'hired-locksmith',kind:'unlock_safe',requestId:'mercenary:27'};
  assert.equal((await safe.object.userData.mercenaryTarget.unlock(effect)).ok,true);
  assert.equal(request.requestId,'safe:hotel:manager:1:unlock');assert.equal(request.context,effect);assert.equal(request.context.actionId,27);assert.equal(request.context.memberId,'hired-locksmith');
 }finally{safe.dispose()}
});

test('failed requests can retry with the same stable idempotency key',async()=>{
 let calls=0;const ids=[],safe=fixture({onUnlock:(id,request)=>{ids.push(request.requestId);return ++calls===1?{ok:false,reason:'guards_alive'}:{ok:true,opened:true}},onCollect:()=>({ok:true})});
 try{assert.equal((await safe.unlock()).ok,false);assert.equal((await safe.unlock()).ok,true);assert.equal(calls,2);assert.equal(ids[0],ids[1]);assert.equal((await safe.collect()).reason,'unconfirmed_collection');assert.equal(safe.getState().collected,false)}finally{safe.dispose()}
});

test('confirmed source state restores an empty open safe after recreation',()=>{
 const safe=fixture({sourceState:{opened:true,collected:true,revision:15}});try{
  assert.equal(safe.getState().locked,false);assert.equal(safe.getState().collected,true);assert.equal(safe.getState().openFraction,1);assert.equal(safe.needsUpdate,false);assert.equal(safe.stats().draws,2);
  assert.equal(safe.object.userData.interiorSafe.getState().id,'safe:hotel:manager:1');
 }finally{safe.dispose()}
});

test('opening really moves the narrow door collider, preserves the body and settles to no update work',async()=>{
 const safe=fixture({onUnlock:()=>({ok:true,opened:true})});try{
  const before=safe.getCollisionBodies();assert.equal(safe.getCollisionBodies(),before,'stable collider array when idle');
  for(let i=0;i<100;i++)assert.equal(safe.update(1/60),false);assert.equal(safe.stats().animationUpdates,0);
  await safe.unlock();assert.equal(safe.needsUpdate,true);assert.equal(safe.update(NaN),false);assert.equal(safe.update(-1),false);
  for(let i=0;i<100;i++)safe.update(1/60);
  assert.equal(safe.needsUpdate,false);assert.equal(safe.getState().openFraction,1);assert(Math.abs(safe.doorPivot.rotation.y+Math.PI*112/180)<1e-9);
  const after=safe.getCollisionBodies();assert.notEqual(before,after);assert.deepEqual(before.slice(0,5),after.slice(0,5),'static shell retained');assert.notDeepEqual(before.at(-1).polygonCR,after.at(-1).polygonCR,'leaf moves with exact hinge rotation');
  assert.equal(safe.getCollisionBodies(),after);assert(safe.stats().animationUpdates<=52,'bounded .85 second transition');
  const updates=safe.stats().animationUpdates;for(let i=0;i<600;i++)safe.update(.1);assert.equal(safe.stats().animationUpdates,updates);
  const oldMin=after[0].minYM;safe.object.position.set(8.2,4,12.3);const moved=safe.getCollisionBodies();assert.equal(moved[0].minYM,oldMin+4);assert(Math.abs(moved[0].polygonCR[0][0]-after[0].polygonCR[0][0]-2)<1e-9);
 }finally{safe.dispose()}
});

test('geometry, materials and colliders dispose only at the last lease, including late replies',async()=>{
 const wait=deferred(),a=fixture({onUnlock:()=>wait.promise}),b=fixture({id:'safe:hotel:manager:2'}),scene=new THREE.Scene();scene.add(a.object,b.object);
 const ag=a.object.getObjectByName('Safe_Hollow_Steel_Body').geometry,bg=b.object.getObjectByName('Safe_Hollow_Steel_Body').geometry;assert.equal(ag,bg);let disposed=0;ag.addEventListener('dispose',()=>disposed++);
 const pending=a.unlock();await Promise.resolve();a.dispose();a.dispose();assert.equal(disposed,0);assert.equal(scene.children.length,1);assert.equal(a.needsUpdate,false);assert.deepEqual(a.getCollisionBodies(),[]);
 wait.resolve({ok:true,opened:true,collected:true});assert.equal((await pending).reason,'disposed');assert.equal(a.getState().opened,false,'late reply cannot mutate discarded geometry');
 b.dispose();assert.equal(disposed,1);assert.equal(scene.children.length,0);
});

test('idle CPU baseline and cached collision lookup remain bounded without geometry churn',()=>{
 const safe=fixture();try{
  safe.getCollisionBodies();for(let i=0;i<20000;i++)safe.update(1/60);
  const samples=[],emptySamples=[];let sink=0;
  for(let block=0;block<16;block++){
   let start=performance.now();for(let i=0;i<10000;i++)sink+=0;emptySamples.push((performance.now()-start)/10000);
   start=performance.now();for(let i=0;i<10000;i++)sink+=Number(safe.update(1/60));samples.push((performance.now()-start)/10000);
  }
  const percentile=(values,f)=>values.sort((a,b)=>a-b)[Math.floor((values.length-1)*f)],start=performance.now(),array=safe.getCollisionBodies();for(let i=0;i<10000;i++)assert.equal(safe.getCollisionBodies(),array);
  const collisionMeanMs=(performance.now()-start)/10000;
  assert.equal(sink,0);assert.equal(safe.stats().animationUpdates,0);assert.equal(safe.stats().colliderBuilds,1);
  console.log(JSON.stringify({scenario:'one safe, no renderer; CPU only',before:{emptyCallP50Ms:percentile(emptySamples,.5),emptyCallP95Ms:percentile(emptySamples,.95)},after:{idleUpdateP50Ms:percentile(samples,.5),idleUpdateP95Ms:percentile(samples,.95),cachedCollisionMeanMs:collisionMeanMs},...safe.stats(),limitation:'Performance of the loaded game scene is not verified'}));
 }finally{safe.dispose()}
});
