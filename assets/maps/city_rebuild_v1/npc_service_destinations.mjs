// Resolve hospital access from physical entries; preserve native walls and water.
export function createNpcServiceDestinations({getHospitals,vehicleQuery,pedestrianQuery,isRoad,worldScale=4.1,clock=()=>performance.now()}={}){
 const cache=new Map(),jobs=new Map();let budgetSpent=0;
 const radius=.18,spacing=.25;
 function clearPoint(r,c,carId){
  for(const [dr,dc]of [[0,0],[radius,0],[-radius,0],[0,radius],[0,-radius]]){
   const p=pedestrianQuery({r:r+dr,c:c+dc,ignoreVehicleId:carId});if(!p||p.blocked||p.depth>.025)return false;
  }return true;
 }
 function clearSegment(a,b,carId){
  const n=Math.max(1,Math.ceil(Math.hypot(b.r-a.r,b.c-a.c)/.08));
  for(let i=0;i<=n;i++)if(!clearPoint(a.r+(b.r-a.r)*i/n,a.c+(b.c-a.c)*i/n,carId))return false;return true;
 }
 function push(heap,node){let i=heap.length;heap.push(node);while(i){const p=(i-1)>>1;if(heap[p].f<=node.f)break;heap[i]=heap[p];i=p;}heap[i]=node;}
 function pop(heap){const top=heap[0],last=heap.pop();if(heap.length){let i=0;while(i*2+1<heap.length){let child=i*2+1;if(child+1<heap.length&&heap[child+1].f<heap[child].f)child++;if(last.f<=heap[child].f)break;heap[i]=heap[child];i=child;}heap[i]=last;}return top;}
 const heuristic=(point,goals)=>{let d=Infinity;for(const goal of goals)d=Math.min(d,Math.hypot(goal.access.r-point.r,goal.access.c-point.c));return d;};
 function makeJob(hospital,carId){
  const candidates=[];
  for(let ring=1;ring<=7;ring+=.5)for(let i=0;i<16;i++){
   const a=i*Math.PI/8,r=hospital.door.r+Math.sin(a)*ring,c=hospital.door.c+Math.cos(a)*ring;
   if(!isRoad(c*worldScale,r*worldScale))continue;
   for(const angle of [0,Math.PI/2,Math.PI,-Math.PI/2]){
    if(!isRoad((c+Math.cos(angle)*.65)*worldScale,(r+Math.sin(angle)*.65)*worldScale)||!isRoad((c-Math.cos(angle)*.65)*worldScale,(r-Math.sin(angle)*.65)*worldScale))continue;
    candidates.push({r,c,angle,d:ring});
   }
  }
  candidates.sort((a,b)=>a.d-b.d);
  return {hospital,carId,candidates,index:0,goals:[],goalKeys:new Set(),heap:null,seen:new Map(),expanded:0};
 }
 function advance(job,deadline){
  const {hospital,carId}=job;
  while(job.index<job.candidates.length&&clock()<deadline){
   const bay=job.candidates[job.index++];
   if(vehicleQuery({carId,from:bay,to:bay,roadsOnly:true,halfLength:1.04,halfWidth:.5})?.clear!==true)continue;
   const side=Math.sign((hospital.door.r-bay.r)*Math.cos(bay.angle)-(hospital.door.c-bay.c)*Math.sin(bay.angle))||1;
   const access={r:bay.r+Math.cos(bay.angle)*.72*side,c:bay.c-Math.sin(bay.angle)*.72*side},key=access.r.toFixed(3)+'|'+access.c.toFixed(3);
   if(job.goalKeys.has(key)||!clearPoint(access.r,access.c,carId))continue;
   job.goals.push({bay,access});job.goalKeys.add(key);
  }
  if(job.index<job.candidates.length)return null;
  if(!job.goals.length||!clearPoint(hospital.door.r,hospital.door.c,carId)){job.failed=true;return null;}
  if(!job.heap){const first={...hospital.door,ir:0,ic:0,g:0,parent:null};first.f=heuristic(first,job.goals);job.heap=[];push(job.heap,first);job.seen.set('0|0',0);}
  // One resumable reverse search serves all bays, rather than one expensive
  // independent pathfinder per candidate. Every edge sweeps a .18-tile body.
  while((job.current||job.heap.length)&&clock()<deadline&&job.expanded<12000){
   if(!job.current){job.current=pop(job.heap);job.expanded++;job.goalIndex=0;job.neighborIndex=0;}
   const current=job.current;
   while(job.goalIndex<job.goals.length){
    if(clock()>=deadline)return null;
    const goal=job.goals[job.goalIndex++];
    if(Math.hypot(current.r-goal.access.r,current.c-goal.access.c)>.36||!clearSegment(current,goal.access,carId))continue;
    const footRoute=[goal.access];for(let p=current;p;p=p.parent)footRoute.push({r:p.r,c:p.c});
    return {hospitalId:hospital.hospitalId,door:hospital.door,bay:{r:goal.bay.r,c:goal.bay.c,angle:goal.bay.angle},access:goal.access,footRoute};
   }
   const neighbors=[[1,0],[-1,0],[0,1],[0,-1]];
   while(job.neighborIndex<neighbors.length){
    if(clock()>=deadline)return null;
    const [dr,dc]=neighbors[job.neighborIndex++],ir=current.ir+dr,ic=current.ic+dc,key=ir+'|'+ic,g=current.g+spacing;
    if((job.seen.get(key)??Infinity)<=g||Math.hypot(ir*spacing,ic*spacing)>10)continue;
    const next={r:hospital.door.r+ir*spacing,c:hospital.door.c+ic*spacing,ir,ic,g,parent:current};
    if(!clearSegment(current,next,carId))continue;
    job.seen.set(key,g);next.f=g+heuristic(next,job.goals);push(job.heap,next);
   }
   job.current=null;
  }
  if((!job.current&&!job.heap.length)||job.expanded>=12000)job.failed=true;return null;
 }
 function query(request={}){
  const hospitals=getHospitals();if(!hospitals?.length)return null;
  const ordered=[...hospitals].sort((a,b)=>Math.hypot(a.door.r-(request.from?.r||0),a.door.c-(request.from?.c||0))-Math.hypot(b.door.r-(request.from?.r||0),b.door.c-(request.from?.c||0)));
  for(const hospital of ordered){
   const id=hospital.hospitalId,cached=cache.get(id);if(cached)return cached;
   let job=jobs.get(id);if(job?.retryAt>clock())continue;
   const budget=Math.max(0,2-budgetSpent);if(!budget)return null;
   const start=clock();if(!job){job=makeJob(hospital,request.carId);jobs.set(id,job);}
   const result=advance(job,start+budget);budgetSpent+=clock()-start;
   if(result){cache.set(id,result);jobs.delete(id);return result;}
   if(job.failed){jobs.set(id,{retryAt:clock()+5000,reason:job.goals.length?'foot-route-blocked':'no-clear-roadside-access',expanded:job.expanded,goals:job.goals.length});continue;}return null;
  }return null;
 }
 return {query,beginFrame(){budgetSpent=0;for(const [id,job]of jobs)if(job.retryAt&&job.retryAt<=clock())jobs.delete(id);},invalidate(){cache.clear();jobs.clear();},diagnostics:()=>[...jobs].map(([id,j])=>({id,index:j.index,expanded:j.expanded,goals:Array.isArray(j.goals)?j.goals.length:j.goals,reason:j.reason}))};
}
