import {vehicleWindowFrame} from './vehicle_window_fire.mjs';
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


function envelope(f){
 const c=f.npc.walker.artistContext(),frame=vehicleWindowFrame(THREE,f.car,f.m._mercenaryVehicleSeat),side=frame.side,plane=Math.max(Math.abs(frame.min[0]),Math.abs(frame.max[0])),local=name=>f.car.object.worldToLocal(c.worldPosition(name)),head=local('head'),shoulder=local(side>0?'upperarm_r':'upperarm_l'),crossing=[];
 c.object.traverse(mesh=>{if(!mesh.isSkinnedMesh)return;mesh.skeleton.update();const attr=mesh.geometry.attributes.position,index=mesh.geometry.index,verts=[];for(let i=0;i<attr.count;i++){const v=new THREE.Vector3().fromBufferAttribute(attr,i);mesh.applyBoneTransform(i,v);mesh.localToWorld(v);f.car.object.worldToLocal(v);verts.push(v);}for(let j=0;j<(index?.count||attr.count);j+=3){const ids=[0,1,2].map(k=>index?index.getX(j+k):j+k);for(let k=0;k<3;k++){const a=verts[ids[k]],b=verts[ids[(k+1)%3]],ax=a.x*side-plane,bx=b.x*side-plane;if(ax*bx<0)crossing.push(a.clone().lerp(b,ax/(ax-bx)));}}});
 const bad=crossing.filter(v=>v.y<frame.min[1]-.002||v.y>frame.max[1]+.002||v.z<frame.min[2]-.002||v.z>frame.max[2]+.002);
 return {headOutside:head.x*side-plane,shoulderOutside:shoulder.x*side-plane,bad:bad.length,badMinY:bad.length?Math.min(...bad.map(v=>v.y)):null,badMaxY:bad.length?Math.max(...bad.map(v=>v.y)):null,badMinZ:bad.length?Math.min(...bad.map(v=>v.z)):null,badMaxZ:bad.length?Math.max(...bad.map(v=>v.z)):null,windowZ:[frame.min[2],frame.max[2]],sill:frame.min[1]};
}
function weaponPosture(f,tag){
 const c=f.npc.walker.artistContext(),weapon=f.npc.weapon,frame=vehicleWindowFrame(THREE,f.car,f.m._mercenaryVehicleSeat),long=!!(weapon.twoHanded??weapon.userData.twoHanded),shooting=long?'r':frame.side>0?'l':'r';
 const trigger=weapon.localToWorld(new THREE.Vector3(0,-.13,-.02)),support=weapon.localToWorld(new THREE.Vector3(...(weapon.userData.supportGrip||[0,.1,.62]))),muzzle=weapon.localToWorld(new THREE.Vector3(...weapon.userData.muzzle));
 const triggerError=c.worldPosition('socket_hand_'+shooting).distanceTo(trigger),supportError=long?c.worldPosition('socket_hand_l').distanceTo(support):0;
 check(triggerError<1e-6,'trigger palm remains on the actual held gun '+tag);if(long)check(supportError<1e-6,'support palm remains on the actual foregrip '+tag);
 // A rifle stock can sit alongside the shoulder. The held working segment
 // between both grips must nevertheless be in front of the turned chest.
 const forward=new THREE.Vector3(0,0,1).applyQuaternion(c.bones.chest.getWorldQuaternion(new THREE.Quaternion())).setY(0).normalize(),center=trigger.clone().lerp(long?support:muzzle,.5),front=center.clone().sub(c.worldPosition('chest')).dot(forward),belowHead=c.worldPosition('head').y-weapon.getWorldPosition(new THREE.Vector3()).y;
 check(front>.03,'held weapon is in front of the chest, not slung behind the shoulder '+tag);if(long)check(belowHead>0,'long-gun receiver is below the head '+tag);
 const plane=Math.max(Math.abs(frame.min[0]),Math.abs(frame.max[0])),outside=p=>f.car.object.worldToLocal(p.clone()).x*frame.side-plane,receiverOutside=outside(weapon.getWorldPosition(new THREE.Vector3())),triggerOutside=outside(trigger),barrelOutside=outside(muzzle),supportOutside=long?outside(support):null;
 check(receiverOutside>.025,'receiver must be visible outside the window, not only the muzzle '+tag);check(triggerOutside>.012,'shooting grip must actually leave the cabin '+tag);check(barrelOutside>.16,'a visible barrel segment projects beyond the own window '+tag);if(long)check(supportOutside>.025,'supporting grip must be outside the own window '+tag);
 let total=0,out=0,frameHits=0;weapon.traverseVisible(mesh=>{if(!mesh.isMesh||!mesh.geometry?.attributes.position)return;const attr=mesh.geometry.attributes.position,index=mesh.geometry.index,vertices=[];for(let i=0;i<attr.count;i++){const p=mesh.localToWorld(new THREE.Vector3().fromBufferAttribute(attr,i));total++;if(outside(p)>.012)out++;vertices.push(f.car.object.worldToLocal(p));}for(let i=0;i<(index?.count||attr.count);i+=3){const ids=[0,1,2].map(k=>index?index.getX(i+k):i+k);for(let k=0;k<3;k++){const a=vertices[ids[k]],b=vertices[ids[(k+1)%3]],ax=a.x*frame.side-plane,bx=b.x*frame.side-plane;if(ax*bx<0){const p=a.clone().lerp(b,ax/(ax-bx));if(p.y<frame.min[1]-.002||p.y>frame.max[1]+.002||p.z<frame.min[2]-.002||p.z>frame.max[2]+.002)frameHits++;}}}});const visibleFraction=out/total;check(visibleFraction>.55,'most real weapon geometry is outside the cabin '+tag);check(frameHits===0,'actual gun triangles cross through the opening, not the door or window frame '+tag);
 return {front,triggerError,supportError,receiverOutside,triggerOutside,barrelOutside,visibleFraction};
}
const rows=[],failures=[];let cases=0;
for(const model of ['compact','kingswell'])for(const sex of ['male','female'])for(const seatId of ['front_right','rear_left','rear_right'])for(const weaponId of process.env.LEAN_QUICK?['tt_pistol','uzi','tommy_gun','ak74','m16']:['nagan','tt_pistol','revolver','deagle','golden_colt','uzi','golden_uzi','tommy_gun','sawn_off','shotgun','ak74','m16','sniper']){
 const f=await scenario({model,sex,seatId,weaponId,defense:false,attacked:false}),c=f.npc.walker.artistContext(),names=['pelvis','thigh_l','thigh_r','shin_l','shin_r','foot_l','foot_r'],lower=names.map(name=>c.worldPosition(name)),root=f.npc.object.position.clone(),tag=[model,sex,seatId,weaponId].join('/');
 f.api.toggleVehicleDefenseFire();
 for(let step=1;step<=4;step++){f.render(.045);const e=envelope(f);if(e.bad)failures.push({tag,phase:'enter'+step,...e});}
 const ready=envelope(f),posture=weaponPosture(f,tag+'/ready');if(ready.headOutside<.10||ready.shoulderOutside<.02)failures.push({tag,phase:'ready',...ready});check(!f.intent(),'ready pose has no damage target');
 f.api.noteVehicleAttack({kind:'street_npc',ref:f.enemy,victimKind:'player'});f.render(.1);f.render(.1);const proof=f.renderer.prepareShot(f.intent()),firing=envelope(f);
 if(!proof.ready||firing.bad)failures.push({tag,phase:'firing',proof,...firing});weaponPosture(f,tag+'/firing');
 for(const [i,name]of names.entries())check(c.worldPosition(name).distanceTo(lower[i])<1e-7,'waist lean retains pelvis and all seated legs '+tag);check(f.npc.object.position.distanceTo(root)<1e-8,'waist lean never moves authority root');
 if(proof.ready){const muzzle=f.npc.weapon.localToWorld(new THREE.Vector3(...f.npc.weapon.userData.muzzle));check(muzzle.distanceTo(new THREE.Vector3(proof.origin.x,proof.origin.y,proof.origin.z))<1e-7,'free-hand brace preserves actual admitted muzzle');}
 f.api.toggleVehicleDefenseFire();for(let step=1;step<=4;step++){f.render(.055);const e=envelope(f);if(e.bad)failures.push({tag,phase:'return'+step,...e});}
 check(!f.intent(),'return cancels damage authority');cases++;rows.push({tag,headOutside:ready.headOutside,shoulderOutside:ready.shoulderOutside,...posture});f.cleanup();
}
console.log(JSON.stringify({status:failures.length?'FAIL':'PASS',checks,cases,minHeadOutside:Math.min(...rows.map(r=>r.headOutside)),minShoulderOutside:Math.min(...rows.map(r=>r.shoulderOutside)),minHeldWeaponFront:Math.min(...rows.map(r=>r.front)),minReceiverOutside:Math.min(...rows.map(r=>r.receiverOutside)),minTriggerOutside:Math.min(...rows.map(r=>r.triggerOutside)),minBarrelOutside:Math.min(...rows.map(r=>r.barrelOutside)),minVisibleWeaponFraction:Math.min(...rows.map(r=>r.visibleFraction)),maxTriggerError:Math.max(...rows.map(r=>r.triggerError)),maxSupportError:Math.max(...rows.map(r=>r.supportError)),failures:failures.slice(0,20),failureCount:failures.length,phases:Object.fromEntries([...new Set(failures.map(f=>f.phase))].map(p=>[p,failures.filter(f=>f.phase===p).length]))}));
assert.equal(failures.length,0,'actual passenger skin must cross through its window throughout lean and retract');
