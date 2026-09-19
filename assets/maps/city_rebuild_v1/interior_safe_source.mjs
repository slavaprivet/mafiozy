// Native-room safe state. Authenticated play always uses the source transport;
// isolated play has its own persisted ledger, never the world UI's cash field.
const LOCAL_KEY='mafiozi.native-interior-safes.standalone.v1',localQueues=new Map();
const fail=reason=>({ok:false,reason});
const clone=value=>JSON.parse(JSON.stringify(value));
const canonical=(buildingId,roomId)=>typeof buildingId==='string'&&buildingId.length>0&&buildingId.length<=160&&typeof roomId==='string'&&roomId.startsWith(buildingId+':floor:')&&/^\d+:(?:main|room:\d+)$/.test(roomId.slice(buildingId.length+7))?'interior-safe:'+roomId:null;
export function defaultInteriorSafeReward(id){let value=2166136261;for(const byte of new TextEncoder().encode(id))value=Math.imul(value^byte,16777619)>>>0;return 15+value%66}
function localAllowed(standalone,localPreview,allowLocal,location){
 try{const url=new URL(typeof location==='string'?location:location?.href);if(!['localhost','127.0.0.1','[::1]'].includes(url.hostname)||!['http:','https:'].includes(url.protocol))return false;if(standalone===true&&url.searchParams.get('standalone')==='1')return true;return localPreview===true&&typeof allowLocal==='function'&&allowLocal()===true}catch{return false}
}
function registryMap(registry){
 const rows=registry instanceof Map?[...registry.values()]:Array.isArray(registry)?registry:registry?.safes||[],map=new Map();
 if(!Array.isArray(rows)||rows.length>1024)throw new TypeError('Invalid native safe registry');
 for(const row of rows){
  const id=canonical(row?.buildingId,row?.roomId),reward=row?.reward??defaultInteriorSafeReward(id||'');
  if(!id||row.id!==id||map.has(id)||!Number.isInteger(reward)||reward<0||reward>5000)throw new TypeError('Invalid canonical native safe');
  map.set(id,Object.freeze({...row,reward}));
 }return map;
}
function serialLocal(storageKey,locks,operation){
 if(typeof locks?.request==='function')return locks.request(storageKey,{mode:'exclusive'},operation);
 const previous=localQueues.get(storageKey)||Promise.resolve(),current=previous.catch(()=>{}).then(operation);localQueues.set(storageKey,current);
 return current.finally(()=>{if(localQueues.get(storageKey)===current)localQueues.delete(storageKey)});
}

/** request is the source's credential-bearing (url, fetchOptions) transport.
 * authorize is used only by standalone and must read its owned squad state.
 * It returns {ok:true}; JSON fields claiming a profession are never examined.
 */
