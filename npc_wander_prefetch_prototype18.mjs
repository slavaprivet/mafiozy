// Isolated proposal, never imported by production. The injected planner keeps
// current footprint, native sweeps, retained frontier and shared CPU budget.
export function prefetchPlanner18(pick){
 const replace=(a,b)=>{if(!pick.includes(a))throw Error('Prefetch staging marker changed: '+a);pick=pick.replace(a,b);};
 replace('function pickNpcWaypoint(npc) {','function prefetchWanderPrototype18(npc) {');
 replace("if(typeof _npcPlanRoadExit==='function'){", "if(!npc._prefetchOnly&&typeof _npcPlanRoadExit==='function'){");
 replace('  if(!search){\n    if(_civilianPlanNext(npc))return true;', '  if(!search&&!npc._prefetchOnly){\n    if(_civilianPlanNext(npc))return true;');
 replace('_npcReserveRouteWork(now,npc)', '_npcReserveRouteWork(now,null)');
 replace('other===npc||other.dead','other===npc||other===npc._prefetchRealActor||other.dead');
 return pick;
}
export function makePrefetchJob18(n,b,now){
 if(!eligible(n,b,now)||!n._route?.length)return null;
 const endpoint=n._route.at(-1);if(!Number.isFinite(endpoint.r+endpoint.c))return null;
 const actor={...n,r:endpoint.r,c:endpoint.c,tr:endpoint.r,tc:endpoint.c,_route:null,_routeIndex:0,_routeGoalR:null,_routeGoalC:null,_npcWanderSearch:null,_npcDirectedSearch:null,_routeSearchPending:false,_prefetchOnly:true,_prefetchRealActor:n};
 return {real:n,actor,route:n._route,endpoint:{...endpoint},plan:n._civilianPlan,phase:n._civilianPlan?.phase,cycle:n._civilianPlan?.cycle,doorId:n._civilianPlan?.doorId,status:'pending'};
}
function eligible(n,b,now){return n&&!n.dead&&n.hp>0&&n._routeKind==='walk'&&!n._routeSearchPending&&!n._npcWanderSearch&&!n._civilianTrip&&!n._ambientTrafficDriver&&!n._residentNativeVisit&&!n._civilianActivity&&!n._civilianSeat&&!n._npcInitialPlacementPending&&b._civilianPlanEligible(n)&&!b._civilianPlanInterrupted(n,now);}
function matches(job,b,now){const n=job.real;return eligible(n,b,now)&&n._route===job.route&&n._civilianPlan===job.plan&&n._civilianPlan?.phase===job.phase&&n._civilianPlan?.cycle===job.cycle&&n._civilianPlan?.doorId===job.doorId;}
export function stepPrefetch18(job,b,now){
 if(!matches(job,b,now)){job.status='cancelled';return false;}
 if(job.status!=='pending')return job.status==='ready';
 const ready=b.prefetchWanderPrototype18(job.actor);
 if(ready){job.path=job.actor._route;job.status='ready';}else if(!job.actor._npcWanderSearch)job.status='failed';
 return ready;
}
export function adoptPrefetch18(job,b,now,choosePurpose){
 if(!matches(job,b,now)||job.status!=='ready')return false;
 const n=job.real;if(Math.hypot(n.r-job.endpoint.r,n.c-job.endpoint.c)>.001)return false;
 // Production integration must run existing shop/bench decisions at arrival.
 if(choosePurpose?.(n)){job.status='superseded';return false;}
 if(n._routeSearchPending||n._residentNativeVisit||n._civilianTrip){job.status='superseded';return false;}
 const first=job.path?.[0],last=job.path?.at(-1);if(!first||!last)return false;
 if(b.NPCS.some(other=>other!==n&&!other.dead&&(Math.floor(other.r)===Math.floor(last.r)&&Math.floor(other.c)===Math.floor(last.c)||Math.floor(other._routeGoalR)===Math.floor(last.r)&&Math.floor(other._routeGoalC)===Math.floor(last.c)))){job.status='stale';return false;}
 if(!b._npcPathPassable(n.r,n.c,first.r,first.c,b.npcPassable)||!b._npcPathPassable(n.r,n.c,first.r,first.c,(r,c)=>b.npcWaypointOk(n,r,c))){job.status='stale';return false;}
 n._previousRouteStartR=n._routeStartR;n._previousRouteStartC=n._routeStartC;n._routeStartR=n.r;n._routeStartC=n.c;
 b._setNpcRoute(n,job.path,'walk');job.status='adopted';return true;
}
