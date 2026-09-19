// Staged transform only: production world is not modified by this module.
export function singleGoalWanderCandidate18(pick){
 const header='  const {queue,nodes,candidates}=search,dirs=[[1,0],[-1,0],[0,1],[0,-1]];';
 if(!pick.includes(header)||!pick.includes('const wanderChoiceTarget=8;'))throw Error('current wander candidate markers not found');
 return pick.replace('const wanderChoiceTarget=8;','const wanderChoiceTarget=1;').replace(header,`  const {queue,nodes,candidates}=search;
  // One complete outing is sufficient. Vary expansion order deterministically
  // per actor and outing so the first eligible target has no common axis bias.
  const dirs=resolver?(search.wanderDirs||(search.wanderDirs=(()=>{
    let seed=2166136261;for(const ch of String(npc.id)+'|'+sr+','+sc+'|'+npc._routeStartR+','+npc._routeStartC){seed^=ch.charCodeAt(0);seed=Math.imul(seed,16777619);}
    const order=[[1,0],[-1,0],[0,1],[0,-1]];
    for(let i=3;i>0;i--){seed^=seed<<13;seed^=seed>>>17;seed^=seed<<5;const j=(seed>>>0)%(i+1),value=order[i];order[i]=order[j];order[j]=value;}
    return order;
  })())):[[1,0],[-1,0],[0,1],[0,-1]];`);
}
