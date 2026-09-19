// Staged only. Root owns the shared production module/reload window.
export function stageNativeGoalAnchors(source){
 const replace=(before,after)=>{if(!source.includes(before))throw Error('Native goal stage source changed: '+before.slice(0,90));source=source.replace(before,after);};
 replace('const heuristic=(r,c)=>{const dr=',`const heuristic=(r,c)=>{if(!search.fine&&search.goalAnchors?.size){let best=Infinity;for(const a of search.goalAnchors.values())best=Math.min(best,Math.abs(row(r)-a.r)+Math.abs(column(c)-a.c));return best;}const dr=`);
 replace(' // END short direct approach',` // END short direct approach
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
   if(passFn(a.r,a.c)&&edgeClear(a.r,a.c,goalR,goalC))discovery.anchors.set(a.key,a);
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
   if(passFn(r,c)&&edgeClear(npc.r,npc.c,r,c)){probe.free=true;break;}
  }
  if(probe.free){npc._routeSearchExpanded=0;npc._routeSearchVisited=1;npc._npcDirectedSearch=null;return false;}
  if(probe.index<steps.length){npc._npcDirectedSearch=search;npc._routeSearchPending=true;return false;}
  search.goalStartIsolated=true;
 }
`);
 replace("if(dist<=goalRadius&&(!search.fine||edgeClear(cr,cc,goalR,goalC))){goal=cur;break;}",`const terminal=search.fine?dist<=goalRadius:search.goalAnchors.has(cur.key);
   if(terminal){
    const fr=cur.key===search.startKey?npc.r:cr,fc=cur.key===search.startKey?npc.c:cc;
    // Door leaves or cars may have moved during the queued search. Recheck
    // the full current connector, including its body/water/dynamic callback.
    if(passFn(fr,fc)&&edgeClear(fr,fc,goalR,goalC)){goal=cur;break;}
    if(!search.fine){search.goalAnchors.delete(cur.key);if(!search.goalAnchors.size){npc._routeSearchExpanded=search.qi;npc._routeSearchVisited=nodes.size;npc._npcDirectedSearch=null;return false;}}
   }`);
 replace('if(search.fine&&!goal)return false;','if(!goal)return false;');
 replace('const path=search.fine?[{r:goalR,c:goalC}]:[];goal=goal||search.best;','const path=[{r:goalR,c:goalC}];');
 return source;
}
