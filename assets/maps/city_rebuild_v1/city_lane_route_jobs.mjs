import {evaluateRoadEdgeControl} from './city_road_edge_controls.mjs';

const edgeKinds=new Set(['pedestrian_crossing','railway_crossing','road_end_turnaround','one_way_narrow_passage']);
const clone=value=>structuredClone(value);
function freeze(value){if(value&&typeof value==='object'&&!Object.isFrozen(value)){for(const child of Object.values(value))freeze(child);Object.freeze(value);}return value;}
function key(value){if(Array.isArray(value))return `[${value.map(key).join(',')}]`;if(value&&typeof value==='object')return `{${Object.keys(value).sort().filter(k=>value[k]!==undefined).map(k=>`${JSON.stringify(k)}:${key(value[k])}`).join(',')}}`;return JSON.stringify(value);}
const blocked=reason=>freeze({ready:false,status:'blocked',reason,points:[]});
const identity=c=>key({id:c?.id,kind:c?.kind,edgeId:c?.edgeId,approachId:c?.approachId,turnId:c?.turnId});

// All expensive path work stays in one persistent worker. Polls return the same
// immutable result; route geometry is never cloned again on the animation thread.
export function createLaneRouteJobs({
 createWorker=()=>new Worker(new URL('./city_lane_route_worker.mjs',import.meta.url),{type:'module'}),
 clock=()=>performance.now(),maxPending=16,maxResults=64,ttlMs=300000,timeoutMs=30000,
 setTimer=(fn,ms)=>setTimeout(fn,ms),clearTimer=id=>clearTimeout(id),
}={}){
 let worker=null,generation=0,sequence=0,initialized=false,disposed=false,failure=null,active=null,timer=null,deadline=Infinity;
 const jobs=new Map(),tokens=new Map(),completed=new Map(),queue=[];
 const limits={pending:Math.max(1,Math.floor(maxPending)),results:Math.max(1,Math.floor(maxResults))};
 function disarm(){if(timer!==null)clearTimer(timer);timer=null;deadline=Infinity;}
 function arm(){disarm();deadline=clock()+timeoutMs;timer=setTimer(()=>fail('route_worker_timeout'),timeoutMs);timer?.unref?.();}
 function erase(job){jobs.delete(job.id);tokens.delete(job.token);completed.delete(job.id);}
 function prune(){const now=clock();for(const [id,job]of completed){if(now-job.lastUsedAt<ttlMs&&completed.size<=limits.results)break;erase(job);}}
 function renew(job){if(job.phase==='done'&&job.result.status==='ready'){job.lastUsedAt=clock();completed.delete(job.id);completed.set(job.id,job);}}
 function finish(job,result,roadControls=[]){
  job.phase='done';job.completedAt=job.lastUsedAt=clock();job.canonical=new Map();job.identities=new Set();
  for(const c of roadControls||[])if(c?.id)job.canonical.set(c.id,freeze(clone(c)));
  const publicResult=clone(result);publicResult.ready=publicResult.status==='ready';
  publicResult.controls=(publicResult.controls||[]).map(c=>{job.identities.add(identity(c));return {...c,routeJob:job.token};});
  job.result=freeze(publicResult);completed.set(job.id,job);prune();
 }
 function fail(reason){
  disarm();initialized=false;failure=reason;worker?.terminate();worker=null;active=null;queue.length=0;
  for(const job of [...jobs.values()])if(job.phase!=='done')finish(job,blocked(reason));
 }
 function timedOut(){if(clock()>=deadline)fail('route_worker_timeout');}
 function dispatch(){
  if(!worker||!initialized||active||failure)return;
  while(queue.length){const job=queue.shift();if(jobs.get(job.id)!==job||job.phase!=='queued')continue;
   active=job;job.phase='planning';arm();
   try{worker.postMessage({type:'route',generation,token:job.token,request:job.request});}catch{fail('route_worker_error');}break;
  }
 }
 function stop(){disarm();worker?.terminate();worker=null;initialized=false;active=null;queue.length=0;jobs.clear();tokens.clear();completed.clear();}
 function initialize(snapshot){
  stop();generation++;disposed=false;failure=null;
  try{
   const owned=worker=createWorker();
   owned.onmessage=event=>{
    if(worker!==owned)return;
    const data=event.data;if(data?.generation!==generation)return;
    if(data.type==='initialized'){if(initialized)return;disarm();initialized=true;dispatch();return;}
    if(data.type==='error'){fail('route_worker_error');return;}
    if(data.type!=='result'||!active||data.token!==active.token)return;
    const job=active;disarm();active=null;
    if(jobs.get(job.id)===job&&job.phase==='planning'){
     try{if(!data.result||!['ready','blocked'].includes(data.result.status))throw Error('Invalid worker result');finish(job,data.result,data.roadControls);}catch{finish(job,blocked('route_worker_invalid_result'));}
    }
    dispatch();
   };
   owned.onerror=()=>{if(worker===owned)fail('route_worker_error');};
   owned.onmessageerror=()=>{if(worker===owned)fail('route_worker_error');};
   arm();owned.postMessage({type:'init',generation,snapshot});
  }catch{fail('route_worker_error');}
  return {generation,status:failure?'blocked':'pending'};
 }
 function cancel(requestId){
  const job=jobs.get(requestId);if(job){erase(job);job.phase='cancelled';const i=queue.indexOf(job);if(i>=0)queue.splice(i,1);}
  return blocked('route_cancelled');
 }
 function query(request){
  timedOut();prune();if(disposed)return blocked('route_jobs_disposed');if(failure)return blocked(failure);
  if(!worker)return blocked('route_worker_uninitialized');
  const id=request?.requestId;if(typeof id!=='string'||!id.length||request?.mode!=='lane-route')return blocked('invalid_route_request');
  let signature;try{signature=key(request);}catch{return blocked('invalid_route_request');}
  let job=jobs.get(id);
  if(job&&job.signature!==signature){cancel(id);job=null;}
  if(!job){
   let pending=0;for(const j of jobs.values())if(j.phase!=='done')pending++;
   if(pending>=limits.pending)return blocked('route_queue_full');
   try{job={id,signature,request:clone(request),token:`${generation}:${++sequence}`,phase:'queued'};}catch{return blocked('invalid_route_request');}
   jobs.set(id,job);tokens.set(job.token,job);queue.push(job);dispatch();
  }
  renew(job);return job.result||{ready:false,status:'pending',phase:job.phase,requestId:id,routeJob:job.token,points:[]};
 }
 function touch(requestId){
  timedOut();prune();const job=jobs.get(requestId);
  if(!job)return {ready:false,status:'blocked',reason:'route_expired'};
  renew(job);return {ready:job.result?.ready||false,status:job.result?.status||'pending',routeJob:job.token,...(job.result?.reason?{reason:job.result.reason}:{})};
 }
 function evaluateControl(control,state={}){
  timedOut();prune();const job=tokens.get(control?.routeJob);
  if(!job||job.phase!=='done'||job.result.status!=='ready')return {allowed:false,reason:'route_expired'};
  if(!job.identities.has(identity(control)))return {allowed:false,reason:'unknown_road_control'};
  if(edgeKinds.has(control.kind)){const result=evaluateRoadEdgeControl({byId:job.canonical},control,state);if(result.reason!=='unknown_road_control')renew(job);return result;}
  if(!control.approachId&&!control.turnId)return {allowed:false,reason:'unknown_road_control'};
  // The caller may now resolve this validated junction identity against its
  // current main-thread controller; none of the caller's rule data is trusted.
  renew(job);return null;
 }
 function invalidate(snapshot){stop();generation++;failure=null;if(snapshot!==undefined)return initialize(snapshot);return {generation,status:'blocked'};}
 function updateWorld(bodies){
  timedOut();if(disposed)return blocked('route_jobs_disposed');if(!worker)return blocked(failure||'route_worker_uninitialized');
  // Worker messages are ordered: a running old route may finish, then the small
  // world update rebuilds its scene. Epoch checks discard that old route result.
  disarm();generation++;initialized=false;failure=null;active=null;queue.length=0;jobs.clear();tokens.clear();completed.clear();
  arm();try{worker.postMessage({type:'world',generation,bodies});}catch{fail('route_worker_error');}
  return {generation,status:failure?'blocked':'pending'};
 }
 function dispose(){stop();generation++;disposed=true;failure=null;}
 function diagnostics(){timedOut();prune();return {generation,initialized,disposed,failure,queued:queue.length,inFlight:active?1:0,results:completed.size,pending:[...jobs.values()].filter(j=>j.phase!=='done').length};}
 return {initialize,query,touch,cancel,invalidate,updateWorld,dispose,evaluateControl,diagnostics};
}
