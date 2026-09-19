import test from 'node:test';
import assert from 'node:assert/strict';
import {pathToFileURL} from 'node:url';
import {createInteriorSafe} from './interior_interactive_safe.mjs';
import {interiorSafeTargets,registerInteriorSafe,requestInteriorSafeAction} from './interior_safe_registry.mjs';
import {createInteriorSafeSource} from './interior_safe_source.mjs';
const T=await import(pathToFileURL('D:/codex_release/artist13_hero_first_DEV_20260907/demo/vendor/build/three.module.js'));
test('constructed safe registry binds the persisted source, animates the actual leaf and restores across scene rebuilds',async()=>{
 const buildingId='test-native',roomId=buildingId+':floor:1:room:1',id='interior-safe:'+roomId,values=new Map(),storage={getItem:k=>values.get(k)??null,setItem:(k,v)=>values.set(k,v)},scene=new T.Scene();
 const make=()=>{const safe=createInteriorSafe(T,{id,buildingId,roomId,onUnlock:(id,d)=>requestInteriorSafeAction('unlock',id,d),onCollect:(id,d)=>requestInteriorSafeAction('collect',id,d)});scene.add(safe.object);const unregister=registerInteriorSafe(safe,{purpose:'residential',position:[0,0,0]});return{safe,dispose(){unregister();safe.dispose()}}};
 let active=make(),source;
 try{
  source=createInteriorSafeSource({standalone:true,userId:'local',location:'http://127.0.0.1/walk?standalone=1',registry:interiorSafeTargets.getTargets(),storage,authorize:({context})=>({ok:context.actionId===27&&context.memberId==='safecracker'})});
  assert.equal((await interiorSafeTargets.setSource(source)).ok,true);assert.equal(interiorSafeTargets.getTargets()[0].locked,true);
  assert.equal((await active.safe.object.userData.mercenaryTarget.unlock({actionId:0})).ok,false);
  const before=active.safe.getCollisionBodies(),receipt=await interiorSafeTargets.getTargets()[0].unlock({actionId:27,memberId:'safecracker'});assert.equal(receipt.ok,true);assert.equal(interiorSafeTargets.getTargets()[0].locked,false);assert.equal(active.safe.needsUpdate,true);
  for(let i=0;i<15;i++)active.safe.update(.1);assert.equal(active.safe.needsUpdate,false);assert.notStrictEqual(active.safe.getCollisionBodies(),before);assert.equal(active.safe.getState().collected,true);
  active.dispose();assert.equal(interiorSafeTargets.getTargets().length,0);active=make();await interiorSafeTargets.setSource(source);assert.equal(active.safe.getState().opened,true);assert.equal(active.safe.getState().openFraction,1);assert.equal(active.safe.needsUpdate,false);assert.equal((await active.safe.unlock({actionId:27,memberId:'safecracker'})).duplicate,true);
 }finally{active.dispose();await interiorSafeTargets.setSource(null);source?.dispose()}
 assert.equal(interiorSafeTargets.getTargets().length,0);
});
