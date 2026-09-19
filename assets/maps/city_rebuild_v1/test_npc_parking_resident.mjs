import fs from 'node:fs';import vm from 'node:vm';import assert from 'node:assert/strict';
const code=fs.readFileSync(new URL('npc_parking_resident_source.js',import.meta.url),'utf8');
let native=false;const car={id:'parked'},look={hair:3,skin:2},live={r:4,c:8,look,car,hp:29,max_hp:60,life:1,state:'returning',_fear:.7},dead={id:'known',r:3,c:7,look,car,dead:true,hp:0,life:2},later={r:6,c:9,car,look,life:4};
const e={performance:{now:()=>1000},_walkRendererActive:()=>native,_parkingNpcs:[live,dead,later],NPCS:[],NPC_ARCHETYPES:{worker:{}},_residentSerial:0,
 _threeParkingNpcView:p=>({id:p.id||'parking_stable'}),_threeVehicleEntityId:p=>p.id,_initNpcEmotions:p=>{p._fear=.1;}};
vm.createContext(e);vm.runInContext(code,e);
assert.equal(e._nativeParkingResidents(),false);assert.equal(e._parkingNpcs.length,3,'Legacy renderer behavior is retained');
native=true;assert.equal(e._nativeParkingResidents(),true);assert.equal(e._parkingNpcs.length,1,'At most two conversions per tick');assert.equal(e.NPCS.length,2);
assert.equal(e.NPCS[0],live,'Keep the same damageable source object');assert.equal(live.id,'parking_stable','Keep the presentation identity');assert.equal(live.look,look);assert.equal(live.hp,29);assert.equal(live._fear,.7);assert.equal(live.r,4);assert.equal(live.c,8,'No migration teleport');assert.equal(live._parkingResidentCarId,'parked');assert.equal(dead.hp,0);assert.equal(dead.dead,true);
e._nativeParkingResidents();e._nativeParkingResidents();assert.equal(e.NPCS.length,3);assert.equal(e._parkingNpcs.length,0,'No stale decorative reservations or duplicate actors');
const world=fs.readFileSync(new URL('../../../world.html',import.meta.url),'utf8');assert(world.includes(code.trim()),'Production mirrors the tested source');
assert.match(world,/function _tickParkingNpcs\(dt\) \{\s*if\(_nativeParkingResidents\(\)\)return;/);assert.match(world,/function _spawnParkingNpc\(\) \{\s*if\(_nativeParkingResidents\(\)\)return;/);
console.log('PASS native parking residents: same IDs/objects/look/HP/positions, death retained, bounded migration and no ghost reservation');
