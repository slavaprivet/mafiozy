// CPU candidate only. Not imported by world.html or any production module.
export function findWanderGridExit18(npc,search,{edgeClear,pointClear,expired,occupiedGoals}){
 const step=.25,limit=384,radius=12,dirs=[[1,0],[-1,0],[0,1],[0,-1]];
 let state=search.gridExit;
 if(!state||state.originR!==npc.r||state.originC!==npc.c){const first={ir:0,ic:0,r:npc.r,c:npc.c,next:0};state=search.gridExit={originR:npc.r,originC:npc.c,queue:[first],qi:0,nodes:new Map([['0,0',first]]),goals:new Set(),expanded:0};}
 while(state.qi<state.queue.length&&state.nodes.size<limit&&!expired()){
  const cur=state.queue[state.qi];
  if(!cur.goalDone){
   const centre={r:Math.floor(cur.r)+.5,c:Math.floor(cur.c)+.5},key=centre.r+','+centre.c;
   if(Math.hypot(centre.r-cur.r,centre.c-cur.c)<=.2&&!state.goals.has(key)){
    if(cur.goalDirection===undefined){
     if(!pointClear(centre.r,centre.c)||!edgeClear(cur,centre)){state.goals.add(key);cur.goalDone=true;}
     else {cur.goalDirection=0;cur.centre=centre;}
    }
    if(cur.goalDirection!==undefined){
     while(cur.goalDirection<4&&!expired()){
      const [dr,dc]=dirs[cur.goalDirection++],end={r:centre.r+dr,c:centre.c+dc};
      if(occupiedGoals.has(`${Math.floor(end.r)},${Math.floor(end.c)}`)||!pointClear(end.r,end.c)||!edgeClear(centre,end))continue;
      const path=[];let node=cur;while(node.parent){path.push({r:node.r,c:node.c});node=node.parent;}path.reverse();
      if(Math.hypot(cur.r-centre.r,cur.c-centre.c)>.000001)path.push(centre);
      path.push(end);return{status:'ready',path,expanded:state.expanded,nodes:state.nodes.size};
     }
     if(cur.goalDirection<4)return{status:'pending'};
     state.goals.add(key);cur.goalDone=true;
    }
   }else cur.goalDone=true;
  }
  while(cur.next<4&&!expired()&&state.nodes.size<limit){
   const [dr,dc]=dirs[cur.next++],ir=cur.ir+dr,ic=cur.ic+dc,key=ir+','+ic;
   if(Math.abs(ir)>radius||Math.abs(ic)>radius||state.nodes.has(key))continue;
   const next={ir,ic,r:state.originR+ir*step,c:state.originC+ic*step,next:0,parent:cur};
   if(!pointClear(next.r,next.c)||!edgeClear(cur,next))continue;
   state.nodes.set(key,next);state.queue.push(next);
  }
  if(cur.next===4){state.qi++;state.expanded++;}
 }
 return{status:state.qi<state.queue.length&&state.nodes.size<limit?'pending':'failed',expanded:state.expanded,nodes:state.nodes.size};
}

export function injectWanderGridExit18(pick){
 const marker='  npc._npcWanderSearch=null;\n  let pool=';
 if(!pick.includes(marker))throw Error('wander candidate insertion marker missing');
 return pick.replace(marker,`  if(resolver&&nodes.size===1&&queue.length===1){
    const escape=findWanderGridExit18(npc,search,{
      pointClear:edgePass,occupiedGoals,expired:_npcRouteWorkExpired,
      edgeClear:(from,to)=>{
        const swept=resolver({mode:'sweep',from,to,radius:.18});
        return !(swept?.swept===true&&swept.blocked)&&_npcPathPassable(from.r,from.c,to.r,to.c,edgePass);
      }
    });
    if(escape.status==='pending'){npc._npcWanderSearch=search;npc.tr=npc.r;npc.tc=npc.c;npc.idleUntil=0;npc.walking=false;return false;}
    if(escape.status==='ready'){npc._npcWanderSearch=null;return _setNpcRoute(npc,escape.path,'walk');}
  }
  npc._npcWanderSearch=null;
  let pool=`);
}
