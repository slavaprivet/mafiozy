import assert from 'node:assert/strict';
import fs from 'node:fs';
import vm from 'node:vm';
import {registerHooks} from 'node:module';
import {pathToFileURL} from 'node:url';
import * as core from './mercenary_core.mjs';
import {createDemoCar,CAR,DRIVER_SEAT} from './car_drive.mjs';
import {createHeroWalker,HERO_ASSET} from './hero_walk.mjs';
import {createNpcNativePerception} from './npc_native_perception.mjs';
import {VEHICLE_SEATS} from './vehicle_seats.mjs';
import {createGlassBreakage} from './glass_breakage.mjs';
import {createNpcVehicleIncomingBridge} from './npc_vehicle_incoming.mjs';
import {createLocalVehicleIncomingCapability} from './npc_vehicle_incoming_capability.mjs';

const read=name=>fs.readFileSync(new URL(name,import.meta.url),'utf8');
const world=read('../../../world.html').replace(/\r\n/g,'\n');
const attackStartActual=world.indexOf('      if(perceivedTarget.visible&&_localHostileCanResolveHit()&&armedAggro&&distToPlayer>.7'),attackEndActual=world.indexOf('      // Игрок в машине',attackStartActual);
const bridgeStartActual=world.indexOf('let _walkNpcVehicleIncomingResolver=null;'),bridgeEndActual=world.indexOf('let _walkCoverResolver=null;',bridgeStartActual);
assert(attackStartActual>=0&&bridgeStartActual>=0,'actual production incoming bridge must exist');
const patch={attack:world.slice(attackStartActual,attackEndActual),bridge:world.slice(bridgeStartActual,bridgeEndActual)};
const walkText=read('./walk_preview.mjs'),walkTargetAnchor='npcVehicleIncoming=createNpcVehicleIncomingBridge({THREE,getTarget:';
const walkTargetStart=walkText.indexOf(walkTargetAnchor)+walkTargetAnchor.length,walkTargetEnd=walkText.indexOf(',getActors:',walkTargetStart);
assert(walkTargetStart>=walkTargetAnchor.length&&walkTargetEnd>walkTargetStart,'actual Walk target descriptor must exist');
const walkTargetSource=walkText.slice(walkTargetStart,walkTargetEnd);
function extract(name){const start=world.indexOf('function '+name+'(');assert(start>=0,name);const tail=world.slice(start),end=tail.search(/\n(?:function |let |const |var )/);return end<0?tail:tail.slice(0,end);}
const host=read('./mercenary_world.js').replace("import(new URL('./mercenary_core.mjs',scriptUrl).href)",'Promise.resolve(module)');
const fixtureText=read('./test_mercenary_rally_actions.mjs');
const fixture=Function('vm','module','script','assert',fixtureText.slice(fixtureText.indexOf('async function fixture('),fixtureText.indexOf('\nfor(const [profession'))+';return fixture;')(vm,core,host,assert);
const vendor=process.env.MAFIOZI_THREE_VENDOR??'D:/codex_release/artist13_hero_first_DEV_20260907/demo/vendor';
registerHooks({resolve(specifier,context,next){return next(specifier==='three'?pathToFileURL(vendor+'/build/three.module.js').href:specifier,context);}});
const THREE=await import(pathToFileURL(vendor+'/build/three.module.js'));
const {GLTFLoader}=await import(pathToFileURL(vendor+'/addons/loaders/GLTFLoader.js'));
const {RoundedBoxGeometry}=await import('../../../tools/vehicle_fleet_qa/RoundedBoxGeometry.mjs');
const bytes=fs.readFileSync(new URL(HERO_ASSET.url)),source=(await new GLTFLoader().parseAsync(bytes.buffer.slice(bytes.byteOffset,bytes.byteOffset+bytes.byteLength),'')).scene;
const scene=new THREE.Scene(),hero=createHeroWalker({THREE,scene:source,targetHeight:1.9}),car=createDemoCar(THREE,RoundedBoxGeometry);
car.profile={...CAR,id:'red_sedan',height:2.22};car.seats=VEHICLE_SEATS;scene.add(car.object,hero.object);car.object.position.set(612.95,0,59.45);
const seat=car.object.localToWorld(new THREE.Vector3(DRIVER_SEAT.side,DRIVER_SEAT.y,DRIVER_SEAT.front));hero.object.position.copy(seat);hero.vehiclePose(1,0,{driver:true,steeringGrips:car.getSteeringGrips(),dt:.1});hero.object.updateMatrixWorld(true);
const f=await fixture(),m=f.recruit('engineer'),cop={id:'real_patrol',kind:'patrol',hp:100,alive:true,x:(car.object.position.x-10)/4.1,y:seat.z/4.1};
Object.assign(f.ctx.player,{r:seat.z/4.1,c:seat.x/4.1,ang:0});Object.assign(m,{r:(car.object.position.z-.15)/4.1,c:(car.object.position.x-.43)/4.1,weapon:'tt_pistol',_mercenaryVehicleId:'fleet:kingswell',_mercenaryVehicleSeat:'front_right',_mercenaryVehiclePhase:'drive',_mercenaryVehicleProgress:1});
const vehicle=()=>({id:'fleet:kingswell',source:false,r:car.object.position.z/4.1,c:car.object.position.x/4.1,ang:Math.PI/2,speed:0,seats:['front_left','front_right','rear_left','rear_right'],occupied:['front_left'],blocked:false});
f.api.bindTargets({squadTransport:{getVehicle:vehicle,getPlayerVehicle:vehicle},groundHeight:()=>0,canMove:()=>true});
let time=1000,rng=.5,sourceVariant=false,onFoot=false,unavailable=false,bodies=[],otherCars=[],wallCalls=0,impacts=0,incoming=0,bullets=[];
const glass=createGlassBreakage(THREE,scene,{groundHeight:()=>0});glass.prepare(car.object);
const walkScope={npcVehicleIncomingCapability:createLocalVehicleIncomingCapability(),sourceVehicleActive:()=>sourceVariant,hero,car,M:4.1,glass,carDamage:{state:{hp:240}},worldHealthFrame:{snapshot:{dead:false}},heroCustodyActive:false,get occupiedSeat(){return onFoot?null:'front_left';},get transition(){return unavailable?{phase:'body'}:null;}};
const target=Function('scope','with(scope){return ('+walkTargetSource+');}')(walkScope);
const bridge=createNpcVehicleIncomingBridge({THREE,getTarget:target,getActors:()=>[{id:'player',object:hero.object}],obstacles:()=>[car.object],getVehicles:()=>[car,...otherCars],bodiesAt:()=>{wallCalls++;return bodies;},local:()=>f.ctx._LOCAL_PREVIEW&&!f.ctx._serverAuthoritativeAmmo,now:()=>time,onImpact:payload=>{impacts++;glass.hit(payload.hit,{direction:payload.direction,impulse:payload.damage,weaponId:payload.weaponId});}});
const coarse=createNpcNativePerception({getVehicles:()=>onFoot?[]:[car],bodiesAt:()=>bodies});
Object.assign(f.ctx,{cityCops:[cop],_worldDirectCombatDemo:false,_walkRendererActive:()=>true,_walkNpcPerceptionResolver:coarse.query,_effectivePlayerStance:()=> 'stand',_walkCoverResolver:null,_murderPoliceArrest:false,_meleeBlockHeld:false,_bankInt:null,_buildingInt:null,_trafficHideActive:false,myDrivingCarId:null,myJailIn:0,playerWanted:false,CITYCOP_PURSUE_R:16,_policeLineClearCache:new Map(),_policeLineClearBucket:-1,MAP:Array.from({length:180},()=>new Uint8Array(200)),_registerIncomingFire:()=>incoming++,_cityCopPursuitChat(){},_threePlayerImpactState:{},spawnBullet:(r,c,tr,tc,data)=>bullets.push({r,c,tr,tc,...data}),spawnMuzzle(){},spawnImpact(){},spawnFloatText(){},Math:Object.assign(Object.create(Math),{random:()=>rng}),performance:{now:()=>time}});
const functions=['_cityCopEngagePlayerAfterHit','_policePerceptionActor','_policeCanSeePoint','_policePursuitTarget','_npcPerceptionHeight','_npcPerceptionTargetHeight','_npcCanSeePoint','_policeWorldLineClear','_markPoliceShot','_localHostileCanResolveHit','_walkCoverDamage','_hurtLocal'];
const noteStart=world.indexOf('function _noteVehicleIncomingAttack('),note=world.slice(noteStart,world.indexOf('// Автоспавн убран',noteStart));
const attackStart=world.indexOf(patch.attack),prefixStart=world.lastIndexOf('    const dpr = player.r - cop.y, dpc = player.c - cop.x;',attackStart),prefix=world.slice(prefixStart,attackStart);
vm.runInContext(patch.bridge+'\n'+functions.map(extract).join('\n')+'\n'+note+'\nfunction actualPoliceStep(cop,now){'+prefix+patch.attack+'}}',f.ctx);
const phaseTimings={sight:[],prepare:[],consume:[]};f.ctx.occupancy=()=>!onFoot||unavailable;f.ctx.resolver=request=>{const start=performance.now(),result=bridge.resolve(request);phaseTimings[request.phase]?.push(performance.now()-start);return result;};vm.runInContext('_walkNpcVehicleIncomingResolver=resolver;_walkVehicleOccupancyResolver=occupancy;',f.ctx);
let checks=0;const check=(value,message)=>{assert(value,message);checks++;};
function step(at=time){time=at;bridge.beginFrame();coarse.beginFrame();f.ctx.actualPoliceStep(cop,time);}
function intent(){return f.api.getVehicleFireIntent(m.id);}
check(f.api.toggleVehicleDefenseFire().ok&&!intent(),'X readiness has no incoming authority');
f.ctx._cityCopEngagePlayerAfterHit(cop,time);const firstDue=cop._murderNextShootAt;
check(firstDue===1260&&!intent()&&!cop._shotSeq,'actual engagement only schedules ordinary first shot');
step(1259);check(!cop._shotSeq&&bullets.length===0&&!intent(),'source cadence suppresses early geometry or receipt');
step(1260);check(cop._shotSeq===1&&bullets.length===1,'actual due source branch marks one emitted shot');
check(cop._murderNextShootAt===2435,'existing900..1450ms source cadence remains1175ms under RNG.5');
check(f.ctx.myHp===100&&impacts===1&&bridge.stats().glass===1,'closed glass receives real first impact and player HP stays100');
check(intent()?.targetRef===cop,'only emitted physical police attack creates ordinary host defensive receipt');
check(cop._visualShot.ray&&cop._visualShot.sequence===1,'accepted physical origin/contact go to existing NPC visual shot contract');
const unchangedSeq=cop._shotSeq;step(1400);step(2200);check(cop._shotSeq===unchangedSeq&&bullets.length===1,'repeated updates before cadence do not spend another sequence');
glass.update(.1);step(2435);check(cop._shotSeq===2&&f.ctx.myHp===90&&incoming===1,'after real glass fracture fresh skin contact reaches actual _hurtLocal once');
check(impacts===1&&bullets.at(-1).hit===true,'skin hit is not also dispatched as vehicle damage');
const hp=f.ctx.myHp,seq=cop._shotSeq;step(2435);check(f.ctx.myHp===hp&&cop._shotSeq===seq,'same source update cannot duplicate health damage');

