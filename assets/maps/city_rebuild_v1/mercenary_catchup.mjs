// Bounded safe recovery for the player's idle followers. All distances are metres.
// Geometry and authority remain with the source/Walk host; missing checks fail closed.
const finite=p=>p&&[p.x,p.z].every(Number.isFinite);
const distance=(a,b)=>Math.hypot(a.x-b.x,a.z-b.z);
const offsets=[[0,0],[-1,-1],[-1,0],[-1,1],[0,-1],[0,1],[1,-1],[1,0],[1,1]];

/** Shared with vehicle dismount/recovery callers; never falls back to origin. */
export function createMercenarySafePlacement({worldScale=4.1,ready=()=>false,queryPoint,bodyClear,groundHeight,isInsideBuilding,blocksVehicle}={}){
 const radius=.18*worldScale,height=1.9;
 function check(point,member){
  if(!finite(point)||ready()!==true||![queryPoint,bodyClear,groundHeight,isInsideBuilding,blocksVehicle].every(f=>typeof f==='function'))return {ok:false,reason:'resolver_unavailable'};
  if(bodyClear(point,member)!==true)return {ok:false,reason:'body_blocked'};
  let low=Infinity,high=-Infinity,ground;
  for(const[dx,dz]of offsets){
   const x=point.x+dx*radius,z=point.z+dz*radius,y=groundHeight(x,z),q=queryPoint({x,z});
   if(!Number.isFinite(y)||!q||q.blocked!==false||!Number.isFinite(q.depth))return {ok:false,reason:'unsupported_or_solid'};
   if(q.depth>.025)return {ok:false,reason:'water'};
   if(isInsideBuilding({x,y:y+.9,z})!==false)return {ok:false,reason:'building'};
   if(dx===0&&dz===0)ground=y;low=Math.min(low,y);high=Math.max(high,y);
  }
  if(high-low>.28)return {ok:false,reason:'uneven_ground'};
  // Circumscribed circle includes the entire square source body footprint.
  if(blocksVehicle({x:point.x,y:ground,z:point.z},{radius:radius*Math.SQRT2,height})!==false)return {ok:false,reason:'vehicle'};
  return {ok:true,point:{x:point.x,y:ground,z:point.z}};
 }
 return {check,radius,height};
}

export function mercenaryCatchupEligible(m){
 return !!m&&m.owned===true&&m.status==='active'&&m.hp>0&&!m.dead&&(m.order||'follow')==='follow'&&!m.action&&!m.queued&&!m.combat&&!m.carried&&!m.carrying&&!m.seated&&!m.vehicleChase&&!m.interior&&!m.safeExit&&!m.conversation&&finite(m.position);
}

/** Incremental shared drop search. Only caller-owned `state` is mutated. */
export function advanceMercenarySafeDrop(state,{origin,yaw=0,memberId,slot=0,occupied=[],validate,now,maxChecks=4}={}){
 const empty=(status,checks=0,refused=0)=>({status,point:null,checks,refused});
 if(!state||!finite(origin)||!Number.isFinite(now)||typeof validate!=='function')return empty('unavailable');
 if(!state.origin||state.memberId!==memberId||distance(state.origin,origin)>2||state.status==='ready')Object.assign(state,{origin:{...origin},yaw,memberId,slot,attempt:0,pending:null,retryAt:0,status:'pending'});
 if(state.status==='blocked'){
  if(now<state.retryAt)return empty('blocked');
  Object.assign(state,{origin:{...origin},yaw,attempt:0,pending:null,status:'pending'});
 }
 let checks=0,refused=0;const limit=Math.min(4,Math.max(0,maxChecks));
 while(checks<limit&&state.attempt<32){
  if(state.pending&&now-state.pending.at<60)break;
  let point;
  if(state.pending)point=state.pending.point;
  else{const ring=Math.floor(state.attempt/8),turn=(state.attempt%8+state.slot*2)%8,angle=state.yaw+Math.PI+turn*Math.PI/4+(ring%2)*Math.PI/8,radius=[3.6,5,6.4,8][ring];point={x:state.origin.x+Math.cos(angle)*radius,z:state.origin.z+Math.sin(angle)*radius};}
  const d=distance(point,origin);
  if(d<2.5||d>10||occupied.some(p=>p.id!==memberId&&finite(p)&&distance(p,point)<1.6)){state.attempt++;state.pending=null;continue;}
  checks++;const result=validate(point,memberId);
  if(!result?.ok||!finite(result.point)||!Number.isFinite(result.point.y)){refused++;state.attempt++;state.pending=null;continue;}
  if(!state.pending){state.pending={point:result.point,at:now};break;}
  if(Math.abs(result.point.y-state.pending.point.y)>.08){refused++;state.attempt++;state.pending=null;continue;}
  state.status='ready';state.point={...result.point};return {status:'ready',point:state.point,checks,refused};
 }
 if(state.attempt>=32){state.status='blocked';state.retryAt=now+2000;state.pending=null;}
 return empty(state.status,checks,refused);
}

