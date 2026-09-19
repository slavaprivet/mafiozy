import test from 'node:test';
import assert from 'node:assert/strict';
import {createInteriorSafeSource,defaultInteriorSafeReward} from './interior_safe_source.mjs';

const buildingId='hotel_01',roomId='hotel_01:floor:1:room:0',id='interior-safe:'+roomId;
const registry=[{id,buildingId,roomId,purpose:'hotel',position:[10,3.4,20],reward:57}],args={safeId:id,buildingId,roomId,requestId:id+':unlock'};
const memoryStorage=()=>{let value=null;return {getItem:()=>value,setItem:(key,next)=>{value=next},peek:()=>value}};
const localOptions=(storage,extra={})=>({standalone:true,userId:'local-player',registry,storage,location:'http://127.0.0.1:18538/walk?standalone=1',authorize:()=>({ok:true}),...extra});
const accepted={ok:true,id,targetId:id,buildingId,roomId,opened:true,locked:false,collected:true,revision:1,cash:157,gained:57};
const deferred=()=>{let resolve;const promise=new Promise(r=>resolve=r);return {promise,resolve}};

test('authenticated source uses the supplied credential transport with only canonical request fields',async()=>{
 let called;const source=createInteriorSafeSource({userId:'111',registry,request:async(url,init)=>{called={url,init};return {ok:true,json:async()=>accepted}}});
 try{
  const receipt=await source.unlock({...args,cash:99999,position:[0,0,0],profession:'safecracker',context:{mercenaryId:'untrusted'}});
  assert.equal(receipt.ok,true);assert.equal(called.url,'/world/interior-safes/111');assert.equal(called.init.method,'POST');
  assert.deepEqual(JSON.parse(called.init.body),{action:'unlock',...args});assert.equal(source.getState(id).collected,true);
  assert.equal(source.getLocalLedger().reason,'standalone_not_allowed');
 }finally{source.dispose()}
});

test('authenticated failures, missing authority, wrong target and unconfirmed replies never populate state',async()=>{
 for(const reply of[{ok:false,reason:'mercenary_not_authorized'},{ok:false,reason:'unauthorized'},{ok:true}, {...accepted,id:'wrong'}, {...accepted,collected:false}]){
  const source=createInteriorSafeSource({userId:'111',registry,request:()=>reply});try{assert.equal((await source.unlock(args)).ok,false);assert.equal(source.getState(id),null)}finally{source.dispose()}
 }
 const offline=createInteriorSafeSource({userId:'111',registry});try{assert.equal((await offline.unlock(args)).reason,'source_not_connected')}finally{offline.dispose()}
 const failed=createInteriorSafeSource({userId:'111',registry,request:()=>{throw Error('offline')}});try{assert.equal((await failed.unlock(args)).reason,'source_unavailable')}finally{failed.dispose()}
});

test('standalone source is guarded by both explicit option and loopback standalone URL',async()=>{
 for(const location of['https://example.com/walk?standalone=1','http://127.0.0.1/walk','file:///walk?standalone=1','http://localhost/walk?standalone=0']){
  const storage=memoryStorage(),source=createInteriorSafeSource(localOptions(storage,{location}));try{assert.equal((await source.unlock(args)).reason,'standalone_not_allowed');assert.equal((await source.hydrate()).reason,'standalone_not_allowed');assert.equal(storage.peek(),null)}finally{source.dispose()}
 }
 const storage=memoryStorage(),authenticated=createInteriorSafeSource({standalone:false,userId:'111',registry,storage,location:'http://localhost/walk?standalone=1'});
 try{assert.equal((await authenticated.unlock(args)).reason,'source_not_connected');assert.equal(storage.peek(),null)}finally{authenticated.dispose()}
});

test('standalone ledger persists once across adapter recreation and multiple users',async()=>{
 const storage=memoryStorage(),first=createInteriorSafeSource(localOptions(storage));let changes=0;first.subscribe(()=>changes++);
 const before=await first.hydrate();assert.equal(before.safes[0].opened,false);
 const award=await first.unlock(args);assert.equal(award.gained,57);assert.equal(award.localBalance,57);assert.equal(award.cash,undefined,'does not masquerade as authenticated money');assert.equal(changes,2);first.dispose();
 const restored=createInteriorSafeSource(localOptions(storage,{authorize:undefined})),other=createInteriorSafeSource(localOptions(storage,{userId:'other-player',authorize:undefined}));
 try{
  const state=await restored.hydrate();assert.equal(state.safes[0].opened,true);assert.equal(state.safes[0].collected,true);
  assert.equal((await restored.unlock(args)).gained,0);assert.equal((await other.unlock(args)).gained,0);
  const ledger=restored.getLocalLedger();assert.equal(ledger.entries.length,1);assert.equal(ledger.balance,57);assert.equal(other.getLocalLedger().balance,0);
  assert.equal(ledger.entries[0].safeId,id);assert.equal(ledger.entries[0].requestId,args.requestId);
 }finally{restored.dispose();other.dispose()}
});

