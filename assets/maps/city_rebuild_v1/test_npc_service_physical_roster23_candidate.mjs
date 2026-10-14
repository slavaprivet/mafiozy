import assert from 'node:assert/strict';
import fs from 'node:fs';
import vm from 'node:vm';
import {performance} from 'node:perf_hooks';
import {servicePhysicalRosterWorldCandidate} from '../../../npc_service_physical_roster23_patch_candidate.mjs';

const source=fs.readFileSync(new URL('../../../world.html',import.meta.url),'utf8').replace(/\r\n/g,'\n');
const patched=servicePhysicalRosterWorldCandidate(source);
const functionText=(text,name)=>{const at=text.indexOf('function '+name+'(');assert.ok(at>=0,name);const stop=text.indexOf('\n}',at);assert.ok(stop>at,name);return text.slice(at,stop+2);};
const helper=functionText(patched,'_getWalkServicePhysicalBodies23');
new vm.Script(helper);
const rendererTail=text=>text.slice(text.indexOf('  getDynamicEntities(radius'));
assert.equal(rendererTail(patched),rendererTail(source),'existing renderer method and subsequent runtime remain byte-identical');
assert.throws(()=>servicePhysicalRosterWorldCandidate(patched),/anchor changed/);
assert.ok(servicePhysicalRosterWorldCandidate(source.replace(/\n/g,'\r\n')).includes('\r\n'));
let passed=0;
function fixture(extra={}){
 let now=100000;
 const ctx=vm.createContext({performance:{now:()=>now},prevT:77,NPCS:[],CARS:[],_buildingInt:null,_bankInt:null,
  _customGang:null,_murderPoliceArrest:null,CORPSE_AUTO_REMOVE_MS:300000,...extra});
 vm.runInContext('const _threeNpcIds=new WeakMap();let _threeNpcIdSeq=0;const _threeBusPersonIds=new WeakMap();const _threeBusPersonSeq={bus_rider:0,bus_waiter:0};',ctx);
 for(const name of ['_threeNpcEntityId','_threeBusPersonView','_threeParkingNpcView','_corpseRemovalDue','_beachgoerWorldPos'])vm.runInContext(functionText(source,name),ctx);
 vm.runInContext(helper,ctx);
 return {ctx,query:(input={r:12,c:97,radius:4})=>ctx._getWalkServicePhysicalBodies23(input),setNow:v=>now=v};
}
const person=(id,r=12,c=97)=>({id,r,c,hp:60,ang:.5});
function test(label,run){run();passed++;console.log('PASS '+label);}
test('all 120 source residents, independent of player/render quota',()=>{
 const f=fixture({NPCS:Array.from({length:120},(_,i)=>person('resident_'+i)),player:{r:900,c:900}}),result=f.query();
 assert.equal(result.complete,true);assert.equal(result.rows.length,120);assert.equal(result.rows[119].ref,f.ctx.NPCS[119]);assert.equal(result.sourceFrame,77);
});
test('fresh source position every call; query filtering and no renderer dependency',()=>{
 const p=person('fresh'),f=fixture({NPCS:[p]});assert.equal(f.query().rows.length,1);p.r=50;assert.equal(f.query().rows.length,0);p.r=12;assert.equal(f.query().rows[0].r,12);
});
test('corpse anchor retained through employee replacement; pure timer read',()=>{
 const corpse={...person('old',99,99),dead:true,hp:0,deadAt:1,_deathR:12,_deathC:97},replacement={...person('new'),_stationaryService:{generation:2}},before=JSON.stringify(corpse);
 const f=fixture({NPCS:[corpse,replacement]});f.setNow(61001);let rows=f.query().rows;assert.equal(rows.length,2);assert.equal(rows[0].ref,corpse);assert.equal(rows[0].r,12);assert.equal(rows[1].generation,2);assert.equal(JSON.stringify(corpse),before);
 f.setNow(300002);assert.equal(f.query().rows.length,1);assert.equal(JSON.stringify(corpse),before);
});
test('real source wrappers retain original ref across police, convoy, guards, beach, race',()=>{
 const cop={id:'cop',y:12,x:97,alive:true},boss={id:'boss',y:12,x:97,alive:true},guard={id:'g',y:12,x:97,hp:10},beach={id:'b',y:12,x:97},race=person('r');
 const f=fixture({cityCops:[cop],worldEvent:{id:'e',boss,guards:[]},michaelGuards:new Map([['g',guard]]),beachgoers:new Map([['b',beach]]),RACE_CHEER_CREW:[race]});
 const rows=f.query().rows;for(const ref of [cop,boss,guard,beach,race])assert.ok(rows.some(row=>row.ref===ref));assert.ok(rows.some(row=>row.id==='npc_world_event_e_boss'));
});
test('downing, carry and seat ownership retained without fake foot height',()=>{
 const down={...person('down'),_medicalDowned:true},carried={...person('carry'),_carriedByAmbulance:true},seated={...person('seat'),_transportVehicleId:'v',_transportBoarded:true};
 const f=fixture({NPCS:[down,carried,seated]});const rows=f.query().rows;assert.equal(rows[0].downed,true);assert.equal(rows[1].carried,true);assert.equal(rows[1].poseKnown,false);assert.equal(rows[2].seated,true);assert.equal(rows[2].vehicleId,'service_v');for(const r of rows){assert.equal(r.footY,null);assert.equal(r.elevation,null);}
});
test('bus and parking view helpers preserve actual source refs and stable IDs',()=>{
 const bus={r:12,c:97,tgtR:12,tgtC:98},parking={...person('park'),state:'idle_at',life:1.5};
 const f=fixture({_busWaiters:[bus],_parkingNpcs:[parking]});let a=f.query(),b=f.query();assert.equal(a.complete,true);assert.equal(a.rows[0].id,b.rows[0].id);assert.equal(a.rows[0].ref,bus);assert.equal(a.rows[1].ref,parking);
});
test('all foot-visible junkyard workers included regardless of viewer proximity',()=>{
 const worker={...person('worker'),_footVisible:true};assert.equal(fixture({_junkyardFootWorkers:[worker]}).query().rows[0].ref,worker);
});
test('identical object aliases deduplicate; different objects same ID fail closed',()=>{
 const p=person('same'),f=fixture({NPCS:[p,p]});assert.equal(f.query().rows.length,1);f.ctx.NPCS.push({...p});assert.equal(f.query().reason,'conflicting-source-id');
});
test('invalid raw XY wrapper cannot coerce NaN to origin',()=>{
 const f=fixture({cityCops:[{id:'bad',y:NaN,x:97,alive:true}]});assert.equal(f.query().reason,'invalid-source-position');
});
test('invalid bounds, missing source, local pending and legacy rooms fail closed',()=>{
 const f=fixture();for(const q of [null,{}, {r:12,c:97,radius:17},{r:12,c:97,radius:0}])assert.equal(f.query(q).complete,false);
 f.ctx.NPCS=null;assert.equal(f.query().reason,'source-unavailable');f.ctx.NPCS=[{...person('p'),_npcInitialPlacementPending:true}];assert.equal(f.query().reason,'local-placement-pending');f.ctx._buildingInt={npcs:[]};assert.equal(f.query().reason,'legacy-interior-space');
});
test('authored stand-ins have stable IDs and no fake source actor ref',()=>{
 const f=fixture({MICHAEL_POS:{r:12,c:97}}),row=f.query().rows[0];assert.equal(row.id,'npc_michael_dealer');assert.equal(row.ref,null);assert.equal(row.authored,true);
});
test('does not lazily create Michael guard bodies on physics read',()=>{
 let called=0;const f=fixture({MICHAEL_POS:{r:12,c:97},michaelGuards:new Map(),_michaelDecorGuards:null,_michaelDecor:()=>{called++;return []}});
 assert.equal(f.query().reason,'authored-roster-uninitialized');assert.equal(called,0);
});
test('source exceptions never become empty clear list',()=>{const f=fixture({_myGang:{[Symbol.iterator](){throw Error('unavailable')}}});assert.equal(f.query().complete,false);assert.equal(f.query().rows.length,0);});
test('current mercenary host posture/downing and source vehicle binding are preserved',()=>{
 const crew={...person('merc'),hp:0,_mercenaryVehicleSeat:'rear_left',_mercenaryVehicleId:'fleet:a',_mercenaryVehiclePhase:'board'};
 const f=fixture({_myGang:[crew],window:{MafioziMercenaries:{getMember:()=>({available:true,downed:true,posture:'prone'})}}});let row=f.query().rows[0];assert.equal(row.ref,crew);assert.equal(row.downed,true);assert.equal(row.dead,false);assert.equal(row.vehicleId,'fleet:a');assert.equal(row.vehiclePhase,'board');assert.equal(row.seated,true);assert.equal(row.poseKnown,false);assert.equal(row.prone,true);
 crew._mercenaryHospital=true;assert.equal(f.query().rows.length,0);
});
// Bounded CPU observation only. This is not a full scene performance result.
const f=fixture({NPCS:Array.from({length:384},(_,i)=>person('cost_'+i,12+i%30,97+Math.floor(i/30)))}),times=[];
for(let i=0;i<250;i++){const at=performance.now();f.query();if(i>=50)times.push(performance.now()-at);}times.sort((a,b)=>a-b);
console.log(JSON.stringify({passed,cpu:{scenario:'384 source residents; 50 warm + 200 reads',p50:times[100],p95:times[190]},limitations:['source projection tests, no rendered pose geometry','no GPU or full-scene FPS']}));
