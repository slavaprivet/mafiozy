// Local source parked-car locks only. Server quest/police locks need a server receipt.
(()=>{
 const completed=new Map(),local=()=>typeof _LOCAL_PREVIEW!=='undefined'&&_LOCAL_PREVIEW===true;
 const key=id=>String(id??'').replace(/^traffic:/,'');
 function resolve(id){if(!local()||typeof CARS==='undefined')return null;const wanted=key(id);if(!wanted)return null;return CARS.find(car=>{if(typeof _threeVehicleEntityId==='function')return _threeVehicleEntityId(car)===wanted;const explicit=car.id??car._id;return explicit!=null?`vehicle_${explicit}`===wanted:typeof _threeVehicleIds!=='undefined'&&_threeVehicleIds.get(car)===wanted;})||null;}
 const intact=car=>car&&!car.wrecked&&!car._wrecked&&!car._shotWrecked&&!car._destroySequenceAt&&!car._hidden&&!car._towed&&!(Number.isFinite(car.hp)&&car.hp<=0);
 function get(id){const car=resolve(id);if(!car)return {available:false,locked:false,lockpickable:false,reason:'source_vehicle_unavailable'};const allowed=intact(car)&&car.parked===true;return {available:true,sourceId:key(id),locked:allowed&&car._lockpicked!==true,lockpickable:allowed,reason:allowed?'':'only_parked_civilian_supported'};}
 function unlock(target,effect={}){
  if(!local())return {ok:false,reason:'server_unlock_not_connected'};
  const id=key(target?.sourceId||target?.id),actionKey=String(effect.actionId??'');if(!actionKey)return {ok:false,reason:'action_required'};
  if(completed.has(actionKey))return completed.get(actionKey)===id?{ok:true,duplicate:true}:{ok:false,reason:'action_target_mismatch'};
  const host=window.MafioziMercenaries,action=host?.getAction?.(effect.memberId),member=host?.getMember?.(effect.memberId),row=host?.getRoster?.().members?.find(r=>String(r.id)===String(effect.memberId));
  if(row?.profession!=='safecracker'||action?.kind!=='unlock_door'||String(action.id)!==actionKey||action.targetId!==effect.targetId||!['working','awaiting'].includes(action.phase)||action.progress<1||!member||member.hp<=0||member.dead||member.downed||member.available===false)return {ok:false,reason:'specialist_action_unconfirmed'};
  const car=resolve(id);if(!intact(car)||car.parked!==true)return {ok:false,reason:'vehicle_unavailable'};
  if(!member.position||!Number.isFinite(car.r)||!Number.isFinite(car.c)||Math.hypot(member.position.x-car.c*4.1,member.position.z-car.r*4.1)>4.5)return {ok:false,reason:'specialist_out_of_range'};
  car._lockpicked=true;completed.set(actionKey,id);if(completed.size>4096)completed.delete(completed.keys().next().value);
  return {ok:true,opened:true,sourceId:id};
 }
 window.MafioziMercenaryVehicleLocks={get,unlock};
})();
