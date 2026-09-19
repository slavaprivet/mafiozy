import fs from 'node:fs';import vm from 'node:vm';import assert from 'node:assert/strict';
const world=fs.readFileSync(new URL('../../../world.html',import.meta.url),'utf8').replaceAll('\r','');
const fn=name=>world.match(new RegExp(`^function ${name}\\([^]*?^}`,'m'))[0];
vm.runInNewContext(`
const _busWaiters=[],_busRiders=[],BUS_STOPS=[{r:10,c:10,sign_r:9,sign_c:9},{r:20,c:20,sign_r:19,sign_c:19}],BUS={state:'stopped',routeIdx:0,r:10,c:10};
const _busRandomLook=()=>({}),_npcPacedSpeed=s=>Math.min(s,1.8/4.1),_npcPathPassable=()=>false,npcPassableForSnitch=()=>false;
${fn('_busStopCount')}
${fn('_spawnBusWaiter')}
${fn('_onBusArrival')}
${fn('_busFootStep')}
${fn('_tickBus').replace('// 4) Сам автобус','return; // 4) Сам автобус')}
_tickBus._nextSpawnT=Infinity;
_spawnBusWaiter(0);_spawnBusWaiter(0);const first=_busWaiters[0],position={r:first.r,c:first.c};
_onBusArrival(0);assert(first.leaving);assert.equal(_busStopCount(0),2,'blocked boarding still counts against stop population');
BUS.state='driving';_tickBus(.1);assert(!first.leaving,'does not chase a departed bus');assert.equal(first.r,position.r);assert.equal(first.c,position.c);
BUS.state='stopped';BUS.routeIdx=1;_onBusArrival(0);_tickBus(.1);assert(!first.leaving,'unrelated stop cannot recruit an old waiter');
for(let i=0;i<500;i++){BUS.routeIdx=0;_onBusArrival(0);_tickBus(.1);if(_busStopCount(0)<2)_spawnBusWaiter(0);}
assert.equal(_busWaiters.length,2,'500 obstructed arrivals cannot grow waiting population');assert.equal(_busRiders.length,4,'stranded alighted population has a finite spawn budget');
assert.equal(_busWaiters[0],first,'existing people retained; no teleport or culling of blocked actors');
`,{assert,Math,performance:{now:()=>1}});
console.log('PASS bus missed-departure reaction, same-stop boarding, stable existing people and bounded waiters/riders across 500 blocked arrivals');