export function createMercenaryCatchup({placement,farDistance=65,farDelayMs=6000,noProgressMs=10000,cooldownMs=20000,maxChecksPerUpdate=4}={}){
 const states=new Map(),stats={checks:0,refused:0,placed:0,waiting:0,maxChecksPerUpdate:0};let cursor=0,lastUpdate=null;
 const reset=(s,m,now)=>{s.progressAt=now;s.progressPoint={...m.position};s.farAt=null;s.search=null;s.nextTry=now;};
 const clear=()=>{states.clear();cursor=0;lastUpdate=null;};
 function update({now,hero,members=[],enabled=true,maxChecks=4}={}){
  if(!Number.isFinite(now))return {relocations:[],checks:0};
  const roster=members.filter(m=>m?.id!=null).slice().sort((a,b)=>String(a.id).localeCompare(String(b.id))),ids=new Set(roster.map(m=>m.id));
  for(const id of states.keys())if(!ids.has(id))states.delete(id);
  const interrupted=lastUpdate!==null&&(now<lastUpdate||now-lastUpdate>1000);lastUpdate=now;
  const canRun=enabled===true&&hero?.alive!==false&&!hero?.interior&&!hero?.inVehicle&&finite(hero?.position)&&typeof placement?.check==='function';
  const relocations=[],limit=Math.min(4,Math.max(0,maxChecksPerUpdate),Math.max(0,maxChecks));let checks=0;
  const occupied=roster.filter(m=>m.status!=='hospital'&&!m.seated&&finite(m.position)).map(m=>({id:m.id,x:m.position.x,z:m.position.z}));
  for(let offset=0;offset<roster.length;offset++){
   const index=(cursor+offset)%roster.length,m=roster[index];let state=states.get(m.id);
   if(!state){state={cooldownUntil:0,lastReason:'observing'};reset(state,m,now);states.set(m.id,state);}
   if(!canRun||interrupted||!mercenaryCatchupEligible(m)){reset(state,m,now);state.lastReason='ineligible';continue;}
   const d=distance(m.position,hero.position);
   if(distance(m.position,state.progressPoint)>=1.25){state.progressPoint={...m.position};state.progressAt=now;}
   if(d>farDistance){if(state.farAt===null)state.farAt=now;}else state.farAt=null;
   if(d<=12){state.progressAt=now;state.search=null;state.lastReason='near_leader';continue;}
   if(now<state.cooldownUntil){state.lastReason='cooldown';continue;}
   const far=state.farAt!==null&&now-state.farAt>=farDelayMs,stuck=now-state.progressAt>=noProgressMs;
   if(!far&&!stuck){state.lastReason='observing';continue;}
   if(!state.search)state.search={};
   const previousStatus=state.search.status,result=advanceMercenarySafeDrop(state.search,{origin:hero.position,yaw:Number(hero.angle)||0,memberId:m.id,slot:index,occupied,validate:point=>placement.check(point,m),now,maxChecks:limit-checks});
   checks+=result.checks;stats.checks+=result.checks;stats.refused+=result.refused;
   state.lastReason=result.status==='blocked'?'no_safe_point':'confirm_ground';if(result.status==='blocked'&&previousStatus!=='blocked')stats.waiting++;
   if(result.point){relocations.push({id:m.id,point:result.point,reason:far?'far':'stuck'});stats.placed++;state.cooldownUntil=now+cooldownMs;reset(state,{position:result.point},now);state.lastReason='placed';}
   if(relocations.length||checks>=limit)break;
  }
  if(roster.length)cursor=(cursor+1)%roster.length;stats.maxChecksPerUpdate=Math.max(stats.maxChecksPerUpdate,checks);
  return {relocations,checks};
 }
 return {update,clear,stats,inspect:id=>{const s=states.get(id);return s?{reason:s.lastReason,attempt:s.search?.attempt||0,pending:!!s.search?.pending,cooldownUntil:s.cooldownUntil,nextTry:s.search?.retryAt||0}:null;}};
}
