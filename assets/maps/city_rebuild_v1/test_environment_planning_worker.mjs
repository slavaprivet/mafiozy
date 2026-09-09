import assert from 'node:assert/strict';
import fs from 'node:fs';
import {Worker as NodeWorker} from 'node:worker_threads';
import {createLandscapePlan} from './landscape_plan.mjs';
import {createExplorationRailwayPlan} from './exploration_railway_plan.mjs';
import {buildExplorationDecorPlan} from './exploration_decor_worker_core.mjs';
import {explorationKeepouts} from './exploration_scene_support.mjs';
import {planEnvironmentGrass} from './environment_grass_plan.mjs';
import {createCityRoadDressingPlan} from './city_road_dressing_plan.mjs';
import {createCityParkingPlan,replanCityParkingWalks} from './city_parking_plan.mjs';
import {buildEnvironmentVisualPlans} from './environment_planning_worker_core.mjs';
import {planEnvironmentVisualsAsync,ENVIRONMENT_PLANNING_TIMEOUT_MS} from './environment_planning_worker_client.mjs';

let tests=0;async function test(name,fn){await fn();tests++;console.log('PASS',name);}
const read=n=>JSON.parse(fs.readFileSync(new URL(n,import.meta.url),'utf8'));
const topology=read('./topology_for_placement.json'),instances=[...read('./buildings_placement.v1.json').instances,...read('./decor_placement.v1.json').instances],keepouts=explorationKeepouts(instances),landscape=createLandscapePlan(),railPlan=createExplorationRailwayPlan({landscape,topology}),decorPlan=buildExplorationDecorPlan({topology,instances,keepouts}),input={topology,instances,keepouts,decorPlan},before=JSON.stringify(input);
const roadKeepouts=[...keepouts,...explorationKeepouts([{collision:{worldBodies:decorPlan.colliders||[]}}])];
let parkingPlan=createCityParkingPlan({topology,instances,keepouts:roadKeepouts,railPlan});
const {isRoad,paintSafe,safeSign,...roadPlan}=createCityRoadDressingPlan({topology,landscape,railPlan,keepouts:[...roadKeepouts,...parkingPlan.keepouts],accessKeepouts:parkingPlan.accessKeepouts,instances});
parkingPlan=replanCityParkingWalks(parkingPlan,{topology,instances,keepouts:roadKeepouts,railPlan,extraBodies:[...roadPlan.colliders,...decorPlan.colliders]});
const grassPlan=planEnvironmentGrass({topology,landscape,railPlan,keepouts:[...keepouts,...parkingPlan.keepouts],decorPlan}),expected={grassPlan,roadPlan,parkingPlan};
await test('pure worker core equals the current main-thread plans and does not mutate source',()=>{
  const actual=buildEnvironmentVisualPlans(input);assert.deepEqual(actual,expected);assert.equal(JSON.stringify(input),before);assert.deepEqual(structuredClone(actual),actual);assert.ok(!('isRoad' in actual.roadPlan));assert.ok(!('paintSafe' in actual.roadPlan));assert.ok(!('safeSign' in actual.roadPlan));
});

