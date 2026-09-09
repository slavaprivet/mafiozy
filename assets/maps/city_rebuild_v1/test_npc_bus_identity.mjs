import assert from 'node:assert/strict';
import fs from 'node:fs';
import vm from 'node:vm';

const world=fs.readFileSync(new URL('../../../world.html',import.meta.url),'utf8').replace(/\r\n/g,'\n');
const helper=fs.readFileSync(new URL('./npc_bus_identity_source.js',import.meta.url),'utf8').trim();
assert.ok(world.includes(helper),'tested helper is the actual source bridge implementation');
const fn=name=>{const found=world.match(new RegExp(`^function ${name}\\([^]*?^}`,'m'));assert.ok(found,name);return found[0];};
const context=vm.createContext({assert,performance:{now:()=>1000},Math});
vm.runInContext(`
const _threeNpcIds=new WeakMap();let _threeNpcIdSeq=0;
const _threeNpcActionRefs=new Map();
const NPCS=[],_parkingNpcs=[],cityCops=[],worldCops=[],gangNests=[];
const _buildingInt=null,_bankInt=null,worldEvent=null,aggroZones={};
const michaelGuards=new Map(),beachgoers=new Map();
const _busRiders=[],_busWaiters=[];
const BUS={r:0,c:0,state:'stopped',stopUntil:Infinity,doorPhase:0};
const BUS_STOPS=[];
${world.match(/^const NPC_HERO_PACE=.*$/m)[0]}
${world.match(/^function _npcPacedSpeed\(.*$/m)[0]}
const npcPassableForSnitch=()=>true;
const _npcPathPassable=()=>true;
${fn('_busFootStep')}
${helper}
${fn('_threeNpcEntityId')}
${fn('_walkShotNativeRef')}
${fn('_tickBus')}
_tickBus._nextSpawnT=5000;
const render=(p,kind)=>_threeNpcEntityId(_threeBusPersonView(p,kind));
const a={r:0,c:0,tgtR:0,tgtC:0,life:.01,walkPhase:0};
const b={r:26,c:0,tgtR:28,tgtC:0,life:10,walkPhase:0};
_busRiders.push(a,b);
const aid=render(a,'bus_rider'),bid=render(b,'bus_rider');
assert.equal(aid,'npc_bus_rider_0');assert.equal(bid,'npc_bus_rider_1');
_threeNpcActionRefs.set(aid,{ref:a});_threeNpcActionRefs.set(bid,{ref:b});
const oldR=b.r;_tickBus(.1);
assert.equal(_busRiders.length,1);assert.equal(_busRiders[0],b);
assert.equal(render(b,'bus_rider'),bid,'expiry must not transfer another person identity');
assert.equal(_walkShotNativeRef(bid),b,'contact resolves same actual person after splice');
assert.equal(_walkShotNativeRef(aid),null,'expired id cannot hit its replacement');
assert.ok(Math.abs((b.r-oldR)*4.1/.1-NPC_HERO_PACE.walk*4.1)<1e-9,'actual source pedestrian stays at current source paced walk speed');
const c={r:0,c:0,tgtR:1,tgtC:0,life:10};_busRiders.unshift(c);
const cid=render(c,'bus_rider');assert.equal(cid,'npc_bus_rider_2');
assert.equal(render(b,'bus_rider'),bid,'array reorder retains identity');
assert.equal(_threeBusPersonView(b,'bus_rider')._actionRef,b);
assert.equal(_threeBusPersonView(b,'bus_rider').walking,true);
b.r=b.tgtR;b.c=b.tgtC;assert.equal(_threeBusPersonView(b,'bus_rider').walking,false);
const w0={r:0,c:0,leaving:false,idleT:0},w1={r:2,c:0,leaving:true,idleT:0,walkPhase:0};
_busWaiters.push(w0,w1);const wid0=render(w0,'bus_waiter'),wid1=render(w1,'bus_waiter');
assert.equal(wid0,'npc_bus_waiter_0');assert.equal(wid1,'npc_bus_waiter_1');
_busWaiters.shift();assert.equal(render(w1,'bus_waiter'),wid1);
assert.equal(_threeBusPersonView(w0,'bus_waiter').moving,false);
assert.equal(_threeBusPersonView(w1,'bus_waiter').moving,true);
assert.equal(_threeBusPersonView(w1,'bus_waiter').civilianTripRiding,undefined,'no invented onboard passengers');
assert.equal(w1.id,undefined,'source identity and legacy decor lock fields remain untouched');
`,context);
assert.ok(world.includes("combat.push(_threeBusPersonView(person,'bus_waiter'))"));
assert.ok(world.includes("combat.push(_threeBusPersonView(person,'bus_rider'))"));
assert.ok(!world.includes('id:`bus_rider_${i}`'));
console.log('PASS bus source stable identity: splice/expiry/reorder, no reused IDs, exact combat ref, actual source pace constant and tick, waiting/boarding/alighted walking states.');
