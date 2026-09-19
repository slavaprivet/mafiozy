import {movePedestrian} from './walk_motion.mjs';
const STEP=1/120,RADIUS=.58,GRAVITY=18;
const clamp=(v,lo,hi)=>Math.max(lo,Math.min(hi,v));
// power=1 is the default vehicle blast; cover returns transmission in [0,1].
// Hero y is the current height; optional groundY identifies the floor below it.
export function planBlastKnockback(heroPoint,blast,cover){
 if(!heroPoint||!blast?.point)return null;
 const p=blast.point,y=heroPoint.y??0,py=p.y??0,power=blast.power??1,radius=blast.radius??8;
 if(![heroPoint.x,heroPoint.z,y,p.x,p.z,py,power,radius].every(Number.isFinite)||power<=0||radius<=0)return null;
 const dx=heroPoint.x-p.x,dz=heroPoint.z-p.z,distance=Math.hypot(dx,y-py,dz);
 if(distance>=radius)return null;
 const transmission=cover?Number(cover(p,heroPoint)):1;
 if(!Number.isFinite(transmission)||transmission<=0)return null;
 const strength=clamp(Math.sqrt(power)*(1-distance/radius)*clamp(transmission,0,1),0,2);
 if(strength<.015)return null;
 const horizontal=Math.hypot(dx,dz),nx=horizontal>1e-8?dx/horizontal:0,nz=horizontal>1e-8?dz/horizontal:1;
 const speed=Math.min(15,10*strength),vy=Math.min(8.5,5.5*strength);
 const duration=Math.min(3,1.15+strength*.7),baseY=Number.isFinite(heroPoint.groundY)?Math.min(y,heroPoint.groundY):y;
 return {x:heroPoint.x,y,z:heroPoint.z,baseY,vx:nx*speed,vy,vz:nz*speed,heading:Math.atan2(nx,nz),elapsed:0,progress:0,rolls:strength>1.1?2:1,duration,strength,kind:'tumble',done:false,blocked:false,remainder:0};
}
export function stepBlastKnockback(body,dt,allowed=()=>true,{groundHeight,ceilingHeight}={}){
 if(!body)return null;
 if(body.done||!Number.isFinite(dt)||dt<=0)return {...body};
 // Callers may retain the launch object, so take one snapshot.  A render frame
 // can contain up to thirty fixed steps; mutating this private snapshot avoids
 // cloning the complete body state for every one of them.
 let s={...body},remaining=(s.remainder??0)+Math.min(.25,dt);
 const delta={x:0,z:0};
 const floorAt=(x,z,fallback)=>{const value=groundHeight?.(x,z);return Number.isFinite(value)?value:fallback};
 // Fixed steps preserve the same collision and landing trajectory at 30/60/120Hz.
 while(remaining+1e-10>=STEP&&!s.done){
  remaining-=STEP;
  const currentFloor=floorAt(s.x,s.z,s.baseY);
  const grounded=s.y<=currentFloor+1e-8&&s.vy<=0;
  const speed=Math.hypot(s.vx,s.vz),nextSpeed=Math.max(0,speed-(grounded?8:.4)*STEP),ratio=speed?nextSpeed/speed:0;
  let vx=s.vx*ratio,vz=s.vz*ratio;
  delta.x=(s.vx+vx)*.5*STEP;delta.z=(s.vz+vz)*.5*STEP;
  let moved=movePedestrian(s,delta,allowed,RADIUS);
  let bx=Math.abs(moved.x-s.x-delta.x)>1e-6,bz=Math.abs(moved.z-s.z-delta.z)>1e-6;
  if(bx)vx=0;if(bz)vz=0;
  let vy=s.vy-GRAVITY*STEP,y=s.y+(s.vy+vy)*.5*STEP;
  let baseY=floorAt(moved.x,moved.z,s.baseY);
  if(groundHeight&&baseY>Math.max(y,currentFloor)){
   // Uphill correction consumes horizontal kinetic energy instead of granting
   // free potential energy. An unaffordable step acts as a wall.
   const rise=baseY-Math.max(y,currentFloor),v2=vx*vx+vz*vz,cost=2*GRAVITY*rise;
   if(cost>v2){moved={x:s.x,z:s.z};baseY=currentFloor;vx=0;vz=0;bx=true;bz=true}
   else {const uphillRatio=v2?Math.sqrt(Math.max(0,v2-cost)/v2):0;vx*=uphillRatio;vz*=uphillRatio}
  }
  if(y<=baseY){y=baseY;vy=0}
  const ceiling=ceilingHeight?.(moved.x,moved.z);
  let ceilingBlocked=false,cramped=false;
  if(Number.isFinite(ceiling)){
   // Stop upward motion at the head; never bounce or add energy. A malformed
   // room shorter than the tumble body keeps floor safety and reports cramped.
   const maxY=Math.max(baseY,ceiling-.65);
   cramped=ceiling-baseY<.65;
   if(y>maxY){y=maxY;vy=Math.min(0,vy);ceilingBlocked=true}
  }
  const elapsed=Math.min(s.duration,s.elapsed+STEP),progress=elapsed/s.duration,done=progress>=1-1e-9&&y<=baseY+1e-8&&vy<=0;
  const blocked=s.blocked||bx||bz,hadCeilingBlock=s.ceilingBlocked??false;
  s.x=moved.x;s.z=moved.z;s.y=y;s.baseY=baseY;
  s.vx=done?0:vx;s.vy=done?0:vy;s.vz=done?0:vz;
  s.elapsed=elapsed;s.progress=done?1:Math.min(.999,progress);s.done=done;
  s.blocked=blocked;s.ceilingBlocked=hadCeilingBlock||ceilingBlocked;s.cramped=cramped;
 }
 s.remainder=s.done?0:Math.max(0,remaining);
 return s;
}
