import test from 'node:test';
import assert from 'node:assert/strict';
import {createLaneRouteJobs} from './city_lane_route_jobs.mjs';

function fixture(options={}){
 let now=0;const workers=[],timers=new Map();let nextTimer=0;
 const client=createLaneRouteJobs({...options,clock:()=>now,setTimer:(fn,ms)=>{timers.set(++nextTimer,{fn,at:now+ms});return nextTimer;},clearTimer:id=>timers.delete(id),createWorker:()=>{
  const w={messages:[],terminated:false,postMessage(m){this.messages.push(structuredClone(m));},terminate(){this.terminated=true;},emit(data){this.onmessage?.({data});}};workers.push(w);return w;
 }});
 const init=()=>{client.initialize({fixture:true});const w=workers.at(-1);w.emit({type:'initialized',generation:w.messages[0].generation});return w;};
 const ready=(w,result={status:'ready',points:[{r:1,c:2}],controls:[]},roadControls=[])=>{const m=w.messages.at(-1);w.emit({type:'result',generation:m.generation,token:m.token,result,roadControls});};
 return {client,workers,timers,init,ready,advance(ms,{fire=false}={}){now+=ms;if(fire)for(const [id,t]of [...timers])if(t.at<=now){timers.delete(id);t.fn();}}};
}
const request=(requestId='a',extra={})=>({mode:'lane-route',requestId,from:{r:1,c:2},to:{r:3,c:4},...extra});

test('initialization queues, repeated polls deduplicate and immutable completed geometry is reused',()=>{
 const f=fixture();f.client.initialize({});const w=f.workers[0];
 assert.equal(f.client.query(request()).phase,'queued');assert.equal(w.messages.length,1);
 w.emit({type:'initialized',generation:w.messages[0].generation});
 assert.equal(f.client.query(request()).phase,'planning');assert.equal(w.messages.length,2);
 const points=Array.from({length:5000},(_,c)=>({r:1,c}));f.ready(w,{status:'ready',points,controls:[]});
 const result=f.client.query(request());assert.equal(result.ready,true);assert.equal(result.points.length,5000);
 for(let i=0;i<100;i++)assert.equal(f.client.query(request()),result);
 assert.throws(()=>{result.points[0].r=90;},TypeError);points[0].r=80;assert.equal(result.points[0].r,1);assert.equal(w.messages.length,2);
 assert.equal(f.timers.size,0);
});

test('one worker job in flight; changed request cancels logically and stale result cannot win',()=>{
 const f=fixture(),w=f.init();const first=f.client.query(request());
 const changed=request('a',{to:{r:7,c:8}}),second=f.client.query(changed);assert.equal(second.phase,'queued');assert.notEqual(first.routeJob,second.routeJob);
 f.client.query(request('b'));assert.equal(w.messages.length,2);
 f.ready(w);assert.equal(w.messages.length,3);assert.equal(w.messages.at(-1).token,second.routeJob);
 w.emit({type:'result',generation:w.messages[0].generation,token:first.routeJob,result:{status:'ready',points:[]}});
 assert.equal(f.client.query(changed).status,'pending');f.ready(w);assert.equal(f.client.query(changed).status,'ready');assert.equal(w.messages.length,4);
 f.ready(w,{status:'blocked',reason:'no_route',points:[]});assert.equal(f.client.query(request('b')).reason,'no_route');
});

test('cancellation removes queued work but reserves active slot until worker reply',()=>{
 const f=fixture(),w=f.init();f.client.query(request());f.client.query(request('b'));f.client.query(request('c'));
 assert.equal(f.client.cancel('b').reason,'route_cancelled');f.client.cancel('a');assert.equal(w.messages.length,2);
 f.ready(w);assert.equal(w.messages.at(-1).request.requestId,'c');assert.equal(w.messages.length,3);
 f.ready(w);assert.equal(f.client.diagnostics().results,1);
});

test('generation invalidation terminates worker and ignores old replies and errors',()=>{
 const f=fixture(),old=f.init();const token=f.client.query(request()).routeJob;
 f.client.invalidate({newSnapshot:true});assert.equal(old.terminated,true);const w=f.workers[1];
 old.emit({type:'result',generation:old.messages[0].generation,token,result:{status:'ready',points:[]}});old.onerror();
 assert.equal(f.client.query(request()).phase,'queued');w.emit({type:'initialized',generation:w.messages[0].generation});f.ready(w);
 assert.equal(f.client.query(request()).status,'ready');assert.notEqual(f.client.query(request()).controls?.[0]?.routeJob,token);
 f.client.dispose();assert.equal(w.terminated,true);assert.equal(f.timers.size,0);assert.equal(f.client.query(request()).reason,'route_jobs_disposed');
});

