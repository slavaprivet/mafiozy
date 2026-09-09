import assert from 'node:assert/strict';
import fs from 'node:fs';
import vm from 'node:vm';
const world=fs.readFileSync(new URL('../../../world.html',import.meta.url),'utf8').replace(/\r\n/g,'\n');
const fn=name=>world.match(new RegExp(`^function ${name}\\([^]*?^}`,'m'))[0];
const line=name=>world.match(new RegExp(`^function ${name}\\(.*$`,'m'))[0];
const foot=fs.readFileSync(new URL('./npc_bus_foot_source.js',import.meta.url),'utf8').trim();
assert.ok(world.includes(foot));
vm.runInNewContext(`
const MAP_ROWS=50,MAP_COLS=50,MAP=Array.from({length:50},()=>Array(50).fill(0));
const isBlockedPed=()=>false,_inPrisonIslandRestrictedZone=()=>false,inArena=()=>false,inLair=()=>false,_cityV3NextSurfaceAt=()=>false,_inPitCorridor=()=>false;
const npcPassable=()=>false;
let _walkNpcNavigationResolver=null,_walkNpcWaterResolver=null,_npcWaterBypass=0;
const _npcNavigationStats={queries:0,solidRefusals:0,waterRefusals:0};
${world.match(/^const NPC_HERO_PACE=.*$/m)[0]}
${line('_npcPacedSpeed')}
${fn('_npcNavigationAt')}
${line('_npcRouteWalkBlocked')}
${fn('npcPassableForSnitch')}
${fn('_npcBodyPassable')}
${fn('_npcPathPassable')}
${foot}
const _busWaiters=[],_busRiders=[],BUS_STOPS=[];
const BUS={r:10,c:14,state:'stopped',stopUntil:Infinity,doorPhase:0};
${fn('_tickBus')}
_tickBus._nextSpawnT=5000;
const passenger={r:10,c:10,tgtR:10,tgtC:14,life:10,walkPhase:0};
_busRiders.push(passenger);
_tickBus(.1);
assert.ok(Math.abs(passenger.c-10-NPC_HERO_PACE.walk*.1)<1e-10,'alighted pedestrian may cross road toward sidewalk');
const originalC=passenger.c;
for(const kind of ['water','building','car']){
 _walkNpcNavigationResolver=({r,c})=>({blocked:kind!=='water'&&c>originalC+.19,depth:kind==='water'&&c>originalC+.19?1:0});
 const phase=passenger.walkPhase,life=passenger.life;
 for(let i=0;i<20;i++)_tickBus(.1);
 assert.equal(passenger.c,originalC,kind+' must stop the swept body, not just its centre');
 assert.equal(passenger.walkPhase,phase,'blocked feet do not walk in place');
 assert.equal(passenger.life,life,'blocked exit does not start arrival expiry timer');
 assert.equal(passenger._busFootMoving,false);
}
const waiter={r:10,c:originalC,leaving:true,idleT:0,walkPhase:0};_busWaiters.push(waiter);
_tickBus(.1);assert.equal(waiter.c,originalC,'boarding pedestrian uses the same obstacle gate');
_walkNpcNavigationResolver=()=>({blocked:false,depth:0});
_tickBus(.1);assert.ok(waiter.c>originalC);assert.ok(passenger.c>originalC,'both resume physically after obstacle clears');
const before=passenger.c;_busFootStep(passenger,10,40,3,10);
assert.ok(passenger.c-before<=NPC_HERO_PACE.walk*.1+1e-10,'frame stall cannot teleport a passenger');
_walkNpcNavigationResolver=({c})=>({blocked:c>20.99&&c<21.04,depth:0});
assert.equal(_npcPathPassable(10,20,10,22,npcPassableForSnitch),false,'shared path samples catch a wall between clear endpoints');
assert.equal(BUS.r,10);assert.equal(BUS.c,14,'passenger correction never moves the bus');
`,{assert,Math,performance:{now:()=>1000}});
console.log('PASS bus foot actual source gates: paced road exit, swept water/building/car rejection, blocked wait, resume, no frame-stall jump, unchanged bus.');
