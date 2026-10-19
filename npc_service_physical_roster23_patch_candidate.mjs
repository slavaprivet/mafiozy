// Review-only source bridge delta. Never writes or activates the runtime.
// The roster comes from THIS world's existing presentation source assembly,
// before distance/priority/cap filtering; no separate hand-maintained taxonomy.
export function servicePhysicalRosterWorldCandidate(input) {
 const crlf=input.includes('\r\n');let source=input.replace(/\r\n/g,'\n');
 const start='    let npcSource=_buildingInt?',end='    const npcLifePool=x=>{';
 const at=source.indexOf(start),stop=source.indexOf(end,at);
 if(at<0||stop<at||source.indexOf(start,at+1)>=0)throw Error('Physical roster source assembly anchor changed');
 let assembly=source.slice(at,stop);
 // Existing render wrappers without _actionRef still represent real bodies.
 // Keep their original identity only in this independent query's projection.
 for(const name of ['boss','person','guard','beachNpc','RACE_PHOTOGRAPHER'])
  assembly=assembly.replaceAll('combat.push({...'+name+',id:', 'combat.push({...'+name+',_actionRef:'+name+',id:');
 // These two existing projections are authored stand-ins, not mutable actors.
 assembly=assembly.replace('combat.push({...pose,id:', 'combat.push({...pose,_serviceAuthored23:true,id:')
  .replace("combat.push({id:`lair_fallback_", "combat.push({_serviceAuthored23:true,id:`lair_fallback_")
  .replace("combat.push({id:'michael_dealer'", "combat.push({_serviceAuthored23:true,id:'michael_dealer'")
  .replace('const michaelDecor=_michaelDecor();','const michaelDecor=_michaelDecorGuards||[];')
  .replace('beachNpc._evacuated||beachNpc._carriedByAmbulance','beachNpc._evacuated');
 // Rendering's ||0 convenience cannot silently relocate malformed physics.
 assembly=assembly.replace(/([rc]):\+([^,\n]+?)\|\|0/g, '$1:Number($2)');
 const helper=String.raw`
function _getWalkServicePhysicalBodies23(input={}){
 const now=performance.now(),sourceFrame=typeof prevT==='number'?prevT:null;
 const deny=reason=>({complete:false,reason,now,sourceFrame,space:'native-world',rows:[]});
 if(!input||![input.r,input.c,input.radius].every(Number.isFinite)||input.radius<=0||input.radius>16)return deny('invalid-bounds');
 if(typeof NPCS==='undefined'||!Array.isArray(NPCS))return deny('source-unavailable');
 if(_buildingInt||_bankInt)return deny('legacy-interior-space');
 const inside=false,fxNow=now;
 try{
 if(typeof MICHAEL_POS!=='undefined'&&typeof michaelGuards!=='undefined'&&michaelGuards.size===0&&typeof _michaelDecor==='function'&&typeof _michaelDecorGuards!=='undefined'&&!_michaelDecorGuards&&Math.hypot(MICHAEL_POS.r-input.r,MICHAEL_POS.c-input.c)<=input.radius+5)return deny('authored-roster-uninitialized');
`+assembly+String.raw`
 // Foot-visible workers are physical independently of viewer proximity.
 if(typeof _junkyardFootWorkers!=='undefined')for(const worker of _junkyardFootWorkers||[])if(worker?._footVisible)npcSource.push(worker);
 const rows=[],byId=new Map(),byRef=new Map(),radius2=input.radius*input.radius;
 for(const x of npcSource){
  if(!x)continue;
  const ref=x._serviceAuthored23?null:(x._actionRef||x),owner=ref||x;
  if(owner._evacuated||owner._corpseExpired||owner._mercenaryHospital)continue;
  const crew=!!ref&&String(x.id||'').startsWith('crew_');
  const mercenary=crew&&typeof window!=='undefined'?window.MafioziMercenaries?.getMember?.(owner.id):null;
  if(mercenary?.available===false)continue;
  const downed=!!owner._medicalDowned||owner._empireDownUntil>now||owner.downed===true||owner.lifeState==='downed'||mercenary?.downed===true;
  const rawHp=owner.hp,hasHp=(typeof rawHp==='number'||typeof rawHp==='string'&&rawHp.trim()!=='')&&Number.isFinite(Number(rawHp));
  const dead=owner.dead===true||owner.alive===false||!downed&&hasHp&&Number(rawHp)<=0;
  if(dead&&typeof _corpseRemovalDue==='function'&&_corpseRemovalDue(owner,now))continue;
  const r=dead&&Number.isFinite(owner._deathR)?owner._deathR:(x.r??x.y),c=dead&&Number.isFinite(owner._deathC)?owner._deathC:(x.c??x.x);
  if(!Number.isFinite(r)||!Number.isFinite(c))return deny('invalid-source-position');
  if((r-input.r)**2+(c-input.c)**2>radius2)continue;
  if(owner._npcInitialPlacementPending)return deny('local-placement-pending');
  const id=_threeNpcEntityId(x);
  if(typeof id!=='string'||!id)return deny('invalid-source-id');
  const duplicate=ref&&byRef.get(ref);
  if(duplicate){if(duplicate.r!==r||duplicate.c!==c)return deny('conflicting-source-alias');if(!duplicate.aliasIds.includes(id))duplicate.aliasIds.push(id);continue;}
  if(byId.has(id))return deny('conflicting-source-id');
  const hijack=owner._vehicleHijack||owner._vehicleCorpseSeat||null;
  let vehicleId=x.parkingCarId||owner._ambientTrafficCarId||null,vehiclePhase=x.parkingState||owner._ambientTrafficPhase||null;
  if(owner._civilianTrip&&typeof _civilianTripForNpc==='function'){const trip=_civilianTripForNpc(owner);vehicleId=trip?.carId||vehicleId;vehiclePhase=trip?.phase||vehiclePhase;}
  if(hijack){vehicleId=hijack.carId||hijack.vehicleId||vehicleId;vehiclePhase=hijack.phase||'seated';}
  if(owner._transportVehicleId){vehicleId='service_'+owner._transportVehicleId;vehiclePhase=owner._transportBoardPhase||'drive';}
  if(owner.transport_vehicle_id){vehicleId='quest_'+owner.transport_vehicle_id;vehiclePhase='drive';}
  if(owner._medicalCrewVehicleId){vehicleId='service_'+owner._medicalCrewVehicleId;vehiclePhase=owner._medicalBoardPhase||'drive';}
  if(owner._mercenaryVehicleSeat){vehicleId=owner._mercenaryVehicleId||null;vehiclePhase=owner._mercenaryVehiclePhase||'drive';}
  const carried=!!(owner._carriedByAmbulance||owner._ambulanceInTransit);
  const seated=!!(owner._civilianTripRiding||owner._ambientTrafficPhase==='drive'||owner._transportBoarded||owner.transport_vehicle_id||owner._inVehicle||hijack?.phase==='seated'||owner._vehicleCorpseSeat||owner._civilianSeat||owner._mercenaryVehicleSeat);
  const row={id,aliasIds:[id],ref,r,c,ang:Number.isFinite(x.ang)?x.ang:0,dead,downed,
   prone:!!(owner._forcedCrawl||owner.prone||owner._knockedUntil>now||owner._meleeStunnedUntil>now||mercenary?.posture==='prone'),
   crouching:!!(owner.crouching||owner._lifeState==='cower'||owner._panicCowerUntil>now||mercenary?.posture==='crouch'),
   carried,seated,vehicleId,vehiclePhase,generation:owner._stationaryService?.generation??null,
   authored:!ref,footY:null,elevation:null,poseKnown:!carried&&!seated&&!vehiclePhase&&(!crew||!!mercenary),
   lifeState:String(owner._lifeState||owner.lifeState||''),deathAt:Number.isFinite(owner.deadAt)?owner.deadAt:null};
  rows.push(row);byId.set(id,row);if(ref)byRef.set(ref,row);
 }
 return {complete:true,now,sourceFrame,space:'native-world',rows};
 }catch(error){return deny('source-roster-unavailable');}
}
`;
 const anchor='window.Mafiozi3DBridge = Object.freeze({';
 if(source.indexOf(anchor)<0||source.indexOf(anchor)!==source.lastIndexOf(anchor)||source.includes('function _getWalkServicePhysicalBodies23('))throw Error('Physical roster bridge anchor changed');
 source=source.replace(anchor,helper+'\n'+anchor+'\n  getWalkServicePhysicalBodies23(input){return _getWalkServicePhysicalBodies23(input);},');
 return crlf?source.replace(/\n/g,'\r\n'):source;
}
