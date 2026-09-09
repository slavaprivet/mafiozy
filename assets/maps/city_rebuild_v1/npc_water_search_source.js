function _npcWaterSearchStep(n,depth,now){
 if(typeof _npcReserveRouteWork==='function'&&!_npcReserveRouteWork(performance.now(),n))return;
 const deadline=performance.now()+4,expired=()=>performance.now()>=deadline||typeof _npcRouteWorkExpired==='function'&&_npcRouteWorkExpired();
 let search=n._waterEscapeSearch;if(!search||Math.hypot(n.r-search.r,n.c-search.c)>.01)search=n._waterEscapeSearch={r:n.r,c:n.c,depth,radius:.5,index:0,candidate:null};
 while(search.radius<=12&&!expired()){
  if(!search.candidate){const angle=search.index*Math.PI*2/24,r=search.r+Math.sin(angle)*search.radius,c=search.c+Math.cos(angle)*search.radius,d=_npcRouteWaterDepth(r,c);search.index++;if(search.index>=24){search.index=0;search.radius+=.5;}
   if(d>=search.depth-.02)continue;search.candidate={r,c,steps:Math.max(1,Math.ceil(Math.hypot(r-search.r,c-search.c)/.14)),i:1,previous:search.depth};
  }
  const candidate=search.candidate;let valid=true;
  while(candidate.i<=candidate.steps&&!expired()){
   const t=candidate.i/candidate.steps,r=search.r+(candidate.r-search.r)*t,c=search.c+(candidate.c-search.c)*t,d=_npcRouteWaterDepth(r,c);
   if(d>candidate.previous+.002){valid=false;break;}
   _npcWaterBypass++;try{valid=_npcBodyPassable(r,c,_npcWaterEgressPassable);}finally{_npcWaterBypass--;}
   if(!valid)break;candidate.previous=d;candidate.i++;
  }
  if(!valid){search.candidate=null;continue;}
  if(candidate.i>candidate.steps){n._waterEscapeTarget={r:candidate.r,c:candidate.c,depth:candidate.previous};n._waterEscapeSearch=null;_clearNpcRoute(n);return;}
 }
 if(search.radius>12&&!search.candidate){n._waterEscapeSearch=null;n._waterEscapeRetryAt=now+3000;}
}
