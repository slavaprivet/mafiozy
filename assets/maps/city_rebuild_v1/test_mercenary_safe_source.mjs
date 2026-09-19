import assert from 'node:assert/strict';
import {createMercenarySafeBinding,authorizeMercenarySafe} from './mercenary_safe_source.mjs';
import {createMercenarySquad} from './mercenary_core.mjs';
import {interiorSafeTargets as registry,registerInteriorSafe,requestInteriorSafeAction} from './interior_safe_registry.mjs';
const buildingId='hotel_01',roomId='hotel_01:floor:1:room:0',id='interior-safe:'+roomId;
const storageData=new Map(),storage={getItem:k=>storageData.get(k)??null,setItem:(k,v)=>storageData.set(k,v)};
const location='http://127.0.0.1:18538/world.html?previewcity=1&renderer=walk';
let state={id,buildingId,roomId,locked:true,opened:false,collected:false},hydrations=0,time=1000,resolveCount=0,nearLoot=false;const balances=[];
const safe={object:{userData:{mercenaryTarget:{id,kind:'safe',buildingId,roomId,reward:57}}},getState:()=>({...state}),
  applySourceState:s=>{state={...state,...s};hydrations++;},
  async unlock(context){const receipt=await requestInteriorSafeAction('unlock',id,{buildingId,roomId,requestId:id+':unlock',context});if(receipt.ok)safe.applySourceState(receipt);return receipt;},collect:()=>{throw Error('Unexpected collect')}};
const unregister=registerInteriorSafe(safe,{purpose:'hotel',position:[0,0,0]});
let core=createMercenarySquad({now:()=>time,getMember:id=>({id,hp:100,available:true,position:{x:0,y:0,z:0}}),getTarget:()=>({...state,kind:'safe',position:{x:0,y:0,z:0}}),performEffect:e=>safe.unlock(e)});
core.recruit({id:'locksmith',profession:'safecracker'});
const host={canUseLocalEffects:()=>true,getMember:id=>({id,hp:100,available:true}),getAction:id=>core.getAction(id),getRoster:()=>({members:core.getRoster()}),
  canCollectSafeLoot:()=>nearLoot,syncSafeLootBalance:balance=>balances.push(balance),
  getPendingTransactions:()=>core.snapshot().pendingTransactions,resolvePending:(id,receipt)=>{resolveCount++;return core.resolvePending(id,receipt);}};
