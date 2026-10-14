// Retry-capable pure protocol for long NPC navigation edges. It is intentionally
// not wired to the current boolean world hook: pending must be scheduled again.
const ENDPOINT_Y_EPSILON=.05;
export function createNpcPedestrianEdgeProbe({motion,groundHeight,worldScale=4.1,maxChunkDistance=.55,maxWorkUnitsPerFrame=2048,maxChunksPerCall=16}={}){
 if(typeof motion?.route!=='function'||typeof groundHeight!=='function'||![worldScale,maxChunkDistance,maxWorkUnitsPerFrame,maxChunksPerCall].every(Number.isFinite)||worldScale<=0||maxChunkDistance<=0||maxWorkUnitsPerFrame<1||maxChunksPerCall<1)throw Error('NPC edge probe requires motion, support and positive budgets');
 const weights=motion.limits?.workWeights,spacing=motion.limits?.probeSpacing;
 if(!weights||!Number.isFinite(spacing)||spacing<=0||!['support','sample','occupy','walkable','slope'].every(key=>Number.isFinite(weights[key])&&weights[key]>=0))throw Error('NPC edge probe requires measured motion work limits');
 const endpointEstimate=weights.support+weights.occupy,estimate=x=>weights.support+Math.max(1,Math.ceil(x/spacing+1e-12))*(weights.support+weights.sample+weights.occupy+weights.walkable+weights.slope);
 if(endpointEstimate>maxWorkUnitsPerFrame)throw Error('NPC edge probe endpoint exceeds hard work budget');
 if(estimate(maxChunkDistance)>maxWorkUnitsPerFrame)throw Error('NPC edge probe chunk exceeds hard work budget');
 let frameWorkUnits=0;
 const signature=({from,to,height,swimming,ignoreVehicleId})=>JSON.stringify([from.r,from.c,from.y??null,to.r,to.c,to.y??null,height,swimming?1:0,ignoreVehicleId??null]);
 const pending=(request,cursor,edgeWorkUnits,chunks,reason='work_budget')=>({moved:false,blocked:true,pending:true,terminal:false,reason,retry:'next_frame',booleanHookCompatible:false,accepted:{...cursor},workUnits:edgeWorkUnits,frameWorkUnits,retryToken:{version:1,signature:signature(request),cursor:{...cursor},workUnits:edgeWorkUnits,chunks}});
 function probe({from,to,height=motion.limits?.bodyHeight??1.9,swimming=false,ignoreVehicleId=null,retryToken=null}={}){
  const request={from,to,height,swimming,ignoreVehicleId};
  if(!from||!to||![from.r,from.c,to.r,to.c,height].every(Number.isFinite)||height<=0)return {moved:false,blocked:true,pending:false,terminal:true,reason:'invalid',retryToken:null,workUnits:0,frameWorkUnits};
  const expected=signature(request);
  if(retryToken&&(retryToken.version!==1||retryToken.signature!==expected||!retryToken.cursor||![retryToken.cursor.r,retryToken.cursor.c,retryToken.cursor.y,retryToken.workUnits,retryToken.chunks].every(Number.isFinite)))return {moved:false,blocked:true,pending:false,terminal:true,reason:'stale_retry_token',retryToken:null,workUnits:0,frameWorkUnits};
  const fromX=from.c*worldScale,fromZ=from.r*worldScale,toX=to.c*worldScale,toZ=to.r*worldScale;
  const initialY=Number.isFinite(from.y)?from.y:groundHeight(fromX,fromZ);
  if(!Number.isFinite(initialY))return {moved:false,blocked:true,pending:false,terminal:true,reason:'unsupported',retryToken:null,workUnits:0,frameWorkUnits};
  const targetY=Number.isFinite(to.y)?to.y:groundHeight(toX,toZ,initialY),endpointY=Number.isFinite(targetY)?groundHeight(toX,toZ,targetY):NaN;
  if(!Number.isFinite(endpointY))return {moved:false,blocked:true,pending:false,terminal:true,reason:'unsupported',retryToken:null,workUnits:0,frameWorkUnits};
  if(Math.abs(endpointY-targetY)>ENDPOINT_Y_EPSILON)return {moved:false,blocked:true,pending:false,terminal:true,reason:'endpoint_storey_mismatch',retryToken:null,workUnits:0,frameWorkUnits};
  let cursor=retryToken?{...retryToken.cursor}:{r:from.r,c:from.c,y:initialY},edgeWorkUnits=retryToken?.workUnits??0,chunks=retryToken?.chunks??0,callChunks=0;
  while(callChunks<maxChunksPerCall){
   if(frameWorkUnits>=maxWorkUnitsPerFrame)return pending(request,cursor,edgeWorkUnits,chunks);
   const x=cursor.c*worldScale,z=cursor.r*worldScale,dx=toX-x,dz=toZ-z,distance=Math.hypot(dx,dz);
   if(distance<=1e-7){
    if(frameWorkUnits+endpointEstimate>maxWorkUnitsPerFrame)return pending(request,cursor,edgeWorkUnits,chunks);
    const endpoint=motion.route({x,y:cursor.y,z},{x:toX,y:targetY,z:toZ},{height,swimming,ignoreVehicleId,withTraversal:false}),units=endpoint?.workUnits;
    if(!Number.isFinite(units)||units<0)return {moved:false,blocked:true,pending:false,terminal:true,reason:'invalid_work_contract',accepted:{...cursor},workUnits:edgeWorkUnits,frameWorkUnits,retryToken:null};
    frameWorkUnits+=units;edgeWorkUnits+=units;
    if(frameWorkUnits>maxWorkUnitsPerFrame)return {moved:false,blocked:true,pending:false,terminal:true,reason:'work_contract_exceeded',accepted:{...cursor},workUnits:edgeWorkUnits,frameWorkUnits,retryToken:null};
    if(!endpoint.moved&&endpoint.reason!=='still')return {moved:false,blocked:true,pending:false,terminal:true,reason:endpoint.reason||'blocked',accepted:{...cursor},workUnits:edgeWorkUnits,frameWorkUnits,retryToken:null,traversal:null,traversalKind:null};
    const position=endpoint.position;
    if(!position||![position.x,position.y,position.z].every(Number.isFinite)||Math.hypot(position.x-toX,position.z-toZ)>1e-5||Math.abs(position.y-targetY)>ENDPOINT_Y_EPSILON)return {moved:false,blocked:true,pending:false,terminal:true,reason:'endpoint_storey_mismatch',accepted:{...cursor},workUnits:edgeWorkUnits,frameWorkUnits,retryToken:null};
    return {moved:true,blocked:false,pending:false,terminal:true,reason:'clear',accepted:{x:toX,y:targetY,z:toZ},workUnits:edgeWorkUnits,frameWorkUnits,retryToken:null,chunks};
   }
   const chunkDistance=Math.min(distance,maxChunkDistance),fraction=chunkDistance/distance,target={x:x+dx*fraction,z:z+dz*fraction};
   const reserved=estimate(chunkDistance);if(frameWorkUnits+reserved>maxWorkUnitsPerFrame)return pending(request,cursor,edgeWorkUnits,chunks);
   // Edge admission only establishes passability. NPC traversal needs a
   // separate executor; running player planTraversal here breaks the hard cap.
   const result=motion.route({x,y:cursor.y,z},target,{height,swimming,ignoreVehicleId,withTraversal:false}),units=result?.workUnits;
   if(!Number.isFinite(units)||units<0)return {moved:false,blocked:true,pending:false,terminal:true,reason:'invalid_work_contract',accepted:{...cursor},workUnits:edgeWorkUnits,frameWorkUnits,retryToken:null};
   frameWorkUnits+=units;edgeWorkUnits+=units;chunks++;callChunks++;
   if(frameWorkUnits>maxWorkUnitsPerFrame)return {moved:false,blocked:true,pending:false,terminal:true,reason:'work_contract_exceeded',accepted:{...cursor},workUnits:edgeWorkUnits,frameWorkUnits,retryToken:null};
   if(!result.moved)return {moved:false,blocked:true,pending:false,terminal:true,reason:result.reason||'blocked',accepted:{...cursor},workUnits:edgeWorkUnits,frameWorkUnits,retryToken:null,traversal:result.pending||result.reason==='unsupported'?null:result.traversal??null,traversalKind:result.pending||result.reason==='unsupported'?null:result.traversalKind??null};
   const position=result.position;
   if(!position||![position.x,position.y,position.z].every(Number.isFinite)||Math.hypot(position.x-target.x,position.z-target.z)>1e-5)return {moved:false,blocked:true,pending:false,terminal:true,reason:'invalid_motion_result',accepted:{...cursor},workUnits:edgeWorkUnits,frameWorkUnits,retryToken:null};
   cursor={r:position.z/worldScale,c:position.x/worldScale,y:position.y};
   if(fraction===1){
    if(Math.abs(position.y-targetY)>ENDPOINT_Y_EPSILON)return {moved:false,blocked:true,pending:false,terminal:true,reason:'endpoint_storey_mismatch',accepted:{...cursor},workUnits:edgeWorkUnits,frameWorkUnits,retryToken:null};
    return {moved:true,blocked:false,pending:false,terminal:true,reason:'clear',accepted:{...position},workUnits:edgeWorkUnits,frameWorkUnits,retryToken:null,chunks};
   }
  }
  return pending(request,cursor,edgeWorkUnits,chunks,'chunk_yield');
 }
 function beginFrame(){frameWorkUnits=0;}
 return {probe,beginFrame,diagnostics:()=>({frameWorkUnits,maxWorkUnitsPerFrame,maxChunkDistance,maxChunksPerCall})};
}
