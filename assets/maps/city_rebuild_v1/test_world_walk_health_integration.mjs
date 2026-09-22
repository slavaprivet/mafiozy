import assert from 'node:assert/strict';
import fs from 'node:fs';
import vm from 'node:vm';
import {pathToFileURL} from 'node:url';
import {createBlastResponse} from './blast_response.mjs';
const THREE=await import(pathToFileURL((process.env.MAFIOZI_THREE_VENDOR||'D:/codex_release/artist13_hero_first_DEV_20260907/demo/vendor')+'/build/three.module.js'));
const world=fs.readFileSync(new URL('../../../world.html',import.meta.url),'utf8').replaceAll('\r','');
const cut=(a,b)=>{const i=world.indexOf(a),j=world.indexOf(b,i);assert(i>=0&&j>i);return world.slice(i,j)};
const context={_LOCAL_PREVIEW:true,_worldDirectCombatDemo:false,_murderPoliceArrest:null,_walkRendererActive:()=>true,
 _meleeBlockHeld:false,player:{r:5,c:6,ang:0},myHp:100,myDead:false,document:{documentElement:{dataset:{}}},performance:{now:()=>1000},_registerIncomingFire(){},_threePlayerImpactState:{},_meleeBruiseAt:0,
 _walkShotContext:{ref:{id:'previous-direct-hit'}},_threeNpcEntityId:n=>'npc_'+n.id,
 _localBallisticTargets(weapon){assert.equal(weapon,'vehicle_explosion');assert.equal(context._walkShotContext,null,'splash target enumeration ignores only the old direct-shot restriction');return targets;}};
