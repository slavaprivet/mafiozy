export const ENVIRONMENT_PLANNING_TIMEOUT_MS=20000;
let nextRequestId=0;
const namedError=(name,message)=>Object.assign(new Error(message),{name});
// Keep the identity, purpose and entrance needed by parking plus occupancy
// bounds used by roads. Never send model URLs or a Three scene graph.
// Authored polygon clearances must also survive: parking walking routes
// distinguish these reservations from newly added solid decor keepouts.
const roadPlannerRecord=item=>{
  const source=item?.userData?.instance||item||{},record={};
  for(const key of['id','assetId','role','entry','clearance','footprint','entryCorridor','clearancePolygonCR'])if(source[key])record[key]=source[key];
  // These two towers have an obsolete placement EntranceAnchor. The worker
  // needs the audited asset fingerprint and transform to locate their actual
  // existing door/ramp; stripping them would send pedestrians into the road.
  if(source.assetId==='compact_podium_glass_tower_v1'){
    record.binding={sha256:source.binding?.sha256,lod:source.binding?.lod};
    record.transform=source.transform;
  }
  if(source.role==='district_detention'){
    record.stopFootprint=source.stopFootprint;
    record.transform={yawDegrees:source.transform?.yawDegrees};
  }
  if(source.collision?.worldBodies?.length)record.collision={worldBodies:source.collision.worldBodies};
  return record;
};

/** One worker per scene planning transaction. Fallback is explicitly owned by the caller. */
export function planEnvironmentVisualsAsync(input,{signal,timeoutMs=ENVIRONMENT_PLANNING_TIMEOUT_MS}={}){
  if(!Number.isFinite(timeoutMs)||timeoutMs<=0||timeoutMs>ENVIRONMENT_PLANNING_TIMEOUT_MS)return Promise.reject(new RangeError('Environment planning timeout must be between 0 and 20000 ms'));
  if(signal?.aborted)return Promise.reject(namedError('AbortError','Environment planning cancelled'));
  if(typeof Worker!=='function')return Promise.reject(namedError('NotSupportedError','Environment planning Worker is unavailable'));
  return new Promise((resolve,reject)=>{
    let worker,timer=null,settled=false;
    const id=++nextRequestId;
    const cancel=()=>finish(namedError('AbortError','Environment planning cancelled'));
    function cleanup(){
      if(timer!==null)clearTimeout(timer);
      signal?.removeEventListener('abort',cancel);
      if(worker){worker.onmessage=null;worker.onerror=null;worker.onmessageerror=null;try{worker.terminate()}catch{/* Keep the original outcome if a host worker already terminated. */}}
    }
    function finish(error,result){if(settled)return;settled=true;cleanup();if(error)reject(error);else resolve(result);}
    try{
      worker=new Worker(new URL('./environment_planning_worker.mjs',import.meta.url),{type:'module',name:'walk-environment-plan'});
      worker.onmessage=event=>{
        const data=event.data||{};
        if(data.id!==id)return;
        if(data.error){finish(namedError(data.error.name||'Error',data.error.message||String(data.error)));return;}
        if(!Array.isArray(data.grassPlan?.tufts)||!Array.isArray(data.roadPlan?.markings)||!Array.isArray(data.parkingPlan?.lots)){finish(namedError('DataError','Environment planning worker returned an incomplete plan'));return;}
        finish(null,{grassPlan:data.grassPlan,roadPlan:data.roadPlan,parkingPlan:data.parkingPlan,workerMs:Number.isFinite(data.workerMs)?data.workerMs:null,mode:'worker'});
      };
      worker.onerror=event=>finish(event.error||new Error(event.message||'Environment planning worker failed'));
      worker.onmessageerror=()=>finish(namedError('DataCloneError','Environment planning worker response could not be decoded'));
      signal?.addEventListener('abort',cancel,{once:true});
      if(signal?.aborted){cancel();return;}
      timer=setTimeout(()=>finish(namedError('TimeoutError','Environment planning exceeded '+timeoutMs+' ms timeout')),timeoutMs);
      // Only the source placement record is relevant, never a Three scene graph.
      // Grass consumes ground colliders; omitting its unused renderer/feature data
      // keeps the main-thread structured-clone cost bounded during scene reload.
      const payload={topology:input?.topology,keepouts:input?.keepouts||[],instances:(input?.instances||[]).map(roadPlannerRecord),decorPlan:{colliders:input?.decorPlan?.colliders||[]}};
      worker.postMessage({id,input:payload});
    }catch(error){finish(error);}
  });
}
