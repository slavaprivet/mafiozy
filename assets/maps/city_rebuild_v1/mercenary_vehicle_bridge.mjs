import {createNpcVehicleAccessResolver} from './npc_vehicle_access.mjs';

// Authored geometry only. The source squad host owns reservations and orders.
// Fleet ids have a namespace so they can never alias a source quest vehicle.
export function createMercenaryVehicleBridge({worldScale=4.1,getFleet=()=>null,getTraffic=()=>null,getPlayer=()=>null,canCross=()=>false}={}){
 const reservations=new Map();
 const accessActors=new WeakMap();
 const fleetRecord=id=>String(id).startsWith('fleet:')?getFleet()?.records?.find(r=>String(r.id)===String(id).slice(6)):null;
 const getActor=id=>fleetRecord(id)?.car||(!String(id).startsWith('fleet:')?getTraffic()?.getActor?.(id):null);
 function getAccessActor(id){
  const actor=getActor(id);if(!actor)return null;
  // Kingswell's frozen VEHICLE_SEATS uses the same implicit door defaults as
  // vehicleDoorPoint. Extend only this geometry view, never the shared seats.
  let cached=accessActors.get(actor);if(!cached||cached.originalSeats!==actor.seats){
   cached={originalSeats:actor.seats,object:actor.object,get profile(){return actor.profile;},seats:actor.seats?.map(seat=>({...seat,doorDistance:seat.doorDistance??1.9,doorFront:seat.doorFront??seat.anchor?.front}))};accessActors.set(actor,cached);
  }return cached;
 }
 const resolveAccess=createNpcVehicleAccessResolver({worldScale,traffic:{getActor:getAccessActor,setNpcAccess(id,phase,progress,seatId){
  if(String(id).startsWith('fleet:'))getActor(id)?.setDoorById?.(phase==='release'?0:phase==='board'||phase==='exit'?Math.sin(Math.PI*Math.max(0,Math.min(1,progress))):0,seatId);
  else getTraffic()?.setNpcAccess?.(id,phase,progress,seatId);
 }}});
 function access(request){const result=resolveAccess(request);return result&&[result.outside?.r,result.outside?.c,result.seat?.r,result.seat?.c].every(Number.isFinite)?result:null;}
 function getVehicle(id){
  const actor=getActor(id),o=actor?.object,record=fleetRecord(id);
  if(!o?.parent||![o.position.x,o.position.z,o.rotation.y].every(Number.isFinite)||!Array.isArray(actor.seats))return null;
  const player=getPlayer(),occupied=player?.id===id&&player.seatId?[player.seatId]:[];
  return {id:String(id),source:!String(id).startsWith('fleet:'),r:o.position.z/worldScale,c:o.position.x/worldScale,ang:Math.PI/2-o.rotation.y,
   seats:actor.seats.filter(s=>s.canDrive!==true&&s.id!=='front_left').map(s=>s.id),occupied,
   speed:Math.abs(Number(record?.state?.speed??o.userData?.sourceMotion?.speed??actor.speed)||0),blocked:!!(record?.damage?.state?.wrecked||record?.state?.waterState?.flooded),
   exiting:player?.id===id&&player.exiting===true};
 }
 return {getActor,getVehicle,access,
  isPlayerInVehicle:()=>!!getPlayer()?.id,
  getPlayerVehicle(){const p=getPlayer();return p?.id&&!p.exiting&&p.ready!==false?getVehicle(p.id):null;},
  canCross:(id,from,to)=>canCross(id,from,to)===true,
  setReservations(rows){reservations.clear();for(const row of rows){if(!row?.vehicleId||!row.seatId)continue;let seats=reservations.get(row.vehicleId);if(!seats)reservations.set(row.vehicleId,seats=new Set());seats.add(row.seatId);}},
  reservedSeats:id=>[...(reservations.get(String(id))||[])],
 };
}