const targets=[],previousShotContext=context._walkShotContext;
vm.createContext(context);
vm.runInContext(cut('function _localHostileCanResolveHit()','\nlet myKills'),context);
vm.runInContext(cut('const _walkBlastReceipts=new Set();','function _threeNpcDeathState('),context);
const hit={eventId:'one',r:5,c:6,distance:5,transmission:1};
assert.equal(context._applyWalkVehicleBlast(hit).damage,35);assert.equal(context.myHp,65);
assert.equal(context._walkShotContext,previousShotContext,'source restores direct-shot context after local splash');
assert.equal(context._applyWalkVehicleBlast(hit).reason,'duplicate');assert.equal(context.myHp,65);
for(const [eventId,distance,transmission] of [['covered',1,0],['outside',10,1],['far',100,1]]){assert.equal(context._applyWalkVehicleBlast({...hit,eventId,distance,transmission}).damage,0);assert.equal(context.myHp,65)}
assert.equal(context._applyWalkVehicleBlast({...hit,eventId:'partial',transmission:.5}).damage,18);
for(const bad of [{distance:NaN},{transmission:2},{eventId:''},{r:Infinity}])assert.equal(context._applyWalkVehicleBlast({...hit,...bad,eventId:bad.eventId??'invalid'}).reason,'invalid');
context._LOCAL_PREVIEW=false;assert.equal(context._applyWalkVehicleBlast({...hit,eventId:'online'}).reason,'server-owned');assert.equal(context.myHp,47);
context._LOCAL_PREVIEW=true;context._walkRendererActive=()=>false;assert.equal(context._applyWalkVehicleBlast({...hit,eventId:'legacy'}).reason,'renderer');context._walkRendererActive=()=>true;
// The expanded source contract also asks for NPC exposure independently of
// hero proximity. Keep the real local blast helper and stub only its external
// roster/contact provider; covered/missing LOS is never invented as clear.
const npc={id:'nearby',r:1,c:0,hp:100};targets.push({key:npc,r:npc.r,c:npc.c,hit(damage){assert.equal(context._walkShotContext,null);npc.hp-=damage;}});
context.fixtureBlastExposureResolver=query=>{assert.equal(query.targets.length,1);assert.equal(query.targets[0].id,'npc_nearby');return {exposures:[{id:'npc_nearby',transmission:.5}]};};
vm.runInContext('_walkBlastExposureResolver=globalThis.fixtureBlastExposureResolver;',context);
const nearby=context._applyWalkVehicleBlast({eventId:'hero-far-npc-near',r:0,c:0});
assert.equal(nearby.damage,0);assert.equal(context.myHp,47);assert.equal(nearby.npcHits.length,1);assert.equal(npc.hp,79);
assert.equal(context._walkShotContext,previousShotContext);
assert.equal(context._applyWalkVehicleBlast({eventId:'hero-far-npc-near',r:0,c:0}).reason,'duplicate');assert.equal(npc.hp,79);
vm.runInContext('_walkBlastExposureResolver=null;',context);
assert.equal(context._applyWalkVehicleBlast({eventId:'missing-los',r:0,c:0}).npcHits.length,0);assert.equal(npc.hp,79);
const scene=new THREE.Scene(),hero={object:new THREE.Group()};hero.object.position.set(0,0,5);scene.add(hero.object);
const exposures=[],launches=[];
const blast=createBlastResponse(THREE,scene,{getHero:()=>hero,getVehicles:()=>[],getRoots:()=>[],getGlass:()=>({}),groundHeight:()=>0,onHeroLaunch:(body,event)=>launches.push({body,event}),onBlast:(event,exposure)=>exposures.push({event,exposure})});
blast.enqueue({point:{x:0,y:0,z:0},power:1,radius:10});blast.update();blast.update();
assert.equal(exposures.length,1);assert.equal(launches.length,1);assert.equal(exposures[0].exposure.distance,5);assert.equal(exposures[0].exposure.transmission,1);assert.equal(exposures[0].event.id,launches[0].event.id);blast.dispose();
const blockedScene=new THREE.Scene(),blockedHero={object:new THREE.Group()},blockers=new THREE.Group(),wall=new THREE.Mesh(new THREE.PlaneGeometry(12,12),new THREE.MeshStandardMaterial({side:THREE.DoubleSide}),),vehicleObject=new THREE.Group();blockedHero.object.position.set(0,0,5);wall.position.z=2.5;vehicleObject.position.set(0,0,5);blockers.add(wall);blockedScene.add(blockedHero.object,blockers,vehicleObject);let blockedCarHits=0,blockedExposure=null;
const blockedBlast=createBlastResponse(THREE,blockedScene,{getHero:()=>blockedHero,getVehicles:()=>[{car:{object:vehicleObject},damage:{state:{wrecked:false,destroying:false},blastImpact(){blockedCarHits++}},roll:{impact(){throw Error('covered vehicle must not roll')}}}],getRoots:()=>[blockers],getGlass:()=>({}),groundHeight:()=>0,onHeroLaunch:()=>{throw Error('covered hero must not launch')},onBlast:(_,exposure)=>{blockedExposure=exposure}});
blockedBlast.enqueue({point:{x:0,y:0,z:0},power:1,radius:10});blockedBlast.update();assert.equal(blockedExposure.transmission,0,'opaque cover remains exact under scratch-ray reuse');assert.equal(blockedCarHits,0,'covered vehicle keeps the same blast admission');blockedBlast.dispose();
const clearScene=new THREE.Scene(),clearHero={object:new THREE.Group()},clearRoots=new THREE.Group(),clearPane=new THREE.Mesh(new THREE.PlaneGeometry(50,50),new THREE.MeshStandardMaterial({transparent:true,opacity:.25,side:THREE.DoubleSide}));clearPane.position.z=3;clearRoots.add(clearPane);clearScene.add(clearHero.object,clearRoots);clearHero.object.position.set(0,0,7);let clearExposure=null,clearCarHits=0,clearRolls=0;
const clearVehicles=Array.from({length:3},(_,index)=>{const object=new THREE.Group();object.position.set(index-1,0,6);clearScene.add(object);return {car:{object},damage:{state:{wrecked:false,destroying:false},blastImpact(){clearCarHits++}},roll:{impact(){clearRolls++}}}});
const clearBlast=createBlastResponse(THREE,clearScene,{getHero:()=>clearHero,getVehicles:()=>clearVehicles,getRoots:()=>[clearRoots],getGlass:()=>({}),groundHeight:()=>0,onHeroLaunch(){},onBlast:(_,exposure)=>{clearExposure=exposure}});
clearBlast.enqueue({point:{x:0,y:0,z:0},power:1,radius:10});clearBlast.update();assert.equal(clearExposure.transmission,1,'transparent intersections do not become cover');assert.equal(clearCarHits,3,'every admitted car keeps its blast damage');assert.equal(clearRolls,3,'every admitted car keeps its impact reaction');clearBlast.dispose();
const walk=fs.readFileSync(new URL('./walk_preview.mjs',import.meta.url),'utf8');
assert(walk.includes('updateWorldWalkHealth();walkPlayerHud?.update'));
assert(walk.includes('worldHealthFrame?.inputsBlocked===true'));
// Execute the actual Walk callback with the real queued blast producer. A
// source vehicle ID authorizes this route; an RPG visual has no such identity.
const onBlastStart=walk.indexOf('onBlast(event,heroExposure){'),onBlastEnd=walk.indexOf('},onHeroLaunch(',onBlastStart);
assert(onBlastStart>=0&&onBlastEnd>onBlastStart,'actual per-explosion Walk callback');
const dispatches=[],host={M:4.1,walkBlastSession:'fixture-session',document:{body:{dataset:{}}},npcBridge:{applyWalkVehicleBlast(input){dispatches.push(input);return {accepted:true};}}};
vm.createContext(host);vm.runInContext('globalThis.onBlast=({'+walk.slice(onBlastStart,onBlastEnd+1)+'}).onBlast;',host);
const noHeroScene=new THREE.Scene(),sourceCar={object:new THREE.Group()};sourceCar.object.userData.sourceVehicleId='source-car';
const independentBlast=createBlastResponse(THREE,noHeroScene,{getHero:()=>null,getVehicles:()=>[],getRoots:()=>[],getGlass:()=>({}),groundHeight:()=>0,onHeroLaunch:()=>assert.fail('no hero to launch'),onBlast:host.onBlast});
independentBlast.enqueue({point:{x:8.2,y:.8,z:4.1},source:sourceCar});independentBlast.update();independentBlast.update();
assert.equal(dispatches.length,1,'one source event, even without a visible hero');assert.equal(dispatches[0].sourceVehicleId,'source-car');assert.equal(dispatches[0].r,1);assert.equal(dispatches[0].c,2);assert.equal(dispatches[0].y,.8);assert.equal(dispatches[0].eventId,'walk-fleet:fixture-session:1');
independentBlast.enqueue({point:{x:8.2,y:.8,z:4.1},power:1.4,radius:11});independentBlast.update();
assert.equal(dispatches.length,1,'RPG visual blast does not charge source damage a second time');
independentBlast.dispose();
assert(walk.includes('worldWalkHealthSurfaceReceipt(event)'));assert(walk.includes('synchronizeWorldWalkHealthSurface(artistSurface'));
console.log('PASS actual source HP blast admission + physical blast callback: range, occlusion, dedupe, no authenticated writes, no RPG double charge, health/death host wiring');
