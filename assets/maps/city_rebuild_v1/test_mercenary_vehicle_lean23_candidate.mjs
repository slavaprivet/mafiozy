import {planVehicleWindowShot,applyVehicleWindowPose,setVehicleWindowOpen} from './vehicle_window_fire.mjs';
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




function lean(c,car,frame,blend){
 const side=frame.side;c.rotateAdd('spine_01',0,0,-side*.6*blend);c.object.updateMatrixWorld(true);
 const local=name=>car.object.worldToLocal(c.worldPosition(name)),head=local('head'),shoulder=local(side>0?'upperarm_r':'upperarm_l'),top=local('socket_head'),plane=Math.max(Math.abs(frame.min[0]),Math.abs(frame.max[0]));
 const dx=side*Math.min(.3,Math.max(0,plane+.14-head.x*side))*blend,dy=Math.max(0,Math.min(.5,frame.min[1]+.25-shoulder.y,frame.max[1]-.03-top.y))*blend,
 dz=Math.max(frame.min[2]+.20-Math.min(head.z,shoulder.z),Math.min(0,frame.max[2]-.20-Math.max(head.z,shoulder.z)))*blend;
 const bone=c.bones.spine_01,p=new THREE.Vector3(),q=new THREE.Quaternion(),scale=new THREE.Vector3();bone.matrix.decompose(p,q,scale);const destination=local('spine_01').add(new THREE.Vector3(dx,dy,dz));car.object.localToWorld(destination);bone.parent.worldToLocal(destination);bone.matrix.compose(destination,q,scale);bone.matrixWorldNeedsUpdate=true;c.object.updateMatrixWorld(true);
}
const rows=[];
for(const model of ['compact','kingswell'])for(const sex of ['male','female'])for(const seatId of ['front_right','rear_left','rear_right'])for(const weaponId of ['nagan','tt_pistol','revolver','deagle','golden_colt','uzi','golden_uzi','tommy_gun','sawn_off','shotgun','ak74','m16','sniper']){
 const f=await scenario({model,sex,seatId,weaponId,defense:false,attacked:false}),c=f.npc.walker.artistContext(),frame=vehicleWindowFrame(THREE,f.car,seatId),side=frame.side;
 setVehicleWindowOpen(f.car,seatId,true);const proxy={...c,rotateAdd(name,...args){c.rotateAdd(name,...args);if(name==='head')lean(c,f.car,frame,1);}};
 const plan=planVehicleWindowShot({vehicleState:{yaw:0},seatId,aimDirection:{x:side,y:0,z:0},weaponId,frame});if(f.npc.weapon.userData.twoHanded)plan.localMuzzle.z=Math.min(frame.max[2]-.18,plan.localMuzzle.z+.3);const result=applyVehicleWindowPose(THREE,proxy,{plan,car:f.car,weapon:f.npc.weapon,blend:1}),local=name=>f.car.object.worldToLocal(c.worldPosition(name)),head=local('head'),shoulder=local(side>0?'upperarm_r':'upperarm_l'),plane=Math.max(Math.abs(frame.min[0]),Math.abs(frame.max[0]));
 if(!f.npc.weapon.userData.twoHanded){const hand=side>0?'r':'l',target=f.car.object.localToWorld(new THREE.Vector3(side*(plane-.10),frame.min[1]+.48,Math.max(frame.min[2]+.15,Math.min(frame.max[2]-.15,head.z+.15))));c.reachPalm(hand,target,c.bones['hand_'+hand].getWorldQuaternion(new THREE.Quaternion()));c.object.updateMatrixWorld(true);}
 const crossing=[],badBones={};c.object.traverse(mesh=>{if(!mesh.isSkinnedMesh)return;mesh.skeleton.update();const pos=mesh.geometry.attributes.position,index=mesh.geometry.index,verts=[];for(let i=0;i<pos.count;i++){const v=new THREE.Vector3().fromBufferAttribute(pos,i);mesh.applyBoneTransform(i,v);mesh.localToWorld(v);f.car.object.worldToLocal(v);verts.push(v);}for(let j=0;j<(index?.count||pos.count);j+=3){const ids=[0,1,2].map(k=>index?index.getX(j+k):j+k);for(let k=0;k<3;k++){const a=verts[ids[k]],b=verts[ids[(k+1)%3]],ax=a.x*side-plane,bx=b.x*side-plane;if(ax*bx<0){const p=a.clone().lerp(b,ax/(ax-bx));crossing.push(p);if(p.y<frame.min[1])for(const id of ids){const weights=mesh.geometry.attributes.skinWeight,indices=mesh.geometry.attributes.skinIndex;for(let k=0;k<4;k++)if(weights.getComponent(id,k)>.35){const name=mesh.skeleton.bones[indices.getComponent(id,k)].name;badBones[name]=(badBones[name]||0)+1;}}}}}});
 const bounds=crossing.length?{minY:Math.min(...crossing.map(v=>v.y)),maxY:Math.max(...crossing.map(v=>v.y)),minZ:Math.min(...crossing.map(v=>v.z)),maxZ:Math.max(...crossing.map(v=>v.z)),outside:crossing.filter(v=>v.y<frame.min[1]||v.y>frame.max[1]||v.z<frame.min[2]||v.z>frame.max[2]).length}:{};
 rows.push({model,sex,seatId,weaponId,bounds,badBones,frameMin:frame.min,frameMax:frame.max,headOutside:+(head.x*side-plane).toFixed(3),headY:+head.y.toFixed(3),shoulderOutside:+(shoulder.x*side-plane).toFixed(3),shoulderOverSill:+(shoulder.y-frame.min[1]).toFixed(3),result:{canFire:result.canFire,reason:result.reason,clear:result.ownCarClear,self:result.selfClear,reachable:result.reachable,obstruction:result.obstruction}});f.cleanup();
}
console.log(JSON.stringify({total:rows.length,failed:rows.filter(r=>!r.result.canFire||r.bounds.outside),headMin:Math.min(...rows.map(r=>r.headOutside)),shoulderMin:Math.min(...rows.map(r=>r.shoulderOutside))},null,2));
