// Read-only parking lifetime audit against authored static scene and source gates.
import fs from 'node:fs';
import vm from 'node:vm';
import {createCivilianNativeFixture} from './test_civilian_native_fixture.mjs';
const f=await createCivilianNativeFixture(),{box,car,M}=f;
const shape={halfLength:(f.actor.profile.collisionHalfLength??f.actor.profile.halfLength)/M,halfWidth:(f.actor.profile.collisionHalfWidth??f.actor.profile.halfWidth)/M};
Object.assign(car,{_nativeParkingShape:shape});
const slots=f.lanes.query({mode:'parking-anchors'}).slots,rows=[];
for(const slot of slots){
 Object.assign(car,{r:slot.r,c:slot.c,ang:slot.angle});f.syncCar();f.pedestrian.beginFrame();f.nav.beginFrame();
 const body=f.nav.query({carId:car.id,from:slot,to:slot,roadsOnly:false});if(!body.clear)continue;
 const a=f.access({carId:car.id});if(!a)continue;
 const outside=f.pedestrian.query({r:a.outside.r,c:a.outside.c,ignoreVehicleId:car.id}),trip={npc:{r:a.seat.r,c:a.seat.c},carId:car.id,car};
 const clear=box._civilianTripDoorPath(trip,a.seat.r,a.seat.c,a.outside.r,a.outside.c),free=box._civilianTripParkingPoseFree(car,slot);
 rows.push({id:slot.id,lotId:slot.lotId,slot:{r:slot.r,c:slot.c,angle:slot.angle},size:{width:slot.widthM,length:slot.lengthM},free,bodyClear:body.clear,doorClear:clear,access:structuredClone(a),outside});
}
const result={shape,slots:slots.length,clearCarRows:rows.length,blockedDriverExit:rows.filter(r=>r.free&&!r.doorClear),limits:f.limits};
fs.writeFileSync(new URL('../../../outputs/npc_parking_egress23_audit.json',import.meta.url),JSON.stringify(result,null,2));console.log(JSON.stringify(result,null,2));