// Native walls and other vehicles stay in the fresh pre-attack visibility gate.
const head=hero.artistContext().worldPosition('head'),mid=head.clone().lerp(new THREE.Vector3(cop.x*4.1,1.45,cop.y*4.1),.5),mr=mid.z/4.1,mc=mid.x/4.1;
bodies=[{polygonCR:[[mc-.05,mr-.6],[mc+.05,mr-.6],[mc+.05,mr+.6],[mc-.05,mr+.6]],minYM:0,maxYM:3}];step(cop._murderNextShootAt);check(cop._shotSeq===seq&&f.ctx.myHp===hp,'new native wall stops real source branch after prior clear cached sight');bodies=[];
otherCars=[{object:{position:{x:mid.x,y:0,z:mid.z},scale:{x:1,y:1,z:1},rotation:{y:0},visible:true},profile:{...CAR,height:2.22}}];step(time+300);check(cop._shotSeq===seq,'other car occlusion is retained');otherCars=[];
unavailable=true;step(time+300);check(cop._shotSeq===seq,'entry phase is not a stable occupied target');unavailable=false;
sourceVariant=true;step(time+300);check(cop._shotSeq===seq&&bridge.resolve({phase:'sight',localAllowed:true}).reason==='source-pose-stamp-unavailable','source-car variant explicitly fails closed; no root-as-seat assumption');sourceVariant=false;
f.ctx._serverAuthoritativeAmmo=true;step(time+300);check(cop._shotSeq===seq&&f.ctx.myHp===hp,'authenticated mode cannot use local bridge authority');f.ctx._serverAuthoritativeAmmo=false;
vm.runInContext('_walkNpcVehicleIncomingResolver=null;',f.ctx);step(time+300);check(cop._shotSeq===seq,'missing Walk resolver cannot fall back to through-car HP');vm.runInContext('_walkNpcVehicleIncomingResolver=resolver;',f.ctx);
const beforeCoords={x:cop.x,y:cop.y};cop.x=(car.object.position.x+.43)/4.1;cop.y=(car.object.position.z-10)/4.1;step(time+300);check(cop._shotSeq===seq,'real rear seat/body cover blocks the source attack');Object.assign(cop,beforeCoords);

