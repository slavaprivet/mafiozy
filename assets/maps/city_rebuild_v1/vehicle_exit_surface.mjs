import {createSurfaceMotion} from './surface_motion.mjs';

// Exit body motion owns horizontal inertia and the small visual hop. This
// controller owns only continuous world-height support, including water.
export function createVehicleExitSurface({position,groundHeight,waterAt=()=>null}){
  if(typeof groundHeight!=='function'||!position||![position.x,position.y,position.z].every(Number.isFinite))throw Error('Finite vehicle exit position and groundHeight required');
  const motion=createSurfaceMotion();let latest=null;
  const waterAtPoint=(x,z)=>{const water=waterAt(x,z);return water&&water.depth>0&&Number.isFinite(water.level)?water:null;};
  function floorHeight(x,z){
    const referenceY=motion.state?.y??position.y,floor=groundHeight(x,z,referenceY),water=waterAtPoint(x,z);
    if(!Number.isFinite(floor))throw Error('Finite exit support height required');
    // Keep a recovering actor at the surface until swimming can take ownership.
    return water?Math.max(floor,water.level-.05):floor;
  }
  const initialFloor=floorHeight(position.x,position.z),initialY=Math.max(position.y,initialFloor);
  motion.reset({...position,y:initialY},{grounded:initialY<=initialFloor+.02});
  latest={...motion.state,blocked:false,water:waterAtPoint(position.x,position.z),floorY:initialFloor};
  function update({x,z,dt,hop=0}){
    if(!Number.isFinite(hop)||hop<0)throw Error('Finite nonnegative exit hop required');
    const supported=motion.update({x,z,dt,floorHeight});
    latest={...supported,y:supported.y+hop,water:waterAtPoint(supported.x,supported.z)};
    return {...latest};
  }
  return {update,floorHeight,get state(){return {...latest};}};
}

// Full skin contact queries thousands of vertices. Sample the expensive world
// support at most once per grid node, keeping the budget independent of mesh
// detail. Cell maxima conservatively cover a rising plane or an axis-aligned
// step, without bilinear interpolation sinking vertices into the high side.
export function createExitPoseFloorSampler(position,floorHeight){
  if(!position||![position.x,position.z].every(Number.isFinite)||typeof floorHeight!=='function')throw Error('Finite exit pose position and floorHeight required');
  const spacing=.25,radius=1.8,extent=Math.ceil(radius/spacing),width=extent*2+1;
  const heights=new Float64Array(width*width),ready=new Uint8Array(width*width);
  const cells=new Float64Array((width-1)*(width-1)),cellReady=new Uint8Array(cells.length);
  const originX=position.x,originZ=position.z;let samples=0,queries=0,outside=0;
  function node(ix,iz){
    const index=(iz+extent)*width+ix+extent;
    if(!ready[index]){
      const value=floorHeight(originX+ix*spacing,originZ+iz*spacing);
      if(!Number.isFinite(value))throw Error('Finite exit pose floor required');
      heights[index]=value;ready[index]=1;samples++;
    }
    return heights[index];
  }
  function sample(x,z){
    if(!Number.isFinite(x)||!Number.isFinite(z))throw Error('Finite exit pose sample required');
    const dx=(x-originX)/spacing,dz=(z-originZ)/spacing;queries++;
    if(Math.abs(dx)>extent||Math.abs(dz)>extent)outside++;
    const ix=Math.max(-extent,Math.min(extent-1,Math.floor(dx))),iz=Math.max(-extent,Math.min(extent-1,Math.floor(dz)));
    const index=(iz+extent)*(width-1)+ix+extent;
    if(!cellReady[index]){cells[index]=Math.max(node(ix,iz),node(ix+1,iz),node(ix,iz+1),node(ix+1,iz+1));cellReady[index]=1;}
    return cells[index];
  }
  Object.defineProperty(sample,'stats',{get:()=>({samples,maxSamples:width*width,queries,outside,spacing,radius,coveredRadius:extent*spacing})});
  return sample;
}

// Swimming may still be warming its lift when the exit finishes. Blend from
// the known surface pose, never from the seabed value exposed by cold swim IK.
export function createExitSwimHandoff({fromY,waterLevel}){
  if(!Number.isFinite(fromY)||!Number.isFinite(waterLevel))throw Error('Finite exit swim handoff heights required');
  const minimum=waterLevel-1.05,start=Math.max(fromY,minimum),duration=.45;
  let elapsed=0,done=false,current=start;
  function update(targetY,dt){
    if(!Number.isFinite(targetY)||!Number.isFinite(dt)||dt<0)throw Error('Finite exit swim target and nonnegative timestep required');
    elapsed+=dt;
    const progress=Math.min(1,elapsed/duration),blend=progress*progress*(3-2*progress);
    const safeTarget=Math.max(minimum,targetY);
    const desired=Math.max(minimum,start+(safeTarget-start)*blend),maxStep=10*dt;
    current+=Math.max(-maxStep,Math.min(maxStep,desired-current));
    // A suddenly warm target may arrive on the final frame. Finish only after
    // reaching it, so removing the handoff cannot introduce a one-frame snap.
    done=elapsed>=duration&&targetY>=minimum&&Math.abs(current-targetY)<1e-8;
    return current;
  }
  return {update,get done(){return done;}};
}
