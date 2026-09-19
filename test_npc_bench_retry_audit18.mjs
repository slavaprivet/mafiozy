import fs from 'node:fs';
import vm from 'node:vm';
import assert from 'node:assert/strict';
const world=fs.readFileSync('world.html','utf8');
const code=world.slice(world.indexOf('// CIVILIAN_PURPOSEFUL_PLANS_START'),world.indexOf('// CIVILIAN_PURPOSEFUL_PLANS_END'));
let now=1000;
const attempted=[];
const c={Math,Number,Map,Set,performance:{now:()=>now},MAP_ROWS:100,MAP_COLS:100,
 _npcLifeEligible:()=>true,_isRespawnableResident:()=>true,_residentBuildingDoors:()=>[],
 _walkNpcNavigationResolver:()=>({blocked:false,depth:0}),_clearNpcRoute:n=>{n._route=null;},
 _planNpcRouteTo(n,r,col,pass,radius,limit,kind){attempted.push([r,col]);n._routeSearchPending=false;if(col<6)return false;n._route=[{r,c:col}];return true;},
 npcWaypointOk:()=>true,_npcPathPassable:()=>true,
 _setNpcRoute(n,route,kind){n._route=route;n._routeKind=kind;return true;}};
vm.createContext(c);vm.runInContext(code,c);c._civilianPlanUnit=()=>0;
c._setWalkCivilianPlaces({benches:[{id:'blocked-bench',r:5,c:5,yaw:0,seatWorldY:.61},{id:'clear-bench',r:5,c:7,yaw:0,seatWorldY:.61}]});
const n={id:'resident_bench_audit',r:4,c:5,_civilianPlan:{phase:'walk_to_bench',cycle:0}};
assert.equal(c._civilianPlanNext(n,now),false);
assert.equal(n._civilianPlan.benchId,null);
assert(n._civilianPlan._failedBenches['blocked-bench']>now);
now+=201;
assert.equal(c._civilianPlanNext(n,now),true,'next attempt chooses the reachable alternative');
assert.equal(attempted.length,2);assert.equal(n._civilianPlan.benchId,'clear-bench');

// Pending is not failure: keep the same destination and retained frontier.
const waiting={id:'pending',r:4,c:5,_civilianPlan:{phase:'walk_to_bench',cycle:0}};
c._planNpcRouteTo=(actor)=>{actor._routeSearchPending=true;return false;};
assert.equal(c._civilianPlanNext(waiting,now),false);
assert.equal(waiting._civilianPlan.benchId,'blocked-bench');
assert.equal(waiting._civilianPlan._failedBenches,undefined);
assert.equal(waiting._civilianPlan.retryAt,0);

// With all nearby benches unreachable, proceed to the next real task.
c._setWalkCivilianPlaces({benches:[{id:'only-blocked',r:5,c:5,yaw:0,seatWorldY:.61}]});
c._planNpcRouteTo=(actor)=>{actor._routeSearchPending=false;return false;};
const none={id:'no-bench',r:4,c:5,_civilianPlan:{phase:'walk_to_bench',cycle:0}};
c._civilianPlanNext(none,now);now+=201;c._civilianPlanNext(none,now);
assert.equal(none._civilianPlan.phase,'seek_shop');assert.equal(none._civilianPlan.benchId,null);
// Temporary geometry can recover; expired failures do not blacklist forever.
now+=60001;none._civilianPlan.phase='walk_to_bench';none._civilianPlan.retryAt=0;
c._planNpcRouteTo=(actor,r,col)=>{actor._routeSearchPending=false;actor._route=[{r,c:col}];return true;};
assert(c._civilianPlanNext(none,now));assert.equal(none._civilianPlan.benchId,'only-blocked');
console.log(JSON.stringify({pass:true,attemptsToReachAlternative:2,checks:'definitive failure, pending preservation, all failed next task, expiry recovery',limit:'actual plan selection + controlled route fixture; not LIVE geometry or a LIVE count'}));
