// Isolated candidate for the narrow surface unfreeze. It is not imported by
// runtime hosts. Canonical integration should fold this scan into route probes.
export function createPedestrianSurfaceContinuityCandidate({motion,supportHeight,sample,terrainSlopeAt=()=>null}={}){
 if(typeof motion?.route!=='function'||typeof supportHeight!=='function'||typeof sample!=='function'||typeof terrainSlopeAt!=='function')throw Error('Continuity candidate requires shared motion and surface queries');
 const limits=motion.limits||{},spacing=limits.probeSpacing??.055,stepHeight=limits.stepHeight??.34,walkSlope=limits.walkSlope??.95,scrambleSlope=limits.scrambleSlope??2.35,scrambleStepRise=limits.scrambleStepRise??.18,scrambleSpeedScale=limits.scrambleSpeedScale??.48;
 function route(from,to,options={}){
  if(!from||!to||![from.x,from.y,from.z,to.x,to.z].every(Number.isFinite))return {moved:false,reason:'invalid',position:from&&Number.isFinite(from.x)?{...from}:null,traversal:null,traversalKind:null};
  const distance=Math.hypot(to.x-from.x,to.z-from.z),steps=Math.max(1,Math.ceil(distance/spacing)),context={actorKind:'pedestrian',ignoreVehicleId:options.ignoreVehicleId};let previous={...from},previousFloor=supportHeight(from.x,from.z,from.y,context),downhillScramble=false,maxSlope=0,maxDrop=0;
  if(!Number.isFinite(previousFloor))return blocked('unsupported',previous);
  for(let i=1;i<=steps;i++){
   const t=i/steps,x=from.x+(to.x-from.x)*t,z=from.z+(to.z-from.z)*t,surface=sample(x,z,previous.y,context),floor=supportHeight(x,z,previous.y,context);
   if(!surface||![surface.floor,surface.top,surface.waterDepth,floor].every(Number.isFinite))return blocked('unsupported',previous);
   const horizontal=Math.hypot(x-previous.x,z-previous.z),rise=floor-previousFloor,drop=Math.max(0,-rise),grade=rise/Math.max(horizontal,1e-6),terrainSlope=terrainSlopeAt(x,z,context),groundSurface=Math.abs(surface.top-surface.floor)<.03;
   maxDrop=Math.max(maxDrop,drop);maxSlope=Math.max(maxSlope,Math.abs(grade),Number.isFinite(terrainSlope)?Math.abs(terrainSlope):0);
   if(drop>stepHeight+1e-6||groundSurface&&Number.isFinite(terrainSlope)&&Math.abs(terrainSlope)>scrambleSlope+1e-6){
    const edge={x,y:previous.y,z,floor,drop:previous.y-floor};
    if(options.ledgePolicy==='free-fall')return {moved:true,reason:'free_fall',movementMode:'free-fall',position:{x,y:previous.y,z},maxRise:0,stepRise:0,autoStep:false,slope:maxSlope,ascentMode:'walk',speedScale:1,traversal:null,traversalKind:null,verticalTransition:{kind:'free-fall',start:{...previous},edge,groundY:floor,fallDistance:Math.max(0,previous.y-floor)}};
    return {...blocked('ledge_drop',previous),movementMode:'blocked',verticalTransition:{kind:'free-fall',start:{...previous},edge,groundY:floor,fallDistance:Math.max(0,previous.y-floor)}};
   }
   if(groundSurface&&grade< -walkSlope-1e-6&&Number.isFinite(terrainSlope)&&Math.abs(terrainSlope)>walkSlope){downhillScramble=true;maxSlope=Math.max(maxSlope,Math.abs(grade));}
   previous={x,y:floor,z};previousFloor=floor;
  }
  const result=motion.route(from,to,options);
  if(result.moved&&downhillScramble)return {...result,reason:'clear',movementMode:'scramble',ascentMode:'scramble',slope:Math.max(result.slope||0,maxSlope),speedScale:scrambleSpeedScale,traversal:null,traversalKind:null};
  if(result.moved&&maxDrop>0&&maxDrop<=stepHeight+1e-6)return {...result,movementMode:result.ascentMode==='scramble'?'scramble':'walk',descentStep:maxDrop};
  return result;
 }
 const blocked=(reason,position)=>({moved:false,reason,movementMode:reason==='unsupported'?'unsupported':'blocked',position:{...position},maxRise:0,stepRise:0,autoStep:false,slope:0,ascentMode:'walk',speedScale:1,traversal:null,traversalKind:null});
 return {route,limits};
}
