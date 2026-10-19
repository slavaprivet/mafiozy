// Isolated orchestration only. No world/authority writes and no teleport.
import {beginExteriorGuardPost23 as beginPost,stepExteriorGuardPost23 as stepPost} from './npc_exterior_guard_post23_candidate.mjs';
const point=p=>({r:p.r,c:p.c});
const distance=(a,b)=>Math.hypot(a.r-b.r,a.c-b.c);
const finite=p=>Number.isFinite(p?.r)&&Number.isFinite(p?.c);
const WAIT_MS=1500,JOB_MS=30000,LEASE_MS=12000;
export function beginGuardWaitDetour23(actor,site,slot,patrolStep,timeMs){
  const direct=beginPost(actor,site,slot,patrolStep);
  if(!direct||!Number.isFinite(timeMs))return null;
  return {binding:direct,stage:'direct',direct,startedAt:timeMs,lastTime:timeMs,deadline:timeMs+JOB_MS,
    geometryQueries:0,retried:false,bendIndex:0,reservation:null,status:'pending'};
}
function bindingValid(job,actor,site){
  const b=job.binding;
  return actor?.id===b.actorId&&actor.ownerFactionId===b.ownerFactionId&&actor.siteId===b.siteId&&actor.generation===b.generation&&
    actor.alive===true&&!actor.combat&&!actor.vehicle&&!actor.interior&&finite(actor)&&
    site?.siteId===b.siteId&&site.instanceId===b.instanceId&&site.ownerFactionId===b.ownerFactionId&&
    site.revision===b.revision&&site.manifestRevision===b.manifestRevision&&site.loaded===true&&finite(site.approach)&&distance(site.approach,b.approach)<.001;
}
function beginEdge(from,to){return {from:point(from),to:point(to),stage:'sweep',sample:0,samples:Math.max(1,Math.ceil(distance(from,to)/.14))};}
function edgeStep(edge,ctx){
  const end=ctx.now()+Math.min(2,ctx.budgetMs);let units=0;
  while(units<96&&ctx.now()<end){
    if(edge.stage==='sweep'){units++;if(ctx.sweepClear(edge.from,edge.to)!==true)return 'blocked';edge.stage='body';continue;}
    if(edge.stage==='body'){
      const t=edge.sample/edge.samples;edge.point={r:edge.from.r+(edge.to.r-edge.from.r)*t,c:edge.from.c+(edge.to.c-edge.from.c)*t};
      units++;if(ctx.bodyClear(edge.point)!==true)return 'blocked';edge.stage='exterior';continue;
    }
    if(edge.stage==='exterior'){
      units++;if(ctx.exterior(edge.point)!==true)return 'blocked';
      if(++edge.sample<=edge.samples){edge.stage='body';continue;}edge.stage='final-sweep';continue;
    }
    units++;return ctx.sweepClear(edge.from,edge.to)===true?'ready':'blocked';
  }
  return 'pending';
}
export function stepGuardWaitDetour23(job,ctx){
  if(!job)return {status:'blocked',reason:'invalid-binding'};
  const finish=(status,reason)=>{
    const release=job.reservation?.key;job.reservation=null;job.status=status;job.reason=reason;
    return {status,reason,...(release?{release}: {})};
  };
  if(!bindingValid(job,ctx.actor,ctx.site))return finish('cancelled','owner-or-context-changed');
  if(!Number.isFinite(ctx.timeMs)||ctx.timeMs<job.lastTime)return finish('cancelled','invalid-clock');
  job.lastTime=ctx.timeMs;
  if(job.status!=='pending')return {status:job.status,reason:job.reason};
  if(ctx.cancelled===true)return finish('cancelled','order-cancelled');
  if(ctx.timeMs>=job.deadline)return finish('blocked','job-expired');
  if(job.reservation&&ctx.timeMs>=job.reservation.expiresAt)return finish('cancelled','reservation-expired');
  if(!Array.isArray(ctx.reservations||[])||(ctx.reservations||[]).length>64||!Array.isArray(ctx.occupied||[])||(ctx.occupied||[]).length>64)return finish('blocked','occupancy-budget-exceeded');
  const b=job.binding;
  const occupied=[...(ctx.occupied||[])];
  for(const lease of ctx.reservations||[]){
    if(lease.cancelled===true||lease.siteId!==b.siteId||lease.revision!==b.revision||lease.ownerFactionId!==b.ownerFactionId||!(lease.expiresAt>ctx.timeMs))continue;
    if(!finite(lease.target)||typeof lease.actorId!=='string')return finish('blocked','invalid-reservation');
    occupied.push({id:lease.actorId,...lease.target});
  }
  if(occupied.length>64)return finish('blocked','occupancy-budget-exceeded');
  const taken=p=>occupied.some(other=>other.id!==b.actorId&&finite(other)&&distance(p,other)<.65);
  if(job.reservation&&taken(job.reservation.target))return finish('cancelled','reservation-conflict');
  const moving=job.stage==='moving-bend'||job.stage==='moving-post';
  if(!moving&&distance(ctx.actor,job.expectedFrom||b.from)>.001)return finish('cancelled','actor-moved');
  const leg=()=>({status:'move',leg:job.stage==='moving-bend'?'staging':'post',target:point(job.legTarget),path:[point(job.legTarget)],reservation:{...job.reservation,target:point(job.reservation.target)}});
  if(moving){
    if(ctx.movementStatus==='blocked')return finish('blocked','movement-blocked');
    if(ctx.movementStatus!=='arrived')return leg();
    if(distance(ctx.actor,job.legTarget)>=.35)return finish('blocked','false-leg-arrival');
    if(job.stage==='moving-post')return finish('arrived','physical-post-arrival');
    // Existing source stops its single leg <=.34 cells before the waypoint.
    // Revalidate the second leg from that REAL position; never snap to the bend.
    job.expectedFrom=point(ctx.actor);job.edge=beginEdge(ctx.actor,job.finalTarget);job.stage='final-edge';
    return {status:'pending',phase:'validate-second-leg'};
  }
  if(job.stage==='waiting'){
    if(ctx.timeMs<job.waitUntil)return {status:'waiting',until:job.waitUntil};
    job.retried=true;job.direct=beginPost(ctx.actor,ctx.site,b.slot,b.step);job.stage='direct';
  }
  if(ctx.admitted!==true||!(ctx.budgetMs>0))return {status:'pending',phase:job.stage};
  if(job.geometryQueries>=4096)return finish('blocked','query-budget-exhausted');
  const work={...ctx,occupied};
  for(const key of ['bodyClear','exterior','sweepClear','siteBodyClear','siteSweepClear'])if(typeof ctx[key]==='function')work[key]=(...args)=>{
    if(job.geometryQueries>=4096)throw new Error('query-budget-exhausted');job.geometryQueries++;return ctx[key](...args);
  };
  const publish=(target,staging)=>{
    if(taken(target))return finish('blocked','post-reserved');
    job.finalTarget=point(target);job.reservation={key:`${b.actorId}:${b.generation}:${b.siteId}:${b.slot}:${b.step}`,actorId:b.actorId,
      siteId:b.siteId,revision:b.revision,ownerFactionId:b.ownerFactionId,expiresAt:ctx.timeMs+LEASE_MS,target:point(target)};
    job.legTarget=point(staging||target);job.stage=staging?'moving-bend':'moving-post';return leg();
  };
  try{
    if(job.stage==='direct'){
      const result=stepPost(job.direct,{...work,siteBodyClear:undefined,siteSweepClear:undefined});
      if(result.status==='ready')return publish(result.target);
      if(result.status==='pending')return {status:'pending',phase:'direct'};
      if(result.status==='cancelled')return finish('cancelled',result.reason);
      if(result.reason!=='no-connected-exterior-post')return finish('blocked',result.reason);
      if(!job.retried){job.stage='waiting';job.waitUntil=ctx.timeMs+WAIT_MS;return {status:'waiting',until:job.waitUntil};}
      job.stage='choose-bend';return {status:'pending',phase:job.stage};
    }
    if(job.stage==='choose-bend'){
      if(job.bendIndex>=12)return finish('blocked','no-safe-two-leg-post');
      const index=job.bendIndex++;
      if(index<8){const angle=b.slot*2.3999632297+index*Math.PI/4;job.bend={r:ctx.actor.r+Math.sin(angle)*1.2,c:ctx.actor.c+Math.cos(angle)*1.2};}
      else{
        // Four lateral probes relative to the known entrance, instead of four
        // arbitrary distant compass points. Still the same 12-candidate budget.
        const dr=b.approach.r-ctx.actor.r,dc=b.approach.c-ctx.actor.c,length=Math.hypot(dr,dc)||1;
        const side=index%2?1:-1,offset=index<10?1.25:2.2;
        job.bend={r:ctx.actor.r+.16*dr/length-side*offset*dc/length,c:ctx.actor.c+.16*dc/length+side*offset*dr/length};
      }
      job.edge=beginEdge(ctx.actor,job.bend);job.stage='bend-edge';return {status:'pending',phase:job.stage};
    }
    if(job.stage==='bend-edge'){
      const result=edgeStep(job.edge,work);
      if(result==='pending')return {status:'pending',phase:job.stage};
      if(result==='blocked'){job.stage='choose-bend';return {status:'pending',phase:job.stage};}
      job.post=beginPost({...ctx.actor,...job.bend},ctx.site,b.slot,b.step);job.stage='bend-post';return {status:'pending',phase:job.stage};
    }
    if(job.stage==='bend-post'){
      const result=stepPost(job.post,{...work,actor:{...ctx.actor,...job.bend},avoidPoint:b.from});
      if(result.status==='pending')return {status:'pending',phase:job.stage};
      if(result.status!=='ready'){job.stage='choose-bend';return {status:'pending',phase:job.stage};}
      if(distance(result.target,b.from)<.9){job.stage='choose-bend';return {status:'pending',phase:job.stage};}
      return publish(result.target,job.bend);
    }
    if(job.stage==='final-edge'){
      const result=edgeStep(job.edge,work);
      if(result==='pending')return {status:'pending',phase:job.stage};
      if(result==='blocked')return finish('blocked','second-leg-blocked');
      job.legTarget=point(job.finalTarget);job.stage='moving-post';return leg();
    }
  }catch(_){return finish('blocked',job.geometryQueries>=4096?'query-budget-exhausted':'geometry-unavailable');}
  return finish('blocked','invalid-stage');
}