// Preserve source random horizontal spread: distant .99 miss must not become
// the candidate's exact head contact. Remain inside unchanged 14-cell range.
cop.x=f.ctx.player.c-12;cop.y=f.ctx.player.r;rng=.99;step(time+300);step(time+1);
check(cop._shotSeq===seq+1&&f.ctx.myHp===hp&&bullets.at(-1).hit===false,'actual source spread produces one real miss with zero invented HP: '+JSON.stringify({seq:cop._shotSeq,hp:f.ctx.myHp,bullet:bullets.at(-1),stats:bridge.stats()}));
check(cop._murderNextShootAt===time+1444.5,'upper cadence uses original RNG expression');
check(cop._visualShot.ray.target.z!==head.z,'renderer target reflects the actual missed ray');
cop.x=beforeCoords.x;cop.y=beforeCoords.y;check(intent()?.targetRef===cop,'real missed attack remains provenance when hostile is physically in range again');

// Real on-foot path keeps old native visibility/cadence/damage with no bridge.
onFoot=true;rng=.5;step(cop._murderNextShootAt);check(cop._shotSeq===seq+2&&f.ctx.myHp===hp-10,'on-foot fallback still uses unchanged legacy local damage');check(cop._visualShot===undefined,'old vehicle ray cannot leak into later foot shot');
const afterFoot=cop._shotSeq;f.ctx._LOCAL_PREVIEW=false;f.ctx._serverAuthoritativeAmmo=true;step(cop._murderNextShootAt);check(cop._shotSeq===afterFoot,'actual _localHostileCanResolveHit stops online local hits');
check(f.ctx._policeCanSeePoint(cop,f.ctx.player.r,f.ctx.player.c,24),'online on-foot ordinary perception is unchanged');
f.ctx._LOCAL_PREVIEW=true;f.ctx._serverAuthoritativeAmmo=false;onFoot=false;rng=.99;
check(f.ctx._walkPoliceVehicleIncoming({phase:'prepare',cop:{...cop}}).reason==='unregistered-source','same-id unregistered source never falls back to invented shot');
const cohort=Array.from({length:12},(_,i)=>({id:'cohort'+i,kind:'patrol',hp:100,alive:true,x:f.ctx.player.c-12,y:f.ctx.player.r+i*.01,_murderNextShootAt:time,_playerAttackUntil:time+45000,_murderAggroUntil:time+45000,_shotSeq:0}));
for(const c of cohort){c.ang=Math.atan2(f.ctx.player.r-c.y,f.ctx.player.c-c.x);f.ctx.cityCops.push(c);}
let frames=0,maxSight=0,maxPhysical=0,sourceMs=[];
for(;frames<32&&!cohort.every(c=>c._shotSeq>0);frames++){
 time+=100;bridge.beginFrame();coarse.beginFrame();const start=performance.now();for(const c of cohort)f.ctx.actualPoliceStep(c,time);sourceMs.push(performance.now()-start);
 maxSight=Math.max(maxSight,bridge.stats().sightProbes);maxPhysical=Math.max(maxPhysical,bridge.stats().probes);
 check(bridge.stats().sightProbes<=2&&bridge.stats().probes<=1,'actual12-source-body loop respects both per-frame geometry budgets');
 if(frames===0)check(cohort.filter(c=>c._shotSeq===0).every(c=>c._murderNextShootAt===time-100),'pending/budget does not advance rejected source cadence');
}
check(cohort.every(c=>c._shotSeq>0),'all12 actual cops eventually emit under source cadence and fair geometry queues');
const percentile=values=>{const sorted=[...values].sort((a,b)=>a-b);return {calls:sorted.length,p50:sorted[Math.floor(sorted.length*.5)],p95:sorted[Math.floor(sorted.length*.95)],max:sorted.at(-1)};};
console.log(JSON.stringify({status:'PASS actual source-body + actual production local Walk geometry',checks,sourceShots:cop._shotSeq,hp:f.ctx.myHp,carImpacts:impacts,incomingHealthHits:incoming,bridge:bridge.stats(),cohort:{observers:12,frames,maxSight,maxPhysical,shots:cohort.map(c=>c._shotSeq)},actualPhaseCpuMs:Object.fromEntries(Object.entries(phaseTimings).map(([key,values])=>[key,percentile(values)])),twelveCopBodyCpuMs:percentile(sourceMs),broadphaseCalls:wallCalls,productionEdits:0},null,2));
glass.dispose();
