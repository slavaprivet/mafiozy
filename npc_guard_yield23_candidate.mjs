// Isolated candidate. The host owns actors, collision checks and atomic leases.
const point=p=>({r:p.r,c:p.c}),finite=p=>Number.isFinite(p?.r)&&Number.isFinite(p?.c);
const distance=(a,b)=>Math.hypot(a.r-b.r,a.c-b.c),id=s=>typeof s==='string'&&s.length>0;
const LIMIT=2048,SLICE=64,LEASE_MS=12000;
const actorValid=(a,s)=>id(a?.id)&&Number.isSafeInteger(a.generation)&&a.generation>=0&&a.alive===true&&!a.combat&&!a.vehicle&&!a.interior&&a.siteId===s.siteId&&a.ownerFactionId===s.ownerFactionId&&finite(a);
const bind=a=>({id:a.id,generation:a.generation,from:point(a)});
export function beginGuardYield23(waiter,yielder,site,target,orderId,timeMs){
 if(!site||site.loaded!==true||!id(site.siteId)||!id(site.instanceId)||!id(site.ownerFactionId)||!id(site.manifestRevision)||(!Number.isSafeInteger(site.revision)||site.revision<0)||!finite(site.approach)||!actorValid(waiter,site)||!actorValid(yielder,site)||waiter.id===yielder.id||!finite(target)||!id(orderId)||!Number.isFinite(timeMs)||distance(waiter,target)<.9||distance(waiter,target)>8||distance(waiter,yielder)>5)return null;
 return{waiter:bind(waiter),yielder:bind(yielder),site:{siteId:site.siteId,instanceId:site.instanceId,ownerFactionId:site.ownerFactionId,revision:site.revision,manifestRevision:site.manifestRevision,approach:point(site.approach)},target:point(target),orderId,started:timeMs,lastTime:timeMs,deadline:timeMs+20000,waitUntil:timeMs+1000,stage:'wait',status:'pending',queries:0,candidateIndex:0,claimAttempts:0,lease:null,claimed:false};
}
function pointSegment(p,a,b){const dr=b.r-a.r,dc=b.c-a.c,n=dr*dr+dc*dc,t=n?Math.max(0,Math.min(1,((p.r-a.r)*dr+(p.c-a.c)*dc)/n)):0;return Math.hypot(p.r-a.r-t*dr,p.c-a.c-t*dc);}
const edge=(from,to,mover,future=null)=>({from:point(from),to:point(to),mover,future,stage:'sweep',i:0,n:Math.max(1,Math.ceil(distance(from,to)/.12))});
const intersects=(a,b)=>a.some(x=>b.includes(x));
export function stepGuardYield23(job,ctx){
 if(!job)return{status:'blocked',reason:'invalid-request'};
 const finish=(status,reason)=>{const lease=job.lease;job.status=status;job.reason=reason;job.lease=null;return{status,reason,...(job.claimed?{stopActors:[job.waiter.id,job.yielder.id]}:{}),...(lease?{release:lease.key}:{})};};
 if(job.status!=='pending')return{status:job.status,reason:job.reason};
 const w=ctx.waiter,y=ctx.yielder,s=ctx.site,b=job.site,actors=[job.waiter.id,job.yielder.id];
 if(!s||Object.keys(b).some(k=>k!=='approach'&&s[k]!==b[k])||s.loaded!==true||!finite(s.approach)||distance(s.approach,b.approach)>.001||!actorValid(w,s)||!actorValid(y,s)||w.id!==job.waiter.id||y.id!==job.yielder.id||w.generation!==job.waiter.generation||y.generation!==job.yielder.generation)return finish('cancelled','binding-changed');
 if(ctx.cancelled)return finish('cancelled','order-cancelled');
 if(!Number.isFinite(ctx.timeMs)||ctx.timeMs<job.lastTime)return finish('cancelled','invalid-clock');job.lastTime=ctx.timeMs;
 if(ctx.timeMs>=job.deadline)return finish('blocked','job-expired');
 if(!Array.isArray(ctx.occupied)||ctx.occupied.length>64||!Array.isArray(ctx.leases)||ctx.leases.length>64||ctx.occupied.some(p=>!id(p.id)||!finite(p)))return finish('blocked','invalid-occupancy');
 if(job.lease&&ctx.timeMs>=job.lease.expiresAt)return finish('cancelled','lease-expired');
 const leases=ctx.leases.filter(l=>l.cancelled!==true&&l.expiresAt>ctx.timeMs&&l.siteId===b.siteId&&l.revision===b.revision&&l.ownerFactionId===b.ownerFactionId);
 if(leases.some(l=>!id(l.key)||!Array.isArray(l.actorIds)||l.actorIds.length!==2||l.actorIds.some(a=>!id(a))||!Array.isArray(l.targets)||l.targets.some(p=>!id(p.actorId)||!finite(p))))return finish('blocked','invalid-lease');
 const competing=leases.find(l=>l.key!==job.lease?.key&&(intersects(l.actorIds,actors)||l.targets.some(p=>distance(p,job.target)<.65||job.yieldTarget&&distance(p,job.yieldTarget)<.65)));
 if(job.claimed&&competing)return finish('cancelled','lease-conflict');
 const beforeMove=!['yield-move','pass-proof','pass-move'].includes(job.stage);
 if(beforeMove&&(distance(w,job.waiter.from)>.001||distance(y,job.yielder.from)>.001))return finish('cancelled','actor-moved-before-claim');
 if(job.stage==='yield-move'&&distance(w,job.waiter.from)>.001)return finish('cancelled','waiting-actor-moved');
 if(job.stage==='pass-proof'&&distance(w,job.waiter.from)>.001)return finish('cancelled','waiting-actor-moved');
 if(['pass-proof','pass-move'].includes(job.stage)&&distance(y,job.yieldStopped)>.001)return finish('cancelled','yielding-actor-moved');
 if(job.stage==='wait'||job.stage==='claim-backoff'){
  if(ctx.timeMs<job.waitUntil)return{status:'waiting',until:job.waitUntil};
  job.stage=job.stage==='wait'?'choose':'claim';
 }
 const leaseMatches=l=>l&&l.key===job.lease?.key&&l.expiresAt===job.lease.expiresAt&&l.actorIds.length===2&&actors.every(a=>l.actorIds.includes(a))&&l.targets.length===2&&job.lease.targets.every(p=>l.targets.some(t=>t.actorId===p.actorId&&distance(t,p)<1e-8));
 if(job.claimed&&!leases.some(leaseMatches))return finish('cancelled','lease-lost');
 if(job.stage==='claim'){
  if(leases.some(leaseMatches)&&!competing){job.claimed=true;job.stage='yield-recheck';job.edge=edge(y,job.yieldTarget,y.id);}
  else if(competing||ctx.reservationResult==='rejected'){
   if(++job.claimAttempts>=2)return finish('blocked','lease-busy');job.waitUntil=ctx.timeMs+500;job.stage='claim-backoff';return{status:'waiting',until:job.waitUntil};
  }else return{status:'reserve',reservation:{...job.lease,actorIds:[...job.lease.actorIds],targets:job.lease.targets.map(p=>({...p}))},priority:[job.started,w.id,y.id]};
 }
 // No motion is published until the all-or-nothing lease locks both actors.
 if(ctx.admitted!==true||!(ctx.budgetMs>0))return{status:'pending',holdActors:actors,phase:job.stage};
 if(typeof ctx.now!=='function'||typeof ctx.bodyClear!=='function'||typeof ctx.exterior!=='function'||typeof ctx.sweepClear!=='function')return finish('blocked','geometry-unavailable');
 const end=ctx.now()+Math.min(2,ctx.budgetMs);let used=0;
 const available=()=>used<SLICE&&job.queries<LIMIT&&ctx.now()<end;
 const query=(fn,...args)=>{used++;job.queries++;return fn(...args)===true;};
 const bodies=(mover,future)=>{
  const all=ctx.occupied.filter(p=>p.id!==mover&&p.id!==w.id&&p.id!==y.id);if(mover!==w.id)all.push(w);if(mover!==y.id)all.push(future||y);return all;
 };
 const clearDynamic=(a,z,mover,future)=>bodies(mover,future).every(p=>pointSegment(p,a,z)>.36)&&leases.filter(l=>l.key!==job.lease?.key).every(l=>l.targets.every(p=>pointSegment(p,a,z)>.36));
 function walkEdge(e){
  while(available()){
   if(e.stage==='sweep'){if(!clearDynamic(e.from,e.to,e.mover,e.future)||!query(ctx.sweepClear,e.from,e.to))return'blocked';e.stage='body';continue;}
   if(e.stage==='body'){const t=e.i/e.n;e.p={r:e.from.r+(e.to.r-e.from.r)*t,c:e.from.c+(e.to.c-e.from.c)*t};if(!query(ctx.bodyClear,e.p))return'blocked';e.stage='exterior';continue;}
   if(e.stage==='exterior'){if(!query(ctx.exterior,e.p))return'blocked';if(++e.i<=e.n){e.stage='body';continue;}e.stage='final';continue;}
   return clearDynamic(e.from,e.to,e.mover,e.future)&&query(ctx.sweepClear,e.from,e.to)?'ready':'blocked';
  }return'pending';
 }
 const move=(who,target,role)=>({status:'move',actorId:who.id,role,target:point(target),path:[point(target)],holdActors:actors.filter(a=>a!==who.id),leaseKey:job.lease.key});
 try{
  if(job.stage==='yield-move'||job.stage==='pass-move'){
   const yielding=job.stage==='yield-move',who=yielding?y:w,target=yielding?job.yieldTarget:job.target;
   // The host additionally checks every actual movement step, just as for all
   // source routes. The candidate never grants a collision exemption.
   if(!available())return{status:'pending',holdActors:actors};
   if(!query(ctx.bodyClear,who))return finish('blocked','body-obstructed');
   if(!available())return{status:'pending',holdActors:actors};
   if(!query(ctx.exterior,who)||!clearDynamic(who,who,who.id))return finish('blocked','body-obstructed');
   if(ctx.movementStatus?.[who.id]==='blocked')return finish('blocked','movement-blocked');
   if(ctx.movementStatus?.[who.id]!=='arrived')return move(who,target,yielding?'yield':'pass');
   if(distance(who,target)>=.35)return finish('blocked','false-arrival');
   if(!yielding)return finish('arrived','physical-post-arrival');
   job.yieldStopped=point(y);job.edge=edge(w,job.target,w.id);job.stage='pass-proof';return{status:'pending',holdActors:actors,phase:job.stage};
  }
  while(available()){
   if(job.stage==='choose'){
    if(job.candidateIndex>=12)return finish('blocked','no-safe-yield');const i=job.candidateIndex++,dr=job.target.r-w.r,dc=job.target.c-w.c,len=Math.hypot(dr,dc),side=((y.r-w.r)*(-dc)+(y.c-w.c)*dr)>=0?1:-1;
    const angle=[0,Math.PI/4,-Math.PI/4,Math.PI/2,-Math.PI/2,Math.PI][i%6],nr=-dc/len*side,nc=dr/len*side,radius=i<6?.8:1.1;
    job.yieldTarget={r:y.r+(nr*Math.cos(angle)-nc*Math.sin(angle))*radius,c:y.c+(nr*Math.sin(angle)+nc*Math.cos(angle))*radius};
    // Prove the waiting corridor even if the source stops .35 early. The
    // actual stop is rechecked after physical yielding, before installing it.
    const t=(radius-.35)/radius;job.earlyStop={r:y.r+(job.yieldTarget.r-y.r)*t,c:y.c+(job.yieldTarget.c-y.c)*t};
    if(((job.earlyStop.r-w.r)*(-dc)+(job.earlyStop.c-w.c)*dr)*((job.yieldTarget.r-w.r)*(-dc)+(job.yieldTarget.c-w.c)*dr)<=0||pointSegment(job.earlyStop,w,job.target)<=.38||pointSegment(job.yieldTarget,w,job.target)<=.38||distance(job.yieldTarget,job.target)<.65){continue;}
    job.edge=edge(y,job.yieldTarget,y.id);job.stage='yield-proof';
   }
   const result=walkEdge(job.edge);if(result==='pending')break;
   if(result==='blocked'){
    if(job.stage==='yield-recheck'||job.stage==='pass-proof')return finish('blocked','path-obstructed');job.stage='choose';continue;
   }
   if(job.stage==='yield-proof'){job.edge=edge(w,job.target,w.id,job.earlyStop);job.stage='future-pass-proof';continue;}
   if(job.stage==='future-pass-proof'){
    job.lease={key:`yield:${b.siteId}:${b.revision}:${job.orderId}:${w.id}:${w.generation}:${y.id}:${y.generation}`,siteId:b.siteId,revision:b.revision,ownerFactionId:b.ownerFactionId,actorIds:[...actors].sort(),targets:[{actorId:w.id,...job.target},{actorId:y.id,...job.yieldTarget}],expiresAt:ctx.timeMs+LEASE_MS};job.stage='claim';return{status:'reserve',reservation:{...job.lease,actorIds:[...job.lease.actorIds],targets:job.lease.targets.map(p=>({...p}))},priority:[job.started,w.id,y.id]};
   }
   if(job.stage==='yield-recheck'){job.stage='yield-move';return move(y,job.yieldTarget,'yield');}
   if(job.stage==='pass-proof'){job.stage='pass-move';return move(w,job.target,'pass');}
   return finish('blocked','invalid-stage');
  }
 }catch(_){return finish('blocked','geometry-unavailable');}
 if(job.queries>=LIMIT)return finish('blocked','query-budget-exhausted');
 return{status:'pending',holdActors:actors,phase:job.stage};
}
