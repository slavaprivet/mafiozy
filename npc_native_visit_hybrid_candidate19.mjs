// CPU prototype only. Never imported by world.html or the walk renderer.
export function nativeVisitHybridCandidate19(actualHelper,world){
 const start=world.indexOf('function _npcFindWanderGridExit('),end=world.indexOf('function pickNpcWaypoint(',start);
 if(start<0||end<0)throw new Error('Current physical grid-exit helper missing');
 const exitHelper=world.slice(start,end).replace('function _npcFindWanderGridExit(','function _npcFindVisitGridExit19(').replace('limit=384','limit=Math.min(96,search.hybridNodeLimit||96)');
 let helper=actualHelper.replace(/\r\n/g,'\n');
 const marker=" if(!search||search.algorithm!=='astar-visit'";
 if(!helper.includes(marker))throw new Error('Current visit search initialization missing');
 const implementation=`
 // A bounded local escape can reconnect an isolated actual origin to the
 // coarse graph. Its scratch actor is only a planning origin, never an NPC.
 const beginFine=spent=>{
  delete search.hybrid;
  if(maxVisited-spent<2){npc._routeSearchExpanded=spent;npc._routeSearchVisited=spent;npc._npcDirectedSearch=null;return false;}
  const first={r:0,c:0,key:'0,0',g:0,closed:false};
  Object.assign(search,{fine:true,startKey:first.key,heap:[],nodes:new Map([[first.key,first]]),qi:0,coarseExpanded:spent,best:first,bestD:Math.hypot(npc.r-goalR,npc.c-goalC),limit:maxVisited-spent});
  const h=heuristic(0,0);push({node:first,g:0,h,f:h});return null;
 };
 const continueHybrid=()=>{
  const hybrid=search.hybrid;
  const pending=()=>{npc._npcDirectedSearch=search;npc._routeSearchPending=true;return false;};
  if(hybrid.phase==='exit'){
   const exit=_npcFindVisitGridExit19(npc,hybrid.local,{pointClear:slicePass,edgeClear:(a,b)=>edgeClear(a.r,a.c,b.r,b.c),expired:_npcRouteWorkExpired,occupiedGoals:hybrid.occupied});
   if(exit.status==='pending')return pending();
   hybrid.exitVisited=exit.nodes||hybrid.local.gridExit?.nodes.size||1;
   hybrid.exitExpanded=exit.expanded||hybrid.local.gridExit?.expanded||0;
   if(exit.status!=='ready')return beginFine(1+hybrid.exitVisited);
   hybrid.prefix=exit.path;hybrid.proxy={...exit.path.at(-1),_npcVisitHybridDisabled:true};
   hybrid.coarseLimit=Math.min(192,Math.floor((maxVisited-1-hybrid.exitVisited)/3));
   if(hybrid.coarseLimit<2)return beginFine(1+hybrid.exitVisited);
   hybrid.phase='coarse';
  }
  if(hybrid.phase==='coarse'){
   if(_npcRouteWorkExpired())return pending();
   hybrid.proxy._routeSearchPending=false;
   const ready=_npcPlanNativeVisitRoute(hybrid.proxy,goalR,goalC,passFn,goalRadius,hybrid.coarseLimit,kind);
   if(!ready&&hybrid.proxy._routeSearchPending)return pending();
   hybrid.coarseVisited=hybrid.proxy._routeSearchVisited||1;
   if(!ready)return beginFine(1+hybrid.exitVisited+hybrid.coarseVisited);
   hybrid.phase='verify';hybrid.verifyIndex=0;
  }
  // Recheck the physical prefix after queued coarse work. A moved vehicle
  // cannot turn the earlier local escape into an unverified published path.
  while(hybrid.verifyIndex<hybrid.prefix.length&&!_npcRouteWorkExpired()){
   const from=hybrid.verifyIndex?hybrid.prefix[hybrid.verifyIndex-1]:npc,to=hybrid.prefix[hybrid.verifyIndex];
   if(!slicePass(from.r,from.c)||!edgeClear(from.r,from.c,to.r,to.c))return beginFine(1+hybrid.exitVisited+hybrid.coarseVisited);
   hybrid.verifyIndex++;
  }
  if(hybrid.verifyIndex<hybrid.prefix.length)return pending();
  npc._routeSearchExpanded=1+hybrid.exitExpanded+(hybrid.proxy._routeSearchExpanded||0);
  npc._routeSearchVisited=1+hybrid.exitVisited+hybrid.coarseVisited;npc._npcDirectedSearch=null;
  return _setNpcRoute(npc,[...hybrid.prefix,...hybrid.proxy._route],kind);
 };
`;
 helper=helper.replace(marker,implementation+marker);
 helper=helper.replace(' // BEGIN short direct approach'," if(search.hybrid){const resumed=continueHybrid();if(resumed!==null)return resumed;}\n // BEGIN short direct approach");
 const fallback="  if(!goal&&!search.fine&&search.qi===1&&nodes.size===1&&maxVisited>2){";
 if(!helper.includes(fallback))throw new Error('Current isolated-start fallback missing');
 helper=helper.replace(fallback,fallback+`
   if(!npc._npcVisitHybridDisabled&&maxVisited>=64&&search.goalAnchors.size&&typeof _npcFindVisitGridExit19==='function'){
    search.hybrid={phase:'exit',local:{hybridNodeLimit:Math.min(96,Math.floor((maxVisited-1)/4))},occupied:new Set()};
    const resumed=continueHybrid();if(resumed!==null)return resumed;continue;
   }
`);
 return exitHelper+'\n'+helper;
}
