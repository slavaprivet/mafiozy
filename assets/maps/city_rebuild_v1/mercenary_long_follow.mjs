// Bounded receding-horizon follow over the existing local route planner.
import {createMercenaryRoutePlanner} from './mercenary_route.mjs';

const distance=(a,b)=>Math.hypot(a.x-b.x,a.z-b.z);
const valid=p=>p&&Number.isFinite(p.x)&&Number.isFinite(p.z);

export function createMercenaryLongFollow({canMove,groundHeight=()=>0,clock=()=>performance.now()}={}){
  const planner=createMercenaryRoutePlanner({canMove,groundHeight,clock});
  const stats={searches:0,expanded:0,checks:0,completedStages:0,retargets:0,cancellations:0,maxSearchExpanded:0};
  let route=null,blockedUntil=0;
  const clear=()=>{route=null;blockedUntil=0;};
  const cancel=()=>{clear();stats.cancellations++;return {status:'cancelled',waypoint:null};};
  const reply=status=>({status,waypoint:null});

  function begin(from,goal,arrivalRadius,stamp){
    const d=distance(from,goal),length=Math.min(24,d),heading=Math.atan2(goal.z-from.z,goal.x-from.x),candidates=[];
    // Monotone stage endpoints avoid a left/right endpoint cycle. A large
    // enclosure requiring a global detour must fail closed here.
    for(const angle of d<=24?[0]:[0,Math.PI/6,-Math.PI/6,Math.PI/3,-Math.PI/3]){
      const p=d<=24?{...goal}:{x:from.x+Math.cos(heading+angle)*length,z:from.z+Math.sin(heading+angle)*length};
      if(d>24&&d-distance(p,goal)<1)continue;
      p.y=groundHeight(p.x,p.z);candidates.push({point:p,arrivalRadius:d<=24?arrivalRadius:.04});
    }
    route={origin:{...from},goal:{...goal},createdAt:stamp,candidates,candidateIndex:0,search:null,path:null,index:0};
  }

  function advance(from,goal,{active=true,purpose='follow',arrivalRadius=.6,maxExpanded=8,budgetMs=.75}={}){
    if(!active||purpose!=='follow'||!valid(from)||!valid(goal))return cancel();
    const stamp=clock(),d=distance(from,goal);
    if(d<=arrivalRadius){clear();return reply('arrived');}
    if(route){
      const drift=distance(route.goal,goal);
      // Small leader updates preserve pending work and the current safe leg.
      if(drift>12||(route.search&&stamp-route.createdAt>6000&&drift>.8)){clear();stats.retargets++;}
    }
    if(stamp<blockedUntil)return reply('blocked');
    if(!route)begin(from,goal,arrivalRadius,stamp);
    if(route.path){
      while(route.index<route.path.length&&distance(from,route.path[route.index])<=.06)route.index++;
      if(route.index>=route.path.length){
        stats.completedStages++;clear();
        // A new search waits for the next update; never chain local searches
        // into one unbounded operation in the caller's current slice.
        return reply('stage_complete');
      }
      return {status:'moving',waypoint:{...route.path[route.index]},stopDistance:.04};
    }
    if(!(budgetMs>0)||!(maxExpanded>0))return reply('budget');
    const deadline=stamp+Math.min(.75,budgetMs);
    if(!route.search){
      const candidate=route.candidates[route.candidateIndex];
      if(!candidate){route=null;blockedUntil=stamp+2000;return reply('blocked');}
      // An endpoint inside a house needs one footprint check, not 2400 nodes.
      stats.checks++;
      if(canMove(candidate.point,candidate.point)!==true){route.candidateIndex++;return reply('candidate_failed');}
      route.search=planner.start(route.origin,candidate.point,{arrivalRadius:candidate.arrivalRadius});stats.searches++;
    }
    if(clock()>=deadline)return reply('budget');
    const search=route.search,beforeExpanded=search.stats.expanded,beforeChecks=search.stats.checks;
    search.advance({maxExpanded:Math.min(8,Math.floor(maxExpanded)),budgetMs:deadline-clock()});
    stats.expanded+=search.stats.expanded-beforeExpanded;stats.checks+=search.stats.checks-beforeChecks;
    stats.maxSearchExpanded=Math.max(stats.maxSearchExpanded,search.stats.expanded);
    if(!search.done)return reply('searching');
    route.search=null;
    if(!search.path){route.candidateIndex++;return reply('candidate_failed');}
    route.path=search.path;route.index=0;
    // The adapter retains every actual movement and swept collision check.
    return reply('path_ready');
  }

  return {advance,cancel,stats,
    blocked(){clear();blockedUntil=clock()+500;},
    inspect(){return route?{goal:{...route.goal},candidateIndex:route.candidateIndex,searching:!!route.search,pathLength:route.path?.length||0}:null;}
  };
}
