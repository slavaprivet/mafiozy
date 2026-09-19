// Candidate only: do not import from the game. Root owns release timing.
export const candidateSource=String.raw`// Native resident visits only. Caller owns the existing 2 jobs / 4 ms budget.
function _npcPlanNativeVisitRoute(npc,goalR,goalC,passFn,goalRadius,maxVisited,kind){
 const sr=Math.floor(npc.r),sc=Math.floor(npc.c),startKey=sr*MAP_COLS+sc;
 const key=[npc.r,npc.c,goalR,goalC,goalRadius,maxVisited,kind].join('|');
 const resolver=_walkNpcNavigationResolver;
 let search=npc._npcDirectedSearch;
 const row=r=>search.fine?npc.r+r*.25:r+.5,column=c=>search.fine?npc.c+c*.25:c+.5;
 const heuristic=(r,c)=>{const dr=Math.abs(row(r)-goalR),dc=Math.abs(column(c)-goalC);return Math.max(0,dr-goalRadius,dc-goalRadius,dr+dc-Math.SQRT2*goalRadius);};
 const less=(a,b)=>a.f<b.f||a.f===b.f&&(a.h<b.h||a.h===b.h&&a.node.key<b.node.key);
 const push=entry=>{const heap=search.heap;let i=heap.length;heap.push(entry);while(i){const p=(i-1)>>1;if(!less(entry,heap[p]))break;heap[i]=heap[p];i=p;}heap[i]=entry;};
 const pop=()=>{const heap=search.heap,result=heap[0],last=heap.pop();if(heap.length){let i=0;while(i*2+1<heap.length){let child=i*2+1;if(child+1<heap.length&&less(heap[child+1],heap[child]))child++;if(!less(heap[child],last))break;heap[i]=heap[child];i=child;}heap[i]=last;}return result;};
 const edgeClear=(fr,fc,r,c)=>{
  const segments=Math.max(1,Math.ceil(Math.hypot(r-fr,c-fc)/.14));
  for(let s=1;s<=segments;s++)if(!passFn(fr+(r-fr)*s/segments,fc+(c-fc)*s/segments))return false;
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
   if(!passFn(npc.r+(goalR-npc.r)*t,npc.c+(goalC-npc.c)*t)){search.direct=null;break;}
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
 const dirs=[[1,0],[-1,0],[0,1],[0,-1]];
 for(;;){
  let goal=null;const nodes=search.nodes;
  while(search.heap.length&&nodes.size<search.limit&&!_npcRouteWorkExpired()){
   const entry=pop(),cur=entry.node;if(cur.closed||entry.g!==cur.g)continue;
   cur.closed=true;search.qi++;const cr=row(cur.r),cc=column(cur.c),dist=Math.hypot(cr-goalR,cc-goalC);
   if(dist<search.bestD){search.bestD=dist;search.best=cur;}
   // Fine nodes within the goal disk may be on the far side of a wall. Only
   // accept one with a physically clear final connection to the actual door.
   if(dist<=goalRadius&&(!search.fine||edgeClear(cr,cc,goalR,goalC))){goal=cur;break;}
   const fr=cur.key===search.startKey?npc.r:cr,fc=cur.key===search.startKey?npc.c:cc;
   for(const [dr,dc]of dirs){
    const r=cur.r+dr,c=cur.c+dc,key=search.fine?r+','+c:r*MAP_COLS+c,existing=nodes.get(key);if(existing?.closed)continue;
    const rr=row(r),rc=column(c),length=Math.hypot(rr-fr,rc-fc),g=cur.g+length;
    if(existing&&g>=existing.g||!passFn(rr,rc)||!edgeClear(fr,fc,rr,rc))continue;
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
  if(search.fine&&!goal)return false;
  const path=search.fine?[{r:goalR,c:goalC}]:[];goal=goal||search.best;
  while(goal&&goal.key!==search.startKey){path.push({r:row(goal.r),c:column(goal.c)});goal=nodes.get(goal.parent);}
  path.reverse();return _setNpcRoute(npc,path,kind);
 }
}
`;
