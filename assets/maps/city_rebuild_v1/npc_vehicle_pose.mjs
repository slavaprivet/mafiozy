// A vehicle must exist in the rendered scene before an NPC can bind to its seat.
// The traffic adapter owns a stable scratch point: seat binding is synchronous,
// so every NPC pose can reuse it without exposing a shared gameplay position.
export function createNpcTrafficVehicleBinding({THREE,actor}={}){
 if(!THREE?.Vector3||!actor?.object?.isObject3D)return null;
 const anchor=actor.seats?.find(seat=>seat.id==='front_left')?.anchor,driverRoot=new THREE.Vector3(),doorHandle=new THREE.Vector3();
 return {actor,object:actor.object,get yaw(){return actor.object.rotation.y;},getSeat(seatId='front_left'){return actor.seats?.find(seat=>seat.id===seatId)||null;},getDriverRootWorld(){
  if(!anchor)return null;actor.object.updateWorldMatrix(true,false);return actor.object.localToWorld(driverRoot.set(anchor.side,anchor.y,anchor.front));
 },getSeatRootWorld(seatId='front_left'){
  const target=actor.seats?.find(seat=>seat.id===seatId)?.anchor;if(!target)return null;actor.object.updateWorldMatrix(true,false);return actor.object.localToWorld(driverRoot.set(target.side,target.y,target.front));
 },getDoorHandleWorld(seatId='front_left'){return actor.getDoorHandleWorld?.(seatId,doorHandle)||null;},poseOccupant(walker,seatId,options={}){
  if(typeof actor.poseOccupant==='function')return actor.poseOccupant(walker,seatId,options);
  const seat=actor.seats?.find(s=>s.id===seatId);if(!seat)return;
  return walker.vehiclePose(options.fold??1,options.reach??0,{...options,driver:seat.canDrive===true,steeringGrips:seat.canDrive===true?actor.getSteeringGrips?.():undefined});
 }};
}
export function resolveNpcVehicleBinding(source,getVehicle){
 const phase=source?.civilianTripPhase,transition=phase==='board'||phase==='exit';
 if((!source?.civilianTripRiding&&!transition)||!source.civilianTripCarId||typeof getVehicle!=='function')return null;
 const vehicle=getVehicle(String(source.civilianTripCarId));if(!vehicle?.object?.isObject3D||!vehicle.object.parent)return null;
 for(let node=vehicle.object;node;node=node.parent)if(!node.visible)return null;
 const seatId=source.vehicleSeatId||'front_left',seatMeta=typeof vehicle.getSeat==='function'?vehicle.getSeat(seatId):null;
 const rootSeat=typeof vehicle.getSeatRootWorld==='function'?vehicle.getSeatRootWorld(seatId):seatId==='front_left'?(typeof vehicle.getDriverRootWorld==='function'?vehicle.getDriverRootWorld():vehicle.driverRootWorld):null;
 const seat=rootSeat||(seatId==='front_left'?(typeof vehicle.getDriverSeatWorld==='function'?vehicle.getDriverSeatWorld():vehicle.driverSeatWorld):null);
 if(!seat||![seat.x,seat.y,seat.z,vehicle.yaw].every(Number.isFinite))return null;
 return {vehicle,seat,seatId,side:seatMeta?.side,canDrive:seatMeta?.canDrive,yaw:vehicle.yaw,rootSeat:!!rootSeat,phase,progress:Math.max(0,Math.min(1,Number(source.civilianTripProgress)||0)),transition};
}
const seatPoseScratch=new WeakMap();
const newSeatPoseScratch=T=>({position:new T.Vector3(),quaternion:new T.Quaternion(),sourcePoint:new T.Vector3(),seatPoint:new T.Vector3(),seatQuaternion:new T.Quaternion(),carQuaternion:new T.Quaternion(),parentQuaternion:new T.Quaternion(),visualWorld:new T.Matrix4(),inverseWorld:new T.Matrix4()});
export function applyNpcVehicleBinding({THREE,walker,binding,dt}){
 const c=walker.artistContext();
 if(binding.rootSeat&&typeof binding.vehicle.poseOccupant==='function'){
  let pool=seatPoseScratch.get(walker);
  if(!pool){pool={depth:0,slots:[]};seatPoseScratch.set(walker,pool);}
  // Keep the usual and one nested callback allocation-free after warmup.
  // Deeper reentry uses independent temporary storage, never the outer root.
  const scratch=pool.depth<2?(pool.slots[pool.depth]??=newSeatPoseScratch(THREE)):newSeatPoseScratch(THREE);pool.depth++;
  try{
  const {position,quaternion,sourcePoint,seatPoint,seatQuaternion,carQuaternion,parentQuaternion,visualWorld,inverseWorld}=scratch;
  position.copy(c.object.position);quaternion.copy(c.object.quaternion);
  const fold=binding.transition?(binding.phase==='board'?binding.progress:1-binding.progress):1;
  c.object.getWorldPosition(sourcePoint);seatPoint.set(binding.transition?sourcePoint.x:binding.seat.x,sourcePoint.y+(binding.seat.y-sourcePoint.y)*fold,binding.transition?sourcePoint.z:binding.seat.z);
  c.object.getWorldQuaternion(seatQuaternion).slerp(binding.vehicle.object.getWorldQuaternion(carQuaternion),fold);
  // Both seat anchors and the car rotation are world-space. Convert the
  // temporary pose through the actor parent, then restore authority below.
  if(c.object.parent){c.object.parent.worldToLocal(seatPoint);seatQuaternion.premultiply(c.object.parent.getWorldQuaternion(parentQuaternion).invert());}
  // During the door crossing the source root advances continuously. Snapping
  // to the seat here used to erase that motion and hide the entire entry.
  // Blend the facing as well: a side-on approach must not rotate every limb
  // to the car axis in the zero-progress boarding frame.
  c.object.position.copy(seatPoint);c.object.quaternion.copy(seatQuaternion);c.object.updateMatrixWorld(true);
  const gripUnit=Math.max(0,Math.min(1,(fold-.62)/.38)),gripBlend=gripUnit*gripUnit*(3-2*gripUnit),doorUnit=Math.max(0,Math.min(1,binding.progress/.55)),doorRelease=Math.max(0,Math.min(1,(binding.progress-.45)/.55)),doorGripBlend=.55*doorUnit*doorUnit*(3-2*doorUnit)*(1-doorRelease*doorRelease*(3-2*doorRelease)),doorGrip=binding.transition&&doorGripBlend>0?binding.vehicle.getDoorHandleWorld?.(binding.seatId):null;
  binding.vehicle.poseOccupant(walker,binding.seatId||'front_left',{fold,...(binding.transition?{side:binding.side,driver:binding.canDrive,gripBlend,doorGrip,doorGripBlend}:{}),reach:binding.transition?Math.sin(binding.progress*Math.PI)*.65:0,dt,steer:binding.vehicle.steer||0});c.object.updateMatrixWorld(true);
  visualWorld.copy(c.visualPivot.matrixWorld);c.object.position.copy(position);c.object.quaternion.copy(quaternion);c.object.updateMatrixWorld(true);
  visualWorld.premultiply(inverseWorld.copy(c.object.matrixWorld).invert());visualWorld.decompose(c.visualPivot.position,c.visualPivot.quaternion,c.visualPivot.scale);c.object.updateMatrixWorld(true);return;
  }finally{pool.depth--;}
 }
 walker.vehiclePose(1,0,{driver:true,dt,steer:binding.vehicle.steer||0});
 c.visualPivot.rotation.y=Math.atan2(Math.sin(binding.yaw-c.object.rotation.y),Math.cos(binding.yaw-c.object.rotation.y));c.object.updateMatrixWorld(true);
 const hips=c.worldPosition('thigh_l').add(c.worldPosition('thigh_r')).multiplyScalar(.5),target=new THREE.Vector3(binding.seat.x,binding.seat.y,binding.seat.z);
 const delta=target.sub(hips).applyQuaternion(c.object.getWorldQuaternion(new THREE.Quaternion()).invert());c.visualPivot.position.add(delta);c.object.updateMatrixWorld(true);
 const grips=typeof binding.vehicle.getSteeringWheelWorld==='function'?binding.vehicle.getSteeringWheelWorld():binding.vehicle.steeringWheel;
 for(const [side,key]of [['l','left'],['r','right']]){const p=grips?.[key];if(p&&[p.x,p.y,p.z].every(Number.isFinite))c.reachPalm(side,new THREE.Vector3(p.x,p.y,p.z),c.bones['hand_'+side].getWorldQuaternion(new THREE.Quaternion()));}
 c.object.updateMatrixWorld(true);
}

