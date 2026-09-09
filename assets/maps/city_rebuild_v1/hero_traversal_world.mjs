import {circleFits} from './walk_motion.mjs';

// All heights are world metres. Reuse the live collider index, including doors.
export function createTraversalWorld({groundHeight,ceilingHeight,bodiesAt,contains,walkable,waterAt,blocksDynamic,inBody}){
 function supportHeight(x,z,referenceY){
  let floor=groundHeight(x,z,referenceY);
  for(const body of bodiesAt(x,z))if(Number.isFinite(body.maxYM)&&body.maxYM<=referenceY+.28&&body.maxYM>floor&&inBody(body,x,z))floor=body.maxYM;
  return floor;
 }
 function pointFits(x,z,y,height=1.9){
  if(!contains(x,z)||blocksDynamic(x,z)||groundHeight(x,z,y)>y+.28||ceilingHeight(x,z,y)<y+height-.03)return false;
  for(const body of bodiesAt(x,z)){
   if((body.maxYM??Infinity)<=y+.05||(body.minYM??-Infinity)>=y+height-.03)continue;
   if(inBody(body,x,z))return false;
  }
  return true;
 }
 function canOccupy(p,height=1.9){return circleFits(p.x,p.z,(x,z)=>pointFits(x,z,p.y,height));}
 function sample(x,z,referenceY){
  const floor=groundHeight(x,z,referenceY);let top=floor;
  for(const body of bodiesAt(x,z))if(inBody(body,x,z)){
   // Unknown-height obstacles remain walls; never invent a climbable top.
   if((body.minYM??-Infinity)>referenceY+1.9)continue;
   top=Math.max(top,body.maxYM??Infinity);
  }
  return {floor,top,waterDepth:waterAt(x,z)?.depth??0,walkable:contains(x,z)&&walkable(x,z)};
 }
 return {supportHeight,pointFits,canOccupy,sample};
}
