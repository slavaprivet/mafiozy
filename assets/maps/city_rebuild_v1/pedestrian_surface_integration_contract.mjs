// Pure host arbitration and frame metadata. It moves no actor and owns no
// renderer state; /walk and native NPC navigation may share this contract.
export const PEDESTRIAN_MOVEMENT_PRIORITY=Object.freeze(['vehicle','jump','ladder','water','cover','surface']);
const ENDPOINT_Y_EPSILON=.05;

export function pedestrianMovementOwner(state={}){
 if(state.occupiedSeat||state.sourceVehicleActive||state.vehicleTransition)return 'vehicle';
 if(state.jump||state.traversalActive||state.airborne)return 'jump';
 if(state.ladderActive)return 'ladder';
 if(state.swimming||state.inDeepWater)return 'water';
 if(state.coverActive)return 'cover';
 return 'surface';
}

export function createPedestrianSurfaceMetadataLatch({stepHold=.18,scrambleGrace=.12,traversalHold=.08}={}){
 if(![stepHold,scrambleGrace,traversalHold].every(v=>Number.isFinite(v)&&v>=0))throw Error('Invalid surface metadata lifetime');
 const frame={kind:null,until:0,traversalKind:null,plan:null,reason:null,slope:0,maxRise:0,speedScale:1,stepRise:0};let active=false,lastDirectionX=0,lastDirectionZ=0,hasLastDirection=false,cancelReason=null;
 const clear=reason=>{active=false;frame.kind=null;frame.plan=null;frame.traversalKind=null;hasLastDirection=false;cancelReason=reason;};
 function coreUpdate(result,{now=0,direction=null,owner='surface'}={}){
  if(!Number.isFinite(now))throw Error('Finite surface metadata time required');
  if(owner!=='surface'){clear('owner:'+owner);return false;}
  const directionX=direction?.x||0,directionZ=direction?.z||0,length=Math.hypot(directionX,directionZ),nextX=length>.001?directionX/length:0,nextZ=length>.001?directionZ/length:0,hasDirection=length>.001;
  if(hasDirection&&hasLastDirection&&nextX*lastDirectionX+nextZ*lastDirectionZ<-.15)clear('turn-around');
  if(hasDirection){lastDirectionX=nextX;lastDirectionZ=nextZ;hasLastDirection=true;}
  if(!result?.moved){
   active=!!result?.traversalKind;if(active){frame.kind='traversal';frame.until=now+traversalHold;frame.traversalKind=result.traversalKind;frame.plan=result.traversal;frame.reason=result.reason;}else cancelReason=result?.reason||'blocked';return active;
  }
  const stepUntil=result.autoStep?now+stepHold:active&&frame.kind==='step'?frame.until:-Infinity;
  frame.plan=null;frame.traversalKind=null;frame.reason=null;
  if(result.ascentMode==='scramble'){active=true;frame.kind='scramble';frame.until=now+scrambleGrace;frame.slope=result.slope;frame.maxRise=result.maxRise;frame.speedScale=result.speedScale;}
  else if(stepUntil>now){active=true;frame.kind='step';frame.until=stepUntil;frame.stepRise=result.stepRise;frame.maxRise=result.maxRise;frame.speedScale=1;}
  else{active=false;frame.kind=null;}
  cancelReason=null;return active;
 }
 function alive(now){if(active&&now>frame.until){active=false;frame.kind=null;frame.plan=null;}return active;}
 function copyInto(out,includePlan=true){out.kind=frame.kind;out.until=frame.until;out.traversalKind=frame.traversalKind;out.reason=frame.reason;out.slope=frame.slope;out.maxRise=frame.maxRise;out.speedScale=frame.speedScale;out.stepRise=frame.stepRise;out.plan=includePlan?frame.plan:undefined;return out;}
 function cloneFrame(){if(frame.kind==='traversal')return {kind:'traversal',until:frame.until,traversalKind:frame.traversalKind,plan:frame.plan,reason:frame.reason};if(frame.kind==='scramble')return {kind:'scramble',until:frame.until,slope:frame.slope,maxRise:frame.maxRise,speedScale:frame.speedScale};return {kind:'step',until:frame.until,stepRise:frame.stepRise,maxRise:frame.maxRise,speedScale:frame.speedScale};}
 function update(result,args={}){coreUpdate(result,args);return sample(args.now??0);}
 function updateInto(out,result,args={}){coreUpdate(result,args);return alive(args.now??0)?copyInto(out,false):null;}
 function sample(now){return alive(now)?cloneFrame():null;}
 function sampleInto(out,now,{includePlan=true}={}){return alive(now)?copyInto(out,includePlan):null;}
 function consumeTraversal(){if(!active||frame.kind!=='traversal')return null;const plan=frame.plan;active=false;frame.kind=null;frame.plan=null;return plan;}
 return {update,updateInto,sample,sampleInto,consumeTraversal,cancel:clear,get state(){return active?cloneFrame():null},get cancelReason(){return cancelReason}};
}

