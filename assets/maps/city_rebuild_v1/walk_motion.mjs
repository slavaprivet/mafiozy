// Footprint-sampled pedestrian movement. No runtime or network dependencies.
export function circleFits(x,z,isPointWalkable,radius=.36){
 if(!Number.isFinite(x)||!Number.isFinite(z)||!isPointWalkable(x,z))return false;
 for(let i=0;i<12;i++){const angle=i*Math.PI/6;if(!isPointWalkable(x+Math.cos(angle)*radius,z+Math.sin(angle)*radius))return false}
 return true;
}
export function movePedestrian(position,delta,isPointWalkable,radius=.36){
 if(![position.x,position.z,delta.x,delta.z,radius].every(Number.isFinite)||radius<=0)throw Error('Invalid pedestrian step');
 const count=Math.max(1,Math.ceil(Math.hypot(delta.x,delta.z)/Math.min(.12,radius/2)));
 if(count>200)throw Error('Pedestrian step too large');
 let x=position.x,z=position.z;const dx=delta.x/count,dz=delta.z/count;
 for(let i=0;i<count;i++){
  if(circleFits(x+dx,z+dz,isPointWalkable,radius)){x+=dx;z+=dz}
  else if(circleFits(x+dx,z,isPointWalkable,radius))x+=dx;
  else if(circleFits(x,z+dz,isPointWalkable,radius))z+=dz;
 }
 return {x,z,moved:Math.hypot(x-position.x,z-position.z)>1e-6};
}
