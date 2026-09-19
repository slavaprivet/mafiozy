// A civilian leaving a parked car may stand on the carriageway. Ordinary
// sidewalk wander rules cannot validate their first step there. Use the same
// bounded native planner for one physical road-to-land connection.
const _npcRoadExitOffsets=(()=>{const a=[];for(let r=-16;r<=16;r++)for(let c=-16;c<=16;c++){const d=r*r+c*c;if(d&&d<=256)a.push({r:r*.25,c:c*.25,d});}return a.sort((a,b)=>a.d-b.d||a.r-b.r||a.c-b.c);})();
const _npcRoadExitCorners=[[-.18,-.18],[-.18,.18],[.18,-.18],[.18,.18]];
function _npcRoadExitPass(r,c){return _npcBodyPassable(r,c,npcPassableForSnitch);}
function _npcPlanRoadExit(n,now=performance.now()){
 if(typeof _walkNpcNavigationResolver!=='function'||!_isRespawnableResident(n)||n._npcInitialPlacementPending||n._uniqueNpc||n._empireBoss||n._empireCrew||n._gang||n._arcKey==='bandit'||n.police||n._civilianTrip||n._civilianTripRiding||n._ambientTrafficDriver||n._residentNativeVisit||n._civilianActivity||n._civilianSeat||n._beach||_civilianPlanInterrupted(n,now))return null;
 // A real building journey already has permission to cross a road. Do not
 // divert it, discard its goal or cancel its retained search at a car exit.
 if(n._routeKind==='building_entry'&&n._route?.length||n._routeSearchPending&&n._routeSearchKind==='building_entry'&&n._civilianPlan?.doorId)return null;
 const resolver=_walkNpcNavigationResolver,onRoad=resolver({r:n.r,c:n.c})?.surface==='road'||_npcRoadExitCorners.some(([dr,dc])=>resolver({r:n.r+dr,c:n.c+dc})?.surface==='road');
 if(!onRoad&&!n._npcRoadExit)return null;
 const land=(r,c)=>resolver({r,c})?.surface==='land'&&npcWaypointOk(n,r,c);
 if(_npcBodyPassable(n.r,n.c,land)){
  if(n._npcRoadExit){delete n._npcRoadExit;n._roadExitStatus='complete';if(n._routeSearchKind==='civilian_road_exit')_cancelNpcDirectedSearch(n);if(n._routeKind==='civilian_road_exit')_clearNpcRoute(n);}
  return null;
 }
 if(n._routeKind==='civilian_road_exit'&&n._route?.length)return true;
 let state=n._npcRoadExit;
 if(!state||state.r!==n.r||state.c!==n.c||state.resolver!==resolver){
  _cancelNpcDirectedSearch(n);_clearNpcRoute(n);
  state=n._npcRoadExit={r:n.r,c:n.c,resolver,index:0,goal:null,attempts:0,retryAt:0};
 }
 if(now<state.retryAt){n.idleUntil=state.retryAt;return false;}
 if(state.retryAt){state.index=0;state.attempts=0;state.retryAt=0;}
 n.tr=n.r;n.tc=n.c;n.idleUntil=0;n.walking=false;n._routeSearchKind='civilian_road_exit';
 const pending=()=>{n._routeSearchPending=true;n._roadExitStatus='route-pending';return false;};
 const failed=()=>{_cancelNpcDirectedSearch(n);_clearNpcRoute(n);state.goal=null;state.retryAt=now+1000;n.idleUntil=state.retryAt;n._roadExitStatus='no-clear-land';return false;};
 if(!state.goal){
  n._routeRequestAt??=now;pending();
  if(!_npcReserveRouteWork(performance.now(),n))return false;
  try{
   while(state.index<_npcRoadExitOffsets.length&&!_npcRouteWorkExpired()){
    const offset=_npcRoadExitOffsets[state.index++],r=state.r+offset.r,c=state.c+offset.c;
    if(_npcBodyPassable(r,c,land)){state.goal={r,c};break;}
   }
   if(!state.goal&&state.index>=_npcRoadExitOffsets.length)return failed();
  }finally{_npcFinishRouteWork();}
  // The actor has consumed this frame's admission; retain the exact goal for
  // the next turn instead of obtaining a second planner slice in this frame.
  return pending();
 }
 const goal=state.goal,ready=_planNpcRouteTo(n,goal.r,goal.c,_npcRoadExitPass,.18,384,'civilian_road_exit');
 if(n._routeSearchPending)return pending();
 if(ready&&_npcBodyPassable(goal.r,goal.c,land)){n._roadExitStatus='walking-to-land';return true;}
 // A moving car or changed land/door must be observed before publishing a
 // completed route. A bounded retry can choose another neighbouring landing.
 _clearNpcRoute(n);state.goal=null;state.attempts++;
 if(state.attempts>=4)return failed();
 return pending();
}
