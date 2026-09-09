import fs from 'node:fs';import vm from 'node:vm';import assert from 'node:assert/strict';
const source=fs.readFileSync(process.argv[2]||'world.html','utf8').replace(/\r\n/g,'\n');
const ctx=vm.createContext({_npcPathPassable:()=>true,npcPassable:()=>true});
vm.runInContext(source.slice(source.indexOf('const NPC_HERO_PACE='),source.indexOf('// NPC_LIFE_SYSTEM_START')),ctx);
const a=source.indexOf('function _npcAdvanceRoute(');vm.runInContext(source.slice(a,source.indexOf('\n}',a)+2),ctx);
const chase=source.match(/const chaseSpeed=(.*?),goalShift=/)[1];
for(const fps of [30,60,144])for(const base of [.8,8]){
 ctx.n={r:0,c:0,speed:base,walkPhase:0,_route:[{r:100,c:0}],_routeIndex:0};
 const speed=vm.runInContext(chase,ctx);
 for(let i=0;i<fps;i++)ctx._npcAdvanceRoute(ctx.n,1/fps,speed);
 assert.ok(ctx.n.r*4.1<=7.8+1e-9,`actual melee pursuit exceeds run cap at ${fps} FPS: ${ctx.n.r*4.1}`);
 assert.ok(ctx.n.r>0&&ctx.n.walking,'pursuit intent remains active');
}
const retreat=source.match(/_npcAdvanceRoute\(n,dt,(.*?),_empireBossPassable\);_empireMovementWatch\(n,hq/)[1];
const escort=[...source.matchAll(/_npcAdvanceRoute\(n,dt,(.*?),_empireBossPassable\);_empireMovementWatch\(n,target/g)].find(m=>m[1].includes('leader.speed'))[1];
const target=source.match(/_npcAdvanceRoute\(n,dt,(.*?),_empireBossPassable\),distanceAfter/)[1];
ctx.now=10000;ctx.n={speed:99};ctx.leader={speed:99};
assert.ok(vm.runInContext(retreat,ctx)*4.1<=7.8+1e-9);
assert.ok(vm.runInContext(escort,ctx)*4.1<=1.8+1e-9,'peaceful escort uses walking cap');
ctx.leader._fighting=true;assert.ok(vm.runInContext(escort,ctx)*4.1<=7.8+1e-9);
assert.ok(vm.runInContext(target,ctx)*4.1<=1.8+1e-9);
const bankStart=source.indexOf('const speed=3.8,'),bankEnd=source.indexOf('\n      if(_canStandBankInterior',bankStart),bank=source.slice(bankStart,bankEnd);
for(const fps of [30,60,144])for(const sep of [{r:0,c:0},{r:4,c:9},{r:-4,c:-9}]){
 Object.assign(ctx,{npc:{r:0,c:0},dr:1,dc:1,mag:Math.SQRT2,sep,dt:1/fps});
 const delta=vm.runInContext(`(()=>{${bank};return Math.hypot(nr-npc.r,nc-npc.c)})()`,ctx);
 assert.ok(delta*fps*4.1<=7.8+1e-8,'bank avoidance vector cannot add unbounded speed');
}
for(const marker of ['const step=_npcPacedSpeed((n.speed||1.15)*scale*1.35,true)*dt;',
 'const step=_npcPacedSpeed(n.speed*moveScale*1.3,true)*dt,',
 'const sp = Math.min(dist, _npcPacedSpeed(n.speed) * dt);'])assert.ok(source.includes(marker));
console.log('PASS real route pursuit30/60/144FPS, escort peaceful/combat, retreat, destination, bank additive separation, interior admission');
