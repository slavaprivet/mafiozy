// Isolated candidate only. Trusted root adapter supplies the existing site and
// its current owner/revision/approach. This module never grants ownership.
const finitePoint=p=>Number.isFinite(p?.r)&&Number.isFinite(p?.c);
const id=value=>typeof value==='string'&&value.trim().length>0;
const copy=p=>({r:p.r,c:p.c});
const distance=(a,b)=>Math.hypot(a.r-b.r,a.c-b.c);
export function beginExteriorGuardPost23(actor,site,slot,step){
  if(!id(actor?.id)||!id(actor.ownerFactionId)||!id(site?.siteId)||!id(site.instanceId)||
    site.ownerFactionId!==actor.ownerFactionId||actor.siteId!==site.siteId||site.loaded!==true||
    !Number.isSafeInteger(site.revision)||site.revision<0||!id(site.manifestRevision)||
    !Number.isSafeInteger(actor.generation)||actor.generation<0||
    !finitePoint(actor)||!finitePoint(site.approach)||!Number.isSafeInteger(slot)||slot<0||slot>2||
    !Number.isSafeInteger(step)||step<0)return null;
  return {actorId:actor.id,ownerFactionId:actor.ownerFactionId,siteId:site.siteId,
    instanceId:site.instanceId,revision:site.revision,manifestRevision:site.manifestRevision,
    generation:actor.generation,from:copy(actor),approach:copy(site.approach),slot,step,
    status:'pending',attempt:0,stage:'start-body',sample:0,edge:0,queries:0};
}
export function stepExteriorGuardPost23(job,ctx){
  if(!job)return {status:'blocked',reason:'invalid-binding'};
  const {actor,site}=ctx;
  const cancel=reason=>{job.status='cancelled';job.reason=reason;delete job.target;return {status:job.status,reason};};
  if(!actor||!site||actor.id!==job.actorId||actor.ownerFactionId!==job.ownerFactionId||actor.siteId!==job.siteId||
    site.siteId!==job.siteId||site.instanceId!==job.instanceId||site.ownerFactionId!==job.ownerFactionId||
    site.revision!==job.revision||site.manifestRevision!==job.manifestRevision||site.loaded!==true||
    actor.generation!==job.generation||!finitePoint(actor)||!finitePoint(site.approach)||
    distance(actor,job.from)>.001||distance(site.approach,job.approach)>.001||
    actor.alive!==true||actor.combat||actor.vehicle||actor.interior)return cancel('ownership-or-context-changed');
  if(job.status!=='pending')return job.status==='ready'?{status:'ready',target:copy(job.target),path:[copy(job.target)]}:{status:job.status,reason:job.reason};
  const blocked=reason=>{job.status='blocked';job.reason=reason;return {status:'blocked',reason};};
  if(ctx.occupied!==undefined&&(!Array.isArray(ctx.occupied)||ctx.occupied.length>64))return blocked('occupancy-budget-exceeded');
  if(distance(job.from,job.approach)>8)return blocked('rejoin-approach-required');
  // Invocation must already own a slice of the shared route budget. No extra
  // search admission or unbounded synchronous callback is hidden here.
  if(ctx.admitted!==true||!(ctx.budgetMs>0))return {status:'pending'};
  const started=ctx.now(),deadline=started+Math.min(2,ctx.budgetMs);let units=0;
  const available=()=>units<96&&ctx.now()<deadline;
  const query=(fn,...args)=>{units++;job.queries++;return fn(...args);};
  const occupied=point=>(ctx.occupied||[]).some(other=>other.id!==job.actorId&&finitePoint(other)&&distance(point,other)<.65);
  const next=()=>{job.attempt++;job.stage='choose';job.edge=0;job.sample=0;delete job.candidate;};
  try{
    while(available()){
      if(job.queries>=4096)return blocked('query-budget-exhausted');
      if(job.stage==='start-body'){if(query(ctx.bodyClear,job.from)!==true)return blocked('invalid-start');job.stage='start-exterior';continue;}
      if(job.stage==='start-exterior'){if(query(ctx.exterior,job.from)!==true)return blocked('start-not-exterior');job.stage='approach-body';continue;}
      if(job.stage==='approach-body'){if(query(ctx.siteBodyClear||ctx.bodyClear,job.approach)!==true)return blocked('invalid-approach');job.stage='approach-exterior';continue;}
      if(job.stage==='approach-exterior'){if(query(ctx.exterior,job.approach)!==true)return blocked('approach-not-exterior');job.stage='choose';continue;}
      if(job.stage==='choose'){
        if(job.attempt>=36)return blocked('no-connected-exterior-post');
        const angle=job.slot*2.3999632297+job.step*Math.PI*.5+(job.attempt%12)*Math.PI/6;
        const radius=[3.2+(job.slot%2)*.65,2,1.1][Math.floor(job.attempt/12)];
        job.candidate={r:job.approach.r+Math.sin(angle)*radius,c:job.approach.c+Math.cos(angle)*radius};
        if(distance(job.from,job.candidate)<.9||(finitePoint(ctx.avoidPoint)&&distance(ctx.avoidPoint,job.candidate)<.9)||occupied(job.candidate)){next();continue;}
        job.stage='candidate-body';continue;
      }
      if(job.stage==='candidate-body'){if(query(ctx.bodyClear,job.candidate)!==true){next();continue;}job.stage='candidate-exterior';continue;}
      if(job.stage==='candidate-exterior'){if(query(ctx.exterior,job.candidate)!==true){next();continue;}job.stage='edge-sweep';job.edge=0;continue;}
      const from=job.edge===0?job.from:job.approach;
      if(job.stage==='edge-sweep'){
        if(query(job.edge===1?(ctx.siteSweepClear||ctx.sweepClear):ctx.sweepClear,from,job.candidate)!==true){next();continue;}
        job.samples=Math.max(1,Math.ceil(distance(from,job.candidate)/.14));job.sample=0;job.stage='edge-body';continue;
      }
      if(job.stage==='edge-body'){
        const t=(job.sample+1)/job.samples;job.point={r:from.r+(job.candidate.r-from.r)*t,c:from.c+(job.candidate.c-from.c)*t};
        if(query(job.edge===1?(ctx.siteBodyClear||ctx.bodyClear):ctx.bodyClear,job.point)!==true){next();continue;}job.stage='edge-exterior';continue;
      }
      if(job.stage==='edge-exterior'){
        if(query(ctx.exterior,job.point)!==true){next();continue;}
        job.sample++;
        if(job.sample<job.samples){job.stage='edge-body';continue;}
        if(job.edge===0&&distance(job.from,job.approach)>.001){job.edge=1;job.stage='edge-sweep';continue;}
        job.stage='final-sweep';continue;
      }
      // The scene may change between slices. Recheck the complete static sweep
      // at publication; normal source movement must recheck every physical step.
      if(job.stage==='final-sweep'){
        if(query(ctx.sweepClear,job.from,job.candidate)!==true||occupied(job.candidate)){next();continue;}
        job.stage='final-body';continue;
      }
      if(job.stage==='final-body'){
        if(query(ctx.bodyClear,job.candidate)!==true){next();continue;}
        job.stage='final-exterior';continue;
      }
      if(job.stage==='final-exterior'){
        if(query(ctx.exterior,job.candidate)!==true||occupied(job.candidate)){next();continue;}
        job.target=copy(job.candidate);job.status='ready';
        return {status:'ready',target:copy(job.target),path:[copy(job.target)]};
      }
      return cancel('invalid-stage');
    }
  }catch(_){return cancel('geometry-unavailable');}
  return {status:'pending'};
}