const originalWorker=globalThis.Worker;let lastWorker;
class BrowserNodeWorker {
  constructor(url,options){
    this.terminated=0;this.url=url;this.options=options;lastWorker=this;
    const bootstrap=`import {parentPort} from 'node:worker_threads';globalThis.self={postMessage:data=>parentPort.postMessage(data)};await import(${JSON.stringify(String(url))});parentPort.on('message',data=>self.onmessage({data}));`;
    this.worker=new NodeWorker(new URL('data:text/javascript,'+encodeURIComponent(bootstrap)),{type:'module'});
    this.worker.on('message',data=>this.onmessage?.({data}));this.worker.on('error',error=>this.onerror?.({error,message:error.message}));
  }
  postMessage(data){this.worker.postMessage(data);}
  terminate(){this.terminated++;return this.worker.terminate();}
}
let realResult;
try{
  globalThis.Worker=BrowserNodeWorker;
  await test('real worker-thread executes the actual browser worker entry and clone-safe response',async()=>{
    realResult=await planEnvironmentVisualsAsync(input);assert.deepEqual({grassPlan:realResult.grassPlan,roadPlan:realResult.roadPlan,parkingPlan:realResult.parkingPlan},expected);assert.equal(realResult.mode,'worker');assert.ok(realResult.workerMs>0);assert.equal(lastWorker.terminated,1);assert.equal(lastWorker.options.type,'module');assert.ok(String(lastWorker.url).endsWith('/environment_planning_worker.mjs'));
  });
  await test('real worker errors reject and terminate instead of doing hidden main-thread work',async()=>{
    await assert.rejects(planEnvironmentVisualsAsync({topology:null}),/roadMask|topology|grid/i);assert.equal(lastWorker.terminated,1);
  });

  let behavior=()=>{},created=0;
  class MockWorker {
    constructor(){this.terminated=0;this.posted=[];created++;lastWorker=this;}
    postMessage(data){this.posted.push(data);behavior(this,data);}
    terminate(){this.terminated++;}
  }
  globalThis.Worker=MockWorker;
  const success=(worker,id)=>worker.onmessage?.({data:{id,grassPlan:{tufts:[]},roadPlan:{markings:[]},parkingPlan:{lots:[]},workerMs:7}});
  await test('mismatched reply ignored, matching success terminates exactly once',async()=>{
    behavior=(w,d)=>{w.onmessage({data:{id:d.id+100,grassPlan:{tufts:[]},roadPlan:{markings:[]}}});assert.equal(w.terminated,0);queueMicrotask(()=>success(w,d.id));};
    const result=await planEnvironmentVisualsAsync({});assert.equal(result.workerMs,7);assert.equal(lastWorker.terminated,1);assert.equal(lastWorker.onmessage,null);
  });
  await test('only plain instance records and relevant decor colliders are cloned to worker',async()=>{
    behavior=(w,d)=>queueMicrotask(()=>success(w,d.id));const raw={id:'building',assetId:'hospital',role:'public',entry:{anchorRC:{r:1,c:2}},label:'unused display metadata',clearance:{minC:1,maxC:2,minR:1,maxR:2},clearancePolygonCR:[[1,1],[2,1],[2,2]],collision:{worldBodies:[{polygonCR:[[1,1],[2,1],[2,2]]}]}};const renderObject={userData:{instance:raw},render(){throw Error('must never clone renderer')}};
    await planEnvironmentVisualsAsync({instances:[renderObject],decorPlan:{colliders:[],unusedFunction(){}}});assert.deepEqual(lastWorker.posted[0].input.instances,[{id:raw.id,assetId:raw.assetId,role:raw.role,entry:raw.entry,clearance:raw.clearance,clearancePolygonCR:raw.clearancePolygonCR,collision:raw.collision}]);assert.deepEqual(explorationKeepouts(lastWorker.posted[0].input.instances),explorationKeepouts([raw]),'minimization preserves authored clearance polygon identity, so walking routes do not misclassify it as a new solid obstacle');assert.deepEqual(lastWorker.posted[0].input.decorPlan,{colliders:[]});
  });
  await test('worker error, response decoding error and malformed result reject with cleanup',async()=>{
    for(const kind of['error','messageerror','bad-data','reported-error']){
      behavior=(w,d)=>queueMicrotask(()=>{if(kind==='error')w.onerror({message:'worker crashed'});else if(kind==='messageerror')w.onmessageerror({});else if(kind==='bad-data')w.onmessage({data:{id:d.id,grassPlan:{}}});else w.onmessage({data:{id:d.id,error:{name:'RangeError',message:'bad geometry'}}});});
      await assert.rejects(planEnvironmentVisualsAsync({}));assert.equal(lastWorker.terminated,1);assert.equal(lastWorker.onerror,null);
    }
  });
  await test('postMessage clone error terminates and rejects immediately',async()=>{
    behavior=()=>{throw new DOMException('not cloneable','DataCloneError')};await assert.rejects(planEnvironmentVisualsAsync({}),e=>e.name==='DataCloneError');assert.equal(lastWorker.terminated,1);
  });
  await test('timeout bounded to 20 seconds, shortened test timer terminates idle worker',async()=>{
    assert.equal(ENVIRONMENT_PLANNING_TIMEOUT_MS,20000);behavior=()=>{};await assert.rejects(planEnvironmentVisualsAsync({},{timeoutMs:5}),e=>e.name==='TimeoutError');assert.equal(lastWorker.terminated,1);
    const count=created;await assert.rejects(planEnvironmentVisualsAsync({},{timeoutMs:20001}),RangeError);assert.equal(created,count);
  });
  await test('cancellation before launch creates no worker, cancellation while running terminates',async()=>{
    behavior=()=>{};const already=new AbortController();already.abort();const count=created;await assert.rejects(planEnvironmentVisualsAsync({},{signal:already.signal}),e=>e.name==='AbortError');assert.equal(created,count);
    const controller=new AbortController(),pending=planEnvironmentVisualsAsync({},{signal:controller.signal});controller.abort();await assert.rejects(pending,e=>e.name==='AbortError');assert.equal(lastWorker.terminated,1);
  });
  await test('late abort after success cannot terminate twice or alter result',async()=>{
    behavior=(w,d)=>queueMicrotask(()=>success(w,d.id));const controller=new AbortController(),result=await planEnvironmentVisualsAsync({},{signal:controller.signal});controller.abort();assert.equal(result.mode,'worker');assert.equal(lastWorker.terminated,1);
  });
  await test('unavailable or startup-failed workers reject without fallback',async()=>{
    globalThis.Worker=undefined;await assert.rejects(planEnvironmentVisualsAsync(input),e=>e.name==='NotSupportedError');globalThis.Worker=class{constructor(){throw Error('module worker denied')}};await assert.rejects(planEnvironmentVisualsAsync(input),/module worker denied/);
  });
}finally{globalThis.Worker=originalWorker;}
console.log(JSON.stringify({tests,status:'PASS',grassTufts:grassPlan.tufts.length,roadMarkings:roadPlan.markings.length,signals:roadPlan.signals.length,workerMs:Math.round(realResult.workerMs),equivalent:true}));
