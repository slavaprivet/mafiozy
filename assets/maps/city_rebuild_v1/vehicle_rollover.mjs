// Bounded ground-contact roll model. Translation/steering remain with stepCar.
// Public impact accepts the same outward-body contact normal as damage.
export function createVehicleRollover(T,car){
 const halfWidth=car.profile?.halfWidth??1.28,halfHeight=(car.profile?.height??2.16)/2,inertia=(halfWidth**2+halfHeight**2)/3;
 let angle=0,omega=0,active=false,lastContact=null,time=0,lastImpact=-Infinity;
 const snap=()=>Math.round(angle/(Math.PI/2))*Math.PI/2;
 function impact(contact,yaw=car.object.rotation.y){
  if(!contact||![contact.impactSpeed,contact.normal?.x,contact.normal?.z,yaw].every(Number.isFinite)||contact.impactSpeed<=0||time-lastImpact<.25)return false;
  const side=contact.normal.x*Math.cos(yaw)-contact.normal.z*Math.sin(yaw);
  if(Math.abs(side)<.15)return false;
  // Road-supported wheels resist the lateral impulse below the centre of mass.
  const speed=contact.impactSpeed,lever=Math.max(.35,halfHeight*.6944444444);
  omega+=Math.max(-8,Math.min(8,side*speed*lever/inertia*.48));
  active=true;lastContact=contact;lastImpact=time;return true;
 }
 function update(dt){
  if(!Number.isFinite(dt)||dt<0)throw Error('Invalid roll timestep');
  time+=dt;
  if(active){const n=Math.max(1,Math.ceil(Math.min(dt,.1)*120)),h=Math.min(dt,.1)/n;
   for(let i=0;i<n;i++){
    const s=Math.sin(angle),c=Math.cos(angle),derivative=halfWidth*Math.sign(s)*c-halfHeight*Math.sign(c)*s;
    omega+=(-9.81*derivative/inertia-omega*1.65)*h;
    const previous=angle;angle+=omega*h;
    const rest=snap();if((previous-rest)*(angle-rest)<=0&&Math.abs(omega)<1.15){angle=rest;omega=0;active=false;break}
   }
  }
  const lift=halfWidth*Math.abs(Math.sin(angle))+halfHeight*Math.abs(Math.cos(angle));
  car.object.rotation.z=angle;car.object.position.y=lift-halfHeight*Math.cos(angle);
 }
 function reset(){angle=omega=time=0;lastImpact=-Infinity;active=false;lastContact=null;car.object.rotation.z=0;car.object.position.y=0}
 return{impact,update,reset,get angle(){return angle},get unstable(){return active||Math.abs(Math.sin(angle/2))>.08},stats:()=>({angle,angularVelocity:omega,active,overturned:Math.cos(angle)<.5,lastContact})};
}
