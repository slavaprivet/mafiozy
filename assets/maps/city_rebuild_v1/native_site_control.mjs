// Isolated native-site contract. No renderer loop, persistence, ownership
// writes or network authority. Only a trusted world/server adapter may supply
// facts and atomically revalidate/commit the returned intent.
const validId=value=>typeof value==='string'&&value.trim().length>0;
const revision=value=>Number.isSafeInteger(value)&&value>=0;
const denied=reason=>({ok:false,reason});
// Capture presence is a supported feet point, not merely an XZ projection.
// 15 cm accommodates small locomotion/floor-sampling error, not jumping or roofs.
export const NATIVE_SITE_FLOOR_TOLERANCE_M=.15;
export const nativeSiteId=instanceId=>validId(instanceId)?'native-site:'+instanceId:null;

export function createNativeSiteCatalog({entries=[],policies=[],manifestRevision}={}){
 if(!validId(manifestRevision))throw new Error('Explicit manifest revision required');
 const policyById=new Map(),records=new Map(),duplicates=new Set();
 for(const policy of policies){
  if(!validId(policy?.instanceId)||policyById.has(policy.instanceId))throw new Error('Invalid or duplicate site policy');
  policyById.set(policy.instanceId,{capturable:policy.capturable===true,headquartersEligible:policy.headquartersEligible===true});
 }
 for(const entry of entries){
  const instance=entry?.instance,id=nativeSiteId(instance?.id);if(!id)continue;
  if(records.has(id)||duplicates.has(id)){records.delete(id);duplicates.add(id);continue;}
  const policy=policyById.get(instance.id),hasInterior=['containsInterior','approachPoint','floorHeight','ceilingHeight'].every(key=>typeof entry[key]==='function');
  records.set(id,{entry,descriptor:Object.freeze({id,instanceId:instance.id,assetId:instance.assetId||'',gameplayId:instance.gameplayId??null,
   capturable:!!policy?.capturable&&hasInterior,headquartersEligible:!!policy?.capturable&&!!policy?.headquartersEligible&&hasInterior})});
 }
 return Object.freeze({
  manifestRevision,
  get(id){return records.get(id)?.descriptor||null;},
  list(){return [...records.values()].map(record=>record.descriptor);},
  status(id){return duplicates.has(id)?'ambiguous':records.has(id)?'loaded':'missing';},
  contains(id,point){
   const record=records.get(id);if(!record||![point?.x,point?.y,point?.z].every(Number.isFinite))return false;
   const entry=record.entry;
   if(!['containsInterior','floorHeight','ceilingHeight'].every(key=>typeof entry[key]==='function'))return false;
   try{
    if(entry.containsInterior(point)!==true)return false;
    // referenceY selects the actual storey/stair surface rather than ground.
    const floor=entry.floorHeight(point.x,point.z,point.y),ceiling=entry.ceilingHeight(point);
    return Number.isFinite(floor)&&Number.isFinite(ceiling)&&ceiling>floor&&point.y<ceiling&&
     Math.abs(point.y-floor)<=NATIVE_SITE_FLOOR_TOLERANCE_M+1e-6;
   }catch(_){return false;}
  },
  approach(id){
   const record=records.get(id);if(!record||typeof record.entry.approachPoint!=='function')return null;
   const point=record.entry.approachPoint();return [point?.x,point?.y,point?.z].every(Number.isFinite)?{x:point.x,y:point.y,z:point.z}:null;
  }
 });
}

function context(catalog,state,request){
 if(!validId(request?.siteId)||!validId(request?.factionId)||!validId(request?.operationId))return denied('invalid-request');
 const site=catalog.get(request.siteId);if(!site)return denied('site-'+catalog.status(request.siteId));
 if(!site.capturable)return denied('site-not-capturable');
 if(state?.manifestRevision!==catalog.manifestRevision)return denied('manifest-changed');
 if(state?.siteId!==site.id||!revision(state?.revision)||!revision(state?.defenceRevision)||
    !(state.ownerFactionId===null||validId(state.ownerFactionId)))return denied('authority-unavailable');
 if(state.claimantFactionId!==request.factionId)return denied('claimant-mismatch');
 return {ok:true,site};
}

