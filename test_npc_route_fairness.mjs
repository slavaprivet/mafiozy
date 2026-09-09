import fs from 'node:fs';import vm from 'node:vm';import assert from 'node:assert/strict';
const s=fs.readFileSync('world.html','utf8').replace(/\r\n/g,'\n');function fn(n){const a=s.indexOf(`function ${n}(`);return s.slice(a,s.indexOf('\n}',a)+2);}
let now=1000;const c={performance:{now:()=>now},prevT:1000,_walkNpcNavigationResolver:()=>{},MAP_COLS:60,
 npcPassable:(r,col)=>{now+=.04;return r>0&&r<40&&col>0&&col<40;},_setNpcRoute:(n,path)=>{n.path=path;return path.length>0;}};
vm.createContext(c);vm.runInContext(s.slice(s.indexOf('let _npcRouteWorkFrame='),s.indexOf('function _planNpcRouteTo('))+fn('_planNpcRouteTo')+fn('_reservePoliceFootRoute')+'\nlet _policeFootRouteFrame=-1,_policeFootRoutesThisFrame=0;',c);
const actors=Array.from({length:12},(_,i)=>({id:(i%3===0?'police_':'resident_')+i,r:2.5,c:2.5,grants:0}));
for(let frame=0;frame<100;frame++){
 now=1000+frame*33;c.prevT=now;const start=now;let grants=0;
 for(const n of actors){const granted=n.id.startsWith('police')?c._reservePoliceFootRoute(now,n):c._npcReserveRouteWork(now,n);if(granted){n.grants++;grants++;now+=2;}}
 assert.ok(grants<=2&&now-start<=4,'fairness cannot increase frame quota');
}
assert.ok(actors.every(n=>n.grants>=8),JSON.stringify(actors.map(n=>({id:n.id,grants:n.grants}))));
// Actual directed searches resume over many slices; never publish a partial destination.
vm.runInContext('_npcRouteWorkQueue.clear();',c);const walkers=actors.filter(n=>n.id.startsWith('resident'));
for(let frame=0;frame<1500&&!walkers.every(n=>n.done);frame++){
 now=10000+frame*33;c.prevT=now;
 for(const n of walkers){if(n.done)continue;const before=n._npcDirectedSearch?.qi||0;n.done=c._planNpcRouteTo(n,16.5,16.5,c.npcPassable,.1,3000,'building_entry');if(!n.done&&n._npcDirectedSearch)assert.ok(n._npcDirectedSearch.qi>=before,'frontier is not restarted');}
}
assert.ok(walkers.every(n=>n.done&&n.path.at(-1).r===16.5&&n.path.at(-1).c===16.5),'all fixed-order residents finish exact same target over slices');
assert.ok(s.includes("npc._buildingVisitCooldownUntil=now+(npc._routeSearchPending?0:5000)"));
// An abandoned FIFO head may block one transition frame, never all later frames.
vm.runInContext('_npcRouteWorkQueue.clear();',c);now=100000;c.prevT=now;
const abandoned={id:'gone'},active={id:'still_here'};
c._npcReserveRouteWork(now,{id:'consume1'});c._npcReserveRouteWork(now,{id:'consume2'});
assert.equal(c._npcReserveRouteWork(now,abandoned),false);assert.equal(c._npcReserveRouteWork(now,active),false);
let resumed=false;for(let frame=1;frame<=3;frame++){now=100000+frame*33;c.prevT=now;if(c._npcReserveRouteWork(now,active))resumed=true;}
assert.ok(resumed,'abandoned actor cannot hold head for seconds');
assert.ok(s.includes("npc.idleUntil=0;return false;} // Keep the same door search"));
console.log('PASS FIFO 12 mixed police/residents all served under same4ms/2slots;8 exact door searches resume to completion');
