// REVIEW ONLY. Produces a candidate source string; never imported by world.
// Keep the imported commerce file frozen until its owner applies this exact delta.
const arrivalHelper=String.raw`function _residentCommerceArrivalTarget(n,visit,now){
 const pinned=visit?._serviceArrival,seen=visit?._serviceArrivalRegistration||pinned?.registration,buildingId=visit?.door?.instanceId||visit?.door?.id;
 if(!_residentCommerceServiceProviders.size&&!seen)return visit?.door?.inside||null;
 const registration=_residentCommerceServiceProviders.get(buildingId),provider=registration?.provider;
 if(!provider||typeof provider.getServiceArrivalTarget!=='function')return seen?null:visit?.door?.inside||null;
 if(seen&&seen!==registration.token)return null;
 visit._serviceArrivalRegistration=registration.token;
 try{
  const target=provider.getServiceArrivalTarget({npc:n,visit,now});
  if(!target||![target.r,target.c,target.y].every(Number.isFinite)||typeof target.stamp!=='string'||!target.stamp)return null;
  if(pinned&&(pinned.stamp!==target.stamp||pinned.r!==target.r||pinned.c!==target.c||pinned.y!==target.y))return null;
  if(!pinned)visit._serviceArrival={registration:registration.token,stamp:target.stamp,r:target.r,c:target.c,y:target.y};
  return visit._serviceArrival;
 }catch{return null;}
}
`;
export function serviceArrivalSourceCandidate(source){
 const replaceOnce=(before,after)=>{
  if(source.indexOf(before)<0||source.indexOf(before)!==source.lastIndexOf(before))throw Error('Arrival proposal source anchor changed');
  source=source.replace(before,after);
 };
 replaceOnce('function _residentCommerceArrive(n,visit,now){',arrivalHelper+'function _residentCommerceArrive(n,visit,now){');
 replaceOnce(" const door=visit?.door;if(visit.commerce||!door?.inside||visit.phase!=='browsing'||Math.hypot(n.r-door.inside.r,n.c-door.inside.c)>.04)return false;",
 " const door=visit?.door;if(visit.commerce||!door?.inside||visit.phase!=='browsing')return false;\n const arrival=_residentCommerceArrivalTarget(n,visit,now);if(!arrival||Math.hypot(n.r-arrival.r,n.c-arrival.c)>.04)return false;");
 replaceOnce(' const order=visit?.commerce;if(!order||order.settled)return false;',
 ' const order=visit?.commerce;if(!order||order.settled)return false;\n const arrival=_residentCommerceArrivalTarget(n,visit,now);');
 replaceOnce('Math.hypot(n.r-visit.door.inside.r,n.c-visit.door.inside.c)>.08',
 '!arrival||Math.hypot(n.r-arrival.r,n.c-arrival.c)>.08');
 return source;
}
