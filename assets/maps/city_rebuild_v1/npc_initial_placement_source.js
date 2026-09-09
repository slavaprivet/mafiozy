// NPC_NATIVE_INITIAL_PLACEMENT_START
let _npcInitialPlacementDone=false;
const _npcInitialPlacementStats={attempted:false,checked:0,moved:0,unresolved:0,skipped:0,searchChecks:0,pending:0,exhausted:0,slices:0};
const _npcInitialPlacementQueue=[];
let _npcInitialPlacementRows=[];
function _npcInitialPlacementEligible(n){return n&&n.id!==undefined&&!n.dead&&n.alive!==false&&!n._residentIndoors&&!n._interiorId&&!n.interior_id&&!n._insideBuilding&&!n._civilianTrip&&!n._civilianTripRiding&&!n._responseVehicleId&&!n.vehicleId&&!n.vehicle_id&&!n._inVehicle&&!n._inCar&&!n._carriedByAmbulance&&!n._evacuated&&!n._civilianSeat&&!n._uniqueNpc&&!n._said&&!n._empireBoss&&!n._empireCrew&&!n._gang&&!n.gang&&!n._guard&&!n._clientOfBiz&&!n._owner;}
function _npcInitialPlacementStep(maxChecks=96,maxMs=2){
 if(!_walkNpcNavigationResolver||!_npcInitialPlacementQueue.length)return;
 const deadline=performance.now()+maxMs;let checks=0;
 _npcInitialPlacementStats.slices++;
 while(_npcInitialPlacementQueue.length&&checks<maxChecks&&performance.now()<deadline){
  const row=_npcInitialPlacementQueue.shift(),{n,kind,xy}=row;
  if(!_npcInitialPlacementEligible(n)){delete n._npcInitialPlacementPending;_npcInitialPlacementStats.skipped++;continue;}
  const pass=kind==='police'?_policeCrewBodyPassable:(r,c)=>_npcBodyPassable(r,c,(rr,cc)=>npcWaypointOk(n,rr,cc));
  let chosen=null;
  if(!row.checked){row.checked=true;_npcInitialPlacementStats.checked++;checks++;if(pass(row.r,row.c)){delete n._npcInitialPlacementPending;continue;}}
  // Round-robin slices keep a difficult lake spawn from starving later residents.
  let local=0;
  while(local++<16&&checks<maxChecks&&performance.now()<deadline&&row.radius<=row.maxRadius){
   const steps=Math.min(64,Math.max(8,Math.ceil(row.radius*10))),angle=row.index*Math.PI*2/steps;
   const r=row.r+Math.sin(angle)*row.radius,c=row.c+Math.cos(angle)*row.radius;
   row.index++;if(row.index>=steps){row.index=0;row.radius+=row.radius<6?.25:row.radius<24?.5:1;}
   checks++;_npcInitialPlacementStats.searchChecks++;
   if(!pass(r,c)||_npcInitialPlacementRows.some(other=>other!==row&&!other.n.dead&&Math.hypot((other.xy?other.n.y:other.n.r)-r,(other.xy?other.n.x:other.n.c)-c)<.55))continue;
   chosen={r,c};break;
  }
  if(chosen){
   if(xy){n.y=chosen.r;n.x=chosen.c;n.ty=chosen.r;n.tx=chosen.c;}else{n.r=chosen.r;n.c=chosen.c;n.tr=chosen.r;n.tc=chosen.c;_clearNpcRoute(n);}
   if(kind==='police'&&typeof _clearPoliceFootRoute==='function')_clearPoliceFootRoute(n);
   row.r=chosen.r;row.c=chosen.c;n.walking=false;n.walkPhase=0;n._waterEscapeTarget=null;n._waterEscapeSearch=null;n._waterEscapeRetryAt=0;
   delete n._npcInitialPlacementPending;_npcInitialPlacementStats.moved++;
  }else if(row.radius<=row.maxRadius)_npcInitialPlacementQueue.push(row);
  else _npcInitialPlacementStats.exhausted++; // No safe ground in bounded world: never present inside a wall/lake.
 }
 _npcInitialPlacementStats.pending=_npcInitialPlacementQueue.length;
 _npcInitialPlacementStats.unresolved=_npcInitialPlacementStats.pending+_npcInitialPlacementStats.exhausted;
}
function _npcInitialSafePlacement(){
 if(_npcInitialPlacementDone||!_walkNpcNavigationResolver)return;
 _npcInitialPlacementDone=true;_npcInitialPlacementStats.attempted=true;
 if(typeof _buildingInt!=='undefined'&&_buildingInt||typeof _bankInt!=='undefined'&&_bankInt||typeof _majorInteriorObjectId!=='undefined'&&_majorInteriorObjectId)return;
 const rows=[],seen=new Set();
 for(const [pool,kind]of [[typeof NPCS!=='undefined'?NPCS:[],'resident'],[typeof cityCops!=='undefined'?cityCops:[],'police'],[typeof worldCops!=='undefined'?worldCops:[],'police']])for(const n of pool||[]){if(!n||typeof n!=='object'||seen.has(n))continue;seen.add(n);const xy=kind==='police'&&Number.isFinite(n.y)&&Number.isFinite(n.x),r=xy?n.y:n.r,c=xy?n.x:n.c;rows.push({n,kind,xy,r,c});}
 _npcInitialPlacementRows=rows;
 for(const row of rows){const {n}=row;if(!_npcInitialPlacementEligible(n)||!Number.isFinite(row.r)||!Number.isFinite(row.c)){_npcInitialPlacementStats.skipped++;continue;}
  n._npcInitialPlacementPending=true;n.walking=false;row.radius=.25;row.index=0;row.maxRadius=Math.hypot(typeof MAP_ROWS==='number'?MAP_ROWS:200,typeof MAP_COLS==='number'?MAP_COLS:200);_npcInitialPlacementQueue.push(row);
 }
 _npcInitialPlacementStep(128,4);
}
// NPC_NATIVE_INITIAL_PLACEMENT_END
