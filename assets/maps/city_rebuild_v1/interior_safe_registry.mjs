// A bounded registry of actual constructed objects. Source authority is supplied
// by the game host; a mesh or a client-side profession cannot grant an award.
const records=new Map(),pendingHydration=new Set();let source=null,generation=0,revision=0,hydrationQueued=false,unsubscribe=null;
export const interiorSafeTargets={
 getTargets(){return [...records.values()].map(r=>r.target)},
 getLootTargets(){return [...records.values()].filter(r=>{const s=r.safe.getState();return s.lootDropped&&s.opened&&!s.collected&&!s.disposed}).map(r=>({id:r.target.id,object:r.safe.lootBag,state:r.safe.getState,collect:context=>r.safe.collect(context)}))},
 get revision(){return revision},
 async setSource(next){unsubscribe?.();unsubscribe=null;source=next??null;const version=++generation;if(!source?.hydrate)return {ok:false,reason:'source_unavailable'};const ids=[...records.keys()];for(let i=0;i<ids.length;i+=128){const result=await source.hydrate({safeIds:ids.slice(i,i+128)});if(version!==generation)return {ok:false,reason:'source_changed'};if(result?.ok===false)return result;applyHydration(result)}unsubscribe=source.subscribe?.(snapshot=>records.get(snapshot.id??snapshot.safeId)?.safe.applySourceState(snapshot));return{ok:true,count:records.size}},
 getSource(){return source},
};
function applyHydration(result){const snapshots=result?.safes??result?.states??result;if(Array.isArray(snapshots))for(const snapshot of snapshots)records.get(snapshot.id??snapshot.safeId)?.safe.applySourceState(snapshot,{animate:false});else if(snapshots&&typeof snapshots==='object')for(const[id,state]of Object.entries(snapshots))records.get(id)?.safe.applySourceState(state,{animate:false})}
export function registerInteriorSafe(safe,{purpose,position}={}){
 const state=safe.getState(),metadata=safe.object.userData.mercenaryTarget;
 const target={...metadata,object:safe.object,purpose,position,unlock:context=>safe.unlock(context),collect:context=>safe.collect(context)};
 Object.defineProperty(target,'locked',{enumerable:true,get:()=>safe.getState().locked});
 metadata.unlock=target.unlock;metadata.collect=target.collect;
 const record={safe,target};records.set(state.id,record);revision++;
 if(source?.hydrate){pendingHydration.add(state.id);if(!hydrationQueued){hydrationQueued=true;queueMicrotask(async()=>{hydrationQueued=false;const ids=[...pendingHydration];pendingHydration.clear();const version=generation;for(let i=0;i<ids.length;i+=128){try{const result=await source?.hydrate({safeIds:ids.slice(i,i+128)});if(version!==generation)return;applyHydration(result)}catch{}}})}}
 if(typeof window!=='undefined')window.MafioziInteriorSafeTargets=interiorSafeTargets;
 return()=>{if(records.get(state.id)===record){records.delete(state.id);revision++}};
}
export function requestInteriorSafeAction(action,id,details){
 if(!source?.[action])return Promise.resolve({ok:false,reason:'source_unavailable'});
 return source[action]({safeId:id,buildingId:details.buildingId,roomId:details.roomId,requestId:details.requestId,context:details.context});
}
