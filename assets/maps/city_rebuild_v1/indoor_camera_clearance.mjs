// A wall may leave the original boom inside the hero. A render mask is only
// the last resort: first look for a collision-tested shoulder position.
export function createIndoorCameraClearance({THREE:T,resolvePosition}){
 const back=new T.Vector3(),right=new T.Vector3(),probe=new T.Vector3(),last=new T.Vector3(),lastOrigin=new T.Vector3(),blended=new T.Vector3(),radial=new T.Vector3(),segment=new T.Vector3(),offset=new T.Vector3();
 const minimum=.85,enter=1.1,release=1.4,shoulder=1.2;
 let active=false,preferred=0,initialized=false;
 function reset(){active=false;preferred=0;initialized=false}
 function solve({origin,eye,position,desired,objects,ceilingY=Infinity,dt=1/60}){
  if(initialized&&lastOrigin.distanceToSquared(origin)>9)reset();
  let probes=0;
  const check=point=>{
   probes++;const resolved=resolvePosition({THREE:T,from:origin,desired:point,objects,ceilingY:Infinity});
   // Do not accept a resolver result outside its requested, tested segment.
   segment.copy(point).sub(origin);offset.copy(resolved).sub(origin);const squared=segment.lengthSq(),t=squared?offset.dot(segment)/squared:0;
   if(t<0||t>1+1e-6||offset.addScaledVector(segment,-t).lengthSq()>1e-8)return null;
   return resolved;
  };
  const distance=position.distanceTo(eye),recovering=active&&distance>=release;
  // Start the sideways recovery before the camera reaches the hard head
  // clearance, retaining the previous normal frame so entry can blend too.
  if(!active&&distance>=enter){last.copy(position);lastOrigin.copy(origin);initialized=true;return{position,active:false,probes,blocked:false}}
  let candidate=null;
  if(recovering)candidate=position.clone();
  else{
   back.copy(desired).sub(origin);back.y=0;if(back.lengthSq()<1e-8)back.set(0,0,1);back.normalize();right.set(-back.z,0,back.x);
   // Prefer the previously accepted side: no left/right oscillation under
   // successive stair treads. All choices use the full five-ray camera volume.
   const choices=[preferred,...[0,1,2,3].filter(i=>i!==preferred)];
   for(const choice of choices){
    probe.copy(eye);
    if(choice<2)probe.addScaledVector(right,choice===0?shoulder:-shoulder);
    else if(choice===2)probe.addScaledVector(back,-shoulder);
    else probe.y+=shoulder;
    if(Number.isFinite(ceilingY))probe.y=Math.min(probe.y,ceilingY-.44);
    const resolved=check(probe);
    if(resolved&&resolved.distanceTo(eye)>=minimum+.05){candidate=resolved;preferred=choice;break}
   }
  }
  // A genuinely boxed-in camera must not be pushed through a wall just to
  // satisfy a minimum distance. The existing close mask remains the fallback.
  if(!candidate){reset();return{position,active:false,probes,blocked:true}}
  if(initialized){
   last.add(radial.copy(origin).sub(lastOrigin));
   const seconds=Number.isFinite(dt)?Math.max(0,Math.min(.1,dt)):1/60;
   // Exponential damping alone takes a large first step when a side probe
   // changes at a corner. Bound that recovery speed as well as its decay.
   const gap=last.distanceTo(candidate),linearTime=Math.max(0,(gap-.5)/6);
   const travel=seconds<=linearTime?6*seconds:gap-Math.min(gap,.5)*Math.exp(-12*(seconds-linearTime));
   blended.copy(last).lerp(candidate,gap>1e-8?travel/gap:1);
   radial.copy(blended).sub(eye);
   // Recover around the head, never interpolate a chord through it.
   if(radial.length()<minimum+.03){if(radial.lengthSq()<1e-8)radial.copy(candidate).sub(eye);blended.copy(eye).add(radial.setLength(minimum+.03))}
   const safe=check(blended);
   if(safe&&safe.distanceTo(eye)>=minimum)candidate=safe;
  }
  last.copy(candidate);lastOrigin.copy(origin);initialized=true;
  active=!recovering||candidate.distanceTo(position)>.015;
  if(!active)initialized=false;
  return{position:candidate,active,probes,blocked:false};
 }
 return{solve,reset};
}
