import test from 'node:test';
import assert from 'node:assert/strict';
import fs from 'node:fs';
import vm from 'node:vm';
const source=fs.readFileSync(new URL('../../../world.html',import.meta.url),'utf8');
function actual(name){const a=source.indexOf('function '+name+'(');assert(a>=0,name);return source.slice(a,source.indexOf('\n}',a)+2);}
const explode=actual('_explodeGasStation');
function fixture(){
  const noop=()=>{},events=[],c={Math,performance:{now:()=>5000},GAS_REPAIR_MS:30000,GAS_BLAST_RADIUS:6,_gasStationState:gs=>gs._damageState||'leaking',_gasPumpPoints:()=>[{r:0,c:0}],
    spawnWorldC4Explosion:()=>events.push('blast'),spawnShockwave:noop,addShake:noop,hapticHit:noop,fireScreenFlash:noop,showEventBanner:noop,pushFeedEvent:noop,
    player:{r:0,c:0},myDead:false,_hurtLocal:(damage)=>events.push(['player',damage]),
    NPCS:[{id:'near',r:0,c:0},{id:'half',r:3,c:0},{id:'outside',r:6,c:0},{id:'dead',r:0,c:0,dead:true},null],
    cityCops:[{id:'near',x:0,y:0,alive:true},{id:'outside',x:0,y:6,alive:true},{id:'retired',x:0,y:0,alive:false},null],
    _myGang:[{id:'near',r:0,c:0,hp:200},{id:'half',r:0,c:3,hp:200},{id:'outside',r:0,c:6,hp:200},{id:'downed',r:0,c:0,hp:0},null],
    CARS:[{id:'drive',r:0,c:0},{id:'edge',r:0,c:5.2},{id:'beyond',r:0,c:5.20001},{id:'wreck',r:0,c:0,_wrecked:true},{id:'towed',r:0,c:0,_towed:true},null],
    hitNpc:(n,dr,dc,weapon,damage)=>events.push(['npc',n.id,weapon,damage,dr,dc]),hitCityCop:(n,dr,dc,damage)=>events.push(['cop',n.id,damage,dr,dc]),
    spawnFloatText:noop,_saveGang:()=>events.push('save'),spawnCarExplosion:(r,col,car)=>events.push(['car',car.id]),triggerNpcPanic:(...args)=>events.push(['panic',...args]),
    myDrivingCarId:'drive',_exitRequested:true,_myCarFuelPct:50};
  vm.createContext(c);vm.runInContext(actual('_gasBlastDamageAt')+'\n'+explode,c);return {c,events,gs:{name:'station',r:0,c:0}};
}
test('PRODUCTION gas blast completes original damage/save/car/panic tail exactly once without interior bi',()=>{
  const {c,events,gs}=fixture();assert.equal('bi' in c,false);c._explodeGasStation(gs);
  assert.equal(gs._blastApplied,true);assert.equal(gs._damageState,'burning');assert.equal(gs._destroyedAt,5000);assert.equal(gs._repairAt,35000);assert.equal(gs._fireTruckDispatched,false);
  assert.deepEqual(events.filter(e=>Array.isArray(e)&&e[0]==='player'),[['player',105]]);
  assert.deepEqual(events.filter(e=>Array.isArray(e)&&e[0]==='npc'),[['npc','near','rpg',105,0,0],['npc','half','rpg',53,1,0]]);
  assert.deepEqual(events.filter(e=>Array.isArray(e)&&e[0]==='cop'),[['cop','near',105,0,0]]);
  assert.deepEqual(c._myGang.filter(Boolean).map(n=>n.hp),[95,147,200,0]);
  assert.equal(events.filter(e=>e==='save').length,1);assert.deepEqual(events.filter(e=>Array.isArray(e)&&e[0]==='car'),[['car','drive'],['car','edge']]);
  assert.equal(c.CARS[0]._respawnAt,30000);assert.equal(c.CARS[1]._respawnAt,30000);assert.equal(c.CARS[2]._wrecked,undefined);assert.equal(c.CARS[4]._wrecked,undefined);
  assert.equal(c.myDrivingCarId,null);assert.equal(c._exitRequested,false);assert.equal(c._myCarFuelPct,null);
  assert.deepEqual(events.at(-1),['panic',0,0,14,'fire']);assert(events.indexOf('save')<events.findIndex(e=>Array.isArray(e)&&e[0]==='car'));
  const before=JSON.stringify({events,gang:c._myGang,cars:c.CARS});c._explodeGasStation(gs);assert.equal(JSON.stringify({events,gang:c._myGang,cars:c.CARS}),before);
});
test('PRODUCTION non-leaking station and dead player keep existing admission rules',()=>{
  const {c,events,gs}=fixture();gs._damageState='intact';c._explodeGasStation(gs);assert.equal(events.length,0);assert.equal(gs._blastApplied,undefined);
  gs._damageState='leaking';c.myDead=true;c._explodeGasStation(gs);assert.equal(events.some(e=>Array.isArray(e)&&e[0]==='player'),false);assert.equal(events.at(-1)[0],'panic');
});
