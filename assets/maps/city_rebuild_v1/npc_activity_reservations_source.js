// Building visit capacity only. Existing bench and vehicle owners remain separate.
// The caller supplies a canonical physical building key; this helper never
// guesses identity from labels, source IDs, aliases or spatial proximity.
const _npcActivityBuildingSlots=new Map(),_npcActivityOwnerSlots=new Map();
const NPC_ACTIVITY_BUILDING_CAPACITY=15;
const _npcActivityReservationStats={reserved:0,entered:0,released:0,refused:0};
function _npcActivityReservationNow(now){return Number.isFinite(now)?now:performance.now();}
function _npcActivityReservationAlive(owner){return !!owner&&typeof owner==='object'&&!owner.dead&&owner.alive!==false&&!(Number.isFinite(owner.hp)&&owner.hp<=0);}
function _npcActivityPruneBuildingSlots(key,now){
 const slots=_npcActivityBuildingSlots.get(key);if(!slots)return;
 for(const [owner,record]of slots)if(!_npcActivityReservationAlive(owner)||record.phase!=='inside'&&now>=record.until)_npcActivityReleaseBuilding(owner,key,'expired');
}
function _npcActivityReleaseBuilding(owner,key=null,reason='released'){
 const record=_npcActivityOwnerSlots.get(owner);if(!record||key!==null&&record.key!==key)return false;
 const slots=_npcActivityBuildingSlots.get(record.key);slots?.delete(owner);if(!slots?.size)_npcActivityBuildingSlots.delete(record.key);
 _npcActivityOwnerSlots.delete(owner);_npcActivityReservationStats.released++;
 return true;
}
function _npcActivityPruneBuildingReservations({now,owners=null,isPresent=null,isPending=null,isInside=null,buildings=null}={}){
 now=_npcActivityReservationNow(now);let released=0;
 // Pass an authoritative Set/predicate covering exterior AND interior actors.
 // An interior actor must not be considered removed merely because it left NPCS.
 for(const [owner,record]of _npcActivityOwnerSlots){
  const present=typeof isPresent==='function'?isPresent(owner,record.key,record.phase):owners?owners.has(owner):true;
  const exists=buildings?buildings.has(record.key):true;
  const validPhase=record.phase==='inside'?(typeof isInside==='function'?isInside(owner,record.key):true):(typeof isPending==='function'?isPending(owner,record.key):true);
  const expired=record.phase!=='inside'&&now>=record.until;
  if(!_npcActivityReservationAlive(owner)||present===false||exists===false||validPhase===false||expired){_npcActivityReleaseBuilding(owner,record.key,'pruned');released++;}
 }
 return released;
}
function _npcActivityBuildingCount(key,options={}){
 if(options.owners||options.isPresent||options.isPending||options.isInside||options.buildings)_npcActivityPruneBuildingReservations(options);
 else _npcActivityPruneBuildingSlots(key,_npcActivityReservationNow(options.now));
 return _npcActivityBuildingSlots.get(key)?.size||0;
}
function _npcActivityReserveBuilding(owner,key,{now,leaseMs=30000}={}){
 now=_npcActivityReservationNow(now);
 if(!_npcActivityReservationAlive(owner)){_npcActivityReleaseBuilding(owner);return false;}
 if(typeof key!=='string'||!key.trim())return false;
 const previous=_npcActivityOwnerSlots.get(owner);
 if(previous?.key===key){if(previous.phase!=='inside')previous.until=now+Math.max(1000,Number.isFinite(leaseMs)?leaseMs:30000);return true;}
 // An inside visitor cannot simultaneously reserve another interior. Its
 // authoritative exit/cancel/death must release the existing visit first.
 if(previous?.phase==='inside')return false;
 _npcActivityPruneBuildingSlots(key,now);
 const slots=_npcActivityBuildingSlots.get(key);
 if((slots?.size||0)>=NPC_ACTIVITY_BUILDING_CAPACITY){_npcActivityReservationStats.refused++;return false;}
 // Transfer only after capacity is confirmed, so a refused alternative cannot
 // silently destroy an already committed destination.
 if(previous)_npcActivityReleaseBuilding(owner,previous.key,'transferred');
 const record={key,phase:'reserved',since:now,until:now+Math.max(1000,Number.isFinite(leaseMs)?leaseMs:30000)};
 const target=slots||new Map();target.set(owner,record);_npcActivityBuildingSlots.set(key,target);_npcActivityOwnerSlots.set(owner,record);_npcActivityReservationStats.reserved++;
 return true;
}
function _npcActivityEnterBuilding(owner,key,{now}={}){
 now=_npcActivityReservationNow(now);
 if(!_npcActivityReserveBuilding(owner,key,{now}))return false;
 const record=_npcActivityOwnerSlots.get(owner);
 if(record.phase!=='inside'){record.phase='inside';record.enteredAt=now;record.until=Infinity;_npcActivityReservationStats.entered++;}
 return true;
}
function _npcActivityBuildingReservation(owner){
 const record=_npcActivityOwnerSlots.get(owner);return record?{key:record.key,phase:record.phase,since:record.since,until:record.until,enteredAt:record.enteredAt??null}:null;
}
function _npcActivityBuildingReservationSummary(){
 let reserved=0,inside=0;for(const record of _npcActivityOwnerSlots.values())if(record.phase==='inside')inside++;else reserved++;
 return {totalReserved:_npcActivityReservationStats.reserved,totalEntered:_npcActivityReservationStats.entered,released:_npcActivityReservationStats.released,refused:_npcActivityReservationStats.refused,capacity:NPC_ACTIVITY_BUILDING_CAPACITY,buildings:_npcActivityBuildingSlots.size,owners:_npcActivityOwnerSlots.size,reserved,inside};
}

