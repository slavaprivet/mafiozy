import assert from 'node:assert/strict';
import fs from 'node:fs';
import vm from 'node:vm';
import {registerHooks} from 'node:module';
import {pathToFileURL} from 'node:url';
import * as core from './mercenary_core.mjs';
import {createNpcActor,NPC_ASSETS} from './npc_actor.mjs';
import {clone} from './test_npc_death_offline_setup.mjs';
import {createArtistVehicle} from './vehicle_fleet_models.mjs';
import {createDemoCar,CAR} from './car_drive.mjs';
import {VEHICLE_SEATS} from './vehicle_seats.mjs';
import {createNpcTrafficVehicleBinding} from './npc_vehicle_pose.mjs';
import {createWeaponModel} from './hero_arsenal.mjs';
import {createMercenaryVehicleFire,mercenaryVehicleFireWeapon} from './mercenary_vehicle_fire.mjs';
import {createMercenaryVehicleBridge} from './mercenary_vehicle_bridge.mjs';
import {createNpcShotEffects} from './npc_shot_effects.mjs';

// Actual source host, actual gang damage dispatcher, actual posed NPC skins and
// vehicle GLB. Only browser dynamic import is adapted to Node's same module.
const read=name=>fs.readFileSync(new URL(name,import.meta.url),'utf8');
const host=read('./mercenary_world.js'),script=host.replace("import(new URL('./mercenary_core.mjs',scriptUrl).href)",'Promise.resolve(module)');
assert.notEqual(script,host);
const fixtureSource=read('./test_mercenary_rally_actions.mjs');
const fixture=Function('vm','module','script','assert',fixtureSource.slice(fixtureSource.indexOf('async function fixture('),fixtureSource.indexOf('\nfor(const [profession'))+';return fixture;')(vm,core,script,assert);
const world=read('../../../world.html'),loop=world.slice(world.indexOf('function _updateGang(dt) {'),world.indexOf('// Персистентность охраны банка:'));
const combatSource=read('./test_mercenary_focus_source.mjs');
const combat=Function('fixture','vm','loop',combatSource.slice(combatSource.indexOf('async function combat('),combatSource.indexOf("\ntest('explicit focused"))+';return combat;')(fixture,vm,loop);
const vendor=process.env.MAFIOZI_THREE_VENDOR??'D:/codex_release/artist13_hero_first_DEV_20260907/demo/vendor';
registerHooks({resolve(specifier,context,next){return next(specifier==='three'?pathToFileURL(vendor+'/build/three.module.js').href:specifier,context);}});
const THREE=await import(pathToFileURL(vendor+'/build/three.module.js'));
const {GLTFLoader}=await import(pathToFileURL(vendor+'/addons/loaders/GLTFLoader.js'));
const {RoundedBoxGeometry}=await import('../../../tools/vehicle_fleet_qa/RoundedBoxGeometry.mjs');
const load=async url=>{const bytes=fs.readFileSync(url);return(await new GLTFLoader().parseAsync(bytes.buffer.slice(bytes.byteOffset,bytes.byteOffset+bytes.byteLength),'')).scene;};
class Box extends THREE.BoxGeometry{constructor(w,h,d){super(w,h,d);}}
const carSource=await load(new URL('./models/artist_vehicle_pack/compact_sedan.glb',import.meta.url));
const sources=Object.fromEntries(await Promise.all(['male','female'].map(async sex=>[sex,await load(new URL(NPC_ASSETS[sex].url))])));
let checks=0;const check=(value,message)=>{assert(value,message);checks++;};
async function scenario({sex='male',seatId='front_right',yaw=0,weaponId='tt_pistol',source=false,model='compact',defense=true,attacked=true,missingWindow=false}={}){
 const f=await combat(),m=f.ctx._myGang[0];f.ctx._myGang[1].weapon='none';
 const scene=new THREE.Scene(),car=model==='kingswell'?createDemoCar(THREE,RoundedBoxGeometry):createArtistVehicle(THREE,Box,carSource,'compact_sedan');scene.add(car.object);car.object.position.set(41,0,41);car.object.rotation.y=yaw;car.object.updateMatrixWorld(true);
 if(model==='kingswell'){car.profile={...CAR,id:'red_sedan',label:'Kingswell',height:2.22,massKg:1500};car.seats=VEHICLE_SEATS;}
 if(missingWindow)car.doors.clear();
 const binding=createNpcTrafficVehicleBinding({THREE,actor:car});
 let descriptorOffset=0;
 const carId=source?'quest_audit':'fleet:audit',descriptor=()=>({id:carId,source,r:car.object.position.z/4.1,c:(car.object.position.x+descriptorOffset)/4.1,ang:Math.PI/2-car.object.rotation.y,speed:0,seats:['front_left','front_right','rear_left','rear_right'],occupied:['front_left'],blocked:false});
 if(source)f.ctx.questCars=new Map([['audit',{id:'audit',x:10,y:10,ang:Math.PI/2-yaw,passenger_uids:[]}]]);
 const transport={getPlayerVehicle:descriptor,getVehicle:descriptor,setReservations(){},getActor:()=>car,access:({seatId})=>{const s=binding.getSeatRootWorld(seatId).clone();return {seat:{r:s.z/4.1,c:s.x/4.1},outside:{r:s.z/4.1,c:s.x/4.1}};}};
 f.api.bindTargets({squadTransport:transport,canMove:()=>true,groundHeight:()=>0,hasLineOfSight:()=>true});
 Object.assign(m,{weapon:weaponId,_mercenaryVehicleId:carId,_mercenaryVehicleSeat:seatId,_mercenaryVehiclePhase:'drive',_mercenaryVehicleProgress:1});
 Object.assign(f.ctx,{_threeNpcEntityId:n=>'npc_'+n.id});
 const seat=car.seats.find(s=>s.id===seatId),side=new THREE.Vector3(seat.side,0,0).applyQuaternion(car.object.quaternion),seatPosition=binding.getSeatRootWorld(seatId).clone(),target=seatPosition.clone().addScaledVector(side,8);
 f.enemy.r=target.z/4.1;f.enemy.c=target.x/4.1;f.enemy.hp=1000;
 const actors=new Map(),create=(id,sex='male')=>{const a=createNpcActor({THREE,scene,source:sources[sex],cloneSkeleton:clone,id,sex,getVehicle:()=>binding});actors.set(id,a);return a;};
 const npc=create('npc_crew_'+m.id,sex),enemy=create('npc_'+f.enemy.id),hero=create('player');
 npc.mountWeapon(createWeaponModel(THREE,weaponId));
 hero.update(0,{position:{x:41,y:0,z:44},yaw:0,life:{}});
 const snapshot=()=>f.api.decorateEntities([{id:npc.id,hp:m.hp}])[0];
 const render=(dt=.1)=>{const life=snapshot();npc.update(dt,{time:f.ctx.performance.now()/1000,position:{x:m.c*4.1,y:0,z:m.r*4.1},yaw:Math.PI/2-m.ang,life});enemy.update(0,{time:1,position:{x:f.enemy.c*4.1,y:0,z:f.enemy.r*4.1},yaw:0,life:{}});};
 const obstacles=[car.object],renderer=createMercenaryVehicleFire({THREE,getActors:()=>[...actors.values()].filter(a=>a!==hero).map(a=>({id:a.id,object:a.object})),getActor:id=>actors.get(id),getPlayer:()=>hero,obstacles:()=>obstacles,getHost:()=>f.api,diagnostics:true});
 f.ctx.window.MafioziMercenaryVehicleFire=renderer;
 check(f.api.canIssueVehicleFireCommand(),'eligible passenger permits command');
 if(defense)check(f.api.toggleVehicleDefenseFire().ok,'actual X toggle arms defense without a focus');
 if(attacked)check(f.api.noteVehicleAttack({kind:'street_npc',ref:f.enemy,victimKind:'player',victimId:'player'}),'actual incoming source receipt');
 render();render();render();
 return {...f,m,scene,car,binding,transport,npc,enemyActor:enemy,hero,actors,create,render,obstacles,renderer,intent:()=>f.api.getVehicleFireIntent(m.id),offset:v=>descriptorOffset=v,cleanup(){for(const a of actors.values())a.dispose();}};
}

