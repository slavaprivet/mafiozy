// Read authored doors from the existing source vehicle presentation. No actor,
// traffic route or ownership is created here; unloaded models defer the trip.
export function createNpcVehicleAccessResolver({traffic,worldScale=4.1,allowLogicalActor=null}={}){
 const cache=new WeakMap();
 function point(out,object,co,si,sx,sz,side,front){const x=side*sx,z=front*sz;out.c=(object.position.x+co*x+si*z)/worldScale;out.r=(object.position.z-si*x+co*z)/worldScale;}
 return function resolve({carId,seatId='front_left',phase='query',progress=0,npcId}={}){
  const request={carId,seatId,phase,progress,npcId},actor=traffic?.getActor(carId,request),object=actor?.object,seat=actor?.seats?.find(s=>s.id===seatId);
  if(!object||!seat||!object.parent&&!(actor.logicalSource===true&&(allowLogicalActor?allowLogicalActor(actor,request):actor.sourceBinding?.access===true&&actor.sourceBinding?.bound===true)))return null;
  if(phase!=='query')traffic.setNpcAccess?.(carId,phase,progress,seatId);
  let seats=cache.get(actor);if(!seats){seats=new Map();cache.set(actor,seats);}
  let result=seats.get(seatId);if(!result){result={outside:{r:0,c:0},seat:{r:0,c:0},seatId:seat.id};seats.set(seatId,result);}
  const co=Math.cos(object.rotation.y),si=Math.sin(object.rotation.y),sx=object.scale?.x??1,sz=object.scale?.z??1;
  // Source NPC body is .18 tiles wide in each direction. The hero's door
  // handle distance alone is too close for that gate and strands the approach.
  // Navigation uses a world-aligned square. Its support along a diagonal
  // car's side is larger than .18; keep every body corner outside the hull.
  const bodySupport=worldScale*.18*(Math.abs(co)+Math.abs(si));
  const doorDistance=Math.max(seat.doorDistance,(actor.profile?.halfWidth||0)+(bodySupport+.1)/Math.max(.01,Math.abs(sx)));
  point(result.outside,object,co,si,sx,sz,seat.side*doorDistance,seat.doorFront);point(result.seat,object,co,si,sx,sz,seat.anchor.side,seat.anchor.front);
  return result;
 };
}
