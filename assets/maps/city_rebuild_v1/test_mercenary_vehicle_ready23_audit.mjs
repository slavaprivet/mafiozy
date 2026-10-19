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


const rows=[];
for(const sex of ['male','female'])for(const seatId of ['front_right','rear_left','rear_right'])for(const weaponId of ['tt_pistol','uzi','ak74']){
 const f=await scenario({model:'kingswell',sex,seatId,weaponId,attacked:false}),weapon=f.npc.weapon,frame=vehicleWindowFrame(THREE,f.car,seatId),muzzle=weapon.localToWorld(new THREE.Vector3(...weapon.userData.muzzle)),local=f.car.object.worldToLocal(muzzle.clone()),head=f.car.object.worldToLocal(f.npc.walker.artistContext().worldPosition('head')),hand=f.car.object.worldToLocal(f.npc.walker.artistContext().worldPosition('hand_'+(weaponId==='tt_pistol'&&frame.side>0?'l':'r'))),direction=new THREE.Vector3(0,0,1).applyQuaternion(weapon.getWorldQuaternion(new THREE.Quaternion())),plane=Math.max(Math.abs(frame.min[0]),Math.abs(frame.max[0]));
 rows.push({sex,seatId,weaponId,muzzleOutsideCm:+((local.x*frame.side-plane)*100).toFixed(1),headOutsideCm:+((head.x*frame.side-plane)*100).toFixed(1),handOutsideCm:+((hand.x*frame.side-plane)*100).toFixed(1),muzzleY:+local.y.toFixed(3),windowY:[frame.min[1],frame.max[1]],outwardDot:+(direction.x*frame.side).toFixed(5),actualGunVisible:weapon.visible,sourceIntent:!!f.intent()});
 check(local.x*frame.side>plane+.012,'ready muzzle is really outside its own window');check(direction.x*frame.side>.99,'ready gun points outward');check(!f.intent(),'ready gun creates no target');f.cleanup();
}
console.log(JSON.stringify({status:'PASS',checks,rows},null,2));
