// Native resident destinations. Caller owns the shared 4 ms route budget.
function _npcPlanNativeVisitRoute(npc,goalR,goalC,passFn,goalRadius,maxVisited,kind){
 // BEGIN invocation body cache
 // Adjacent edges revisit endpoint/body probes within this synchronous slice.
 // Never attach these results to search: cars and doors may move before resume.
 const passRows=new Map();let passPoints=0;
 const slicePass=(r,c)=>{
  let samples=passRows.get(r);if(samples?.has(c))return samples.get(c);
  const value=passFn(r,c); // Preserve thrown errors; only successful calls cache.
  if(passPoints<8192){if(!samples)passRows.set(r,samples=new Map());samples.set(c,value);passPoints++;}
  return value;
 };
 // END invocation body cache
 const sr=Math.floor(npc.r),sc=Math.floor(npc.c),startKey=sr*MAP_COLS+sc;
 const key=[npc.r,npc.c,goalR,goalC,goalRadius,maxVisited,kind].join('|');
 const resolver=_walkNpcNavigationResolver;
 let search=npc._npcDirectedSearch;
 const row=r=>search.fine?npc.r+r*.25:r+.5,column=c=>search.fine?npc.c+c*.25:c+.5;
 const heuristic=(r,c)=>{if(!search.fine&&search.goalAnchors?.size){let best=Infinity;for(const a of search.goalAnchors.values())best=Math.min(best,Math.abs(row(r)-a.r)+Math.abs(column(c)-a.c));return best;}const dr=Math.abs(row(r)-goalR),dc=Math.abs(column(c)-goalC);return Math.max(0,dr-goalRadius,dc-goalRadius,dr+dc-Math.SQRT2*goalRadius);};
 const less=(a,b)=>a.f<b.f||a.f===b.f&&(a.h<b.h||a.h===b.h&&a.node.key<b.node.key);
 const push=entry=>{const heap=search.heap;let i=heap.length;heap.push(entry);while(i){const p=(i-1)>>1;if(!less(entry,heap[p]))break;heap[i]=heap[p];i=p;}heap[i]=entry;};
 const pop=()=>{const heap=search.heap,result=heap[0],last=heap.pop();if(heap.length){let i=0;while(i*2+1<heap.length){let child=i*2+1;if(child+1<heap.length&&less(heap[child+1],heap[child]))child++;if(!less(heap[child],last))break;heap[i]=heap[child];i=child;}heap[i]=last;}return result;};
 const edgeClear=(fr,fc,r,c)=>{
  const segments=Math.max(1,Math.ceil(Math.hypot(r-fr,c-fc)/.14));
  for(let s=1;s<=segments;s++)if(!slicePass(fr+(r-fr)*s/segments,fc+(c-fc)*s/segments))return false;
  const swept=resolver({mode:'sweep',from:{r:fr,c:fc},to:{r,c},radius:.18});
  return !(swept?.swept===true&&swept.blocked);
 };
 if(!search||search.algorithm!=='astar-visit'||search.key!==key||search.pass!==passFn||search.resolver!==resolver){
  if(search)npc._routeSearchRestarts=(npc._routeSearchRestarts||0)+1;
  const first={r:sr,c:sc,key:startKey,g:0,closed:false};
  search={algorithm:'astar-visit',key,pass:passFn,resolver,heap:[],nodes:new Map([[startKey,first]]),qi:0,best:first,bestD:Math.hypot(sr+.5-goalR,sc+.5-goalC),startKey,limit:maxVisited};
  const directLength=Math.hypot(goalR-npc.r,goalC-npc.c);
  search.direct=directLength>0&&directLength<=8?{sample:0,count:Math.max(1,Math.ceil(directLength/.14)),swept:false}:null;
  const h=heuristic(sr,sc);push({node:first,g:0,h,f:h});
 }
 // BEGIN short direct approach
 if(search.direct){
  const direct=search.direct;
  if(!direct.swept&&!_npcRouteWorkExpired()){
   const swept=resolver({mode:'sweep',from:{r:npc.r,c:npc.c},to:{r:goalR,c:goalC},radius:.18});
   if(swept?.swept!==true||swept.blocked)search.direct=null;
   else direct.swept=true;
  }
  while(search.direct&&direct.swept&&direct.sample<direct.count&&!_npcRouteWorkExpired()){
   const t=(direct.sample+1)/direct.count;
   if(!slicePass(npc.r+(goalR-npc.r)*t,npc.c+(goalC-npc.c)*t)){search.direct=null;break;}
   direct.sample++;
  }
  if(search.direct){
   if(direct.swept&&direct.sample===direct.count){
    const swept=resolver({mode:'sweep',from:{r:npc.r,c:npc.c},to:{r:goalR,c:goalC},radius:.18});
    if(swept?.swept===true&&!swept.blocked){
     npc._routeSearchExpanded=0;npc._routeSearchVisited=1;npc._npcDirectedSearch=null;
     return _setNpcRoute(npc,[{r:goalR,c:goalC}],kind);
    }
    search.direct=null;
   }
   if(search.direct){npc._npcDirectedSearch=search;npc._routeSearchPending=true;return false;}
  }
 }
 // END short direct approach
 // A visible door need not share a free 4.1 m grid centre. Discover a finite
 // set of physically connected terminal anchors before exploring the city.
 // Existing near anchors win; only their absence permits the 2.25-cell ring.
 if(!search.goalAnchors){
  if(!search.goalDiscovery){
   const radius=2.25,candidates=[];
   for(let r=Math.floor(goalR-radius);r<=Math.floor(goalR+radius);r++)for(let c=Math.floor(goalC-radius);c<=Math.floor(goalC+radius);c++){
    const rr=r+.5,cc=c+.5,d=Math.hypot(rr-goalR,cc-goalC);
    if(d<=radius)candidates.push({r:rr,c:cc,key:r*MAP_COLS+c,d});
   }
   candidates.sort((a,b)=>a.d-b.d||a.key-b.key);
   search.goalDiscovery={candidates,index:0,anchors:new Map()};
  }
  const discovery=search.goalDiscovery;
  while(discovery.index<discovery.candidates.length&&!_npcRouteWorkExpired()){
   const a=discovery.candidates[discovery.index];
   if(a.d>goalRadius&&discovery.anchors.size&&discovery.candidates[discovery.index-1]?.d<=goalRadius)break;
   discovery.index++;
   if(slicePass(a.r,a.c)&&edgeClear(a.r,a.c,goalR,goalC))discovery.anchors.set(a.key,a);
  }
  const nearDone=discovery.index<discovery.candidates.length&&discovery.candidates[discovery.index].d>goalRadius&&discovery.anchors.size&&discovery.candidates[discovery.index-1]?.d<=goalRadius;
  if(discovery.index<discovery.candidates.length&&!nearDone){npc._npcDirectedSearch=search;npc._routeSearchPending=true;return false;}
  search.goalAnchors=discovery.anchors;search.goalDiscovery=null;
 }
 // A narrow corridor may have neither coarse terminal centres nor coarse
 // neighbours at the start, while the existing fine fallback can walk it.
 // Preserve that case; only a non-isolated coarse start can fail immediately.
 if(!search.goalAnchors.size&&!search.fine&&!search.goalStartIsolated){
  const probe=search.goalStartProbe??={index:0,free:false},steps=[[1,0],[-1,0],[0,1],[0,-1]];
  while(probe.index<steps.length&&!_npcRouteWorkExpired()){
   const [dr,dc]=steps[probe.index++],r=sr+dr+.5,c=sc+dc+.5;
   if(slicePass(r,c)&&edgeClear(npc.r,npc.c,r,c)){probe.free=true;break;}
  }
  if(probe.free){npc._routeSearchExpanded=0;npc._routeSearchVisited=1;npc._npcDirectedSearch=null;return false;}
  if(probe.index<steps.length){npc._npcDirectedSearch=search;npc._routeSearchPending=true;return false;}
  search.goalStartIsolated=true;
 }

 const dirs=[[1,0],[-1,0],[0,1],[0,-1]];
 for(;;){
  let goal=null;const nodes=search.nodes;
  while(search.heap.length&&nodes.size<search.limit&&!_npcRouteWorkExpired()){
   const entry=pop(),cur=entry.node;if(cur.closed||entry.g!==cur.g)continue;
   cur.closed=true;search.qi++;const cr=row(cur.r),cc=column(cur.c),dist=Math.hypot(cr-goalR,cc-goalC);
   if(dist<search.bestD){search.bestD=dist;search.best=cur;}
   // Fine nodes within the goal disk may be on the far side of a wall. Only
   // accept one with a physically clear final connection to the actual door.
   const terminal=search.fine?dist<=goalRadius:search.goalAnchors.has(cur.key);
   if(terminal){
    const fr=cur.key===search.startKey?npc.r:cr,fc=cur.key===search.startKey?npc.c:cc;
    // Door leaves or cars may have moved during the queued search. Recheck
    // the full current connector, including its body/water/dynamic callback.
    if(slicePass(fr,fc)&&edgeClear(fr,fc,goalR,goalC)){goal=cur;break;}
    if(!search.fine){search.goalAnchors.delete(cur.key);if(!search.goalAnchors.size){npc._routeSearchExpanded=search.qi;npc._routeSearchVisited=nodes.size;npc._npcDirectedSearch=null;return false;}}
   }
   const fr=cur.key===search.startKey?npc.r:cr,fc=cur.key===search.startKey?npc.c:cc;
   for(const [dr,dc]of dirs){
    const r=cur.r+dr,c=cur.c+dc,key=search.fine?r+','+c:r*MAP_COLS+c,existing=nodes.get(key);if(existing?.closed)continue;
    const rr=row(r),rc=column(c),length=Math.hypot(rr-fr,rc-fc),g=cur.g+length;
    if(existing&&g>=existing.g||!slicePass(rr,rc)||!edgeClear(fr,fc,rr,rc))continue;
    const node=existing||{r,c,key,closed:false};node.g=g;node.parent=cur.key;if(!existing)nodes.set(key,node);
    const h=heuristic(r,c);push({node,g,h,f:g+h});
   }
  }
  if(!goal&&search.heap.length&&nodes.size<search.limit){npc._npcDirectedSearch=search;npc._routeSearchPending=true;return false;}
  // An actual start can be separated from every 4.1 m cell centre while a
  // shorter physical step is free. Only this isolated-start failure retries
  // at 1.025 m resolution. Total node allowance and shared deadline stay fixed.
  if(!goal&&!search.fine&&search.qi===1&&nodes.size===1&&maxVisited>2){
   const first={r:0,c:0,key:'0,0',g:0,closed:false};
   Object.assign(search,{fine:true,startKey:first.key,heap:[],nodes:new Map([[first.key,first]]),qi:0,coarseExpanded:1,best:first,bestD:Math.hypot(npc.r-goalR,npc.c-goalC),limit:maxVisited-1});
   const h=heuristic(0,0);push({node:first,g:0,h,f:h});continue;
  }
  npc._routeSearchExpanded=search.qi+(search.coarseExpanded||0);npc._routeSearchVisited=nodes.size+(search.coarseExpanded||0);npc._npcDirectedSearch=null;
  if(!goal)return false;
  const path=[{r:goalR,c:goalC}];
  while(goal&&goal.key!==search.startKey){path.push({r:row(goal.r),c:column(goal.c)});goal=nodes.get(goal.parent);}
  path.reverse();return _setNpcRoute(npc,path,kind);
 }
}