export function createInteriorSafeSource({standalone=false,localPreview=false,allowLocal,userId,request,registry=[],storage,location=globalThis.location,locks=globalThis.navigator?.locks,authorize,dropLoot=false,storageKey=localPreview===true&&standalone!==true?'mafiozi.native-interior-safes.local-preview.v1':LOCAL_KEY}={}){
 const uid=String(userId??''),registered=registryMap(registry),cache=new Map(),pending=new Map(),listeners=new Set();let disposed=false;
 const local=standalone===true||localPreview===true,localLabel=standalone===true?'standalone':'local-preview';
 if(!uid||uid.length>160||!local&&!/^[1-9]\d{0,17}$/.test(uid))throw new TypeError('A bound source userId is required');
 const allowed=()=>localAllowed(standalone,localPreview,allowLocal,location),route='/world/interior-safes/'+encodeURIComponent(uid);
 function storageOf(){if(storage)return storage;try{return globalThis.localStorage}catch{return null}}
 function readLocal(){
  const target=storageOf();if(!target||typeof target.getItem!=='function'||typeof target.setItem!=='function')throw Error('storage_unavailable');
  let text;try{text=target.getItem(storageKey)}catch{throw Error('storage_unavailable')}
  if(text==null)return {version:1,states:{},ledger:[],balances:{}};
  let state;try{state=JSON.parse(text)}catch{throw Error('storage_state_invalid')}
  if(state?.version!==1||!state.states||typeof state.states!=='object'||Array.isArray(state.states)||!Array.isArray(state.ledger)||!state.balances||typeof state.balances!=='object'||Array.isArray(state.balances))throw Error('storage_state_invalid');
  return state;
 }
 function writeLocal(state){try{storageOf().setItem(storageKey,JSON.stringify(state))}catch{throw Error('storage_unavailable')}}
 function remember(snapshot){
  if(disposed||!snapshot?.id)return;const previous=cache.get(snapshot.id),next={...snapshot};
  if(previous){if((snapshot.revision??0)<(previous.revision??0))return;next.opened=previous.opened||!!next.opened;next.collected=previous.collected||!!next.collected;next.locked=!next.opened}
  cache.set(next.id,next);for(const listener of listeners)try{listener(clone(next))}catch{}
 }
 function stateFor(safe,state){const row=state.states[safe.id];return {id:safe.id,targetId:safe.id,buildingId:safe.buildingId,roomId:safe.roomId,opened:!!row,locked:!row,collected:!!row&&row.collected!==false,lootDropped:row?.lootDropped===true,revision:row?(row.revision||1):0}}
 function resolve(args){
  const id=canonical(args?.buildingId,args?.roomId);if(!id||args.safeId!==id)return null;
  return registered.get(id)||(local?null:{id,buildingId:args.buildingId,roomId:args.roomId});
 }
 async function remote(payload){
  if(typeof request!=='function')return fail('source_not_connected');
  try{
   const response=await request(route,{method:'POST',headers:{'Content-Type':'application/json'},body:JSON.stringify(payload)});
   const data=typeof response?.json==='function'?await response.json():response;
   if(response?.ok===false||data?.ok!==true)return fail(data?.reason||data?.error||'source_rejected');
   return data;
  }catch{return fail('source_unavailable')}
 }
 async function localAction(action,safe,args){
  if(!allowed())return fail('standalone_not_allowed');
  try{return await serialLocal(storageKey,locks,async()=>{
   if(disposed)return fail('disposed');
   if(!allowed())return fail('standalone_not_allowed');
   let state=readLocal(),existing=state.states[safe.id];
   if(dropLoot){
    const reply=(duplicate,gained=0)=>({ok:true,...stateFor(safe,state),duplicate,gained,localBalance:Number(state.balances[uid])||0,source:localLabel});
    if(existing&&(action==='unlock'||existing.collected!==false))return reply(true);
    if(action==='collect'&&!existing)return fail('locked');
    if(typeof authorize!=='function')return fail('mercenary_not_authorized');
    let permission;try{permission=await authorize({safe,action,context:args.context})}catch{return fail('mercenary_not_authorized')}
    if(disposed)return fail('disposed');if(!allowed())return fail('standalone_not_allowed');if(permission?.ok!==true)return fail(permission?.reason||'mercenary_not_authorized');
    state=readLocal();existing=state.states[safe.id];
    if(existing&&(action==='unlock'||existing.collected!==false))return reply(true);
    if(action==='unlock'){
     state.states[safe.id]={safeId:safe.id,buildingId:safe.buildingId,roomId:safe.roomId,openedBy:uid,collected:false,lootDropped:true,revision:1,at:Date.now()};
     writeLocal(state);return reply(false);
    }
    if(!existing)return fail('locked');
    const balance=Number(state.balances[uid]||0);if(!Number.isSafeInteger(balance)||balance<0)throw Error('storage_state_invalid');
    const entry={safeId:safe.id,buildingId:safe.buildingId,roomId:safe.roomId,awardedTo:uid,amount:safe.reward,requestId:safe.id+':collect',at:Date.now()};
    state.states[safe.id]={...existing,...entry,collected:true,revision:2};state.ledger.push(entry);state.balances[uid]=balance+safe.reward;
    writeLocal(state);return reply(false,safe.reward);
   }
   if(existing)return {ok:true,...stateFor(safe,state),duplicate:true,gained:0,localBalance:Number(state.balances[uid])||0,awardedTo:String(existing.awardedTo),source:localLabel};
   if(action==='collect')return fail('locked');
   if(typeof authorize!=='function')return fail('mercenary_not_authorized');
   let permission;try{permission=await authorize({safe,action,context:args.context})}catch{return fail('mercenary_not_authorized')}
   if(disposed)return fail('disposed');if(!allowed())return fail('standalone_not_allowed');if(permission?.ok!==true)return fail(permission?.reason||'mercenary_not_authorized');
   // Re-read after asynchronous permission resolution; never overwrite another
   // confirmed operation or cached ledger with an earlier snapshot.
   state=readLocal();existing=state.states[safe.id];
   if(existing)return {ok:true,...stateFor(safe,state),duplicate:true,gained:0,localBalance:Number(state.balances[uid])||0,awardedTo:String(existing.awardedTo),source:localLabel};
   const balance=Number(state.balances[uid]||0);if(!Number.isSafeInteger(balance)||balance<0)throw Error('storage_state_invalid');
   const entry={safeId:safe.id,buildingId:safe.buildingId,roomId:safe.roomId,awardedTo:uid,amount:safe.reward,requestId:safe.id+':unlock',at:Date.now()};
   if(typeof args.context?.actionId==='string'||Number.isSafeInteger(args.context?.actionId))entry.actionId=args.context.actionId;
   state.states[safe.id]=entry;state.ledger.push(entry);state.balances[uid]=balance+safe.reward;
   writeLocal(state);return {ok:true,...stateFor(safe,state),duplicate:false,gained:safe.reward,localBalance:state.balances[uid],awardedTo:uid,source:localLabel};
  })}catch(error){return fail(error?.message==='storage_state_invalid'?'storage_state_invalid':'storage_unavailable')}
 }
 function act(action,args={}){
  if(disposed)return Promise.resolve(fail('disposed'));const safe=resolve(args);if(!safe)return Promise.resolve(fail('unknown_safe'));
  const requestId=args.requestId??safe.id+':'+action;if(requestId!==safe.id+':'+action)return Promise.resolve(fail('invalid_request_id'));
  const key=safe.id+':'+action;if(pending.has(key))return pending.get(key);
  const payload={action,safeId:safe.id,buildingId:safe.buildingId,roomId:safe.roomId,requestId};
  const task=Promise.resolve().then(()=>local?localAction(action,safe,args):remote(payload)).then(receipt=>{
   if(disposed)return fail('disposed');if(receipt?.ok!==true)return receipt;
   if((receipt.id??receipt.targetId)!==safe.id||receipt.opened!==true||(!(local&&dropLoot&&action==='unlock')&&receipt.collected!==true))return fail('unconfirmed_safe_state');
   remember({...receipt,id:safe.id});return receipt;
  }).finally(()=>pending.delete(key));pending.set(key,task);return task;
 }
 async function hydrate({safeIds}={}){
  if(disposed)return fail('disposed');const ids=safeIds??(registered.size?[...registered.keys()]:undefined);
  if(ids!==undefined&&(!Array.isArray(ids)||ids.length>128||ids.some(id=>typeof id!=='string'||local&&!registered.has(id))))return fail('unknown_safe');
  let receipt;
  if(local){if(!allowed())return fail('standalone_not_allowed');try{const state=readLocal();receipt={ok:true,safes:(ids||[]).map(id=>stateFor(registered.get(id),state)),source:localLabel}}catch(error){return fail(error.message||'storage_unavailable')}}
  else receipt=await remote({action:'hydrate',...(ids?{safeIds:ids}:{})});
  if(disposed)return fail('disposed');if(receipt?.ok!==true)return receipt;
  if(!Array.isArray(receipt.safes)||receipt.safes.some(s=>!canonical(s?.buildingId,s?.roomId)||s.id!==canonical(s.buildingId,s.roomId)))return fail('invalid_source_state');
  for(const snapshot of receipt.safes)remember(snapshot);return receipt;
 }
 return {unlock:args=>act('unlock',args),collect:args=>act('collect',args),hydrate,
  getState(id){const state=cache.get(id);return state?clone(state):null},
  subscribe(listener){if(typeof listener!=='function'||disposed)return()=>{};listeners.add(listener);return()=>listeners.delete(listener)},
  getLocalLedger(){if(!local||!allowed())return fail('standalone_not_allowed');try{const state=readLocal();return {ok:true,entries:clone(state.ledger),balance:Number(state.balances[uid])||0,source:localLabel}}catch(error){return fail(error.message||'storage_unavailable')}},
  dispose(){disposed=true;listeners.clear();cache.clear()},
 };
}