// World adapters. They retain source ownership and never move actors or assign
// routes. Native instanceId is authoritative (npc_resident_building_access).
let _npcActivitySlotsNextAt=0;
const _npcActivityDoorRetry=new WeakMap();
function _npcActivityDoorKey(door){
 if(!door||typeof door!=='object')return null;
 const id=door.native?(door.instanceId??door.id):door.id;
 if(id===null||id===undefined||!String(id).trim())return null;
 return door.native?'native:'+String(id).replace(/^native:/,''):'legacy:'+String(id);
}
function _npcActivityDoorAvailable(owner,door,now){
 now=_npcActivityReservationNow(now);const key=_npcActivityDoorKey(door);
 if(!key||!_npcActivityReservationAlive(owner)||(_npcActivityDoorRetry.get(owner)?.get(key)||0)>now)return false;
 const record=_npcActivityOwnerSlots.get(owner);
 if(record?.key===key)return true;
 if(record?.phase==='inside')return false;
 return _npcActivityBuildingCount(key,{now})<NPC_ACTIVITY_BUILDING_CAPACITY;
}
function _npcActivityClaimDoor(owner,door,now){
 now=_npcActivityReservationNow(now);const key=_npcActivityDoorKey(door);
 if(!_npcActivityDoorAvailable(owner,door,now)||!_npcActivityReserveBuilding(owner,key,{now}))return false;
 const record=_npcActivityOwnerSlots.get(owner);record.door=door;
 if(record.progressAt===undefined){record.progressAt=record.movedAt=now;record.lastR=owner.r;record.lastC=owner.c;record.search=null;record.expanded=0;record.route=null;record.routeIndex=0;}
 return true;
}
function _npcActivityEnterDoor(owner,door,now){
 now=_npcActivityReservationNow(now);const key=_npcActivityDoorKey(door);
 if(!key||!_npcActivityEnterBuilding(owner,key,{now}))return false;
 _npcActivityOwnerSlots.get(owner).door=door;return true;
}
function _npcActivityCancelPending(owner,reason='cancelled'){
 const record=_npcActivityOwnerSlots.get(owner);
 return record?.phase==='reserved'?_npcActivityReleaseBuilding(owner,record.key,reason):false;
}
function _npcActivitySlotsTick(now){
 now=_npcActivityReservationNow(now);if(now<_npcActivitySlotsNextAt)return 0;_npcActivitySlotsNextAt=now+250;
 if(!_npcActivityOwnerSlots.size)return 0;
 const exterior=typeof NPCS!=='undefined'&&Array.isArray(NPCS)?NPCS:[],interior=typeof RESIDENTS_INDOORS!=='undefined'&&Array.isArray(RESIDENTS_INDOORS)?RESIDENTS_INDOORS:[];
 const present=new Set(exterior);for(const owner of interior)present.add(owner);
 const doorKeys=new Map();
 if(typeof _residentBuildingDoors==='function')for(const door of _residentBuildingDoors()||[])if(door?.id!==undefined)doorKeys.set(String(door.id),_npcActivityDoorKey(door));
 let released=0;
 for(const [owner,record]of _npcActivityOwnerSlots){
  if(!_npcActivityReservationAlive(owner)||!present.has(owner)){_npcActivityReleaseBuilding(owner,record.key,'removed');released++;continue;}
  const physicalDoor=owner._residentNativeVisit?.door||(owner._residentIndoors?owner._residentDoor:null);
  if(_npcActivityDoorKey(physicalDoor)===record.key){
   if(record.phase!=='inside')_npcActivityEnterBuilding(owner,record.key,{now});
   continue; // Entering, browsing AND exiting still physically occupy the place.
  }
  if(record.phase==='inside'){_npcActivityReleaseBuilding(owner,record.key,'left');released++;continue;}
  const routeActive=owner._routeKind==='building_entry'&&owner._route?.length;
  const selected=owner._civilianPlan?.doorId??owner._residentVisitTargetId??(routeActive?owner._residentDoor?.id:null);
  const matches=selected!==null&&selected!==undefined&&(doorKeys.get(String(selected))===record.key||String(selected)===String(record.door?.id)||record.door?.native&&String(selected)==='native:'+String(record.door.instanceId));
  const pending=owner._routeSearchPending&&owner._routeSearchKind==='building_entry';
  const committed=matches&&(routeActive||pending||['walk_to_shop','entering'].includes(owner._civilianPlan?.phase));
  if(!committed&&now-record.since>1000){_npcActivityReleaseBuilding(owner,record.key,'abandoned');released++;continue;}
  const moved=Number.isFinite(owner.r)&&Number.isFinite(owner.c)&&Number.isFinite(record.lastR)&&Number.isFinite(record.lastC)&&Math.hypot(owner.r-record.lastR,owner.c-record.lastC)>.035;
  if(moved){record.lastR=owner.r;record.lastC=owner.c;record.movedAt=record.progressAt=now;}
  const search=owner._npcDirectedSearch,expanded=search?Math.max(+search.qi||0,+search.expanded||0):0;
  if(search&&record.search===search&&expanded>record.expanded)record.progressAt=now;
  record.search=search;record.expanded=expanded;
  const route=owner._route,index=owner._routeIndex||0;
  if(route&&record.route===route&&index>record.routeIndex)record.progressAt=now;
  record.route=route;record.routeIndex=index;
  // Search progress cannot hold a place forever if repeated replans never
  // produce physical movement. This does not limit a long, moving journey.
  if(now-(record.progressAt??record.since)>=45000||now-(record.movedAt??record.since)>=120000){
   let retry=_npcActivityDoorRetry.get(owner);if(!retry){retry=new Map();_npcActivityDoorRetry.set(owner,retry);}for(const [key,until]of retry)if(until<=now)retry.delete(key);retry.set(record.key,now+15000);
   _npcActivityReleaseBuilding(owner,record.key,'stalled');released++;continue;
  }
  if(committed)record.until=now+30000;
 }
 return released;
}
