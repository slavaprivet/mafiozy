// Continuous pose clipping and contact-normal response. Collision queries are
// supplied by the host, so the same solver handles city solids and parked cars.
const finite=(v,f=0)=>Number.isFinite(v)?v:f;
const delta=(a,b)=>Math.atan2(Math.sin(a-b),Math.cos(a-b));
export function vehicleStateFromVelocity(state,vx,vz,yawRate=state.yawRate){
 const magnitude=Math.hypot(vx,vz),forward=vx*Math.sin(state.yaw)+vz*Math.cos(state.yaw);
 const sign=Math.abs(forward)>.01?Math.sign(forward):Math.sign(state.speed)||1;
 const stopped=magnitude<.015;
 const travelYaw=stopped?state.yaw:Math.atan2(vx*sign,vz*sign);
 return {...state,vx:stopped?0:vx,vz:stopped?0:vz,speed:stopped?0:sign*magnitude,
  travelYaw,yawRate:finite(yawRate),
  longitudinalVelocity:stopped?0:forward,lateralVelocity:stopped?0:vx*Math.cos(state.yaw)-vz*Math.sin(state.yaw),
  slipAngle:stopped?0:delta(state.yaw,travelYaw)};
}

export function moveVehicleWithContacts(start,next,dt,{fits,contactAt,shape}){
 let x=start.x,z=start.z,yaw=start.yaw,vx=next.vx,vz=next.vz,yawRate=next.yawRate,
  remaining=dt,distance=0,contact=null,bumped=false;
 const sign=Math.sign(next.speed)||1;
 const move=(nx,nz,ny)=>{distance+=sign*Math.hypot(nx-x,nz-z);x=nx;z=nz;yaw=ny;};
 const hitAt=(px,pz,py)=>contactAt?.(px,pz,py,shape);
 // Usually one free step; at most three contacts when wedged into a corner.
 for(let iteration=0;iteration<3&&remaining>1e-7;iteration++){
  let nx=x+vx*remaining,nz=z+vz*remaining,ny=yaw+yawRate*remaining;
  if(fits(nx,nz,ny,shape)){move(nx,nz,ny);remaining=0;break;}
  let hit=hitAt(nx,nz,ny),initialHit=hitAt(x,z,yaw);
  // Existing touching/overlap must never prevent backing away. This also
  // recovers small penetrations introduced by another body's impulse.
  if(hit&&initialHit&&hit.otherVehicle===initialHit.otherVehicle&&
    hit.normal.x*initialHit.normal.x+hit.normal.z*initialHit.normal.z>.95&&
    hit.depth<initialHit.depth-1e-7){move(nx,nz,ny);remaining=0;break;}
  if(initialHit&&initialHit.depth<.04){
   const padding=initialHit.depth+.0005,px=x-initialHit.normal.x*padding,pz=z-initialHit.normal.z*padding;
   if(fits(px,pz,yaw,shape)){x=px;z=pz;nx=x+vx*remaining;nz=z+vz*remaining;hit=hitAt(nx,nz,ny);
    if(fits(nx,nz,ny,shape)){move(nx,nz,ny);remaining=0;break;}}
  }
  let lo=0,hi=1;
  if(fits(x,z,yaw,shape))for(let j=0;j<13;j++){
   const t=(lo+hi)/2;
   if(fits(x+(nx-x)*t,z+(nz-z)*t,yaw+(ny-yaw)*t,shape))lo=t;else hi=t;
  }
  const atImpact=hitAt(x+(nx-x)*hi,z+(nz-z)*hi,yaw+(ny-yaw)*hi)||hit;
  const fraction=Math.max(0,lo-1e-5);
  move(x+(nx-x)*fraction,z+(nz-z)*fraction,yaw+(ny-yaw)*fraction);
  remaining*=1-fraction;bumped=true;
  if(!atImpact){vx=vz=yawRate=0;break;}
  const normal=atImpact.normal,rx=atImpact.point.x-x,rz=atImpact.point.z-z,
   arm=rz*normal.x-rx*normal.z,
   closing=Math.max(0,vx*normal.x+vz*normal.z+yawRate*arm),
   slide=Math.abs(vx*normal.z-vz*normal.x),
   candidate={...atImpact,impactSpeed:closing,slideSpeed:slide,
    velocity:{x:vx,y:0,z:vz},incomingYawRate:yawRate,incomingPose:{x,z,yaw}};
  if(!contact||candidate.impactSpeed>contact.impactSpeed)contact=candidate;
  // Another vehicle may already be moving away. Keep incoming momentum until
  // the fleet evaluates relative velocity and the actual mass of both bodies.
  if(atImpact.otherVehicle)break;
  // Unit-mass rigid-body impulse. Inertia retains the different dimensions of
  // a hatchback and a bus, instead of rotating every vehicle at one rate.
  const w=shape.collisionHalfWidth??shape.halfWidth,l=shape.collisionHalfLength??shape.halfLength,
   inertia=Math.max(.2,(w*w+l*l)/3),impulse=closing/(1+arm*arm/inertia);
  vx-=normal.x*impulse;vz-=normal.z*impulse;yawRate-=arm*impulse/inertia;
  // Small body friction loses energy in a scrape but leaves tangent motion.
  const tx=normal.z,tz=-normal.x,tangent=vx*tx+vz*tz,
   friction=Math.sign(tangent)*Math.min(Math.abs(tangent),impulse*.08);
  vx-=tx*friction;vz-=tz*friction;
  if(closing<1e-6&&fraction<1e-5){yawRate=0;const into=Math.max(0,vx*normal.x+vz*normal.z);vx-=normal.x*into;vz-=normal.z*into;
   if(Math.hypot(vx,vz)<.015)break;}
 }
 return {...vehicleStateFromVelocity({...next,x,z,yaw},vx,vz,yawRate),distance,bumped,contact};
}
