import assert from 'node:assert/strict';
import fs from 'node:fs';
import vm from 'node:vm';
import {registerHooks} from 'node:module';
import {pathToFileURL} from 'node:url';
import * as core from './mercenary_core.mjs';
import {createNpcActor,NPC_ASSETS} from './npc_actor.mjs';
import {clone} from './test_npc_death_offline_setup.mjs';
import {createArtistVehicle} from './vehicle_fleet_models.mjs';
import {createNpcTrafficVehicleBinding} from './npc_vehicle_pose.mjs';
import {createNpcContactRay} from './npc_contact_ray.mjs';
import {ARSENAL,createWeaponModel} from './hero_arsenal.mjs';
import {vehicleWindowFrame,planVehicleWindowShot,applyVehicleWindowPose,setVehicleWindowOpen} from './vehicle_window_fire.mjs';

// Read-only integration audit. No production transformation except replacing the
// browser dynamic import with the same real module in the isolated VM fixture.
// Known runtime blockers are reproduced, not declared as implemented features.
const read=name=>fs.readFileSync(new URL(name,import.meta.url),'utf8');
const host=read('./mercenary_world.js'),script=host.replace("import(new URL('./mercenary_core.mjs',scriptUrl).href)",'Promise.resolve(module)');
assert.notEqual(script,host);
const fixtureSource=read('./test_mercenary_rally_actions.mjs');
const fixture=Function('vm','module','script','assert',fixtureSource.slice(fixtureSource.indexOf('async function fixture('),fixtureSource.indexOf('\nfor(const [profession'))+';return fixture;')(vm,core,script,assert);
const world=read('../../../world.html'),loop=world.slice(world.indexOf('function _updateGang(dt) {'),world.indexOf('// Персистентность охраны банка:'));
const combatSource=read('./test_mercenary_focus_source.mjs');
const combat=Function('fixture','vm','loop',combatSource.slice(combatSource.indexOf('async function combat('),combatSource.indexOf("\ntest('explicit focused"))+';return combat;')(fixture,vm,loop);
const report={status:'AUDIT',productionChanged:false,blockers:[],preserved:[],geometry:null};

{
 const f=await fixture({qa:true});for(const p of ['medic','engineer','safecracker'])f.recruit(p);
 const car={id:'audit-car',x:10,y:10,ang:0,passenger_uids:[]};
 Object.assign(f.ctx,{questCars:new Map([[car.id,car]]),myDrivingCarId:car.id,myIsPassenger:false,_walkVehicleSeatId:'front_left'});f.ctx.QP.uid='me';
 f.api.bindTargets({canMove:()=>true,groundHeight:()=>0,hasLineOfSight:()=>true});f.api.follow();f.tick();
 assert.equal(f.ctx._myGang.filter(m=>m._mercenaryVehicleSeat).length,3);
 const rows=f.api.decorateEntities(f.ctx._myGang.map(m=>({id:'crew_'+m.id,hp:m.hp})));
 assert(rows.every(row=>row.civilianTripRiding&&row.weapon==='none'));
 report.blockers.push('actual seated snapshot hides every weapon');
 const enemy={id:'vehicle-focus-audit',r:10,c:12,hp:100};f.ctx.NPCS.push(enemy);
 assert.equal(f.api.command('eliminate',{id:enemy.id}).ok,true);assert(f.ctx._myGang.every(m=>m._mercenaryDefending));
 f.tick();assert(f.ctx._myGang.every(m=>!m._mercenaryVehicleSeat&&!m._mercenaryVehicleId));
 report.blockers.push('actual eliminate -> defending -> squadVehicleTick ejects all three passengers');
}
{
 const f=await combat();let line=true,checks=0;
 f.api.bindTargets({canMove:()=>true,hasLineOfSight:()=>{checks++;return line;}});
 assert.equal(f.api.command('eliminate',{id:f.enemy.id}).ok,true);assert(checks>0);
 line=false;checks=0;f.update();assert.equal(f.shots.length,2);assert.equal(checks,0);
 report.blockers.push('world gang loop performs no fresh world LOS query after an accepted order');
 const sequences=f.ctx._myGang.map(m=>m._shotSeq);f.update();assert.equal(f.shots.length,2);assert.deepEqual(f.ctx._myGang.map(m=>m._shotSeq),sequences);
 report.preserved.push('one source shot sequence / cooldown per fighter; repeat update does not duplicate the shot');
}
{
 const f=await combat();f.api.bindTargets({canMove:()=>true,hasLineOfSight:()=>false});
 assert.equal(f.api.command('eliminate',{id:f.enemy.id}).ok,false);
 f.api.bindTargets({canMove:()=>true,hasLineOfSight:()=>true});
 for(const flag of ['_friendly','_allied','_invulnerable','downed','dead']){f.enemy[flag]=true;assert.equal(f.api.command('eliminate',{id:f.enemy.id}).ok,false,flag);delete f.enemy[flag];}
 assert.equal(f.api.command('eliminate',{id:f.ctx._myGang[0].id}).ok,false);
 const before=JSON.stringify({inventory:f.ctx._inventoryItems,crew:f.ctx._myGang.map(m=>[m.id,m.weapon,m._shotSeq])});
 f.ctx._serverAuthoritativeAmmo=true;assert.equal(f.api.command('eliminate',{id:f.enemy.id}).ok,false);f.tick();
 assert.equal(JSON.stringify({inventory:f.ctx._inventoryItems,crew:f.ctx._myGang.map(m=>[m.id,m.weapon,m._shotSeq])}),before);
 report.preserved.push('actual own/friendly/downed/invulnerable/occluded command rejection and online authority guard');
}
{
 const walk=read('./walk_preview.mjs'),start=walk.indexOf('mercenaryWalk=createMercenaryWalk('),end=walk.indexOf('\n',start),call=walk.slice(start,end);
 const guard=call.slice(call.indexOf('isBlocked:()=>')+'isBlocked:()=>'.length,call.indexOf(',onOpenChange:'));
 const evaluate=occupiedSeat=>vm.runInNewContext(guard,{occupiedSeat,transition:null,busy:false,mercenaryInputBlocked:()=>false,arsenalOpen:()=>false,$:()=>({hidden:true})});
 assert.equal(evaluate(null),false);assert.equal(evaluate('front_left'),true);
 report.blockers.push('actual Walk shared mercenary UI gate blocks X while occupiedSeat is set');
}

