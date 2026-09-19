import {vehicleCoverPolygon} from './vehicle_cover_edges.mjs';
import {vehicleOpaqueCoverHeight} from './hero_cover_contact.mjs';

// Read the same native actors that render source-world traffic. Never create
// fleet cars or acquire source ownership just to collide with/take cover at one.
export function sourceVehicleCoverBodies(THREE,traffic,position){
 const bodies=[];
 for(const {id,actor,object} of traffic?.getActors()||[]){
  const profile=actor?.profile||object?.userData?.vehicleProfile,motion=object?.userData?.sourceMotion;
  if(!object?.parent||object.visible===false||!profile||Math.hypot(object.position.x-position.x,object.position.z-position.z)>8||Math.abs(motion?.speed||0)>.25||Math.abs(motion?.turnRate||0)>.08)continue;
  const x=object.position.x,z=object.position.z,yaw=object.rotation.y,scaled={...profile,halfWidth:profile.halfWidth*Math.abs(object.scale.x),halfLength:profile.halfLength*Math.abs(object.scale.z)};
  object.updateWorldMatrix(true,true);const bounds=new THREE.Box3().setFromObject(object);
  bodies.push({id:`source-vehicle:${id}`,polygon:vehicleCoverPolygon(x,z,yaw,scaled),standOff:.37,minY:bounds.min.y,maxY:bounds.max.y,vehicle:true,source:{car:actor},
   heightAt:(p,normal)=>vehicleOpaqueCoverHeight(THREE,object,{position:p,normal,maxHeight:Math.min(3.5,bounds.max.y-p.y+.1)}).topY,
   valid:()=>traffic.getActor(id)===actor&&!!object.parent&&object.visible!==false&&Math.hypot(object.position.x-x,object.position.z-z)<.12&&Math.abs(Math.atan2(Math.sin(object.rotation.y-yaw),Math.cos(object.rotation.y-yaw)))<.05&&Math.abs(object.userData.sourceMotion?.speed||0)<.35});
 }
 return bodies;
}
