import assert from 'node:assert/strict';
import fs from 'node:fs';
import vm from 'node:vm';
const world=fs.readFileSync(new URL('../../../world.html',import.meta.url),'utf8');
const cut=(start,end)=>{const a=world.indexOf(start),b=world.indexOf(end,a);assert(a>=0&&b>a);return world.slice(a,b)};
const blast=cut('const _walkBlastReceipts=new Set();','function _threeNpcDeathState(');
const c4=cut('const _walkLocalC4Charges19=new Map();','function _raycastDamageableCar(');
const ballistic=cut('function _localBallisticTargets(','function _projectTargetOnRay(');
const register=cut('  registerWalkBlastExposureResolver(resolver)', '\n  applyWalkVehicleBlast(').trim().replace(/,$/,'');
function fixture(){
  const hits=[],timers=[];
  const c={_LOCAL_PREVIEW:true,_worldDirectCombatDemo:false,_walkRendererActive:()=>true,_localHostileCanResolveHit(){return c._LOCAL_PREVIEW||c._worldDirectCombatDemo},_walkShotContext:{ref:{id:'only-direct-hit'}},_bankInt:null,_buildingInt:null,NPCS:[],CARS:[],cityCops:[],beachgoers:new Map(),player:{r:100,c:100},myHp:100,myDead:false,currentWeapon:'pistol',myMode:'pvp',QP:{uid:'local'},_myC4Count:3,_lastWorldC4PlantAt:0,worldC4Charges:new Map(),ws:null,clock:1000,performance:{now:()=>c.clock},setTimeout(fn,ms){timers.push({fn,ms})},_prisonWeaponLocked:()=>false,renderWeaponHud(){},showToast(){},showEventBanner(){},spawnWorldC4Explosion(r,c){hits.push({fx:true,r,c})},_walkShotPhysicalContact:()=>null,_walkShotAllows:()=>false,_threeNpcEntityId:n=>'npc_'+n.id,_beachgoerWorldPos:n=>({r:n.r,c:n.c}),_interiorNpcHitRadius:()=>.4,
    hitNpc(n,dy,dx,weapon,damage){assert.equal(c._walkShotContext,null);hits.push({id:n.id,weapon,damage,dy,dx});if(n._invulnerable)return;n.hp=Math.max(0,n.hp-damage);if(n.hp<=0){if(n.medical){n.hp=1;n._medicalDowned=true}else{n.dead=true;n.deadAt=c.clock;n._deathRecord20={version:1,confirmed:true,fatal:true,cause:'blast',targetId:'npc_'+n.id,eventId:'death:'+n.id,deathKey:String(c.clock)}}}},
    _hitBeachgoer(n,dy,dx,damage,impact){c.hitNpc(n,dy,dx,impact.weapon,damage)},_hitBankGuard(n,dy,dx,damage,impact){c.hitNpc(n,dy,dx,impact.weapon,damage)},_hitInteriorNpc(n,dy,dx,damage,weapon){c.hitNpc(n,dy,dx,weapon,damage)},hitCityCop(n,dy,dx,damage){c.hitNpc(n,dy,dx,'city-handler',damage)},hitGangCar(n,damage){hits.push({id:n.id,damage,car:true})},_hurtLocal(damage,by,underFire,detail){c.myHp=Math.max(0,c.myHp-damage);c.myDead=c.myHp<=0;hits.push({hero:true,damage,detail})}};
  vm.createContext(c);vm.runInContext(ballistic+blast+c4+'\nconst bridge={'+register+'};globalThis.register=bridge.registerWalkBlastExposureResolver;',c);
  vm.runInContext(fs.readFileSync(new URL('./npc_blast_record20_source.js',import.meta.url),'utf8'),c);
  c.register(q=>({exposures:q.targets.map(t=>({id:t.id,transmission:1}))}));
  return {c,hits,timers};
}
let passed=0;const check=(name,fn)=>{fn();passed++;console.log('PASS',name)};
check('actual target enumeration ignores direct-shot restriction and rendering, deduplicates references',()=>{
 const {c,hits}=fixture(),a={id:'near',r:0,c:0,hp:100},b={id:'far',r:20,c:0,hp:100},d={id:'other',r:1,c:0,hp:100};c.NPCS=[a,a,b,d];const old=c._walkShotContext;
 const out=c._applyWalkVehicleBlast({eventId:'v',r:0,c:0});assert.equal(out.npcHits.length,2);assert.equal(a.hp,30);assert.equal(d.hp,59);assert.equal(b.hp,100);assert.equal(c._walkShotContext,old);assert.equal(hits.length,2);
 assert.equal(c._applyWalkVehicleBlast({eventId:'v',r:0,c:0}).reason,'duplicate');assert.equal(hits.length,2);
});
check('wall blocks, partial transmission attenuates, missing/broken LOS fails closed',()=>{
 for(const provider of [null,()=>{throw Error('unavailable')},()=>({exposures:[]})]){const {c}=fixture();c.NPCS=[{id:'a',r:0,c:0,hp:100}];c.register(provider);c._applyWalkVehicleBlast({eventId:'v',r:0,c:0});assert.equal(c.NPCS[0].hp,100)}
 const {c}=fixture();c.NPCS=[{id:'a',r:0,c:0,hp:100},{id:'b',r:0,c:0,hp:100}];c.register(q=>({exposures:q.targets.map(t=>({id:t.id,transmission:t.id==='npc_a'?0:.5}))}));c._applyWalkVehicleBlast({eventId:'v',r:0,c:0});assert.equal(c.NPCS[0].hp,100);assert.equal(c.NPCS[1].hp,65);
});
check('hero far or dead does not gate NPC; old confirmed hero exposure remains once',()=>{
 const {c}=fixture();c.myDead=true;c.NPCS=[{id:'a',r:0,c:0,hp:100}];assert.equal(c._applyWalkVehicleBlast({eventId:'v',r:0,c:0}).npcHits.length,1);
 c.myDead=false;c.myHp=100;assert.equal(c._applyWalkVehicleBlast({eventId:'v2',r:0,c:0,distance:5,transmission:1}).damage,35);assert.equal(c.myHp,65);
});
check('fixed source range/power reject caller power; boundary and online authority',()=>{
 const {c}=fixture();c.NPCS=[{id:'a',r:10/4.1,c:0,hp:100},{id:'b',r:10.01/4.1,c:0,hp:100}];assert.equal(c._applyWalkVehicleBlast({eventId:'v',r:0,c:0,damage:10000,radius:100}).npcHits.length,0);c._LOCAL_PREVIEW=false;assert.equal(c._applyWalkVehicleBlast({eventId:'online',r:0,c:0}).reason,'server-owned');
 for(const bad of [{r:NaN},{distance:-1,transmission:1},{distance:1,transmission:2},{y:Infinity}])assert.equal(c._LOCAL_PREVIEW=true,c._LOCAL_PREVIEW),assert.equal(c._applyWalkVehicleBlast({eventId:'bad',r:0,c:0,...bad}).reason,'invalid');
});
check('protected, medical and confirmed-death handlers stay authoritative',()=>{
 const {c}=fixture();c.NPCS=[{id:'p',r:0,c:0,hp:10,_invulnerable:true},{id:'m',r:0,c:0,hp:10,medical:true},{id:'d',r:0,c:0,hp:10}];c._applyWalkVehicleBlast({eventId:'v',r:0,c:0});assert.equal(c.NPCS[0].hp,10);assert.equal(c.NPCS[1].hp,1);assert.equal(c.NPCS[1]._deathRecord20,undefined);assert.equal(c.NPCS[2]._deathRecord20.blastPresentation.originSource.r,0);
});
check('local interior and beach/cop/gang sources use existing handlers',()=>{
 const {c,hits}=fixture();c.NPCS=[{id:'s',r:0,c:0,hp:100}];c.beachgoers.set('b',{id:'b',r:0,c:0,hp:100});c.cityCops=[{id:'cop',x:0,y:0,alive:true,hp:100}];c.CARS=[{id:'gang',r:0,c:0,gang:true}];c._applyWalkVehicleBlast({eventId:'street',r:0,c:0});assert.equal(hits.length,4);
 c._bankInt={npcs:[{id:'bank',r:0,c:0,hp:100}]};c._applyWalkVehicleBlast({eventId:'bank',r:0,c:0});assert.equal(hits.at(-1).id,'bank');
 c._bankInt=null;c._buildingInt={npcs:[{id:'inside',r:0,c:0,hp:100},{id:'ally',r:0,c:0,hp:100,_allied:true}]};c._applyWalkVehicleBlast({eventId:'inside',r:0,c:0});assert.equal(hits.at(-1).id,'inside');assert.equal(c._buildingInt.npcs[1].hp,100);
});
check('C4 consumes one owned charge, waits 3 seconds, applies 4 cell radius and replay protection',()=>{
 const {c,timers,hits}=fixture();c.player={r:0,c:0};c.NPCS=[{id:'a',r:4,c:0,hp:100},{id:'b',r:4.01,c:0,hp:100}];assert.equal(c.placeWorldC4(),true);assert.equal(c._myC4Count,2);assert.equal(timers[0].ms,3000);const id=[...c.worldC4Charges.keys()][0];assert.equal(c._detonateWalkLocalC4Charge19(id).reason,'charge');assert.equal(hits.length,0);c.clock=4000;timers[0].fn();assert.equal(c.NPCS[0].hp,0);assert.equal(c.NPCS[1].hp,100);assert.equal(c.myHp,0);assert.equal(c.worldC4Charges.size,0);assert.equal(c._detonateWalkLocalC4Charge19(id).reason,'charge');assert.equal(hits.filter(h=>h.fx).length,1);
});
check('C4 no stock/observer/dead denied, max 3 active and scene change never damages wrong coordinates',()=>{
 const {c,timers}=fixture();for(const patch of [{_myC4Count:0},{myMode:'pve'},{myDead:true}]){Object.assign(c,{_myC4Count:4,myMode:'pvp',myDead:false},patch);assert.equal(c.placeWorldC4(),false)}Object.assign(c,{_myC4Count:4,myMode:'pvp',myDead:false});for(let i=0;i<3;i++){c.clock+=1000;assert.equal(c.placeWorldC4(),true)}c.clock+=1000;assert.equal(c.placeWorldC4(),false);assert.equal(c._myC4Count,1);c._buildingInt={npcs:[]};c.clock+=5000;timers.forEach(t=>t.fn());assert.equal(c.myHp,100);
});
check('network C4 keeps WS contract without local inventory or local damage',()=>{
 const {c,timers}=fixture(),packets=[];c._LOCAL_PREVIEW=false;c.ws={readyState:1,send:data=>packets.push(JSON.parse(data))};assert.equal(c.placeWorldC4(),true);assert.equal(packets[0].t,'world_c4_plant');assert.equal(c._myC4Count,3);assert.equal(timers.length,0);
});
check('context restored if an existing target handler throws',()=>{const {c}=fixture(),old=c._walkShotContext;c.NPCS=[{id:'a',r:0,c:0,hp:100}];c.hitNpc=()=>{throw Error('handler')};assert.throws(()=>c._applyWalkVehicleBlast({eventId:'v',r:0,c:0}));assert.equal(c._walkShotContext,old)});
console.log(`${passed} actual-source blast/C4 cases passed`);
