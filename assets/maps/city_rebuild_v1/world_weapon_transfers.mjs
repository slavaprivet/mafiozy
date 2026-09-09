// Authenticated transport is injected by world; this module never invents a player.
const ART={pistol:'tt_pistol',tt:'tt_pistol',pistol_heavy:'deagle',pistol_gold:'golden_colt',shotgun:'sawn_off',smg:'uzi',rifle:'ak74'};
const IDS=new Set(['nagan','revolver','tt_pistol','deagle','golden_colt','sawn_off','uzi','golden_uzi','tommy_gun','golden_tommy','ak74','m16','sniper','rpg']);
export function weaponArtId(id){const value=ART[id]||id;return IDS.has(value)?value:null;}
export function normalizeNetworkDrops(result,now=performance.now()){
 if(!result?.ok||!Number.isFinite(result.server_now)||!Array.isArray(result.drops))return [];
 return result.drops.slice(0,256).flatMap(d=>{
  if(!d||typeof d!=='object'||typeof d.item_id!=='string')return [];
  const weaponId=weaponArtId(d.item_id);
  if(!weaponId||typeof d.drop_id!=='string'||!d.drop_id||d.space!=='world'||d.layer!=='ground'||d.elevation!==0||![d.r,d.c,d.magazine,d.expires_at].every(Number.isFinite)||!Number.isInteger(d.magazine)||d.magazine<0||d.expires_at<=result.server_now)return [];
  return [{uid:d.drop_id,weaponId,itemId:d.item_id,position:{x:d.c*4.1,y:0,z:d.r*4.1},yaw:0,
   fireState:{magazine:Math.max(0,d.magazine),reserveAmmo:0},expiresAt:now+(d.expires_at-result.server_now)*1000}];
 });
}
export function createWorldWeaponTransfers({request,applyState=()=>{},now=()=>performance.now(),makeId=()=>crypto.randomUUID()}={}){
 let drops=[],pending=false,disposed=false,poll=null,generation=0,lastError=null,uncertain=null;
 async function refresh(){
  if(disposed||pending)return drops;
  // Lost replies are reconciled by receipt, not a new grant/drop. In particular
  // a picked-up item may already have disappeared from the next ground list.
  if(uncertain){await transfer(uncertain.action,uncertain.target,false);return drops;}
  if(poll?.version===generation)return poll.promise;
  const job={version:generation,startedAt:now()};poll=job;
  job.promise=(async()=>{try{const data=await request('weapon-ground');if(!disposed&&job.version===generation){
    // Anchor the server timestamp conservatively at request start: delayed
    // replies must never add their network latency to the five-minute lifetime.
    drops=normalizeNetworkDrops(data,job.startedAt);lastError=data?.ok?null:data?.error||'unavailable';}}
   catch{if(!disposed&&job.version===generation){drops=[];lastError='network';}}
   finally{if(poll===job)poll=null;}return drops;})();return job.promise;
 }
 async function transfer(action,target,refreshAfter=true){
  if(disposed||pending)return {ok:false,error:'busy'};
  if(uncertain&&(uncertain.action!==action||uncertain.target!==target))return {ok:false,error:'pending_confirmation'};
  pending=true;generation++;
  let result,operation;
  try{
   operation=uncertain||{action,target,body:{request_id:makeId(),...(action==='drop'?{item_id:target}:{drop_id:target})}};
   // An uncertain reply retries the SAME receipt ID, never a second transfer.
   for(let attempt=0;attempt<2;attempt++){try{result=await request('weapon-'+action,operation.body);break;}catch(error){if(attempt)throw error;}}
   if(!disposed&&result?.ok){await applyState(result);if(action==='pickup')drops=drops.filter(d=>d.uid!==target);}
   uncertain=null;
   lastError=result?.ok?null:result?.error||'unavailable';
  }catch{if(operation&&!disposed)uncertain=operation;result={ok:false,error:operation?'network':'request_id_unavailable'};lastError=result.error;}
  finally{pending=false;}
  if(!disposed&&refreshAfter&&!uncertain)await refresh();
  return result;
 }
 return {refresh,drop:id=>transfer('drop',id),pickup:id=>transfer('pickup',id),
  getDrops:()=>drops.filter(d=>d.expiresAt>now()),get pending(){return pending||!!uncertain;},get uncertain(){return !!uncertain;},get error(){return lastError;},
  dispose(){disposed=true;drops=[];uncertain=null;generation++;}};
}