// Candidate composition only: actual NPC seated presentation, actual car GLB,
// existing player window pose applied afterward. This sends no gameplay shot.
const vendor=process.env.MAFIOZI_THREE_VENDOR??'D:/codex_release/artist13_hero_first_DEV_20260907/demo/vendor';
registerHooks({resolve(specifier,context,next){return next(specifier==='three'?pathToFileURL(vendor+'/build/three.module.js').href:specifier,context);}});
const THREE=await import(pathToFileURL(vendor+'/build/three.module.js'));
const {GLTFLoader}=await import(pathToFileURL(vendor+'/addons/loaders/GLTFLoader.js'));
const load=async url=>{const bytes=fs.readFileSync(url);return(await new GLTFLoader().parseAsync(bytes.buffer.slice(bytes.byteOffset,bytes.byteOffset+bytes.byteLength),'')).scene;};
class Box extends THREE.BoxGeometry{constructor(w,h,d){super(w,h,d);}}
const carSource=await load(new URL('./models/artist_vehicle_pack/compact_sedan.glb',import.meta.url));
let cases=0,allowed=0,blocked=0,maxLowerBodyShift=0,contactCases=0;const blockedReasons={};
const firearms=ARSENAL.filter(w=>['tt_pistol','uzi'].includes(w.id));assert.equal(firearms.length,2);
for(const sex of ['male','female']){
 const scene=new THREE.Scene(),car=createArtistVehicle(THREE,Box,carSource,'compact_sedan');scene.add(car.object);
 const binding=createNpcTrafficVehicleBinding({THREE,actor:car}),source=await load(new URL(NPC_ASSETS[sex].url));
 const npc=createNpcActor({THREE,scene,source,cloneSkeleton:clone,id:'audit-passenger-'+sex,sex,getVehicle:()=>binding});
 for(const seatId of ['front_right','rear_left','rear_right'])for(const yaw of [0,1.1])for(const weaponInfo of firearms){
  car.object.position.set(18,.2,14);car.object.rotation.y=yaw;car.object.updateMatrixWorld(true);
  const weapon=createWeaponModel(THREE,weaponInfo.id);npc.mountWeapon(weapon);
  npc.update(.05,{time:1+cases*.05,position:{x:18,y:.2,z:14},yaw,moving:false,motionSpeed:0,life:{civilianTripRiding:true,civilianTripCarId:'car',civilianTripPhase:'drive',civilianTripProgress:1,vehicleSeatId:seatId}});
  const context=npc.walker.artistContext(),root=npc.object.position.clone(),legs=['thigh_l','thigh_r','shin_l','shin_r','foot_l','foot_r'].map(name=>context.worldPosition(name));
  const seat=car.seats.find(s=>s.id===seatId),frame=vehicleWindowFrame(THREE,car,seatId),direction=new THREE.Vector3(seat.side,0,0).applyQuaternion(car.object.quaternion);
  const plan=planVehicleWindowShot({vehicleState:{yaw},seatId,aimDirection:direction,weaponId:weaponInfo.id,frame});assert(plan.allowed);
  assert.equal(planVehicleWindowShot({vehicleState:{yaw},seatId,aimDirection:direction.clone().negate(),weaponId:weaponInfo.id,frame}).allowed,false);
  setVehicleWindowOpen(car,seatId,true);
  const result=applyVehicleWindowPose(THREE,context,{plan,car,weapon:npc.weapon});
  assert(result.applied);assert(npc.object.position.distanceTo(root)<1e-9);
  for(const [i,name]of ['thigh_l','thigh_r','shin_l','shin_r','foot_l','foot_r'].entries()){
   const shift=context.worldPosition(name).distanceTo(legs[i]);maxLowerBodyShift=Math.max(maxLowerBodyShift,shift);assert(shift<1e-7,'actual NPC lower body remains seated');
  }
  if(result.canFire){assert(result.outside&&result.selfClear&&result.ownCarClear&&result.reachable);assert(result.direction.dot(direction)>.999999);allowed++;
   const selfContact=createNpcContactRay({THREE,getActors:()=>[npc],obstacles:()=>[car.object]});
   assert.equal(selfContact({origin:result.muzzle,direction:result.direction,range:1,targetOnly:true}),null,'outward muzzle ray misses actual own posed skin');
   if(contactCases===0){
    const standAt=(id,distance)=>{
     const actor=createNpcActor({THREE,scene,source,cloneSkeleton:clone,id,sex}),position=result.muzzle.clone().addScaledVector(result.direction,distance);
     actor.update(0,{time:2,position:{x:position.x,y:0,z:position.z},yaw:0,life:{}});
     const chestHeight=actor.walker.artistContext().worldPosition('chest').y;
     actor.update(0,{time:2,position:{x:position.x,y:position.y-chestHeight,z:position.z},yaw:0,life:{}});return actor;
    };
    const enemy=standAt('candidate-enemy',5),friend=standAt('candidate-friend',2.5),actors=[enemy],obstacles=[car.object];
    const query=createNpcContactRay({THREE,getActors:()=>actors,obstacles:()=>obstacles}),input={origin:result.muzzle,direction:result.direction,range:7,targetOnly:true};
    assert.equal(query(input)?.npcId,enemy.id,'actual skin ray identifies the intended target');contactCases++;
    actors.unshift(friend);assert.equal(query(input)?.npcId,friend.id,'friendly body is the first contact, not filtered out');contactCases++;
    actors.shift();const wall=new THREE.Mesh(new THREE.BoxGeometry(4,4,.2),new THREE.MeshBasicMaterial());
    wall.position.copy(result.muzzle).addScaledVector(result.direction,2);wall.quaternion.setFromUnitVectors(new THREE.Vector3(0,0,1),result.direction);scene.add(wall);obstacles.push(wall);
    assert.equal(query(input),null,'opaque obstacle rejects a target behind it');contactCases++;
    enemy.dispose();friend.dispose();wall.removeFromParent();wall.geometry.dispose();wall.material.dispose();
   }
  }
  else{assert(result.reason);blocked++;blockedReasons[result.reason]=(blockedReasons[result.reason]||0)+1;}
  setVehicleWindowOpen(car,seatId,false);cases++;
 }
 npc.dispose();
}
assert(allowed>0,'actual seated NPC has at least one validated own-window firearm pose');
report.geometry={candidateOnly:true,firearms:firearms.map(w=>w.id),cases,allowed,blocked,maxLowerBodyShift,blockedReasons,contactCases,limits:'No production gameplay dispatch, ammo authority, moving-vehicle LIVE, or full-scene FPS acceptance. The candidate composes existing own hull/head/reach checks with actual posed-skin/world contact; production does not yet call this composition.'};
console.log(JSON.stringify(report,null,2));
