import fs from 'node:fs';
import vm from 'node:vm';
import assert from 'node:assert/strict';
import {performance} from 'node:perf_hooks';
const source=fs.readFileSync(new URL('npc_activity_reservations_source.js',import.meta.url),'utf8');
function fixture(){let now=1000;const b={performance:{now:()=>now},Map,Set,Math,Number,Infinity};vm.createContext(b);vm.runInContext(source,b);return{b,setNow:value=>now=value};}
const {b,setNow}=fixture(),residents=Array.from({length:288},(_,i)=>({id:'resident_'+i,hp:100}));
for(const n of residents.slice(0,15))assert(b._npcActivityReserveBuilding(n,'native:shop-a'));
assert.equal(b._npcActivityBuildingCount('native:shop-a'),15);
assert(!b._npcActivityReserveBuilding(residents[15],'native:shop-a'),'sixteenth reservation refused');
assert(b._npcActivityReserveBuilding(residents[0],'native:shop-a'),'same owner claim is idempotent');
assert.equal(b._npcActivityBuildingCount('native:shop-a'),15);
for(const n of residents.slice(0,7))assert(b._npcActivityEnterBuilding(n,'native:shop-a'));
assert.equal(b._npcActivityBuildingCount('native:shop-a'),15,'inside and pending share same fifteen slots');
assert(!b._npcActivityReserveBuilding(residents[0],'native:shop-b'),'inside cannot reserve another building');
assert(b._npcActivityReserveBuilding(residents[16],'native:shop-b'),'different physical instance independent');
assert.equal(b._npcActivityBuildingCount('native:shop-b'),1);
assert(!b._npcActivityReserveBuilding(residents[16],'native:shop-a'),'full alternative refused');
assert.equal(b._npcActivityBuildingReservation(residents[16]).key,'native:shop-b','refused transfer preserves prior committed destination');
assert(!b._npcActivityReleaseBuilding(residents[0],'native:other'),'wrong building release does not steal slot');
assert(b._npcActivityReleaseBuilding(residents[0],'native:shop-a','exit'));
assert(b._npcActivityReserveBuilding(residents[15],'native:shop-a'),'exit slot immediately reused');
residents[1].dead=true;
assert(b._npcActivityReserveBuilding(residents[17],'native:shop-a'),'dead inside visitor releases before admission');
residents[2].hp=0;
assert(b._npcActivityReserveBuilding(residents[18],'native:shop-a'),'zero health releases before dead flag arrives');
const present=new Set(residents);present.delete(residents[3]);
assert.equal(b._npcActivityPruneBuildingReservations({owners:present}),1,'removed source object released');
assert(b._npcActivityReserveBuilding(residents[19],'native:shop-a'));
assert.equal(b._npcActivityPruneBuildingReservations({isPending:n=>n!==residents[14]}),1,'abandoned pending goal released');
assert(b._npcActivityReserveBuilding(residents[20],'native:shop-a'));
assert.equal(b._npcActivityPruneBuildingReservations({isInside:n=>n!==residents[4]}),1,'authoritative inside exit released');
assert(b._npcActivityReserveBuilding(residents[21],'native:shop-a'));
setNow(1000000);b._npcActivityPruneBuildingReservations();
assert.equal(b._npcActivityBuildingCount('native:shop-a'),2,'inside has no lease expiration, pending does');
assert.equal(b._npcActivityBuildingCount('native:shop-b'),0);
assert.equal(b._npcActivityPruneBuildingReservations({buildings:new Set()}),2,'removed building releases inside occupants too');
assert.equal(b._npcActivityBuildingReservationSummary().owners,0);
const duplicateA={id:'same-id',hp:100},duplicateB={id:'same-id',hp:100};
assert(b._npcActivityReserveBuilding(duplicateA,'physical:one'));
assert(b._npcActivityReserveBuilding(duplicateB,'physical:one'));
assert.equal(b._npcActivityBuildingCount('physical:one'),2,'stable source object identity, not display/id collision');
const key='native:same-source/instance-a',other='native:same-source/instance-b';
assert(b._npcActivityReserveBuilding(residents[22],key));assert(b._npcActivityReserveBuilding(residents[23],other));
assert.equal(b._npcActivityBuildingCount(key),1);assert.equal(b._npcActivityBuildingCount(other),1,'same source prefix does not merge physical instances');
assert(!b._npcActivityReserveBuilding(null,key));assert(!b._npcActivityReserveBuilding({},''));
// Representative 288 resident refresh/prune workload, no timers or renderer.
const perf=fixture(),perfResidents=Array.from({length:288},(_,i)=>({id:'perf-resident-'+i,hp:100})),alive=new Set(perfResidents),samples=[];
for(let frame=0;frame<300;frame++){
 const now=frame*100+1000;perf.setNow(now);const start=performance.now();
 perf.b._npcActivityPruneBuildingReservations({now,owners:alive});
 for(let i=0;i<perfResidents.length;i++)if(alive.has(perfResidents[i])){
  assert(perf.b._npcActivityReserveBuilding(perfResidents[i],'physical:shop-'+Math.floor(i/12),{now}));
  if(i%3===0)assert(perf.b._npcActivityEnterBuilding(perfResidents[i],'physical:shop-'+Math.floor(i/12),{now}));
 }
 samples.push(performance.now()-start);
}
samples.sort((a,c)=>a-c);const summary=perf.b._npcActivityBuildingReservationSummary();
assert.equal(summary.owners,alive.size);assert(summary.owners<=288);assert.equal(summary.buildings,24);
console.log(JSON.stringify({pass:true,checks:'15 total pending+inside; idempotent; actual object ownership; atomic transfer; death; removal; cancellation; inside non-expiry; expired pending; physical instance identity',performance:{residents:alive.size,frames:samples.length,p50Ms:samples[Math.floor(samples.length*.5)],p95Ms:samples[Math.floor(samples.length*.95)],maxMs:samples.at(-1)},summary,limit:'Source-helper CPU only; production hooks and full-scene FPS are not included.'},null,2));