function occupation(state,factionId){
 // The trusted host computes these complete sets for claimantFactionId, never
 // from visibility alone. defendersComplete refers only to HOSTILE defenders.
 // It also classifies every occupant as attacker/nonblocking/hostile using its
 // current authoritative relations. This module does not infer diplomacy from
 // faction inequality or treat a null faction as automatically harmless.
 if(state.defendersComplete!==true||!Array.isArray(state.remainingHostileDefenderIds))return denied('defenders-unknown');
 const defenderIds=new Set();
 for(const id of state.remainingHostileDefenderIds){
  if(!validId(id)||defenderIds.has(id))return denied('defenders-unknown');
  defenderIds.add(id);
 }
 if(defenderIds.size)return denied('defenders-remain');
 if(state.occupantsComplete!==true||!Array.isArray(state.occupants))return denied('occupants-unknown');
 const occupants=state.occupants,occupantIds=new Set();
 // for...of visits sparse slots as undefined; some/every would silently skip
 // them. Duplicate actor identities invalidate even individually valid rows.
 for(const actor of occupants){
  if(!validId(actor?.id)||occupantIds.has(actor.id)||typeof actor?.alive!=='boolean'||typeof actor?.combatReady!=='boolean'||
     !(actor.factionId===null||validId(actor.factionId))||!validId(actor.insideSiteId)||
     !['attacker','nonblocking','hostile'].includes(actor.disposition)||
     (actor.disposition==='attacker'&&actor.factionId!==factionId))return denied('occupants-unknown');
  occupantIds.add(actor.id);
 }
 const present=occupants.filter(actor=>actor.alive&&actor.combatReady&&actor.insideSiteId===state.siteId);
 if(present.some(actor=>actor.disposition==='hostile'))return denied('site-contested');
 const own=present.filter(actor=>actor.disposition==='attacker');
 if(!own.length)return denied('physical-entry-required');
 return {ok:true,actorIds:[...new Set(own.map(actor=>actor.id))].sort()};
}

function intent(type,state,request,extra={}){
 return {ok:true,intent:Object.freeze({type,operationId:request.operationId,siteId:request.siteId,factionId:request.factionId,
  expectedManifestRevision:state.manifestRevision,expectedRevision:state.revision,expectedDefenceRevision:state.defenceRevision,expectedOwnerFactionId:state.ownerFactionId,...extra})};
}

export function planNativeSiteCapture(catalog,state,request){
 const checked=context(catalog,state,request);if(!checked.ok)return checked;
 if(state.ownerFactionId===request.factionId)return denied('already-owned');
 const presence=occupation(state,request.factionId);if(!presence.ok)return presence;
 return intent('capture-native-site',state,request,{enteredActorIds:Object.freeze(presence.actorIds)});
}

export function planNativeHeadquarters(catalog,state,headquarters,request){
 const checked=context(catalog,state,request);if(!checked.ok)return checked;
 if(!checked.site.headquartersEligible)return denied('site-not-headquarters-eligible');
 if(state.ownerFactionId!==request.factionId)return denied('capture-required');
 if(headquarters?.factionId!==request.factionId||!revision(headquarters?.revision)||
    !(headquarters.siteId===null||validId(headquarters.siteId)))return denied('headquarters-authority-unavailable');
 if(headquarters.siteId===request.siteId)return denied('already-headquarters');
 const presence=occupation(state,request.factionId);if(!presence.ok)return presence;
 return intent('assign-native-headquarters',state,request,{enteredActorIds:Object.freeze(presence.actorIds),
  expectedHeadquartersRevision:headquarters.revision,expectedHeadquartersSiteId:headquarters.siteId});
}