export function createNpcPedestrianSurfaceConsumer({motion,groundHeight,worldScale=4.1,maxUniqueEdgesPerFrame=64,maxCacheEntries=256}={}){
 if(typeof motion?.route!=='function'||typeof groundHeight!=='function'||!Number.isFinite(worldScale)||worldScale<=0)throw Error('NPC pedestrian surface consumer requires motion, support and scale');
 if(!Number.isInteger(maxUniqueEdgesPerFrame)||maxUniqueEdgesPerFrame<1||!Number.isInteger(maxCacheEntries)||maxCacheEntries<maxUniqueEdgesPerFrame)throw Error('Invalid NPC pedestrian surface cache budget');
 const cache=new Map();let uniqueEdges=0,hits=0,deferred=0;
 function query({from,to,height=motion.limits?.bodyHeight??1.9,ignoreVehicleId=null,swimming=false,actorKind='pedestrian'}={}){
  if(actorKind!=='pedestrian')return {moved:false,reason:'pedestrian_only',pending:false};
  if(!from||!to||![from.r,from.c,to.r,to.c,height].every(Number.isFinite)||height<=0)return {moved:false,reason:'invalid',pending:false};
  const x=from.c*worldScale,z=from.r*worldScale,targetX=to.c*worldScale,targetZ=to.r*worldScale;
  const fromY=Number.isFinite(from.y)?from.y:groundHeight(x,z),toY=Number.isFinite(to.y)?to.y:groundHeight(targetX,targetZ,fromY);
  if(!Number.isFinite(fromY)||!Number.isFinite(toY))return {moved:false,blocked:true,reason:'unsupported',pending:false};
  const key=JSON.stringify([from.r,from.c,fromY,to.r,to.c,toY,height,swimming?1:0,ignoreVehicleId??null]),cached=cache.get(key);if(cached){hits++;return cached;}
  // Pending requires a retry-capable scheduler. `blocked:true` makes accidental
  // use by the current boolean world hook fail closed until that host supports it.
  if(uniqueEdges>=maxUniqueEdgesPerFrame){deferred++;return {moved:false,blocked:true,reason:'budget_deferred',pending:true,retry:'next_frame',booleanHookCompatible:false};}
  uniqueEdges++;
  const endpointY=groundHeight(targetX,targetZ,toY);
  let result;
  if(!Number.isFinite(endpointY))result={moved:false,blocked:true,reason:'unsupported'};
  else if(Math.abs(endpointY-toY)>ENDPOINT_Y_EPSILON)result={moved:false,blocked:true,reason:'endpoint_storey_mismatch',position:{x,y:fromY,z}};
  else{
   result=motion.route({x,y:fromY,z},{x:targetX,y:toY,z:targetZ},{actorKind:'pedestrian',height,swimming,ignoreVehicleId});
   const distance=Math.hypot(targetX-x,targetZ-z),position=result?.position,positionMatches=position&&[position.x,position.y,position.z].every(Number.isFinite)&&Math.hypot(position.x-targetX,position.z-targetZ)<=1e-5&&Math.abs(position.y-toY)<=ENDPOINT_Y_EPSILON;
   if(distance<=1e-7&&result?.reason==='still'&&positionMatches)result={...result,moved:true,blocked:false,reason:'clear'};
   else if(result?.moved&&!positionMatches)result={...result,moved:false,blocked:true,reason:'endpoint_storey_mismatch'};
   else if(!result?.moved)result={...result,blocked:true};
  }
  const value={...result,pending:false,from:{...from},to:{...to}};if(cache.size<maxCacheEntries)cache.set(key,value);return value;
 }
 function beginFrame(){cache.clear();uniqueEdges=0;hits=0;deferred=0;}
 return {query,beginFrame,diagnostics:()=>({uniqueEdges,hits,deferred,cache:cache.size,maxUniqueEdgesPerFrame,maxCacheEntries})};
}
