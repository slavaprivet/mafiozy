// A vehicle must exist in the rendered scene before an NPC can bind to its seat.
// The traffic adapter owns a stable scratch point: seat binding is synchronous,
// so every NPC pose can reuse it without exposing a shared gameplay position.
export function createNpcTrafficVehicleBinding({THREE,actor}={}){
 if(!THREE?.Vector3||!actor?.object?.isObject3D)return null;
 const anchor=actor.seats?.find(seat=>seat.id==='front_left')?.anchor,driverRoot=new THREE.Vector3();
 return {object:actor.object,get yaw(){return actor.object.rotation.y;},getDriverRootWorld(){
  if(!anchor)return null;actor.object.updateWorldMatrix(true,false);return actor.object.localToWorld(driverRoot.set(anchor.side,anchor.y,anchor.front));
 },getSeatRootWorld(seatId='front_left'){
  const target=actor.seats?.find(seat=>seat.id===seatId)?.anchor;if(!target)return null;actor.object.updateWorldMatrix(true,false);return actor.object.localToWorld(driverRoot.set(target.side,target.y,target.front));
 },poseOccupant(walker,seatId,options){return actor.poseOccupant(walker,seatId,options);}};
}
export function resolveNpcVehicleBinding(source,getVehicle){
 const phase=source?.civilianTripPhase,transition=phase==='board'||phase==='exit';
 if((!source?.civilianTripRiding&&!transition)||!source.civilianTripCarId||typeof getVehicle!=='function')return null;
 const vehicle=getVehicle(String(source.civilianTripCarId));if(!vehicle?.object?.isObject3D||!vehicle.object.parent)return null;
 for(let node=vehicle.object;node;node=node.parent)if(!node.visible)return null;
 const seatId=source.vehicleSeatId||'front_left';
 const rootSeat=typeof vehicle.getSeatRootWorld==='function'?vehicle.getSeatRootWorld(seatId):seatId==='front_left'?(typeof vehicle.getDriverRootWorld==='function'?vehicle.getDriverRootWorld():vehicle.driverRootWorld):null;
 const seat=rootSeat||(seatId==='front_left'?(typeof vehicle.getDriverSeatWorld==='function'?vehicle.getDriverSeatWorld():vehicle.driverSeatWorld):null);
 if(!seat||![seat.x,seat.y,seat.z,vehicle.yaw].every(Number.isFinite))return null;
 return {vehicle,seat,seatId,yaw:vehicle.yaw,rootSeat:!!rootSeat,phase,progress:Math.max(0,Math.min(1,Number(source.civilianTripProgress)||0)),transition};
}
export function applyNpcVehicleBinding({THREE,walker,binding,dt}){
 const c=walker.artistContext();
 if(binding.rootSeat&&typeof binding.vehicle.poseOccupant==='function'){
 const position=c.object.position.clone(),quaternion=c.object.quaternion.clone();
  const fold=binding.transition?(binding.phase==='board'?binding.progress:1-binding.progress):1;
  const sourceYaw=c.object.rotation.y,seatYaw=sourceYaw+Math.atan2(Math.sin(binding.yaw-sourceYaw),Math.cos(binding.yaw-sourceYaw))*fold;
  // During the door crossing the source root advances continuously. Snapping
  // to the seat here used to erase that motion and hide the entire entry.
  // Blend the facing as well: a side-on approach must not rotate every limb
  // to the car axis in the zero-progress boarding frame.
  c.object.position.set(binding.transition?position.x:binding.seat.x,position.y+(binding.seat.y-position.y)*fold,binding.transition?position.z:binding.seat.z);c.object.rotation.set(0,seatYaw,0);c.object.updateMatrixWorld(true);
  const gripUnit=Math.max(0,Math.min(1,(fold-.62)/.38)),gripBlend=gripUnit*gripUnit*(3-2*gripUnit);
  binding.vehicle.poseOccupant(walker,binding.seatId||'front_left',{fold,...(binding.transition?{gripBlend}:{}),reach:binding.transition?Math.sin(binding.progress*Math.PI)*.65:0,dt,steer:binding.vehicle.steer||0});c.object.updateMatrixWorld(true);
  const visualWorld=c.visualPivot.matrixWorld.clone();c.object.position.copy(position);c.object.quaternion.copy(quaternion);c.object.updateMatrixWorld(true);
  visualWorld.premultiply(c.object.matrixWorld.clone().invert());visualWorld.decompose(c.visualPivot.position,c.visualPivot.quaternion,c.visualPivot.scale);c.object.updateMatrixWorld(true);return;
 }
 walker.vehiclePose(1,0,{driver:true,dt,steer:binding.vehicle.steer||0});
 c.visualPivot.rotation.y=Math.atan2(Math.sin(binding.yaw-c.object.rotation.y),Math.cos(binding.yaw-c.object.rotation.y));c.object.updateMatrixWorld(true);
 const hips=c.worldPosition('thigh_l').add(c.worldPosition('thigh_r')).multiplyScalar(.5),target=new THREE.Vector3(binding.seat.x,binding.seat.y,binding.seat.z);
 const delta=target.sub(hips).applyQuaternion(c.object.getWorldQuaternion(new THREE.Quaternion()).invert());c.visualPivot.position.add(delta);c.object.updateMatrixWorld(true);
 const grips=typeof binding.vehicle.getSteeringWheelWorld==='function'?binding.vehicle.getSteeringWheelWorld():binding.vehicle.steeringWheel;
 for(const [side,key]of [['l','left'],['r','right']]){const p=grips?.[key];if(p&&[p.x,p.y,p.z].every(Number.isFinite))c.reachPalm(side,new THREE.Vector3(p.x,p.y,p.z),c.bones['hand_'+side].getWorldQuaternion(new THREE.Quaternion()));}
 c.object.updateMatrixWorld(true);
}

