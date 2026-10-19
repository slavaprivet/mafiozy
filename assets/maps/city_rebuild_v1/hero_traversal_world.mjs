import {circleFits} from './walk_motion.mjs';

// All heights are world metres. Reuse the live collider index, including doors.
export function createTraversalWorld({groundHeight,ceilingHeight,bodiesAt,contains,walkable,waterAt,blocksDynamic,inBody,vehicleSurface,stepHeight=.34}){
 if(!Number.isFinite(stepHeight)||stepHeight<.2||stepHeight>.45)throw Error('Traversal stepHeight must stay within a safe pedestrian range');
 function supportHeight(x,z,referenceY,context={}){
  let floor=groundHeight(x,z,referenceY);
  for(const body of bodiesAt(x,z))if(Number.isFinite(body.maxYM)&&body.maxYM<=referenceY+stepHeight&&body.maxYM>floor&&inBody(body,x,z))floor=body.maxYM;
  return vehicleSurface?Math.max(floor,vehicleSurface.supportHeight(x,z,referenceY,floor,context)):floor;
 }
 function pointFits(x,z,y,height=1.9,context={}){
  if(!contains(x,z)||blocksDynamic(x,z,y,height,context)||vehicleSurface?.blocks(x,z,y,height,0,context)||groundHeight(x,z,y)>y+stepHeight||ceilingHeight(x,z,y)<y+height-.03)return false;
  for(const body of bodiesAt(x,z)){
   if((body.maxYM??Infinity)<=y+.05||(body.minYM??-Infinity)>=y+height-.03)continue;
   if(inBody(body,x,z))return false;
  }
  return true;
 }
 function canOccupy(p,height=1.9,context={}){return circleFits(p.x,p.z,(x,z)=>pointFits(x,z,p.y,height,context));}
 function sample(x,z,referenceY,context={}){
  const floor=groundHeight(x,z,referenceY);let top=floor;
  for(const body of bodiesAt(x,z))if(inBody(body,x,z)){
   // Unknown-height obstacles remain walls; never invent a climbable top.
   if((body.minYM??-Infinity)>referenceY+1.9)continue;
   top=Math.max(top,body.maxYM??Infinity);
  }
  const vehicle=vehicleSurface?.sample(x,z,referenceY,context),vehicleTop=vehicle?.stable&&vehicle.top>=top;
  if(vehicleTop)top=vehicle.top;
  return {floor,top,waterDepth:waterAt(x,z)?.depth??0,walkable:contains(x,z)&&walkable(x,z),...(vehicleTop?{supportKind:'vehicle',vehicle:vehicle.vehicle}:{})};
 }
 return {supportHeight,pointFits,canOccupy,sample,limits:Object.freeze({stepHeight})};
}