test('source world local preview needs explicit host permission, loopback and owned squad authorization',async()=>{
 const storage=memoryStorage();let permitted=true,seenContext;
 const options={standalone:false,localPreview:true,userId:'preview-player',registry,storage,location:'http://127.0.0.1:18538/world.html?direct=1&previewcity=1&renderer=walk',allowLocal:()=>permitted,authorize:({context})=>{seenContext=context;return {ok:true}}};
 const source=createInteriorSafeSource(options);
 try{
  const receipt=await source.unlock({...args,context:{actionId:123,mercenaryId:'hired-1'}});assert.equal(receipt.source,'local-preview');assert.equal(receipt.gained,57);assert.equal(seenContext.actionId,123);assert.equal(source.getLocalLedger().entries[0].actionId,123);
  permitted=false;assert.equal((await source.hydrate()).reason,'standalone_not_allowed');assert.equal((await source.unlock(args)).reason,'standalone_not_allowed');
 }finally{source.dispose()}
 for(const override of[{allowLocal:undefined},{allowLocal:()=>false},{location:'https://example.com/world.html?previewcity=1'},{authorize:undefined}]){
  const other=createInteriorSafeSource({...options,storage:memoryStorage(),allowLocal:()=>true,...override});try{assert.equal((await other.unlock(args)).ok,false)}finally{other.dispose()}
 }
});

test('parallel local source instances share a serialized global safe ledger',async()=>{
 const storage=memoryStorage(),a=createInteriorSafeSource(localOptions(storage)),b=createInteriorSafeSource(localOptions(storage,{userId:'second'}));
 try{
  const [x,y]=await Promise.all([a.unlock(args),b.unlock(args)]);assert.equal(Number(x.duplicate)+Number(y.duplicate),1);assert.equal(x.gained+y.gained,57);assert.equal(a.getLocalLedger().entries.length,1);
 }finally{a.dispose();b.dispose()}
});

test('local permission is host-owned and storage failure cannot report an open paid safe',async()=>{
 const storage=memoryStorage(),unbound=createInteriorSafeSource(localOptions(storage,{authorize:undefined}));
 try{assert.equal((await unbound.unlock({...args,profession:'safecracker',authorized:true})).reason,'mercenary_not_authorized');assert.equal(storage.peek(),null)}finally{unbound.dispose()}
 const broken={getItem:()=>null,setItem:()=>{throw Error('quota')}},source=createInteriorSafeSource(localOptions(broken));
 try{assert.equal((await source.unlock(args)).reason,'storage_unavailable');assert.equal(source.getState(id),null)}finally{source.dispose()}
 const corrupt=createInteriorSafeSource(localOptions({getItem:()=>'{broken',setItem(){throw Error('must not overwrite')}}));try{assert.equal((await corrupt.hydrate()).reason,'storage_state_invalid');assert.equal((await corrupt.unlock(args)).reason,'storage_state_invalid')}finally{corrupt.dispose()}
});

test('inflight remote work is deduplicated and late disposal does not change visuals',async()=>{
 const wait=deferred();let calls=0;const source=createInteriorSafeSource({userId:'111',registry,request:()=>{calls++;return wait.promise}});
 const a=source.unlock(args),b=source.unlock(args);assert.equal(a,b);await Promise.resolve();assert.equal(calls,1);source.dispose();wait.resolve(accepted);
 assert.equal((await a).reason,'disposed');assert.equal(source.getState(id),null);assert.equal((await source.unlock(args)).reason,'disposed');
});

test('hydrate validates source identities and stale refresh cannot close confirmed safe',async()=>{
 let next={ok:true,safes:[accepted]};const source=createInteriorSafeSource({userId:'111',registry,request:()=>next});
 try{
  assert.equal((await source.hydrate()).ok,true);next={ok:true,safes:[{...accepted,opened:false,collected:false,revision:0}]};await source.hydrate();assert.equal(source.getState(id).opened,true);assert.equal(source.getState(id).collected,true);
  next={ok:true,safes:[{...accepted,id:'wrong'}]};assert.equal((await source.hydrate()).reason,'invalid_source_state');
  assert.equal((await source.unlock({...args,safeId:'fabricated'})).reason,'unknown_safe');assert.equal((await source.unlock({...args,requestId:'invented'})).reason,'invalid_request_id');
 }finally{source.dispose()}
});

test('server and standalone defaults are stable within the existing building-find range',()=>{
 assert.equal(defaultInteriorSafeReward(id),80,'Python manifest default for this canonical ID is also 80');
 for(let i=0;i<200;i++){const value=defaultInteriorSafeReward('interior-safe:b:floor:'+i+':main');assert(value>=15&&value<=80)}
});
