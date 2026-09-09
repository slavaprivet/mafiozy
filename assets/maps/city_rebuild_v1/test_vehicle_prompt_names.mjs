import test from 'node:test';
import assert from 'node:assert/strict';
import {readFileSync} from 'node:fs';
import vm from 'node:vm';
import {ARTIST_VEHICLE_PROFILES} from './vehicle_fleet_models.mjs';
const source=readFileSync(new URL('walk_preview.mjs',import.meta.url),'utf8').replaceAll('\r','');
const entrySource=source.slice(source.indexOf('function entrySpot('),source.indexOf('function entryEligible(){'));
test('the real E-entry candidate contains model name and seat, for all thirteen cars',()=>{
 for(const profile of [{id:'red_sedan',label:'Kingswell'},...ARTIST_VEHICLE_PROFILES])for(const seatLabel of ['Водитель','Передний пассажир']){
  const record={id:profile.id,car:{profile},state:{x:0,z:0,yaw:0,speed:0}};
  const context={hero:{object:{position:{x:1.9,z:0}}},carState:record.state,transition:null,jump:null,heroBlast:null,occupiedSeat:null,fleet:{nearby:()=>[record]},canWalk:()=>true,pedestrianAllowed:()=>true,circleFits:()=>true,findVehicleEntry:()=>({near:.1,label:seatLabel,seatId:'front_left',outside:{x:1.9,z:0}})};
  context.frameEntrySpot=undefined;
  vm.runInNewContext(entrySource+'\nresult=entrySpot()',context);
  assert.equal(context.result.label,profile.label+' · '+seatLabel);
  assert.equal(context.result.record,record);
 }
});
test('visible prompt uses the chosen model, not the previously driven car',()=>{
 const prompt=source.slice(source.indexOf('function updateCarPrompt(){'),source.indexOf('function waterAt('));
 assert.match(prompt,/textContent=service\?`\$\{candidate.record.car.profile.label\} · \$\{candidate.label\}`:selected.label/);
 assert.match(prompt,/const owner=selected.record.car/);
 assert.equal(new Set(ARTIST_VEHICLE_PROFILES.map(p=>p.label)).size,12);
});

test('all thirteen display names use the approved fictional 1990s setting',()=>{
 const expected=['Brooklyn SX','Easton S','Brooklyn LX','Bellhaven V8','Ravelli GT','Blackridge','Union Van','Ironvale','Metroline 90','Patrol LX','Union Medic','Ironvale F'];
 assert.deepEqual(ARTIST_VEHICLE_PROFILES.map(profile=>profile.label),expected);
 assert.match(source,/id:'red_sedan',label:'Kingswell'/);
 for(const name of expected)assert(name.length<=12);
});
