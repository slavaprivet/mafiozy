import {trafficActorBlocks} from './world_traffic_presentation.mjs';

// A save/load or newly streamed car can start around the pedestrian. Permit
// only a requested step toward that car's nearest exterior face; the caller
// still checks every world obstacle and every other car along the full step.
export function sourceVehicleEscapeId(traffic,position,delta,radius=.36){
 if(!position||!delta||Math.hypot(delta.x,delta.z)<1e-8)return null;
 for(const {id,actor,object} of traffic?.getActors()||[]){
  if(!trafficActorBlocks(actor,position.x,position.z,radius,{y:position.y,height:1.9}))continue;
  const profile=actor.profile||object.userData.vehicleProfile,c=Math.cos(object.rotation.y),s=Math.sin(object.rotation.y),dx=position.x-object.position.x,dz=position.z-object.position.z;
  const x=dx*c-dz*s,z=dx*s+dz*c,moveX=delta.x*c-delta.z*s,moveZ=delta.x*s+delta.z*c;
  const w=profile.halfWidth*Math.abs(object.scale?.x??1)+radius,l=profile.halfLength*Math.abs(object.scale?.z??1)+radius;
  const faces=[{depth:w-x,along:moveX},{depth:w+x,along:-moveX},{depth:l-z,along:moveZ},{depth:l+z,along:-moveZ}];
  const nearest=Math.min(...faces.map(f=>f.depth));
  if(faces.some(f=>f.depth<=nearest+.02&&f.along>1e-6))return id;
 }
 return null;
}
