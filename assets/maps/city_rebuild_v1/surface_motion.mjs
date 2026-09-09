// World-metre foot support for walking. Host still resolves horizontal walls,
// jump/vehicle states and camera collision. No interpolation beneath a solid floor.
const clamp=(n,a,b)=>Math.max(a,Math.min(b,n));
export function resolveJumpSurface(state,{floor,ceiling=Infinity,bodyHeight=1.9,previousY,dt,flightTime=.8,gravity=18}){
 const jump={...state},ceilingFoot=ceiling-bodyHeight-.04;let worldY=jump.baseY+jump.y;
 if(!jump.falling&&(worldY>ceilingFoot||(jump.elapsed>=flightTime&&worldY>floor+.02))){jump.falling=true;jump.ceilingHit=worldY>ceilingFoot;jump.fallY=Math.min(previousY,worldY,ceilingFoot);jump.fallVelocity=jump.ceilingHit?0:Math.min(0,(worldY-previousY)/Math.max(.001,dt))}
 if(jump.falling){jump.fallY+=jump.fallVelocity*dt-gravity*.5*dt*dt;jump.fallVelocity-=gravity*dt;worldY=jump.fallY;if(worldY<=floor){jump.falling=false;jump.baseY=floor;jump.y=0;jump.elapsed=Math.max(jump.elapsed,flightTime);worldY=floor}}
 jump.worldY=Math.max(floor,Math.min(worldY,Math.max(floor,ceilingFoot)));return jump;
}
export function createSurfaceMotion(options={}){
 const stepHeight=options.stepHeight??.28,maxSlope=options.maxSlope??.8,gravity=options.gravity??18,probeSpacing=options.probeSpacing??.12,snapDown=options.snapDown??.12;
 let state=null;
 const floorAt=(sample,x,z)=>{const y=sample(x,z);if(!Number.isFinite(y))throw Error('floorHeight must return a finite world height');return y};
 function reset(position,{grounded=true,velocityY=0}={}){if(![position.x,position.y,position.z,velocityY].every(Number.isFinite))throw Error('Finite surface position required');state={x:position.x,y:position.y,z:position.z,velocityY,grounded};return {...state}}
 function canMove(from,to,sample,startFloor=undefined){
  const distance=Math.hypot(to.x-from.x,to.z-from.z),steps=Math.max(1,Math.ceil(distance/probeSpacing));let previous;
  if(startFloor===undefined)previous=floorAt(sample,from.x,from.z);
  else {if(!Number.isFinite(startFloor))throw Error('floorHeight must return a finite world height');previous=startFloor;}
  // Test the actual route, so a long frame cannot skip over a raised platform.
  for(let i=1;i<=steps;i++){const f=i/steps,floor=floorAt(sample,from.x+(to.x-from.x)*f,from.z+(to.z-from.z)*f),rise=floor-previous;if(rise>Math.max(stepHeight,maxSlope*distance/steps)+1e-5)return false;previous=floor}return true;
 }
 function update({x,z,dt,floorHeight}){
  if(!state)throw Error('Call surfaceMotion.reset before update');if(!Number.isFinite(dt)||dt<0||![x,z].every(Number.isFinite))throw Error('Invalid surface timestep/position');dt=clamp(dt,0,.1);
  const old={...state},distance=Math.hypot(x-old.x,z-old.z),floor=floorAt(floorHeight,x,z),rise=floor-old.y;
  const blocked=(old.grounded&&!canMove(old,{x,z},floorHeight))||rise>Math.max(stepHeight,maxSlope*distance)+1e-5;
  if(blocked)return {...old,blocked:true,floorY:floorAt(floorHeight,old.x,old.z)};
  state.x=x;state.z=z;
  const drop=old.y-floor,continuousSlope=drop<=maxSlope*distance+.012;
  if(old.grounded&&(rise>=0||drop<=snapDown||continuousSlope)){
   state.y=floor;state.velocityY=0;state.grounded=true;
  }else{
   // Leaving a side edge is a fall, never a teleport to the ground sample.
   state.velocityY=old.velocityY-gravity*dt;state.y=old.y+old.velocityY*dt-gravity*dt*dt*.5;state.grounded=false;
   if(state.y<=floor){state.y=floor;state.velocityY=0;state.grounded=true}
  }
  return {...state,blocked:false,floorY:floor};
 }
 return {reset,canMove,update,get state(){return state?{...state}:null},limits:Object.freeze({stepHeight,maxSlope,gravity,probeSpacing,snapDown})};
}