let geometryCases=0;
for(const model of process.env.DEFENSE_QUICK?[]:['compact','kingswell'])for(const source of model==='kingswell'?[false,true]:[false])for(const sex of ['male','female'])for(const seatId of ['front_right','rear_left','rear_right'])for(const yaw of [0,1.1])for(const weaponId of ['tt_pistol','uzi']){
 const f=await scenario({model,source,sex,seatId,yaw,weaponId}),proof=f.renderer.prepareShot(f.intent());
 check(proof.ready,`${model}/${source}/${sex}/${seatId}/${yaw}/${weaponId}: ${JSON.stringify(proof)}`);geometryCases++;
 const before={r:f.m.r,c:f.m.c,seat:f.m._mercenaryVehicleSeat,seq:f.m._shotSeq||0,inventory:JSON.stringify(f.ctx._inventoryItems),targetKind:f.m.targetKind,targetRef:f.m.targetRef,targetId:f.m.targetId},root=f.npc.object.position.clone(),context=f.npc.walker.artistContext(),legs=['thigh_l','thigh_r','shin_l','shin_r','foot_l','foot_r'].map(n=>context.worldPosition(n));
 for(let i=0;i<3;i++)check(f.renderer.prepareShot(f.intent()).ready,'repeated fresh pose accepted');
 check(f.npc.object.position.distanceTo(root)<1e-8,'repeated proof keeps source root');
 for(const [i,name] of ['thigh_l','thigh_r','shin_l','shin_r','foot_l','foot_r'].entries())check(context.worldPosition(name).distanceTo(legs[i])<1e-7,'repeated proof keeps seated legs');
 let xp=0,accepted;const prepare=f.renderer.prepareShot;f.renderer.prepareShot=intent=>(accepted=prepare(intent));f.ctx.hitNpc=(target,r,c,w,dmg)=>{target.hp-=dmg;f.shots.push(target);};f.ctx._awardGangXp=(member,dmg)=>{check(member===f.m&&dmg>0,'XP comes from accepted damage');xp++;};
 f.update();check(f.shots.length===1&&xp===1,'one accepted source hit / XP');check(f.m._shotSeq===before.seq+1,'one receipt sequence');check(f.m._visualShot.ray&&f.m._visualShot.ray.origin.x===accepted.origin.x,'receipt uses current physical origin');
 f.update();check(f.shots.length===1&&xp===1,'cooldown stops duplicate dispatch');check(f.m._mercenaryVehicleSeat===before.seat,'firing keeps assigned seat');check(JSON.stringify(f.ctx._inventoryItems)===before.inventory,'no hero ammo or inventory mutation');
 check(f.m.targetKind===before.targetKind&&f.m.targetRef===before.targetRef&&f.m.targetId===before.targetId,'defensive hit never replaces prior walking target');
 f.cleanup();
}
let weaponCases=0;
for(const weaponId of process.env.DEFENSE_QUICK?[]:['nagan','revolver','deagle','golden_colt','golden_uzi','tommy_gun','sawn_off','shotgun','ak74','m16','sniper'])for(const sex of ['male','female']){
 const f=await scenario({model:'kingswell',weaponId,sex,seatId:sex==='male'?'front_right':'rear_left',yaw:1.1}),proof=f.renderer.prepareShot(f.intent());
 check(proof.ready,`held ${weaponId}/${sex}: ${JSON.stringify(proof)}`);check(mercenaryVehicleFireWeapon(f.intent().weaponId)===weaponId,'exact held model is preserved');f.update();check(f.shots.length===1,'actual held family dispatches once');weaponCases++;f.cleanup();
}
{
 const f=await scenario({model:'kingswell',defense:false,attacked:false}),c=f.npc.walker.artistContext(),bone=c.bones.chest,rotation=()=>{const q=new THREE.Quaternion();bone.matrix.decompose(new THREE.Vector3(),q,new THREE.Vector3());return q;},q=rotation(),seat=f.m._mercenaryVehicleSeat,root=f.npc.object.position.clone(),orders=JSON.stringify(f.ctx._myGang.map(m=>[m._mercenaryOrder,m._mercenaryRally,m._mercenaryFocus,f.api.getQueue(m.id)]));
 check(!f.intent()&&!f.api.getVehicleDefenseFireState().enabled,'new session starts with no defensive intent');
 f.m._threatRef=f.enemy;f.m._threatUntil=f.ctx.performance.now()+6000;f.api.toggleVehicleDefenseFire();f.render(.09);
 const half=rotation().angleTo(q);check(half>.1,'X begins visible lean before any attacker '+JSON.stringify({half,state:f.api.getVehicleDefenseFireState(),life:f.api.decorateEntities([{id:f.npc.id,hp:f.m.hp}])[0],weapon:f.npc.weapon?.userData?.weaponId}));f.render(.09);check(rotation().angleTo(q)>half,'ready lean progresses smoothly');
 check(!f.intent(),'generic threat and ready pose cannot authorize a shot');f.update();check(f.shots.length===0,'ready pose has zero HP/cooldown authority');
 check(f.npc.object.position.distanceTo(root)<1e-8&&f.m._mercenaryVehicleSeat===seat,'X-ready keeps source root and seat');check(JSON.stringify(f.ctx._myGang.map(m=>[m._mercenaryOrder,m._mercenaryRally,m._mercenaryFocus,f.api.getQueue(m.id)]))===orders,'X leaves queues and walking orders unchanged');
 f.api.toggleVehicleDefenseFire();f.render(.11);const returning=rotation().angleTo(q);check(returning>.05&&returning<1,'off smoothly begins return');f.render(.11);check(rotation().angleTo(q)<1e-6,'off completes return to baseline seating');f.cleanup();
}
{
 const f=await scenario({defense:false,attacked:false,missingWindow:true});f.api.toggleVehicleDefenseFire();f.render(.1);check(!f.intent(),'missing window cannot create intent without attack');f.api.toggleVehicleDefenseFire();f.render(.1);f.render(.2);check(f.npc.object.visible,'missing window followed by X-off is safe and keeps actor');f.cleanup();
}
for(const source of [false,true]){
 const f=await scenario({model:'kingswell',source,weaponId:'ak74'}),carId=source?'quest_audit':'fleet:audit';
 const bridge=createMercenaryVehicleBridge({getFleet:()=>({records:[{id:'audit',car:f.car,state:{speed:8}}]}),getTraffic:()=>({getActor:id=>id===carId?f.car:null}),getPlayer:()=>({id:carId,seatId:'front_left',ready:true})});
 f.api.bindTargets({squadTransport:bridge,groundHeight:()=>0,canMove:()=>true});
 const old=f.intent();f.car.object.position.x+=.35;f.car.object.position.z+=.2;f.car.object.rotation.y+=.04;f.car.object.updateMatrixWorld(true);
 if(source)Object.assign(f.ctx.questCars.get('audit'),{x:20,y:30,ang:1.3}); // Source can lead rendering; rendered geometry still owns this muzzle.
 f.enemy.c+=.04;f.enemy.r+=.05;f.enemyActor.update(0,{position:{x:f.enemy.c*4.1,y:0,z:f.enemy.r*4.1},yaw:0,life:{}});
 check(!f.api.validateVehicleFireIntent(old),'moving car/attacker invalidate previous proof');const fresh=f.intent();check(Math.abs(fresh.vehiclePose.x-f.car.object.position.x)<1e-8,'actual bridge uses fresh rendered car for physical proof');
 check(f.renderer.prepareShot(fresh).ready,'source advance then turning car and moving attacker freshly posed without prior passenger render');f.update();check(f.shots.length===1,'moving actual bridge dispatches one accepted shot');f.cleanup();
}
let rejectionCases=0;
const rejection=async(name,mutate,{render=false,...scenarioOptions}={})=>{const f=await scenario(scenarioOptions);{const baseline=f.renderer.prepareShot(f.intent());check(baseline.ready,'negative baseline '+name+': '+JSON.stringify(baseline));}const before=JSON.stringify({seq:f.m._shotSeq||0,cooldown:f.m._nextShootAt||0,inventory:f.ctx._inventoryItems,hp:f.enemy.hp});await mutate(f);if(render)f.render();f.update();check(f.shots.length===0,name+' rejects damage');check(JSON.stringify({seq:f.m._shotSeq||0,cooldown:f.m._nextShootAt||0,inventory:f.ctx._inventoryItems,hp:f.enemy.hp})===before,name+' preserves authority');f.cleanup();rejectionCases++;};
for(const flag of ['_friendly','_allied','_invulnerable','downed','dead'])await rejection('target '+flag,f=>f.enemy[flag]=true);
await rejection('target disappears',f=>f.ctx.NPCS.splice(f.ctx.NPCS.indexOf(f.enemy),1));
await rejection('same ID replaced',f=>{const i=f.ctx.NPCS.indexOf(f.enemy);f.ctx.NPCS[i]={...f.enemy};});
for(const flag of ['_serverAuthoritativeAmmo','_customGang'])await rejection('online '+flag,f=>f.ctx[flag]=true);
await rejection('preview disabled',f=>f.ctx._LOCAL_PREVIEW=false);
for(const weapon of ['rpg','bazooka','ak47','none','melee','grenade'])await rejection('unsupported '+weapon,f=>f.m.weapon=weapon);
await rejection('passenger downed',f=>f.m.hp=0);
await rejection('exit pending',f=>{f.m._mercenaryVehicleExitPending=true;f.transport.getPlayerVehicle=()=>null;});
await rejection('boarding',f=>{f.m._mercenaryVehiclePhase='board';f.m._mercenaryVehicleProgress=.1;});
await rejection('exiting',f=>f.m._mercenaryVehiclePhase='exit');
await rejection('actor hidden',f=>f.npc.object.visible=false);
await rejection('actor disposed',f=>f.npc.dispose());
await rejection('weapon absent',f=>f.npc.mountWeapon(null));
await rejection('car source pose stale',f=>f.offset(1));
await rejection('forged identity',f=>{const original=f.renderer.prepareShot;f.renderer.prepareShot=intent=>({...original(intent),memberId:'wrong'});});
await rejection('target changes after prepare',f=>{const original=f.renderer.prepareShot;f.renderer.prepareShot=intent=>{const result=original(intent);f.enemy.c+=.5;return result;};});
await rejection('weapon changes after prepare',f=>{const original=f.renderer.prepareShot;f.renderer.prepareShot=intent=>{const result=original(intent);f.m.weapon='uzi';return result;};});
await rejection('own side only',f=>{const seat=f.binding.getSeatRootWorld(f.m._mercenaryVehicleSeat);f.enemy.c=(2*seat.x-f.enemy.c*4.1)/4.1;f.render();f.render();});
await rejection('wall occlusion',f=>{const p=f.renderer.prepareShot(f.intent()),wall=new THREE.Mesh(new THREE.BoxGeometry(3,3,.2),new THREE.MeshBasicMaterial());wall.position.set(p.origin.x,p.origin.y,p.origin.z).addScaledVector(new THREE.Vector3(p.direction.x,p.direction.y,p.direction.z),2);wall.quaternion.setFromUnitVectors(new THREE.Vector3(0,0,1),new THREE.Vector3(p.direction.x,p.direction.y,p.direction.z));f.scene.add(wall);f.obstacles.push(wall);});
for(const kind of ['friend','player'])await rejection(kind+' actual skin blocks',f=>{const p=f.renderer.prepareShot(f.intent()),a=kind==='player'?f.hero:f.create('npc_friend'),position=new THREE.Vector3(p.origin.x,p.origin.y,p.origin.z).addScaledVector(new THREE.Vector3(p.direction.x,p.direction.y,p.direction.z),2.5);a.update(0,{time:2,position:{x:position.x,y:0,z:position.z},yaw:0,life:{}});const chest=a.walker.artistContext().worldPosition('chest');a.update(0,{time:2,position:{x:position.x,y:position.y-chest.y,z:position.z},yaw:0,life:{}});});
for(const seatId of ['front_right','rear_left','rear_right'])for(const weaponId of ['tt_pistol','uzi']){
 const options={model:'kingswell',seatId,weaponId,source:seatId==='rear_left',sex:weaponId==='uzi'?'female':'male',yaw:1.1};
 await rejection('Kingswell wrong side '+seatId+'/'+weaponId,f=>{const seat=f.binding.getSeatRootWorld(seatId);f.enemy.c=(2*seat.x-f.enemy.c*4.1)/4.1;f.enemy.r=(2*seat.z-f.enemy.r*4.1)/4.1;f.render();f.render();},options);
 await rejection('Kingswell wall '+seatId+'/'+weaponId,f=>{const p=f.renderer.prepareShot(f.intent()),wall=new THREE.Mesh(new THREE.BoxGeometry(3,3,.2),new THREE.MeshBasicMaterial());wall.position.set(p.origin.x,p.origin.y,p.origin.z).addScaledVector(new THREE.Vector3(p.direction.x,p.direction.y,p.direction.z),2);wall.quaternion.setFromUnitVectors(new THREE.Vector3(0,0,1),new THREE.Vector3(p.direction.x,p.direction.y,p.direction.z));f.scene.add(wall);f.obstacles.push(wall);},options);
}
{
 const f=await scenario(),before=f.intent();f.car.object.position.x+=1;f.car.object.rotation.y+=.2;f.car.object.updateMatrixWorld(true);check(!f.api.validateVehicleFireIntent(before),'old car pose invalid after movement');
 for(let i=0;i<4;i++)f.render();check(f.renderer.prepareShot(f.intent()).ready,'fresh moved and rotated car can shoot');f.update();check(f.shots.length===1,'moving car source accepts once');
 const stats=f.renderer.stats();check(stats.accepted===1&&stats.sequence===1&&stats.ready>=1,'QA ready distinct from accepted');check(!f.renderer.recordAccepted({},1),'foreign proof not counted');check(f.renderer.stats().accepted===1,'counter stable on invalid proof');
 f.cleanup();
}
check(mercenaryVehicleFireWeapon('pistol')==='tt_pistol'&&mercenaryVehicleFireWeapon('smg')==='uzi'&&mercenaryVehicleFireWeapon('rpg')===null,'explicit supported weapon family');
{
 const f=await scenario(),fx=createNpcShotEffects({THREE,scene:f.scene,getActor:id=>f.actors.get(id)}),base={id:f.npc.id,hp:100,mercenary:{profession:'medic'}};
 fx.sync([base],999000,999);f.update();const shot=f.m._visualShot,receipt={...base,_visualShot:shot},expected={...shot.ray.origin};fx.sync([receipt],1000000,1000);
 f.car.object.position.x+=10;f.npc.weapon.position.x+=3;f.npc.object.updateMatrixWorld(true);fx.update(1000);
 check(fx.stats().totalShots===1,'accepted physical shot creates one effect');check(new THREE.Vector3(...fx.inspect()[0].origin).distanceTo(new THREE.Vector3(expected.x,expected.y,expected.z))<1e-10,'accepted ray survives car and weapon movement');
 const malformed={...receipt,_visualShot:{...shot,sequence:shot.sequence+1,at:1000100,ray:{origin:{x:NaN,y:0,z:0},target:{x:1,y:1,z:1}}}};fx.sync([malformed],1000100,1000.1);fx.update(1000.1);check(fx.stats().totalShots===1&&fx.stats().dropped===1,'invalid accepted ray has no muzzle fallback');
 fx.dispose();f.cleanup();
}
{
 const f=await scenario({source:true});check(f.renderer.prepareShot(f.intent()).ready,'source quest vehicle proof');f.update();check(f.shots.length===1&&f.m._mercenaryVehicleId==='quest_audit','source vehicle dispatch keeps identity');f.cleanup();
}
const cpu={};
{
 const f=await scenario(),second=f.ctx._myGang[1],third=f.recruit('safecracker');
 for(const [member,seat]of [[second,'rear_left'],[third,'rear_right']])Object.assign(member,{weapon:'tt_pistol',_mercenaryVehicleId:'fleet:audit',_mercenaryVehicleSeat:seat,_mercenaryVehiclePhase:'drive',_mercenaryVehicleProgress:1});
 const leftEnemy={...f.enemy,id:'left-attacker',c:10+8/4.1};f.ctx.NPCS.push(leftEnemy);check(f.api.noteVehicleAttack({kind:'street_npc',ref:leftEnemy,victimKind:'player'}),'left passenger has an actual attacker at its own window');
 check(f.api.getVehicleDefenseFireState().enabled,'three armed passengers share enabled defense');
 const attempts=[];f.renderer.prepareShot=intent=>{attempts.push(intent.memberId);return {ready:false,reason:'fixture_occluded'};};
 for(let i=0;i<6;i++){const before=attempts.length;f.tick(.25);f.update();check(attempts.length===before+1,'one physical proof budget per source tick');}
 check(new Set(attempts.slice(0,3)).size===3&&new Set(attempts.slice(3)).size===3,'round robin does not starve blocked passengers at four FPS');
 const before=attempts.length;for(let i=0;i<5;i++)f.update();check(attempts.length<=before+2,'same-member rejected retries are bounded without elapsed time');check(f.shots.length===0,'rejected probe creates no damage');f.cleanup();
}
{
 const f=await scenario(),measure=fn=>{for(let i=0;i<12;i++)fn();const values=[];for(let i=0;i<40;i++){const start=performance.now();fn();values.push(performance.now()-start);}values.sort((a,b)=>a-b);return {p50ms:values[20],p95ms:values[38]};};
 cpu.firingPose=measure(()=>f.render());cpu.physicalAdmission=measure(()=>f.renderer.prepareShot(f.intent()));f.api.setVehicleDefenseFire(false);cpu.seatedIdle=measure(()=>f.render());f.cleanup();
}
console.log(JSON.stringify({status:'PASS',checks,geometryCases,weaponCases,rejectionCases,cpu,limits:'Isolated actual-model CPU only; loaded scene LIVE/FPS remains coordinator responsibility.'}));
