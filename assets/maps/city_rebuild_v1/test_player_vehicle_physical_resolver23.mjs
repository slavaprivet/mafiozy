import assert from 'node:assert/strict';
import {createPlayerVehiclePhysicalResolver} from './player_vehicle_physical_resolver.mjs';

const active={active:true,driving:true,canDrive:true,passenger:false,phase:'driving',seatId:'front_left',presentationCarId:'quest_42',x:20,y:10};
let state=active,calls=0;
const resolve=createPlayerVehiclePhysicalResolver({getVehicleState:()=>state,queryPhysical:request=>{calls++;return {clear:true,from:request.from,to:request.to};}});
const request={mode:'player-physical',carId:'quest_42',from:{r:10,c:20,angle:0},to:{r:10,c:20.2,angle:0}};
assert.equal(resolve(request).clear,true);assert.equal(calls,1,'bound current driver reaches private geometry query once');
assert.equal(resolve({...request,mode:'sweep'}).reason,'invalid_player_physical_request');
assert.equal(resolve({...request,carId:'quest_43'}).reason,'player_vehicle_mismatch');
assert.equal(resolve({...request,from:{r:10,c:20.3,angle:0}}).reason,'player_vehicle_stale_origin');
for(const patch of [{active:false},{driving:false},{canDrive:false},{passenger:true},{phase:'exit'},{seatId:'front_right'}]){state={...active,...patch};assert.equal(resolve(request).reason,'player_vehicle_unbound');}
state=active;const failing=createPlayerVehiclePhysicalResolver({getVehicleState:()=>state,queryPhysical:()=>{throw Error('not ready');}});assert.equal(failing(request).reason,'player_vehicle_navigation_not_ready');
assert.equal(calls,1,'denied or failed requests never reuse a successful physical result');
console.log('PASS private player physical sweep requires the current source car, driver seat and fresh origin');
