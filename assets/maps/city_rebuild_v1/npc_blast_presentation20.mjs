import {normalizeNpcLifecycle} from './npc_source_lifecycle.mjs';
import {normalizeNpcDeathProfile} from './npc_death_profile20.mjs';

// Renderer owner for one body -> complete fragments transition. The source
// supplies an accepted fatal blast and its centre; this controller never hurts
// NPCs or infers death from nearby explosion effects.
export function createNpcBlastPresentation20({parts,getActor,groundHeight,worldScale=4.1,originR=0,originC=0,maxDeaths=256}={}){
 if(!parts?.admit||!parts?.update||!parts?.cull||typeof getActor!=='function'||typeof groundHeight!=='function'||!Number.isFinite(worldScale)||worldScale<=0||!Number.isInteger(maxDeaths)||maxDeaths<1)throw Error('Invalid blast presentation host');
 const deaths=new Map(),current=new Map();let disposed=false,lastNow=-Infinity;
 const keyOf=(id,key)=>JSON.stringify([id,key]);
 function retire(now){for(const [key,entry]of deaths)if(now-entry.receipt.eventAt>=8)deaths.delete(key);}
 function sync(rows,{now,sourceNowMs=now*1000}={}){
  if(disposed||!Number.isFinite(now)||now<lastNow)return;lastNow=now;retire(now);current.clear();
  for(const row of rows||[]){
   if(!row||typeof row.id!=='string'||current.has(row.id))continue;
   const lifecycle=normalizeNpcLifecycle(row,{time:now,sourceNowMs});current.set(row.id,{row,lifecycle});
   if(!lifecycle.dead||lifecycle.key==='dead'||!Number.isFinite(lifecycle.age)||lifecycle.age>=8)continue;
   const key=keyOf(row.id,lifecycle.key);if(deaths.has(key)||deaths.size>=maxDeaths)continue;
   const profile=normalizeNpcDeathProfile({targetId:row.id,lifecycle,record:row.deathRecord});
   const blast=row.deathRecord?.blastPresentation;
   if(!profile.known||profile.cause!=='blast'||blast?.version!==1||!Number.isFinite(blast.originSource?.r)||!Number.isFinite(blast.originSource?.c)||!Number.isFinite(blast.visualSpeed)||blast.visualSpeed<0||blast.visualSpeed>8)continue;
   const x=(blast.originSource.c-originC)*worldScale,z=(blast.originSource.r-originR)*worldScale,y=groundHeight(x,z,getActor(row.id)?.object.position?.y??0);
   if(!Number.isFinite(y)||!Number.isFinite(lifecycle.age))continue;
   deaths.set(key,{key,id:row.id,deathKey:lifecycle.key,status:'waiting',ticket:null,suppressed:false,receipt:{actorId:row.id,eventId:profile.eventId,deathKey:lifecycle.key,cause:'blast',confirmed:true,deathConfirmed:true,origin:{x,y,z},impulse:blast.visualSpeed,eventAt:now-lifecycle.age}});
  }
  for(const entry of deaths.values()){
   const snapshot=current.get(entry.id),same=snapshot?.lifecycle.dead&&snapshot.lifecycle.key===entry.deathKey;
   if(!same&&entry.status!=='culled'){parts.cull(entry.id,entry.deathKey);entry.status='culled';}
  }
 }
 function update(now){
  if(disposed||!Number.isFinite(now)||now<lastNow)return;lastNow=now;retire(now);
  for(const [id,snapshot]of current){const actor=getActor(id);if(snapshot.lifecycle.dead&&actor?.isDeathVisualReplaced?.(snapshot.lifecycle.key))actor.object.visible=false;}
  let admitted=false;
  for(const entry of deaths.values()){
   const snapshot=current.get(entry.id),actor=getActor(entry.id),same=snapshot?.lifecycle.dead&&snapshot.lifecycle.key===entry.deathKey;
   if(!same)continue;
   // Persistent suppression survives the fragments' TTL and actor recreation,
   // but is bound to the exact source death; a respawn is never hidden.
   if(entry.suppressed){if(actor)actor.object.visible=false;continue;}
   if(entry.status!=='waiting')continue;
   if(now-entry.receipt.eventAt>=8){entry.status='expired';continue;}
   if(admitted||!actor?.object.visible||actor.diagnostics?.().disposed)continue;
   const result=parts.admit({actor,receipt:entry.receipt,now});admitted=true;
   entry.status=result.ok?'pending':result.reason==='capacity'||result.reason==='receipt-capacity'?'waiting':'rejected';entry.ticket=result.ticket||null;
  }
  const ready=parts.update(now);
  for(const ticket of ready){
   let entry=null;for(const item of deaths.values())if(item.ticket===ticket){entry=item;break;}if(!entry)continue;
   const snapshot=current.get(entry.id),actor=getActor(entry.id);
   if(!actor?.object.visible||!snapshot?.lifecycle.dead||snapshot.lifecycle.key!==entry.deathKey||actor.markDeathVisualReplaced?.(entry.deathKey)!==true){parts.cull(entry.id,entry.deathKey);entry.status='culled';continue;}
   actor.object.visible=false;entry.suppressed=true;entry.status='presented';
  }
 }
 return {sync,update,diagnostics:()=>({deaths:deaths.size,suppressed:[...deaths.values()].filter(x=>x.suppressed).length,waiting:[...deaths.values()].filter(x=>x.status==='waiting').length,pending:[...deaths.values()].filter(x=>x.ticket?.status==='pending').length}),dispose(){if(disposed)return;disposed=true;parts.dispose?.();deaths.clear();current.clear();}};
}
