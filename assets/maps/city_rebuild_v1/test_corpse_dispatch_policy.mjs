import fs from 'node:fs';import vm from 'node:vm';import assert from 'node:assert/strict';
const source=fs.readFileSync(new URL('../../../world.html',import.meta.url),'utf8');
function fn(name){const start=source.indexOf('function '+name+'(');assert(start>=0,name);const end=source.indexOf('\n}',start);assert(end>start);return source.slice(start,end+2);}
let now=0,fleetReads=0;const box={performance:{now:()=>now},Number,Math,
 _npcCorpseEmsReported:n=>Number.isFinite(n._corpseEmsReportAt)&&n._corpseEmsReportAt>=n.deadAt&&n._corpseEmsIncidentAt===n.deadAt,
 _ensureAmbulanceFleet:()=>{fleetReads++;return [];}};
vm.createContext(box);vm.runInContext(source.match(/const CORPSE_AUTO_REMOVE_MS = \d+;/)[0]+fn('_corpseRemovalDue')+fn('spawnAmbulance'),box);
const body={dead:true,hp:0,deadAt:0};now=299999;assert(!box._corpseRemovalDue(body,now));now=300000;assert(box._corpseRemovalDue(body,now));
for(const field of ['_carriedByAmbulance','_ambulanceLoading','_ambulanceInTransit','_evacuated'])assert(!box._corpseRemovalDue({...body,[field]:true},now),field+' protects ongoing physical handling');
assert(!box._corpseRemovalDue({...body,_vehicleHijack:{phase:'pulled'}},now));assert(box._corpseRemovalDue({...body,_vehicleHijack:{phase:'released'}},now));
assert(!box._corpseRemovalDue({...body,dead:false},now));assert(!box._corpseRemovalDue({...body,deadAt:NaN},now));
now=10000;assert.equal(box.spawnAmbulance(0,0,body),null);assert.equal(fleetReads,0,'Unseen body cannot even start dispatch');
box.spawnAmbulance(0,0,{...body,_corpseEmsReportAt:9000,_corpseEmsIncidentAt:1});assert.equal(fleetReads,0,'A previous death report cannot report another incident');
box.spawnAmbulance(0,0,{...body,_corpseEmsReportAt:9000,_corpseEmsIncidentAt:0});assert.equal(fleetReads,1,'Completed current call enables existing fleet scheduling');
box.spawnAmbulance(0,0,{_medicalDowned:true,hp:1});assert.equal(fleetReads,2,'Living wounded retain their existing medical contract');
now=300000;box.spawnAmbulance(0,0,{...body,_corpseEmsReportAt:9000,_corpseEmsIncidentAt:0});assert.equal(fleetReads,2,'Expired body cannot start another call');
assert.match(source,/const ambulanceQueue=NPCS\.filter\(n=>\(n\.dead\?_npcCorpseEmsReported\(n\):n\._medicalDowned\)/);
assert(!fn('_interpBeachgoers').includes('b.dead=false;b.hp=b.max_hp||60'),'Five-minute expiration never revives beach bodies');
console.log('PASS actual corpse dispatch gate and five-minute expiry, carried/extracted bodies protected, no timeout revival');