const binding=createMercenarySafeBinding({getHost:()=>host,getRegistry:()=>registry,storage,location});await binding.update(time);
assert(registry.getSource());assert.equal(hydrations,1,'Real setSource hydrates actual registered safe');
const source=registry.getSource();assert.equal(source.getState(id).locked,true);
const unauthorized={safe:state,action:'unlock',context:{memberId:'locksmith',actionId:1,profession:'safecracker'}};
assert.equal(authorizeMercenarySafe(host,unauthorized).ok,false,'Claimed UI profession is not an active order');
assert(core.command('locksmith','unlock_safe',id).ok);core.update();const current=core.getAction('locksmith');
assert(authorizeMercenarySafe(host,{...unauthorized,context:{memberId:'locksmith',actionId:current.id}}).ok);
for(const context of [{memberId:'intruder',actionId:current.id},{memberId:'locksmith',actionId:current.id+1}])assert.equal(authorizeMercenarySafe(host,{...unauthorized,context}).ok,false);
assert.equal(authorizeMercenarySafe({...host,getRoster:()=>({members:[{id:'locksmith',profession:'medic'}]})},{...unauthorized,context:{memberId:'locksmith',actionId:current.id}}).ok,false);
assert.equal(authorizeMercenarySafe(host,{...unauthorized,safe:{...state,id:'wrong-safe'},context:{memberId:'locksmith',actionId:current.id}}).ok,false);
time+=8;core.update();assert.equal(core.getAction('locksmith').phase,'awaiting');assert.equal(core.getRoster()[0].xp,0);
const pendingSave=core.snapshot();await new Promise(r=>setImmediate(r));
assert.equal(state.opened,true);assert.equal(state.collected,false);assert.equal(core.getRoster()[0].xp,25);
assert.equal(source.getLocalLedger().entries.length,0);assert.equal(source.getLocalLedger().balance,0,'Unlock drops uncollected money instead of remote award');
assert.equal((await source.collect({safeId:id,buildingId,roomId,requestId:id+':collect'})).ok,false,'Distance guard rejects distant loot');
nearLoot=true;assert.equal((await source.collect({safeId:id,buildingId,roomId,requestId:id+':collect'})).ok,true);
assert.equal(source.getLocalLedger().entries.length,1);assert.equal(source.getLocalLedger().balance,57);assert.equal(balances.at(-1),57,'Receipt synchronizes actual game balance');
const duplicate=await source.unlock({safeId:id,buildingId,roomId,requestId:id+':unlock',context:{profession:'safecracker'}});
assert(duplicate.duplicate);assert.equal(duplicate.gained,0);assert.equal(source.getLocalLedger().entries.length,1,'Reopened safe never awards twice');
binding.dispose();assert.equal(registry.getSource(),null);assert.equal((await source.hydrate()).ok,false);
core=createMercenarySquad({now:()=>time,getMember:id=>({id,hp:100,position:{x:0,y:0,z:0}}),performEffect:()=>{throw Error('Must not resend restored transaction');}});
assert(core.restore(pendingSave).ok);state={...state,opened:false,collected:false,locked:true};
const restored=createMercenarySafeBinding({getHost:()=>host,getRegistry:()=>registry,storage,location});await restored.update(time+2);
assert.equal(state.opened,true,'Hydration restores physical presentation');assert.equal(resolveCount,1,'Source receipt reconciles one pending transaction');
assert.equal(core.getAction('locksmith'),null);assert.equal(core.getRoster()[0].xp,25);assert.equal(registry.getSource().getLocalLedger().entries.length,1);
await restored.update(time+4);assert.equal(resolveCount,1);restored.dispose();
const other={hydrate:async()=>({ok:true,safes:[]})};await registry.setSource(other);
const respectful=createMercenarySafeBinding({getHost:()=>host,getRegistry:()=>registry,storage,location});await respectful.update(time+6);assert.equal(registry.getSource(),other);respectful.dispose();assert.equal(registry.getSource(),other,'Disposal never unbinds another owner');
await registry.setSource(null);unregister();assert.equal(registry.getTargets().length,0);
console.log('PASS mercenary safe binding: actual registry hydration/core command/source ledger, fake profession/order rejection, once reward, restored pending without resend, other authority/dispose');
{
 const rows=[{id,buildingId,roomId,reward:57}],secondRoom='hotel_01:floor:2:main',secondId='interior-safe:'+secondRoom;
 let bound=null,pending=[],attempts=0;
 const reg={getTargets:()=>rows,getSource:()=>bound,async setSource(s){bound=s;attempts++;return s?await s.hydrate({safeIds:rows.map(r=>r.id)}):{ok:false};}};
 const dynamicHost={...host,getPendingTransactions:()=>pending,getRoster:()=>({members:[]})};
 const dynamic=createMercenarySafeBinding({getHost:()=>dynamicHost,getRegistry:()=>reg,storage,location});
 await dynamic.update(2000);const original=bound;assert(original.getState(id));
 rows.push({id:secondId,buildingId,roomId:secondRoom,reward:30});pending=[{requestId:99,kind:'unlock_safe',targetId:id}];
 await dynamic.update(2002);assert.equal(bound,original,'Awaiting transaction blocks replacement');assert.equal(bound.getState(secondId),null);
 pending=[];await dynamic.update(2004);assert.notEqual(bound,original);assert(bound.getState(secondId),'Late constructed safe is registered and hydrated');
 assert.equal((await original.hydrate()).reason,'disposed');const before=attempts;await dynamic.update(2006);assert.equal(attempts,before,'Stable IDs do not recreate source');dynamic.dispose();assert.equal(bound,null);
}
{
 let bound=null,fail=true,attempts=0;const rows=[{id,buildingId,roomId,reward:57}];
 const reg={getTargets:()=>rows,getSource:()=>bound,async setSource(s){bound=s;if(!s)return {ok:false};attempts++;return fail?{ok:false,reason:'temporary_failure'}:s.hydrate({safeIds:[id]});}};
 const retry=createMercenarySafeBinding({getHost:()=>({...host,getPendingTransactions:()=>[]}),getRegistry:()=>reg,storage,location});
 const warn=console.warn;console.warn=()=>{};try{await retry.update(3000);}finally{console.warn=warn;}
 assert.equal(bound,null,'Failed receipt releases its own binding');fail=false;await retry.update(3002);assert(bound);assert.equal(attempts,2);retry.dispose();
}
{
 let bound=null;const otherOwner={owner:true};
 const reg={getTargets:()=>[{id,buildingId,roomId,reward:57}],getSource:()=>bound,async setSource(s){bound=s?otherOwner:null;return {ok:false,reason:'source_changed'};}};
 const racing=createMercenarySafeBinding({getHost:()=>host,getRegistry:()=>reg,storage,location});const warn=console.warn;console.warn=()=>{};try{await racing.update(4000);}finally{console.warn=warn;}
 assert.equal(bound,otherOwner,'Failed candidate never unbinds replacement authority');racing.dispose();assert.equal(bound,otherOwner);
}
console.log('PASS safe binding refresh: late room IDs, awaiting protection, stable signature, failed receipt retry, concurrent authority preservation');
