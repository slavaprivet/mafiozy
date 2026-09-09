// Window fire is presentation/admission only. The host retains ammo, authority,
// car physics and occupant identity. +X is the vehicle's driver/left side.
import {vehicleSeat} from './vehicle_seats.mjs';
import {weaponHeadClearance,findClearWeaponMount} from './hero_weapon_clearance.mjs';
const clamp=(v,a,b)=>Math.max(a,Math.min(b,v));
const finite=v=>Number.isFinite(v);
const paneVisibility=new WeakMap(),handCache=new WeakMap();
function seatDoor(car,seatId){return car?.doors?.get(seatId)||car?.doors?.get(seatId==='front_left'?1:seatId==='front_right'?-1:seatId)}
export function vehicleWindowFrame(THREE,car,seatId){
 const seat=vehicleSeat(seatId,car),door=seatDoor(car,seat.doorId);let pane=door?.getObjectByName('Fitted_door_glass_'+seat.doorId)||door?.getObjectByName('Door_window_'+seat.doorId);
 if(!pane)door?.traverse(n=>{if(!pane&&n.isMesh&&n.material?.transparent)pane=n});
 if(!pane)return null;
 car.object.updateMatrixWorld(true);const bounds=new THREE.Box3(),v=new THREE.Vector3(),a=pane.geometry?.attributes.position;if(!a)return null;
 for(let i=0;i<a.count;i++){v.fromBufferAttribute(a,i);pane.localToWorld(v);car.object.worldToLocal(v);bounds.expandByPoint(v)}
 return {seatId,side:seat.side,min:bounds.min.toArray(),max:bounds.max.toArray(),seat:seat.anchor,carWidth:car.profile?.width||1.94};
}
export function setVehicleWindowOpen(car,seatId,open,{restore=true}={}){
 const door=seatDoor(car,seatId);if(!door)return;
 door.traverse(n=>{if(!n.isMesh||!(n.userData.bodyWindow===seatId||n.name==='Door_window_'+seatId||n.material?.userData?.breakableGlass))return;
 if(open){if(!paneVisibility.has(n))paneVisibility.set(n,n.visible);n.visible=false;}
 else if(paneVisibility.has(n)){n.visible=restore?paneVisibility.get(n):false;paneVisibility.delete(n);}
 });
}
export function planVehicleWindowShot({vehicleState,seatId,aimDirection,weaponId,frame}={}){
 const fail=reason=>({allowed:false,reason,seatId});
 if(!frame||frame.seatId!==seatId)return fail('У этого места нет доступного окна');
 if(!weaponId||weaponId==='none')return fail('Выберите оружие');
 const d=aimDirection;if(!d||![d.x,d.y,d.z,vehicleState?.yaw].every(finite))return fail('Нет направления прицеливания');
 const length=Math.hypot(d.x,d.y,d.z);if(length<.001)return fail('Нет направления прицеливания');
 const direction={x:d.x/length,y:d.y/length,z:d.z/length},yaw=vehicleState.yaw,sin=Math.sin(yaw),cos=Math.cos(yaw);
 const localDirection={x:direction.x*cos-direction.z*sin,y:direction.y,z:direction.x*sin+direction.z*cos};
 // Only the occupant's own side. No muzzle can point through the cabin,
 // windscreen, opposite passenger or roof when the camera circles the car.
 if(localDirection.x*frame.side<.45||Math.abs(localDirection.y)>.50)return fail('Цельтесь наружу через своё окно');
 const y=frame.min[1]+(frame.max[1]-frame.min[1])*.66,z=clamp(frame.seat.front+.05,frame.min[2]+.16,frame.max[2]-.16),x=frame.side*(Math.max(Math.abs(frame.min[0]),Math.abs(frame.max[0]),frame.carWidth*.5)+.12);
 if(frame.max[1]-frame.min[1]<.22||frame.max[2]-frame.min[2]<.32)return fail('Окно слишком узкое');
 return {allowed:true,reason:'',seatId,side:frame.side,frame,direction,localDirection,localMuzzle:{x,y,z},aimYaw:Math.atan2(direction.x,direction.z),aimPitch:Math.asin(direction.y),weaponId};
}
function restHands(THREE,c){
 if(handCache.has(c.object))return handCache.get(c.object);const out={};
 for(const side of ['l','r']){const chain=[];for(let n=c.bones['hand_'+side];n&&n!==c.object;n=n.parent)chain.unshift(n);const q=new THREE.Quaternion();for(const n of chain)if(n!==c.visualPivot)q.multiply(c.rest[n.name]?.q||n.quaternion);out[side]=q;}
 handCache.set(c.object,out);return out;
}
/** Call after car.poseOccupant, once each frame (base pose resets the bones).
 * Keeps root, visual pivot, hips, legs and seat fixed. Returns a real muzzle
 * and direction; host must require canFire before spending ammunition.
 */
