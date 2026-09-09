// Ground presentation for the existing vehicle solver. Steering, damage,
// inertia, contacts and roll state remain owned by the original controllers.
import {createCarWorld} from './car_drive.mjs';
export function createExplorationVehicleWorld({topology,bodies,terrain,metresPerCell=4.1}){
 const relativeBodies=bodies.map(body=>{
  if(!body.polygonCR?.length)return body;
  const x=body.polygonCR.reduce((s,p)=>s+p[0],0)/body.polygonCR.length*metresPerCell,z=body.polygonCR.reduce((s,p)=>s+p[1],0)/body.polygonCR.length*metresPerCell;
  const y=terrain?.contains(x,z)?terrain.groundHeight(x,z):0;
  return y?{...body,minYM:body.minYM-y,maxYM:body.maxYM-y}:body;
 });
 return createCarWorld(topology,relativeBodies,metresPerCell,{surfaceAt:(x,z)=>terrain?.contains(x,z)?terrain.canDrive(x,z):undefined});
}

export function sampleVehicleGround(THREE,state,terrain){
 const height=(x,z)=>terrain?.contains(x,z)?terrain.groundHeight(x,z):0;
 const {x,z,yaw}=state,hx=(height(x+1,z)-height(x-1,z))/2,hz=(height(x,z+1)-height(x,z-1))/2;
 const normal=new THREE.Vector3(-hx,1,-hz).normalize(),slope=new THREE.Quaternion().setFromUnitVectors(new THREE.Vector3(0,1,0),normal);
 const heading=new THREE.Quaternion().setFromAxisAngle(new THREE.Vector3(0,1,0),yaw),rotation=slope.clone().multiply(heading);
 let y=height(x,z);
 // Four wheel contact points, transformed by the slope before sampling the
 // actual terrain. Taking the highest support avoids a wheel cutting a crest.
 const contacts=state.vehicleProfile?.wheelPositions?Object.values(state.vehicleProfile.wheelPositions):[-.96,.96].flatMap(x=>[-1.35,1.3].map(z=>({x,z})));
 for(const contact of contacts){
  const p=new THREE.Vector3(contact.x,0,contact.z).applyQuaternion(rotation);
  y=Math.max(y,height(x+p.x,z+p.z)-p.y);
 }
 return {y,normal,slope,rotation};
}

export function poseVehicleOnLandscape(THREE,car,state,terrain,rollAngle=0){
 if(!car||!state)return;
 const support=sampleVehicleGround(THREE,state,terrain);
 const roll=new THREE.Quaternion().setFromAxisAngle(new THREE.Vector3(0,0,1),rollAngle);
 car.object.quaternion.copy(support.rotation).multiply(roll);
 // Preserve the original overturning model's lift above the support plane.
 const halfWidth=car.profile?.halfWidth??1.28,halfHeight=(car.profile?.height??2.16)/2;
 const lift=halfWidth*Math.abs(Math.sin(rollAngle))+halfHeight*Math.abs(Math.cos(rollAngle))-halfHeight*Math.cos(rollAngle);
 car.object.position.set(state.x,support.y+lift,state.z);
 car.object.updateWorldMatrix(true,false);
 return support;
}
