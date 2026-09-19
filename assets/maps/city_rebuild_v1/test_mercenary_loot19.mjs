import test from 'node:test';
import assert from 'node:assert/strict';
import {pathToFileURL} from 'node:url';
import {createInteriorSafeSource} from './interior_safe_source.mjs';
import {createInteriorSafe} from './interior_interactive_safe.mjs';
import {registerInteriorSafe,interiorSafeTargets} from './interior_safe_registry.mjs';
const THREE=await import(pathToFileURL(process.env.MAFIOZY_THREE||'D:/codex_release/artist13_hero_first_DEV_20260907/demo/vendor/build/three.module.js'));
const buildingId='hotel_01',roomId=buildingId+':floor:0:main',id='interior-safe:'+roomId;
const registry=[{id,buildingId,roomId,reward:57}],args={safeId:id,buildingId,roomId};
const storage=()=>{let value=null;return{getItem:()=>value,setItem:(k,v)=>value=v};};
const options=store=>({standalone:true,dropLoot:true,userId:'local-player',registry,storage:store,location:'http://127.0.0.1/walk?standalone=1',authorize:()=>({ok:true})});
test('physical loot survives reload and concurrent collection awards exactly once',async()=>{
 const store=storage(),source=createInteriorSafeSource(options(store));
 const opened=await source.unlock(args);assert.equal(opened.opened,true);assert.equal(opened.collected,false);assert.equal(opened.lootDropped,true);assert.equal(opened.gained,0);assert.equal(source.getLocalLedger().balance,0);source.dispose();
 const a=createInteriorSafeSource(options(store)),b=createInteriorSafeSource(options(store));
 assert.equal((await a.hydrate()).safes[0].collected,false);
 const receipts=await Promise.all([a.collect(args),b.collect(args)]);assert.equal(receipts.reduce((n,r)=>n+r.gained,0),57);assert.equal(a.getLocalLedger().entries.length,1);assert.equal((await b.unlock(args)).gained,0);a.dispose();b.dispose();
});
test('legacy paid safes cannot respawn a bag or pay again after opting into loot',async()=>{
 const store=storage(),old=createInteriorSafeSource({...options(store),dropLoot:false});assert.equal((await old.unlock(args)).gained,57);old.dispose();
 const next=createInteriorSafeSource(options(store));const state=(await next.hydrate()).safes[0];assert.equal(state.collected,true);assert.equal(state.lootDropped,false);assert.equal((await next.collect(args)).gained,0);next.dispose();
});
test('safe bag drops outside opened body then disappears only on collection receipt',async()=>{
 const safe=createInteriorSafe(THREE,{id,buildingId,roomId,onUnlock:()=>({ok:true,opened:true,collected:false,lootDropped:true,revision:1}),onCollect:()=>({ok:true,opened:true,collected:true,revision:2,gained:57})});
 const unregister=registerInteriorSafe(safe);
 try{
  await safe.unlock();assert.equal(safe.lootBag.visible,false);assert.equal(interiorSafeTargets.getLootTargets().length,1);
  for(let i=0;i<25;i++)safe.update(.1);
  assert.equal(safe.needsUpdate,false);assert.equal(safe.lootBag.visible,true);assert.equal(safe.lootBag.position.z,1.05);assert.equal(safe.lootBag.position.y,0);assert.equal(safe.stats().draws,3);
  const approach=safe.object.userData.mercenaryTarget.getApproachPosition();assert(approach.z>safe.lootBag.position.z,'operator anchor is separate from the dropped bag position');
  assert.equal((await interiorSafeTargets.getLootTargets()[0].collect()).gained,57);assert.equal(safe.lootBag.visible,false);assert.equal(interiorSafeTargets.getLootTargets().length,0);assert.equal(safe.stats().draws,2);
 }finally{unregister();safe.dispose();}
});
