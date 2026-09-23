const denied=reason=>({clear:false,status:'blocked',reason});

// This is the only entry to geometry-only vehicle sweeps. It binds the caller
// to the source bridge's currently occupied driver seat and current car pose;
// npc_vehicle_navigation.query never accepts a request flag that bypasses
// semantic road, parking, driveway or service-access policy.
export function createPlayerVehiclePhysicalResolver({getVehicleState,queryPhysical,maxOriginDrift=.15}={}){
 if(typeof getVehicleState!=='function'||typeof queryPhysical!=='function')throw new TypeError('Player vehicle state and physical query are required');
 return function resolve(request={}){
  if(request.mode!=='player-physical')return denied('invalid_player_physical_request');
  let state;try{state=getVehicleState();}catch{return denied('player_vehicle_unbound');}
  if(!state?.active||!state.driving||state.canDrive!==true||state.passenger||state.phase!=='driving'||state.seatId!=='front_left')return denied('player_vehicle_unbound');
  if(!request.carId||String(request.carId)!==String(state.presentationCarId))return denied('player_vehicle_mismatch');
  const r=Number.isFinite(state.y)?state.y:state.r,c=Number.isFinite(state.x)?state.x:state.c,from=request.from;
  if(!from||![r,c,from.r,from.c].every(Number.isFinite)||Math.hypot(from.r-r,from.c-c)>Math.max(.01,maxOriginDrift))return denied('player_vehicle_stale_origin');
  try{return queryPhysical(request)||denied('player_vehicle_navigation_not_ready');}catch{return denied('player_vehicle_navigation_not_ready');}
 };
}