export function applyVehicleWindowPose(THREE,c,{plan,car,weapon,blend=1,headClearance}={}){
 const fail=reason=>({applied:false,canFire:false,reason});
 if(!plan?.allowed||!car?.object||!weapon?.isObject3D||!c?.reachPalm)return fail(plan?.reason||'Оружие недоступно');
 blend=clamp(blend,0,1);const side=plan.side,unit=c.targetHeight/1.9;
 c.rotateAdd('chest',-.10*blend,side*.92*blend,-side*.46*blend);
 c.rotateAdd('neck',.08*blend,side*.18*blend,side*.12*blend);c.rotateAdd('head',.02*blend,side*.12*blend,side*.15*blend);c.object.updateMatrixWorld(true);
 const data=weapon.userData||{},long=!!(weapon.twoHanded??data.twoHanded),shootingHand=long?'r':side>0?'l':'r',rest=restHands(THREE,c),scale=c.targetHeight/c.sourceHeight;
 const targetQ=new THREE.Quaternion().setFromEuler(new THREE.Euler(-plan.aimPitch,plan.aimYaw,0,'YXZ')),weaponQ=car.object.getWorldQuaternion(new THREE.Quaternion()).slerp(targetQ,blend);
 const palmQ=s=>weaponQ.clone().multiply(new THREE.Quaternion().setFromAxisAngle(new THREE.Vector3(1,0,0),-Math.PI/2)).multiply(rest[s]);
 const support=data.supportGrip||[0,.1,.62],grips=[[shootingHand,[0,-.13,-.02]],...(long?[['l',support]]:[])];
 const constraints=grips.map(([s,p])=>{const shoulder=c.worldPosition('upperarm_'+s),radius=shoulder.distanceTo(c.worldPosition('forearm_'+s))+c.worldPosition('forearm_'+s).distanceTo(c.worldPosition('hand_'+s))-.008*unit;
 return {center:shoulder.sub(new THREE.Vector3(...p).multiplyScalar(scale).applyQuaternion(weaponQ)).add(c.rest['socket_hand_'+s].p.clone().multiplyScalar(scale).applyQuaternion(palmQ(s))),radius};});
 const muzzleLocal=new THREE.Vector3(...(data.muzzle||[0,0,.5])).multiplyScalar(scale),desired=car.object.localToWorld(new THREE.Vector3(plan.localMuzzle.x,plan.localMuzzle.y,plan.localMuzzle.z)),origin=desired.clone().sub(muzzleLocal.clone().applyQuaternion(weaponQ));
 if(blend<1){const dock=c.worldPosition('socket_hand_'+shootingHand);origin.lerp(dock,1-blend);}
 for(let i=0;i<32;i++)for(const {center,radius}of constraints){const d=origin.clone().sub(center);if(d.length()>radius)origin.copy(center).add(d.setLength(radius));}
 const safe=findClearWeaponMount(THREE,c,weapon,{origin,quaternion:weaponQ,constraints,preferredSide:side});origin.copy(safe.origin);
 for(const [s,p]of grips)c.reachPalm(s,new THREE.Vector3(...p).multiplyScalar(scale).applyQuaternion(weaponQ).add(origin),palmQ(s));
 c.object.updateMatrixWorld(true);weapon.position.copy(weapon.parent.worldToLocal(origin.clone()));weapon.quaternion.copy(weapon.parent.getWorldQuaternion(new THREE.Quaternion()).invert().multiply(weaponQ));c.object.updateMatrixWorld(true);
 const muzzle=weapon.localToWorld(new THREE.Vector3(...(data.muzzle||[0,0,.5]))),direction=new THREE.Vector3(0,0,1).applyQuaternion(weapon.getWorldQuaternion(new THREE.Quaternion())),local=car.object.worldToLocal(muzzle.clone());
 const plane=Math.max(Math.abs(plan.frame.min[0]),Math.abs(plan.frame.max[0]));
 const reachable=constraints.every(({center,radius})=>origin.distanceTo(center)<=radius+.002),outside=side*local.x>plane+.012;
 // Ray from the actual gun mount to the actual muzzle, then forward. Only
 // opaque hull meshes count; the separately opened glass is not an obstacle.
 const solids=[];car.object.traverseVisible(n=>{if(n.isMesh&&!(Array.isArray(n.material)?n.material.some(m=>m.transparent):n.material?.transparent))solids.push(n)});
 const boreLength=Math.max(.12,muzzleLocal.z),boreStart=muzzle.clone().addScaledVector(direction,-boreLength);
 const ray=new THREE.Raycaster(boreStart,direction,.025,boreLength+.30),hits=ray.intersectObjects(solids,false);
 // Also cast backward so a barrel starting inside a one-sided panel cannot
 // escape through its back face without detecting that panel.
 const reverse=new THREE.Raycaster(muzzle.clone().addScaledVector(direction,.30),direction.clone().negate(),0,boreLength+.275);hits.push(...reverse.intersectObjects(solids,false));
 const ownCarClear=hits.length===0;
 const selfClear=weaponHeadClearance(THREE,c,weapon,{origin,quaternion:weaponQ}).clear&&(typeof headClearance!=='function'||!!headClearance({context:c,weapon,origin,muzzle,direction}));
 const canFire=blend>.98&&reachable&&outside&&ownCarClear&&selfClear;
 return {applied:true,canFire,reason:canFire?'':!reachable?'Не хватает места для оружия':!selfClear?'Оружие слишком близко к голове':!outside||!ownCarClear?'Ствол упирается в кузов':'Высовываем оружие',muzzle,direction,gunPosition:origin,reachable,outside,ownCarClear,selfClear,shootingHand,gripCount:grips.length,obstruction:hits[0]?.object.name};
}
