// Actual access/hull functions, native profile; no GLB load or renderer.
import fs from 'node:fs';
import assert from 'node:assert/strict';
import {createNpcVehicleAccessResolver} from './npc_vehicle_access.mjs';
import {trafficActorBlocks} from './world_traffic_presentation.mjs';
import {ARTIST_VEHICLE_PROFILE_BY_ID} from './vehicle_fleet_models.mjs';
const profile=ARTIST_VEHICLE_PROFILE_BY_ID.compact_sedan;
assert(profile);
const actor={profile,object:{parent:{},position:{x:82,y:0,z:82},rotation:{y:0},scale:{x:1,y:1,z:1}},
 seats:[{id:'front_left',side:1,doorDistance:profile.halfWidth+.57,doorFront:.5,anchor:{side:.4,front:.4}}]};
const access=createNpcVehicleAccessResolver({traffic:{getActor:()=>actor}}),rows=[];
for(const degrees of [0,15,30,45,60,75,90,135,180,225,270,315])for(const side of [-1,1]){
 actor.object.rotation.y=degrees*Math.PI/180;actor.seats[0].side=side;
 const point=access({carId:'probe'}).outside;
 const contacts=[];
 for(const [dr,dc] of [[0,0],[-.18,-.18],[-.18,.18],[.18,-.18],[.18,.18]]){
  const x=(point.c+dc)*4.1,z=(point.r+dr)*4.1;
  if(trafficActorBlocks(actor,x,z,0,{y:0,height:1.9}))contacts.push({dr,dc});
 }
 rows.push({degrees,side,contacts,outside:{...point}});
}
fs.writeFileSync(new URL('../../../outputs/npc_vehicle_outside_yaw_20260913.json',import.meta.url),JSON.stringify({scenario:'Production access/hull + compact_sedan profile and current authored halfWidth+.57 door convention; source world-axis .18 body; no GLB/GPU',rows},null,2));
console.log(JSON.stringify(rows.map(({degrees,side,contacts})=>({degrees,side,contacts}))));
assert(rows.every(row=>row.contacts.length===0),'authored outside must clear its own car for all five source body points at every heading');
console.log('PASS NPC outside body clearance at 12 headings and both sides');
