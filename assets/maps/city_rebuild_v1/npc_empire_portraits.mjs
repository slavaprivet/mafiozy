import {npcAppearanceFromWorld} from './npc_population.mjs';

// One serial job queue uses the HUD's existing GLB loader and portrait renderer.
export function createNpcEmpirePortraits({THREE,loader,cloneSkeleton,portraits,appearanceLoader,signal,isDisposed=()=>false}){
 const cache=new Map(),pending=new Map();let tail=Promise.resolve();
 function get(row){
  if(!row?.renderId||!row.look||isDisposed())return Promise.resolve(null);
  const appearance=npcAppearanceFromWorld({id:row.renderId,look:row.look,role:row.renderRole||'unique_npc',empireBoss:true,bossColor:row.color,bossAccent:row.accent});
  const key=JSON.stringify(appearance);
  if(cache.has(key))return Promise.resolve(cache.get(key));
  if(pending.has(key))return pending.get(key);
  const job=tail.then(async()=>{
   if(isDisposed()||signal?.aborted)return null;
   const record=await appearanceLoader({THREE,loader,cloneSkeleton,look:row.look,id:row.renderId,appearance,targetHeight:appearance.height,signal});
   try{
    if(isDisposed())return null;
    const url=portraits.renderNpc(record.hero.object,{key:'empire:'+key,rest:record.hero.artistContext().rest});
    if(url){cache.set(key,url);while(cache.size>40)cache.delete(cache.keys().next().value)}
    return url;
   }finally{record.dispose()}
  }).catch(()=>null).finally(()=>pending.delete(key));
  pending.set(key,job);tail=job;return job;
 }
 return {get,dispose(){cache.clear()},get size(){return cache.size}};
}