test('worker error and elapsed init/job timeouts fail closed with no endless pending',()=>{
 for(const stage of ['init','job','error','messageerror']){
  const f=fixture({timeoutMs:30});f.client.initialize({});const w=f.workers[0];
  if(stage!=='init')w.emit({type:'initialized',generation:w.messages[0].generation});
  f.client.query(request());f.client.query(request('b'));
  if(stage==='error')w.onerror();else if(stage==='messageerror')w.onmessageerror();else f.advance(31,{fire:stage==='init'});
  assert.equal(f.client.query(request()).status,'blocked');assert.equal(f.client.query(request('b')).status,'blocked');
  assert.equal(w.terminated,true);assert.equal(f.client.diagnostics().pending,0);assert.equal(f.timers.size,0);
 }
});

test('bounded admission and completed eviction never evict a queued request',()=>{
 const f=fixture({maxPending:2,maxResults:1}),w=f.init();f.client.query(request());f.client.query(request('b'));
 assert.equal(f.client.query(request('c')).reason,'route_queue_full');f.ready(w);
 assert.equal(f.client.query(request('c')).phase,'queued');f.ready(w);f.ready(w);
 assert.equal(f.client.diagnostics().results,1);assert.equal(f.client.query(request('c')).status,'ready');
 assert.equal(f.client.query(request()).status,'pending');
});

test('canonical controls cannot be forged or mutated and expire with their cached route',()=>{
 const f=fixture({ttlMs:100}),w=f.init();f.client.query(request());
 const edge={id:'crossing:1',kind:'pedestrian_crossing',edgeId:'edge:1',crosswalkIds:['zebra:1'],rule:'pedestrian_priority'};
 const junction={approachId:'approach:1',turnId:'turn:1',rule:'signal'};
 f.ready(w,{status:'ready',points:[],controls:[edge,junction]},[edge]);const controls=f.client.query(request()).controls;
 edge.crosswalkIds.length=0;
 assert.equal(f.client.evaluateControl({...controls[0],crosswalkIds:[],rule:'go'},{occupiedCrosswalkIds:['zebra:1']}).allowed,false);
 assert.equal(f.client.evaluateControl({...controls[0],edgeId:'forged'},{}).allowed,false);
 assert.equal(f.client.evaluateControl({...controls[0],routeJob:'forged'},{}).reason,'route_expired');
 assert.equal(f.client.evaluateControl(controls[1],{}),null);
 assert.equal(f.client.evaluateControl({...controls[1],turnId:'forged'},{}).allowed,false);
 assert.throws(()=>controls[0].crosswalkIds.pop(),TypeError);
 f.advance(100);assert.equal(f.client.evaluateControl(controls[0],{}).reason,'route_expired');
});

test('canonical route segments require the active token, owner, geometry and forward direction',()=>{
 const f=fixture(),w=f.init(),route=request('surface',{carId:'surface-car'});f.client.query(route);
 f.ready(w,{status:'ready',points:[{r:7,c:5},{r:7,c:7},{r:9,c:7}],controls:[]});
 const result=f.client.query(route),proof={routeJob:result.routeJob,carId:'surface-car',from:{r:7,c:5.5},to:{r:7,c:6.5}};
 assert.equal(result.routeJob,w.messages[1].token);assert.equal(f.client.evaluateSegment(proof).allowed,true);
 assert.equal(f.client.evaluateSegment({...proof,routeJob:'never-issued'}).reason,'route_expired');
 assert.equal(f.client.evaluateSegment({...proof,carId:'other-car'}).reason,'route_owner_mismatch');
 assert.equal(f.client.evaluateSegment({...proof,from:{r:40,c:39},to:{r:40,c:41}}).reason,'unknown_route_segment');
 assert.equal(f.client.evaluateSegment({...proof,from:proof.to,to:proof.from}).reason,'unknown_route_segment');
 f.client.cancel('surface');assert.equal(f.client.evaluateSegment(proof).reason,'route_expired');
 const next=request('surface-2',{carId:'surface-car'});f.client.query(next);f.ready(w,{status:'ready',points:[{r:7,c:5},{r:7,c:7}],controls:[]});const old=f.client.query(next).routeJob;
 f.client.updateWorld([]);assert.equal(f.client.evaluateSegment({...proof,routeJob:old}).reason,'route_expired');
});

test('endpoint tolerance remains a world distance on long canonical segments',()=>{
 const f=fixture(),w=f.init(),route=request('long-segment',{carId:'surface-car'});f.client.query(route);
 f.ready(w,{status:'ready',points:[{r:0,c:0},{r:0,c:20}],controls:[]});const routeJob=f.client.query(route).routeJob;
 assert.equal(f.client.evaluateSegment({routeJob,carId:'surface-car',from:{r:0,c:19.9},to:{r:0,c:20.1},tolerance:.2}).allowed,true);
 assert.equal(f.client.evaluateSegment({routeJob,carId:'surface-car',from:{r:0,c:20},to:{r:0,c:22},tolerance:.2}).reason,'unknown_route_segment');
});

test('malformed results cannot leave a job stuck or allow an unknown control',()=>{
 const f=fixture(),w=f.init();f.client.query(request());f.ready(w,{status:'pending'});
 assert.equal(f.client.query(request()).reason,'route_worker_invalid_result');
 assert.equal(f.client.evaluateControl({routeJob:'1:1'},{}).allowed,false);
});

