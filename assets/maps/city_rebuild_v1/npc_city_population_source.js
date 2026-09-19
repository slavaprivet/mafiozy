// NPC_CITY_POPULATION_START
// Persistent city-wide residents; renderer visibility never owns their lives.
const NPC_NATIVE_CITY_TARGET=288;
const NPC_CITY_SECTOR_ROWS=6,NPC_CITY_SECTOR_COLS=5;
let _npcCityPopulationCursor=0;
function _npcCitySector(r,c){
 const row=Math.max(0,Math.min(5,Math.floor((r-2)/(MAP_ROWS-4)*6)));
 const col=Math.max(0,Math.min(4,Math.floor((c-2)/(MAP_COLS-4)*5)));
 return row*5+col;
}
function _npcCityPopulationCensus(){
 const counts=new Uint16Array(30);
 for(const n of NPCS)if(n&&!n.dead&&!n._beach&&!n._uniqueNpc&&!n._said&&!n._empireCrew&&!n._medicalCrewVehicleId)counts[_npcCitySector(n.r,n.c)]++;
 return counts;
}
function _npcCityLeastPopulatedSector(counts){
 const start=_npcCityPopulationCursor++%30;let best=start;
 for(let offset=1;offset<30;offset++){const sector=(start+offset)%30;if(counts[sector]<counts[best])best=sector;}
 return best;
}
function _npcNativePopulationFill(need,now){
 const counts=_npcCityPopulationCensus(),deadline=performance.now()+2;
 let added=0,attempts=0;
 // No scene-wide creation burst or repeated 80-try scans in a single frame.
 while(added<Math.min(3,need)&&attempts++<6&&performance.now()<deadline){
  const sector=_npcCityLeastPopulatedSector(counts);
  const n=spawnNpc(sector,{cityOnly:true,sector,maxTries:12,minPlayerDistance:NPC_RESPAWN_MIN_DIST});
  if(!n){counts[sector]+=12;continue;}
  n._homeSector=_npcCitySector(n.r,n.c);
  // A new unseen resident is validated at this exact position; do not move it
  // to a legacy 2D doorway elsewhere in the native city.
  n.idleUntil=now;n.tr=n.r;n.tc=n.c;NPCS.push(n);counts[n._homeSector]++;added++;
 }
 return added;
}
function _npcCityPopulationReport(target,alive){
 if(typeof _UP==='undefined'||!(_UP.has('npcqa')||_UP.has('npccombatqa')||_UP.has('perfqa')))return;
 let moving=0,visiting=0,driving=0,social=0,pending=0;
 for(const n of NPCS){if(n.dead)continue;if(n.walking)moving++;if(n._residentNativeVisit)visiting++;if(n._civilianTripRiding||n._ambientTrafficPhase==='drive')driving++;if(n._civilianActivity)social++;if(n._routeSearchPending||n._npcWanderSearch)pending++;}
 document.documentElement.dataset.npcCityPopulation=JSON.stringify({target,alive,moving,visiting,driving,social,pending,sectors:Array.from(_npcCityPopulationCensus()),cadence:{..._npcSimulationStats}});
}
function _npcRoutineStep(n,dt,passFn){
 const dr=n.tr-n.r,dc=n.tc-n.c,d=Math.hypot(dr,dc);
 if(!(d>0))return false;
 const step=Math.min(d,Math.max(0,dt)*_npcEffectiveSpeed(n));
 const nr=n.r+dr/d*step,nc=n.c+dc/d*step;
 if(!_npcPathPassable(n.r,n.c,nr,nc,passFn))return false;
 n.r=nr;n.c=nc;n.ang=Math.atan2(dr,dc);n.walkPhase+=(step/Math.max(.001,_npcEffectiveSpeed(n)))*8;n.walking=step>0;n._routeBlockedAt=0;
 return true;
}
// NPC_CITY_POPULATION_END
