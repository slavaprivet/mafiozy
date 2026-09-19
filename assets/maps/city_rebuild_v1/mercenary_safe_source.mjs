import {createInteriorSafeSource} from './interior_safe_source.mjs';

// The actual local squad authorizes a safe, never profession text from the UI.
export function authorizeMercenarySafe(host,{safe,action,context}={}){
 if(host?.canUseLocalEffects?.()!==true)return {ok:false,reason:'mercenary_not_authorized'};
 if(action==='collect')return host.canCollectSafeLoot?.(safe)===true?{ok:true}:{ok:false,reason:'loot_out_of_range'};
 if(action!=='unlock'||!context)return {ok:false,reason:'mercenary_not_authorized'};
 const member=host.getMember?.(context.memberId),order=host.getAction?.(context.memberId),record=host.getRoster?.().members?.find(r=>r.id===member?.id);
 if(!member||member.hp<=0||member.available===false||record?.profession!=='safecracker'||order?.kind!=='unlock_safe'||order.targetId!==safe.id||order.id!==context.actionId||!['working','awaiting'].includes(order.phase))return {ok:false,reason:'mercenary_not_authorized'};
 return {ok:true};
}

export function createMercenarySafeBinding({getHost,getRegistry,location=globalThis.location,storage}){
 let source=null,registry=null,signature='',last=-Infinity,disposed=false,configuring=false,candidate=null,candidateRegistry=null;
 const awaiting=host=>(host?.getPendingTransactions?.()||[]).length>0||(host?.getRoster?.().members||[]).some(m=>host.getAction?.(m.id)?.phase==='awaiting');
 function syncLedger(value){const ledger=value?.getLocalLedger?.();if(ledger?.ok===true)getHost()?.syncSafeLootBalance?.(ledger.balance);}
 function release(value,owner){if(!value)return;if(owner?.getSource?.()===value)owner.setSource(null);value.dispose();}
 async function update(now=Date.now()/1000){
  if(disposed||configuring||now-last<1)return;last=now;
  const host=getHost(),next=getRegistry();if(!next||host?.canUseLocalEffects?.()!==true)return;
  // Respect another game authority already bound by the interior owner.
  const owner=next.getSource?.();if(owner&&owner!==source)return;
  const rows=next.getTargets(),nextSignature=rows.map(r=>r.id).sort().join('\n');
  if(source&&registry===next&&owner===source&&signature===nextSignature)return;
  if(!rows.length||source&&awaiting(host))return;configuring=true;
  try{
   candidate=createInteriorSafeSource({localPreview:true,dropLoot:true,allowLocal:()=>getHost()?.canUseLocalEffects?.()===true,userId:'local-player',registry:rows,storage,location,authorize:request=>authorizeMercenarySafe(getHost(),request)});candidateRegistry=next;
   // Validate hydration itself: registry owners may report binding success even
   // when their internal hydrate callback returned an unsuccessful receipt.
   for(let i=0;i<rows.length;i+=128){const hydration=await candidate.hydrate({safeIds:rows.slice(i,i+128).map(r=>r.id)});if(disposed)return;if(hydration?.ok!==true)throw Error(hydration?.reason||'hydrate_failed');}
   if(source&&awaiting(getHost()))return;
   if(next.getSource?.()&&next.getSource()!==source)return;
   const installing=candidate,receipt=await next.setSource(installing);
   if(disposed)return;if(receipt?.ok!==true||next.getSource?.()!==installing)throw Error(receipt?.reason||'source_changed');
   const oldSource=source,oldRegistry=registry;source=installing;registry=next;signature=nextSignature;candidate=null;candidateRegistry=null;release(oldSource,oldRegistry);
   source.subscribe(()=>{if(!disposed&&source===installing)syncLedger(installing);});syncLedger(source);
   for(const pending of host.getPendingTransactions?.()||[]){
    if(pending.kind!=='unlock_safe')continue;
    const state=source.getState(pending.targetId);if(!state)continue;
    host.resolvePending?.(pending.requestId,{ok:state.opened===true,reason:'restored_source_state'});
   }
  }catch(error){release(source,registry);source=null;registry=null;signature='';console.warn('Mercenary safe source unavailable',error);}finally{release(candidate,candidateRegistry);candidate=null;candidateRegistry=null;configuring=false;}
 }
 return {update,dispose(){disposed=true;release(candidate,candidateRegistry);release(source,registry);candidate=null;candidateRegistry=null;source=null;registry=null;signature='';}};
}
