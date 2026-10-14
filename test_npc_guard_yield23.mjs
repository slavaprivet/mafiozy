import assert from 'node:assert/strict';
import fs from 'node:fs';
import vm from 'node:vm';
import {registerHooks} from 'node:module';
import {gunzipSync} from 'node:zlib';
import {performance} from 'node:perf_hooks';
import {beginGuardYield23 as begin,stepGuardYield23 as step} from './npc_guard_yield23_candidate.mjs';
let contracts=0;
function context(){const site={siteId:'native-site:hospital',instanceId:'hospital',ownerFactionId:'owner',revision:1,manifestRevision:'v1',approach:{r:0,c:3},loaded:true},base={siteId:site.siteId,ownerFactionId:'owner',generation:1,alive:true};return{site,waiter:{...base,id:'a',r:0,c:0},yielder:{...base,id:'b',r:0,c:1.5},target:{r:0,c:3},timeMs:0,now:()=>0,budgetMs:2,admitted:true,occupied:[],leases:[],bodyClear:()=>true,exterior:()=>true,sweepClear:()=>true,movementStatus:{}};}
const start=c=>begin(c.waiter,c.yielder,c.site,c.target,'command1',c.timeMs);
function until(job,c,status){for(let i=0;i<200;i++){const before=job.queries,r=step(job,c);assert(job.queries-before<=64);assert(job.queries<=2048);if(r.status===status)return r;if(r.status==='waiting')c.timeMs=r.until;else assert.equal(r.status,'pending',JSON.stringify(r));}assert.fail('finite '+status);}
function claimed(c){const j=start(c),r=until(j,c,'reserve');c.leases.push(r.reservation);const move=until(j,c,'move');assert.equal(move.role,'yield');return{j,move};}
{
 const c=context(),j=start(c);for(const t of [0,300,999]){c.timeMs=t;assert.equal(step(j,c).status,'waiting');assert.equal(j.queries,0);}contracts++;
 c.timeMs=1000;const reserve=until(j,c,'reserve'),queries=j.queries;for(let i=0;i<10;i++){assert.equal(step(j,c).status,'reserve');assert.equal(j.queries,queries);}assert.equal(reserve.reservation.actorIds.length,2);contracts++;
 c.leases.push(reserve.reservation);const move=until(j,c,'move');Object.assign(c.yielder,move.target);c.movementStatus.b='arrived';assert.equal(step(j,c).phase,'pass-proof');const pass=until(j,c,'move');assert.equal(pass.actorId,'a');Object.assign(c.waiter,pass.target);c.movementStatus.a='arrived';const done=step(j,c);assert.equal(done.status,'arrived');assert.equal(done.release,reserve.reservation.key);assert.equal(step(j,c).release,undefined);contracts++;
}
for(const mutate of [c=>c.site.revision++,c=>c.site.ownerFactionId='enemy',c=>c.site.manifestRevision='changed',c=>c.waiter.generation++,c=>c.yielder.generation++,c=>c.waiter.combat=true,c=>c.yielder.vehicle=true,c=>c.yielder.alive=false,c=>c.waiter.interior=true,c=>c.cancelled=true,c=>c.timeMs=-1]){
 const c=context(),{j}=claimed(c);mutate(c);const r=step(j,c);assert.equal(r.status,'cancelled',JSON.stringify(r));assert(r.release);assert.equal(r.stopActors.length,2);contracts++;
}
for(const why of ['expired','lost','blocked','false-arrival','waiting-moved','body-blocked','callback-throw']){
 const c=context(),{j}=claimed(c);if(why==='expired')c.timeMs=j.lease.expiresAt;if(why==='lost')c.leases=[];if(why==='blocked')c.movementStatus.b='blocked';if(why==='false-arrival')c.movementStatus.b='arrived';if(why==='waiting-moved')c.waiter.r+=.1;if(why==='body-blocked')c.bodyClear=()=>false;if(why==='callback-throw')c.bodyClear=()=>{throw Error('unavailable')};const r=step(j,c);assert(['blocked','cancelled'].includes(r.status));assert(r.release);contracts++;
}
{
 const c=context(),j=start(c),r=until(j,c,'reserve');c.leases=[{...r.reservation,key:'competitor'}];const count=j.queries;assert.equal(step(j,c).status,'waiting');assert.equal(j.queries,count);c.timeMs+=500;assert.equal(step(j,c).reason,'lease-busy');assert.equal(j.queries,count);contracts++;
}
{
 const c=context(),j=start(c),r=until(j,c,'reserve');c.reservationResult='rejected';assert.equal(step(j,c).status,'waiting');c.timeMs+=500;c.reservationResult=null;const again=step(j,c);assert.equal(again.status,'reserve');c.leases.push(again.reservation);assert.equal(until(j,c,'move').role,'yield');contracts++;
}
{
 // Host contract: commit both actor locks atomically, never acquire one and
 // wait for another. Two requests can publish intents, only one may move.
 const c=context(),j=start(c),other=begin(c.waiter,c.yielder,c.site,c.target,'command2',0),a=until(j,c,'reserve'),b=until(other,c,'reserve');
 const registry=[],commit=lease=>{if(registry.some(x=>x.actorIds.some(id=>lease.actorIds.includes(id))))return false;registry.push(lease);return true;};assert(commit(a.reservation));assert.equal(commit(b.reservation),false);assert.equal(registry.length,1);c.leases=registry;assert.equal(until(j,c,'move').role,'yield');assert.equal(step(other,c).status,'waiting');contracts++;
}
{
 const c=context(),j=start(c);c.occupied=[{id:'physical-guard',r:0,c:2.5}];c.leases=[{key:'expired',siteId:c.site.siteId,revision:1,ownerFactionId:'owner',expiresAt:0,actorIds:['physical-guard','x'],targets:[{actorId:'physical-guard',r:0,c:2.5},{actorId:'x',r:10,c:10}]}];const r=until(j,c,'blocked');assert.equal(r.reason,'no-safe-yield');assert.equal(j.candidateIndex,12);contracts++;
}
{
 const c=context(),j=start(c);c.admitted=false;c.timeMs=1000;for(let i=0;i<10;i++)assert.equal(step(j,c).status,'pending');assert.equal(j.queries,0);c.timeMs=20000;assert.equal(step(j,c).reason,'job-expired');contracts++;
}
{
 const c=context(),j=start(c);c.bodyClear=()=>false;const r=until(j,c,'blocked');const q=j.queries;for(let i=0;i<30;i++)assert.equal(step(j,c).reason,r.reason);assert.equal(j.queries,q,'unchanged terminal jobs never retry');contracts++;
}
const fixtureUrl=new URL('./assets/maps/city_rebuild_v1/test_civilian_native_fixture.mjs',import.meta.url);
const hook=registerHooks({load(url,c,next){const r=next(url,c);return url===fixtureUrl.href?{...r,source:String(r.source).replace('new GLTFLoader().parseAsync','new GLTFLoader().register(()=>({name:"cpu-no-textures",loadTexture:()=>Promise.resolve(null)})).parseAsync')}:r;}});
const {createCivilianNativeFixture,sourceFunction}=await import(fixtureUrl.href);hook.deregister();
const snapshot=JSON.parse(gunzipSync(fs.readFileSync('assets/maps/city_rebuild_v1/test_fixtures/native_static_collision19.json.gz'))),input=JSON.parse(fs.readFileSync('assets/maps/city_rebuild_v1/test_fixtures/native_guard_crowded23.json','utf8')).cases.find(i=>i.assetId==='hospital'&&i.slot===1&&i.patrolStep===1);
const rows=[];
for(const dt of [1/15,1/7,1/5,1/3]){
 const f=await createCivilianNativeFixture({assetId:'hospital',snapshot}),b=f.box;for(const name of ['_inEmpireRecruitmentYard','_empireBossPassable','_empireTargetFootprintPassable23'])vm.runInContext(sourceFunction(f.source,name),b);
 const site={siteId:'native-site:'+f.item.id,instanceId:f.item.id,ownerFactionId:'owner',revision:1,manifestRevision:'static19',approach:input.approach,loaded:true},base={siteId:site.siteId,ownerFactionId:'owner',generation:1,alive:true,walkPhase:0},waiter={...base,id:'waiting',...input.from},yielder={...base,...input.occupied[1]},target={r:8.307940814693398,c:164.33091853653954},scratch=new f.THREE.Vector3();
 const bodyClear=p=>b._empireTargetFootprintPassable23(p.r,p.c)===true;
 const exterior=p=>[[0,0],[.18,.18],[.18,-.18],[-.18,.18],[-.18,-.18]].every(([dr,dc])=>{const x=(p.c+dc)*f.M,z=(p.r+dr)*f.M;scratch.set(x,f.floor(x,z),z);return !f.entry.containsInterior(scratch);});
 const sweepClear=(a,z)=>f.pedestrian.query({mode:'sweep',from:a,to:z,radius:.18})?.blocked===false;
 const c={site,waiter,yielder,timeMs:f.now,now:()=>performance.now(),budgetMs:2,admitted:true,occupied:[input.occupied[0]],leases:[],bodyClear,exterior,sweepClear,movementStatus:{}},j=begin(waiter,yielder,site,target,'actual'+dt,f.now);let result,installed=null,frames=0,unsafe=0,steps=0,maxSliceMs=0,cpuMs=0,maxCalls=0;const routes=[];
 do{
  c.timeMs=f.now;const at=performance.now(),before=j.queries;result=step(j,c);const elapsed=performance.now()-at;cpuMs+=elapsed;maxSliceMs=Math.max(maxSliceMs,elapsed);maxCalls=Math.max(maxCalls,j.queries-before);assert(j.queries-before<=64&&j.queries<=2048);
  if(result.status==='reserve'){assert.equal(c.leases.length,0);c.leases.push(result.reservation);}
  if(result.status==='move'){
   const who=result.actorId===waiter.id?waiter:yielder,key=result.actorId+':'+result.target.r+','+result.target.c;
   if(installed!==key){b._setNpcRoute(who,result.path,'empire_holding_guard');installed=key;routes.push({role:result.role,from:{r:who.r,c:who.c},target:result.target});}
   const from={r:who.r,c:who.c};f.nextFrame(dt);c.movementStatus[who.id]=b._npcAdvanceRoute(who,dt,1.18,b._empireBossPassable);assert(Math.hypot(who.r-from.r,who.c-from.c)<=1.18*dt+1e-8,'no teleport');
   const others=[input.occupied[0],who===waiter?yielder:waiter],dynamic=others.every(o=>{const dr=who.r-from.r,dc=who.c-from.c,len=dr*dr+dc*dc,t=len?Math.max(0,Math.min(1,((o.r-from.r)*dr+(o.c-from.c)*dc)/len)):0;return Math.hypot(o.r-from.r-t*dr,o.c-from.c-t*dc)>.36;});
   if(!bodyClear(who)||!exterior(who)||!sweepClear(from,who)||!dynamic)unsafe++;steps++;
  }else f.nextFrame(1/60);
  if(result.release)c.leases=c.leases.filter(l=>l.key!==result.release);
  assert(++frames<1200);
 }while(['waiting','pending','reserve','move'].includes(result.status));
 const row={hz:1/dt,status:result.status,reason:result.reason,remaining:Math.hypot(waiter.r-target.r,waiter.c-target.c),candidateCount:j.candidateIndex,queries:j.queries,maxCalls,cpuMs,maxSliceMs,steps,unsafe,routes};rows.push(row);assert.equal(row.status,'arrived',JSON.stringify(row));assert(row.remaining<.35);assert.equal(unsafe,0);assert.equal(c.leases.length,0);assert.equal(routes.length,2);
}
const report={contracts,rows,limits:'Isolated helper, 4 actual hospital static fixtures. Atomic two-actor host lease commit simulated; no runtime wiring, moving-crowd or city FPS acceptance.'};fs.writeFileSync('outputs/npc_guard_yield23_candidate.json',JSON.stringify(report,null,2));console.log(JSON.stringify(report,null,2));