test('body-only world updates reuse the worker, expire old controls and reject old-epoch completion',()=>{
 const f=fixture(),w=f.init();f.client.query(request());
 f.ready(w,{status:'ready',points:[],controls:[{approachId:'a',turnId:'t'}]});
 const control=f.client.query(request()).controls[0];f.client.query(request('running'));
 const oldMessage=w.messages.at(-1),bodies=[{polygon:[{x:1,z:2},{x:3,z:4}]}];
 const update=f.client.updateWorld(bodies);assert.equal(f.workers.length,1);assert.equal(w.terminated,false);
 assert.deepEqual(w.messages.at(-1),{type:'world',generation:update.generation,bodies});
 assert.equal(f.client.evaluateControl(control).reason,'route_expired');assert.equal(f.client.query(request('new')).phase,'queued');
 const count=w.messages.length;
 w.emit({type:'result',generation:oldMessage.generation,token:oldMessage.token,result:{status:'ready',points:[]}});
 w.emit({type:'initialized',generation:oldMessage.generation});assert.equal(w.messages.length,count);
 w.emit({type:'initialized',generation:update.generation});assert.equal(w.messages.length,count+1);assert.equal(w.messages.at(-1).request.requestId,'new');
 f.ready(w);assert.equal(f.client.query(request('new')).status,'ready');
});

test('world update queued during initial setup ignores old initialized epoch',()=>{
 const f=fixture();f.client.initialize({});const w=f.workers[0],oldGeneration=w.messages[0].generation;
 const update=f.client.updateWorld([]);f.client.query(request());assert.equal(w.messages.length,2);
 w.emit({type:'initialized',generation:oldGeneration});assert.equal(w.messages.length,2);
 w.emit({type:'initialized',generation:update.generation});assert.equal(w.messages.length,3);f.ready(w);
 assert.equal(f.client.query(request()).status,'ready');
});

test('touch renews an active trip beyond total TTL but idle time still expires its controls',()=>{
 const f=fixture({ttlMs:100}),w=f.init();f.client.query(request());
 f.ready(w,{status:'ready',points:[{r:1,c:2}],controls:[{approachId:'a',turnId:'t'}]});
 const result=f.client.query(request()),control=result.controls[0];
 for(let i=0;i<20;i++){
  f.advance(90);const lease=f.client.touch('a');assert.equal(lease.status,'ready');assert.equal(lease.routeJob,control.routeJob);assert.equal('points' in lease,false);
 }
 assert.equal(f.client.query(request()),result);f.advance(100);
 assert.equal(f.client.touch('a').reason,'route_expired');assert.equal(f.client.evaluateControl(control).reason,'route_expired');
 assert.equal(w.messages.length,2);
});

test('polls and recognized controls renew leases, including waiting at an occupied crossing',()=>{
 const f=fixture({ttlMs:100}),w=f.init();f.client.query(request());
 const edge={id:'crossing:1',kind:'pedestrian_crossing',edgeId:'edge:1',crosswalkIds:['zebra:1']};
 f.ready(w,{status:'ready',points:[],controls:[edge,{approachId:'a',turnId:'t'}]},[edge]);
 const result=f.client.query(request());f.advance(90);assert.equal(f.client.query(request()),result);
 f.advance(90);assert.equal(f.client.evaluateControl(result.controls[0],{occupiedCrosswalkIds:['zebra:1']}).reason,'pedestrian_crossing');
 f.advance(90);assert.equal(f.client.evaluateControl(result.controls[1]),null);
 f.advance(90);assert.equal(f.client.touch('a').ready,true);
});

test('idle LRU eviction remains bounded and retains touched routes instead of oldest creation',()=>{
 const f=fixture({ttlMs:100,maxResults:2}),w=f.init();
 f.client.query(request('a'));f.ready(w);f.advance(10);f.client.query(request('b'));f.ready(w);
 f.advance(10);assert.equal(f.client.touch('a').ready,true);
 f.client.query(request('c'));f.ready(w);
 assert.equal(f.client.diagnostics().results,2);assert.equal(f.client.touch('b').reason,'route_expired');assert.equal(f.client.touch('a').ready,true);assert.equal(f.client.touch('c').ready,true);
});

test('forged controls, unknown requests and blocked results cannot extend a lease',()=>{
 const f=fixture({ttlMs:100}),w=f.init();f.client.query(request());
 f.ready(w,{status:'ready',points:[],controls:[{approachId:'a',turnId:'t'}]});const control=f.client.query(request()).controls[0];
 f.client.query(request('blocked'));f.ready(w,{status:'blocked',reason:'no_route',points:[]});
 f.advance(90);assert.equal(f.client.evaluateControl({...control,turnId:'forged'}).reason,'unknown_road_control');assert.equal(f.client.touch('missing').reason,'route_expired');
 assert.equal(f.client.touch('blocked').reason,'no_route');assert.equal(f.client.query(request('blocked')).reason,'no_route');
 f.advance(10);assert.equal(f.client.touch('a').reason,'route_expired');assert.equal(f.client.touch('blocked').reason,'route_expired');
});
