// NATIVE_PARKING_RESIDENT_START
function _nativeParkingResidents(now=performance.now()){
 if(typeof _walkRendererActive!=='function'||!_walkRendererActive())return false;
 // Existing decorative people become the same persistent source residents.
 // Native traffic subsequently uses their normal route/boarding/visit lifecycle.
 for(let work=0;work<2&&_parkingNpcs.length;work++){
  const person=_parkingNpcs[0];
  if(!person||!Number.isFinite(person.r)||!Number.isFinite(person.c))break;
  const previousView=typeof _threeParkingNpcView==='function'?_threeParkingNpcView(person,now):null;
  person.id=person.id??previousView?.id??`parking_resident_${++_residentSerial}`;
  person._arcKey=person._arcKey||'worker';person._arc=person._arc||NPC_ARCHETYPES[person._arcKey]||{};
  person.tr=person.r;person.tc=person.c;person.walking=false;
  person.speed=Number.isFinite(person.speed)?person.speed:1.2;
  person.hp=person.dead?0:Number.isFinite(person.hp)?person.hp:60;
  person.max_hp=Number.isFinite(person.max_hp)?person.max_hp:Math.max(60,person.hp);
  person.weapon=null;person._fightWeapon=null;person._beach=false;
  person._parkingResidentCarId=person.car?_threeVehicleEntityId(person.car):null;
  person._civilianPlan=person._civilianPlan||{phase:'seek_shop',cycle:0,retryAt:now};
  person.idleUntil=now;person._nativeParkingResident=true;
  if(person._fear==null)_initNpcEmotions(person);
  if(!NPCS.includes(person))NPCS.push(person);
  _parkingNpcs.shift();
 }
 // New decorative parking loops are replaced by the persistent NPC scheduler.
 return true;
}
// NATIVE_PARKING_RESIDENT_END
