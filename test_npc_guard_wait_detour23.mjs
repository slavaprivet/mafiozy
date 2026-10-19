import assert from 'node:assert/strict';
import fs from 'node:fs';
import vm from 'node:vm';
import {registerHooks} from 'node:module';
import {gunzipSync} from 'node:zlib';
import {performance} from 'node:perf_hooks';
import {beginGuardWaitDetour23 as begin,stepGuardWaitDetour23 as step} from './npc_guard_wait_detour23_candidate.mjs';
let contractCases=0;
function unitContext(){
 const site={siteId:'native-site:fixture',instanceId:'fixture',ownerFactionId:'owner',revision:1,manifestRevision:'v1',loaded:true,approach:{r:0,c:0}};
 const actor={id:'guard',siteId:site.siteId,ownerFactionId:site.ownerFactionId,generation:1,alive:true,r:0,c:0};
 return {actor,site,timeMs:0,now:()=>0,admitted:true,budgetMs:2,bodyClear:()=>true,exterior:()=>true,sweepClear:()=>false,occupied:[],reservations:[]};
}
function until(job,ctx,status){let result;for(let i=0;i<150;i++){result=step(job,ctx);if(result.status===status)return result;assert(['pending','waiting','move'].includes(result.status),'unexpected '+JSON.stringify(result));}assert.fail('finite '+status);}
{
 const ctx=unitContext(),job=begin(ctx.actor,ctx.site,0,0,0);until(job,ctx,'waiting');const count=job.geometryQueries;
 for(const time of [1,500,1499]){ctx.timeMs=time;assert.equal(step(job,ctx).status,'waiting');assert.equal(job.geometryQueries,count,'unchanged waiting is query-free');}
 ctx.timeMs=1500;ctx.sweepClear=()=>true;const result=until(job,ctx,'move');assert.equal(result.leg,'post');assert(result.reservation);contractCases++;
 ctx.timeMs=result.reservation.expiresAt;const expired=step(job,ctx);assert.equal(expired.reason,'reservation-expired');assert.equal(expired.release,result.reservation.key);assert.equal(job.reservation,null);contractCases++;
}
for(const mutate of [c=>c.site.revision++,c=>c.site.ownerFactionId='enemy',c=>c.site.manifestRevision='v2',c=>c.actor.generation++,c=>c.actor.combat=true,c=>c.actor.alive=false,c=>c.actor.vehicle=true,c=>c.cancelled=true]){
 const ctx=unitContext(),job=begin(ctx.actor,ctx.site,0,0,0);until(job,ctx,'waiting');const count=job.geometryQueries;mutate(ctx);
 assert.equal(step(job,ctx).status,'cancelled');assert.equal(job.geometryQueries,count);contractCases++;
}
for(const mode of ['expires','cancelled','old-revision','physical-body-remains']){
 const ctx=unitContext(),target={r:0,c:3.2};ctx.sweepClear=(from,to)=>Math.hypot(to.r-target.r,to.c-target.c)<1e-7;
 const lease={key:'other:1',actorId:'other',siteId:ctx.site.siteId,revision:1,ownerFactionId:'owner',target,expiresAt:1000};ctx.reservations=[lease];
 const job=begin(ctx.actor,ctx.site,0,0,0);until(job,ctx,'waiting');const count=job.geometryQueries;
 if(mode==='cancelled'){lease.cancelled=true;lease.expiresAt=9000;}
 if(mode==='old-revision'){lease.revision=0;lease.expiresAt=9000;}
 if(mode==='physical-body-remains')ctx.bodyClear=p=>Math.hypot(p.r-target.r,p.c-target.c)>.36;
 ctx.timeMs=500;assert.equal(step(job,ctx).status,'waiting');assert.equal(job.geometryQueries,count);
 ctx.timeMs=1500;
 if(mode==='physical-body-remains')assert.equal(until(job,ctx,'blocked').status,'blocked','lease expiry never erases a real body');
 else assert.equal(until(job,ctx,'move').leg,'post');contractCases++;
}
for(const mode of ['owner','cancel','false-arrival','conflict','movement-blocked']){
 const ctx=unitContext();ctx.sweepClear=()=>true;const job=begin(ctx.actor,ctx.site,0,0,0),move=until(job,ctx,'move');
 if(mode==='owner')ctx.site.revision++;
 if(mode==='cancel')ctx.cancelled=true;
 if(mode==='false-arrival')ctx.movementStatus='arrived';
 if(mode==='conflict')ctx.occupied=[{id:'other',...move.target}];
 if(mode==='movement-blocked')ctx.movementStatus='blocked';
 const result=step(job,ctx);assert(['cancelled','blocked'].includes(result.status));assert.equal(result.release,move.reservation.key);assert.equal(job.reservation,null);contractCases++;
}
{
 const ctx=unitContext();ctx.admitted=false;const job=begin(ctx.actor,ctx.site,0,0,0);
 assert.equal(step(job,ctx).status,'pending');assert.equal(job.geometryQueries,0);ctx.timeMs=30000;assert.equal(step(job,ctx).reason,'job-expired');contractCases++;
}
const fixtureUrl=new URL('./assets/maps/city_rebuild_v1/test_civilian_native_fixture.mjs',import.meta.url);
const hook=registerHooks({load(url,c,next){const result=next(url,c);return url===fixtureUrl.href?{...result,source:String(result.source).replace('new GLTFLoader().parseAsync','new GLTFLoader().register(()=>({name:"cpu-no-textures",loadTexture:()=>Promise.resolve(null)})).parseAsync')}:result;}});
const {createCivilianNativeFixture,sourceFunction}=await import(fixtureUrl.href);hook.deregister();
const snapshot=JSON.parse(gunzipSync(fs.readFileSync('assets/maps/city_rebuild_v1/test_fixtures/native_static_collision19.json.gz')));
const inputs=JSON.parse(fs.readFileSync('assets/maps/city_rebuild_v1/test_fixtures/native_guard_crowded23.json','utf8')).cases;
assert.equal(inputs.length,6);
const rows=[],diagnostics=[];
for(const assetId of ['hospital','print_shop']){
  const f=await createCivilianNativeFixture({assetId,snapshot}),b=f.box;
  for(const name of ['_inEmpireRecruitmentYard','_empireBossPassable','_empireTargetFootprintPassable23'])vm.runInContext(sourceFunction(f.source,name),b);
  for(const input of inputs.filter(i=>i.assetId===assetId)){
    assert.equal(input.instanceId,f.item.id);
    const approach=f.entry.approachPoint();assert(Math.hypot(approach.z/f.M-input.approach.r,approach.x/f.M-input.approach.c)<1e-8);
    const site={siteId:'native-site:'+f.item.id,instanceId:f.item.id,ownerFactionId:'fixture-owner',revision:1,manifestRevision:'static19',loaded:true,approach:input.approach};
    const actor={id:'guard-'+input.slot,...input.from,siteId:site.siteId,ownerFactionId:site.ownerFactionId,generation:input.patrolStep,alive:true,walkPhase:0};
    const occupants=input.occupied.map(p=>({...p})),scratch=new f.THREE.Vector3();
    const bodyClear=p=>b._empireTargetFootprintPassable23(p.r,p.c)===true&&occupants.every(other=>Math.hypot(p.r-other.r,p.c-other.c)>.36);
    const exterior=p=>[[0,0],[.18,.18],[.18,-.18],[-.18,.18],[-.18,-.18]].every(([dr,dc])=>{
      const x=(p.c+dc)*f.M,z=(p.r+dr)*f.M;scratch.set(x,f.floor(x,z),z);return f.entry.containsInterior(scratch)!==true;
    });
    const sweepClear=(from,to)=>f.pedestrian.query({mode:'sweep',from,to,radius:.18})?.blocked===false&&occupants.every(other=>{
      const dr=to.r-from.r,dc=to.c-from.c,len=dr*dr+dc*dc,t=len?Math.max(0,Math.min(1,((other.r-from.r)*dr+(other.c-from.c)*dc)/len)):0;
      return Math.hypot(other.r-from.r-t*dr,other.c-from.c-t*dc)>.36;
    });
    const job=begin(actor,site,input.slot,input.patrolStep,f.now),started=f.now;
    // Connectivity of the fixed entrance uses full STATIC building/body/water
    // geometry. Actual movement still includes every stationary guard body.
    const siteBodyClear=p=>b._empireTargetFootprintPassable23(p.r,p.c)===true;
    const siteSweepClear=(from,to)=>f.pedestrian.query({mode:'sweep',from,to,radius:.18})?.blocked===false;
    const ctx={actor,site,occupied:occupants,reservations:[],admitted:true,budgetMs:2,now:()=>performance.now(),bodyClear,exterior,sweepClear,siteBodyClear,siteSweepClear};
    let result,installed=null,unsafe=0,interior=0,movementSteps=0,frames=0,waitFrames=0,maxSlice=0,maxQueries=0,cpuMs=0;
    const legs=[];
    do{
      ctx.timeMs=f.now;const at=performance.now(),before=job.geometryQueries;result=step(job,ctx);
      const elapsed=performance.now()-at;maxSlice=Math.max(maxSlice,elapsed);cpuMs+=elapsed;maxQueries=Math.max(maxQueries,job.geometryQueries-before);
      assert(job.geometryQueries-before<=96);assert(job.geometryQueries<=4096);
      if(result.status==='move'){
        const key=result.leg+':'+result.target.r+','+result.target.c;
        if(installed!==key){b._setNpcRoute(actor,result.path,'empire_holding_guard');installed=key;legs.push({leg:result.leg,from:{r:actor.r,c:actor.c},target:result.target});}
        const from={r:actor.r,c:actor.c};f.nextFrame(1/7);ctx.movementStatus=b._npcAdvanceRoute(actor,1/7,1.18,b._empireBossPassable);
        assert(Math.hypot(actor.r-from.r,actor.c-from.c)<=1.18/7+1e-8,'no teleport');
        if(!sweepClear(from,actor)||!bodyClear(actor))unsafe++;
        if(!exterior(actor))interior++;movementSteps++;
      }else{
        ctx.movementStatus=null;f.nextFrame();if(result.status==='waiting')waitFrames++;
      }
      assert(++frames<1000,'finite job');
    }while(['move','pending','waiting'].includes(result.status));
    rows.push({assetId,slot:input.slot,patrolStep:input.patrolStep,status:result.status,reason:result.reason,remaining:job.finalTarget?Math.hypot(actor.r-job.finalTarget.r,actor.c-job.finalTarget.c):null,queries:job.geometryQueries,maxQueries,cpuMs,maxSlice,elapsedMs:f.now-started,waitFrames,movementSteps,unsafe,interior,legs});
    if(process.argv.includes('--diagnose')&&result.status==='blocked'){
      // Offline diagnostic only, deliberately outside the runtime candidate
      // budget and its timing totals. Never publish this as a scheduler result.
      let checks=0;const cap=40000;
      function edge(a,z,staticOnly=false){
        if(++checks>cap)return false;
        if(!(staticOnly?siteSweepClear:sweepClear)(a,z))return false;
        const count=Math.max(1,Math.ceil(Math.hypot(z.r-a.r,z.c-a.c)/.14));
        for(let i=0;i<=count;i++){
          if(++checks>cap)return false;const t=i/count,p={r:a.r+(z.r-a.r)*t,c:a.c+(z.c-a.c)*t};
          if(!(staticOnly?siteBodyClear:bodyClear)(p)||!exterior(p))return false;
        }return true;
      }
      const goals=[];
      for(const radius of [3.2+(input.slot%2)*.65,2,1.1])for(let angleIndex=0;angleIndex<12;angleIndex++){
        const angle=input.slot*2.3999632297+input.patrolStep*Math.PI*.5+angleIndex*Math.PI/6;
        const target={r:site.approach.r+Math.sin(angle)*radius,c:site.approach.c+Math.cos(angle)*radius};
        if(Math.hypot(actor.r-target.r,actor.c-target.c)>=.9&&bodyClear(target)&&exterior(target)&&!occupants.some(p=>Math.hypot(p.r-target.r,p.c-target.c)<.65)&&edge(site.approach,target,true))goals.push(target);
      }
      const bends=[];for(let dr=-10;dr<=10;dr++)for(let dc=-10;dc<=10;dc++)if(Math.hypot(dr,dc)>=2)bends.push({r:actor.r+dr*.25,c:actor.c+dc*.25,d:Math.hypot(dr,dc)});
      bends.sort((a,b)=>a.d-b.d);let found=null,clearBends=0;
      for(const bend of bends){
        if(checks>=cap)break;if(!edge(actor,bend))continue;clearBends++;
        for(const target of goals)if(edge(bend,target)){found={bend:{r:bend.r,c:bend.c},target};break;}
        if(found)break;
      }
      diagnostics.push({assetId,slot:input.slot,patrolStep:input.patrolStep,checks,capReached:checks>=cap,goals:goals.length,clearBends,found,limitation:'Offline grid candidates only; no source physical arrival claim.'});
    }
    assert.equal(unsafe,0);assert.equal(interior,0);assert(waitFrames>0,'wait before detour');
    if(result.status==='arrived'){assert(legs.length===2,'two source single legs, no corner cutting');assert(rows.at(-1).remaining<.35);assert(result.release,'final arrival releases reservation');}
  }
}
const summary={contractCases,requests:rows.length,arrived:rows.filter(r=>r.status==='arrived').length,blocked:rows.filter(r=>r.status==='blocked').length,cancelled:rows.filter(r=>r.status==='cancelled').length,unsafe:rows.reduce((s,r)=>s+r.unsafe,0),interior:rows.reduce((s,r)=>s+r.interior,0),cpuTotalMs:rows.reduce((s,r)=>s+r.cpuMs,0),maxSliceMs:Math.max(...rows.map(r=>r.maxSlice))};
fs.writeFileSync('outputs/npc_guard_wait_detour23_candidate.json',JSON.stringify({summary,rows,limits:'Six deterministic crowded fixture cases, two actual GLBs. Existing source single-leg movement unmodified. Static other guards; no live city/FPS/authority writes.'},null,2)+'\n');
if(diagnostics.length)fs.writeFileSync('outputs/npc_guard_crowded23_diagnosis.json',JSON.stringify(diagnostics,null,2)+'\n');
console.log(JSON.stringify(diagnostics.length?{summary,diagnostics}:{summary,rows:rows.map(({legs,...row})=>row)},null,2));
assert.equal(summary.arrived,4,'four known safe detours physically finish');assert.equal(summary.blocked,2,'two unresolved crowded layouts remain explicit failures');
