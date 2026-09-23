const SEAT_ORDER=Object.freeze(['front_left','front_right','rear_left','rear_right']);
const validId=value=>typeof value==='string'&&value.length>0&&value.length<=160;
const frozenTarget=row=>Object.freeze({...row});
const stableHash=value=>{let hash=2166136261;for(const char of String(value))hash=Math.imul(hash^char.charCodeAt(0),16777619)>>>0;return hash.toString(16).padStart(8,'0')};

function heroTarget(state,vehicleId){
 if(!state||state.dead===true||!(Number(state.hp)>0))return null;
 const inSeat=validId(state.occupiedSeat)&&state.vehicleId===vehicleId;
 const exitDoor=state.vehicleId===vehicleId&&state.transition?.exiting===true&&state.transition.phase==='door'&&validId(state.transition.seatId);
 if(!inSeat&&!exitDoor)return null;
 const generation=Number(state.lifeGeneration),lifeGeneration=Number.isInteger(generation)&&generation>=0?generation:0;
 return frozenTarget({kind:'hero',actorId:'player',seatId:inSeat?state.occupiedSeat:state.transition.seatId,lifeGeneration});
}

function crewTargets(rows,vehicleId){
 const seenActors=new Set(),seenSeats=new Set(),inside=[];
 for(const row of Array.isArray(rows)?rows:[]){
  const actorId=String(row?.actorId||''),seatId=String(row?.seatId||''),phase=String(row?.phase||''),exitStage=String(row?.exitStage||'');
  const physical=phase==='drive'||phase==='exit'&&exitStage==='door';
  if(!physical||row?.vehicleId!==vehicleId||row?.dead===true||!(Number(row?.hp)>0)||!validId(actorId)||!SEAT_ORDER.includes(seatId)||seenActors.has(actorId)||seenSeats.has(seatId))continue;
  seenActors.add(actorId);seenSeats.add(seatId);inside.push(frozenTarget({kind:'crew',actorId,seatId,lifeGeneration:Number(row.lifeGeneration)||0}));
 }
 inside.sort((a,b)=>SEAT_ORDER.indexOf(a.seatId)-SEAT_ORDER.indexOf(b.seatId)||a.actorId.localeCompare(b.actorId));
 return inside.slice(0,3);
}

export function createWalkVehicleExplosionLocalAuthority({sessionId,canUseLocalEffects,getHeroState,getCrewState,applyHeroReceipt,applyCrewReceipt,maxEvents=256}={}){
 if(!validId(sessionId)||typeof canUseLocalEffects!=='function'||typeof getHeroState!=='function'||typeof getCrewState!=='function'||typeof applyHeroReceipt!=='function'||typeof applyCrewReceipt!=='function'||!Number.isInteger(maxEvents)||maxEvents<1)throw Error('Invalid local vehicle occupant authority');
 const events=new Map(),records=new WeakMap(),generationByVehicleId=new Map();
 const vehicleIdOf=record=>record?.id==null?'':`fleet:${record.id}`;
 const nextGeneration=vehicleId=>{const generation=(generationByVehicleId.get(vehicleId)||0)+1;generationByVehicleId.set(vehicleId,generation);return generation;};
 const epochFor=(record,vehicleId)=>{let epoch=records.get(record);if(!epoch){epoch={vehicleId,generation:nextGeneration(vehicleId),armed:true,last:null};records.set(record,epoch)}return epoch};
 function noteReset(record){if(!record||typeof record!=='object')return false;const vehicleId=vehicleIdOf(record);if(!validId(vehicleId))return false;const epoch=epochFor(record,vehicleId);epoch.generation=nextGeneration(vehicleId);epoch.armed=true;epoch.last=null;return true;}
 function handle(event={}){
  if(canUseLocalEffects()!==true)return Object.freeze({accepted:false,reason:'authority',delivered:0,targets:0});
  const record=event.record,vehicleId=vehicleIdOf(record),explosion=Number(event.state?.explosions);
  if(!validId(vehicleId)||!Number.isInteger(explosion)||explosion<1||event.vehicle!==record?.car)return Object.freeze({accepted:false,reason:'unconfirmed',delivered:0,targets:0});
  const epoch=epochFor(record,vehicleId),generation=epoch.generation,eventId=`walk-local-vehicle:${stableHash(sessionId+'|'+vehicleId)}:${generation}`;
  if(!epoch.armed)return Object.freeze({accepted:true,duplicate:true,eventId,delivered:0,targets:epoch.last?.occupants.length||0,snapshot:epoch.last});
  const occupants=[],hero=heroTarget(getHeroState(record,event),vehicleId);if(hero)occupants.push(hero);
  occupants.push(...crewTargets(getCrewState(vehicleId,record,event),vehicleId).filter(target=>target.seatId!==hero?.seatId));
  const snapshot=Object.freeze({version:1,eventId,vehicleId,generation,damageExplosion:explosion,occupants:Object.freeze(occupants)});
  // Consume before owner callbacks. A death callback may synchronously update
  // seats, damage state, or the renderer; none may recapture this explosion.
  epoch.armed=false;epoch.last=snapshot;events.set(eventId,snapshot);while(events.size>maxEvents)events.delete(events.keys().next().value);
  let delivered=0;const receipts=[];
  // Crew receipts run before the hero owner. _hurtLocal may synchronously start
  // ambulance/death cleanup, but it can no longer invalidate captured seats.
  for(const target of [...occupants].sort((a,b)=>Number(a.kind==='hero')-Number(b.kind==='hero'))){
   const receipt=Object.freeze({id:`${eventId}:${target.kind}:${stableHash(target.actorId)}:${target.lifeGeneration}`,eventId,vehicleId,actorId:target.actorId,seatId:target.seatId,lifeGeneration:target.lifeGeneration,kind:'vehicle_explosion',lethal:true,confirmed:true});
   let result=null;try{result=target.kind==='hero'?applyHeroReceipt(receipt):applyCrewReceipt(receipt);}catch(error){result={accepted:false,reason:'owner-error',error:String(error?.message||error)};}
   if(result?.accepted===true||result?.duplicate===true)delivered++;
   receipts.push(Object.freeze({target,receipt,result}));
  }
  return Object.freeze({accepted:true,duplicate:false,eventId,delivered,targets:occupants.length,snapshot,receipts:Object.freeze(receipts)});
 }
 return Object.freeze({handle,noteReset,inspect:eventId=>events.get(eventId)||null,stats:()=>Object.freeze({events:events.size})});
}

export const walkVehicleExplosionEligibility=Object.freeze({heroTarget,crewTargets});
