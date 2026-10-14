// Review fixture only: apply the proposed narrow adapter changes in memory.
// No production file is written by this module.
import assert from 'node:assert/strict';

export function applyLongFollow23HostCandidate(source){
  let result=source.replace(/\r\n/g,'\n');
  const replace=(before,after)=>{assert.equal(result.split(before).length-1,1,'unique host anchor: '+before.slice(0,100));result=result.replace(before,after);};
  replace('let core,professions,routeFactory,targets={}', 'let core,professions,routeFactory,longFollowFactory,targets={}');
  replace('routeFactory=module.createMercenaryRoutePlanner;core=', 'routeFactory=module.createMercenaryRoutePlanner;longFollowFactory=module.createMercenaryLongFollow;core=');
  replace("if(m.hp<=0||m.dead||m._mercenaryHospital){m._mercenaryMove=null;", "if(m.hp<=0||m.dead||m._mercenaryHospital){m._mercenaryPath=null;m._mercenaryMove=null;");
  replace("clearFocus(m);positions.push(chosen);m._mercenaryOrder='rally';", "clearFocus(m);if(m._mercenaryPath?.stagedFollow)m._mercenaryPath=null;positions.push(chosen);m._mercenaryOrder='rally';");
  replace("m._mercenaryOrder='follow';m._mercenaryRally=null;m._mercenaryFollowAt=0;", "if(m._mercenaryPath?.stagedFollow)m._mercenaryPath=null;m._mercenaryOrder='follow';m._mercenaryRally=null;m._mercenaryFollowAt=0;");
  replace("m._mercenaryHospital=true;m._mercenaryMove=null;return true;", "m._mercenaryHospital=true;m._mercenaryPath=null;m._mercenaryMove=null;return true;");
  replace("const action=core.getAction(r.id);if(m._mercenaryVehicleSeat)", "const action=core.getAction(r.id);if(m._mercenaryPath?.stagedFollow&&(action||r.status==='hospital'||r.status==='downed'||m._mercenaryVehicleSeat||m._mercenaryVehicleChase))m._mercenaryPath=null;if(m._mercenaryVehicleSeat)");
  replace("if(now()-route.blockedAt>.5)m._mercenaryPath=null;", "if(now()-route.blockedAt>.5){if(route.stagedFollow){route.stagedFollow.blocked();route.blockedAt=0;}else m._mercenaryPath=null;}");
  replace("const replace=route&&(route.purpose!==purpose||drift>threshold&&(!tracking||route.direct||drift>12||route.search&&now()-route.createdAt>6||route.path&&Math.hypot(from.x-route.goal.x,from.z-route.goal.z)<=goal.stopDistance+.1));", "const replace=route&&(route.purpose!==purpose||route.stagedFollow&&(!following||m._mercenaryVehicleChase)||!route.stagedFollow&&drift>threshold&&(!tracking||route.direct||drift>12||route.search&&now()-route.createdAt>6||route.path&&Math.hypot(from.x-route.goal.x,from.z-route.goal.z)<=goal.stopDistance+.1));");
  replace("  if(!route){\n   route=m._mercenaryPath={purpose,createdAt:now()", `  // Far followers use local stages before any whole-distance sweep. The
  // ordinary short-range, rally and specialist route contracts stay intact.
  if(following&&!m._mercenaryVehicleChase&&longFollowFactory&&(route?.stagedFollow||Math.hypot(from.x-goal.position.x,from.z-goal.position.z)>32)){
   if(!route?.stagedFollow)route=m._mercenaryPath={purpose,goal:{...goal.position},blockedAt:0,stagedFollow:longFollowFactory({canMove:clear,groundHeight:(x,z)=>Number(targets.groundHeight?.(x,z))||0,clock:()=>performance.now()})};
   const result=route.stagedFollow.advance(from,goal.position,{arrivalRadius:goal.stopDistance,maxExpanded:8,budgetMs:Math.min(.75,routeWorkDeadline-performance.now())});
   route.goal={...goal.position};route.stats=route.stagedFollow.stats;
   if(result.status==='arrived'){m._mercenaryPath=null;return {...goal,routed:false};}
   if(result.waypoint)return {position:result.waypoint,stopDistance:result.stopDistance,routed:true};
   m._mercenaryMoveReason=result.status==='blocked'?'no_route':result.status==='budget'?'search_budget':'search_pending';return null;
  }
  if(!route){
   route=m._mercenaryPath={purpose,createdAt:now()`);
  return result;
}
