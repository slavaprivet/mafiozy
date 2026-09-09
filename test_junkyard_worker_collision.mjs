import fs from 'node:fs';import vm from 'node:vm';import assert from 'node:assert/strict';
const s=fs.readFileSync('world.html','utf8').replace(/\r\n/g,'\n');function fn(n){const a=s.indexOf(`function ${n}(`),line=s.slice(a,s.indexOf('\n',a));return line.endsWith('}')?line:s.slice(a,s.indexOf('\n}',a)+2);}
let blocked=true,now=0;const hit=(r,c)=>blocked&&r>83&&r<85&&c>64&&c<66;
const env={performance:{now:()=>now},npcPassableForSnitch:(r,c)=>!hit(r,c),npcPassable:(r,c)=>!hit(r,c),_npcRouteWalkBlocked:(r,c)=>hit(r,c)};vm.createContext(env);
vm.runInContext(s.match(/const NPC_HERO_PACE=Object.freeze\([^\n]+/)[0]+'\nlet _junkyardFootWorkers=null;'+['_npcPacedSpeed','_npcBodyPassable','_npcPathPassable','_tickJunkyardWorkerFootMotion'].map(fn).join('\n')+'\nglobalThis.workers=()=>_junkyardFootWorkers;',env);
env._tickJunkyardWorkerFootMotion(.033,now);const workers=env.workers(),ids=workers.map(n=>n.id),first=workers[0];
for(let i=0;i<1800;i++){now+=1000/30;const before={r:first.r,c:first.c};env._tickJunkyardWorkerFootMotion(1/30,now);assert.ok(Math.hypot(first.r-before.r,first.c-before.c)*4.1<=1.8/30+1e-9);assert.ok(env._npcBodyPassable(first.r,first.c,env.npcPassableForSnitch));}
assert.ok(first.c<64&&first.c>63.5,'worker reaches obstruction then stops, not crosses');assert.equal(first.walking,false);
const old={r:first.r,c:first.c};now+=60000;blocked=false;env._tickJunkyardWorkerFootMotion(60,now);
assert.ok(Math.hypot(first.r-old.r,first.c-old.c)*4.1<=.18+1e-9,'60-second pause cannot catch up through obstacle');assert.equal(first.walking,true);
assert.equal(env.workers()[0],first);assert.deepEqual(env.workers().map(n=>n.id),ids);
const snap=s.slice(s.indexOf('    if(!inside&&near(JUNKYARD_R,JUNKYARD_C)){'),s.indexOf('    const prisonNpcAllowed='));
assert.ok(snap.includes('npcSource.push(worker)'));assert.ok(!snap.includes('_npcTimedWalkRoute')&&!snap.includes('_planNpc'));
assert.ok(s.includes('function _tickWorldLife(dt) {\n  _tickJunkyardWorkerFootMotion(dt);'));
console.log('PASS stable decorative worker identity, swept wall/car stop, 60s pause no catch-up, source tick owns motion and snapshot read-only');
