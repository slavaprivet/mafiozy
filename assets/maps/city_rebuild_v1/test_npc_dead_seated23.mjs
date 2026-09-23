import test from 'node:test';
import assert from 'node:assert/strict';
import fs from 'node:fs';
import path from 'node:path';
import vm from 'node:vm';
import {registerHooks} from 'node:module';
import {pathToFileURL,fileURLToPath} from 'node:url';

const dir=fileURLToPath(new URL('.',import.meta.url)),root=fileURLToPath(new URL('../../../',import.meta.url)),url=n=>pathToFileURL(path.join(dir,n)),read=n=>fs.readFileSync(path.join(dir,n),'utf8');
const vendor=process.env.MAFIOZI_THREE_VENDOR??'D:/codex_release/artist13_hero_first_DEV_20260907/demo/vendor';
registerHooks({resolve(specifier,context,next){return next(specifier==='three'?pathToFileURL(vendor+'/build/three.module.js').href:specifier,context);}});

const THREE=await import(pathToFileURL(vendor+'/build/three.module.js')),{GLTFLoader}=await import(pathToFileURL(vendor+'/addons/loaders/GLTFLoader.js')),{RoundedBoxGeometry}=await import(pathToFileURL(path.join(root,'tools/vehicle_fleet_qa/RoundedBoxGeometry.mjs'))),{clone}=await import(url('test_npc_death_offline_setup.mjs'));
const {createNpcActor,NPC_ASSETS}=await import(url('npc_actor.mjs')),coreModule=await import(url('mercenary_core.mjs')),{createDemoCar,CAR}=await import(url('car_drive.mjs')),{VEHICLE_SEATS}=await import(url('vehicle_seats.mjs')),{createNpcTrafficVehicleBinding}=await import(url('npc_vehicle_pose.mjs')),{createMercenaryVehicleBridge}=await import(url('mercenary_vehicle_bridge.mjs'));
const load=async location=>{const bytes=fs.readFileSync(new URL(location));return(await new GLTFLoader().parseAsync(bytes.buffer.slice(bytes.byteOffset,bytes.byteOffset+bytes.byteLength),'')).scene;};
const assetLoadStarted=performance.now(),sources=Object.fromEntries(await Promise.all(['male','female'].map(async sex=>[sex,await load(NPC_ASSETS[sex].url)]))),assetLoadMs=performance.now()-assetLoadStarted;
const report=[];
const worldSource=read('mercenary_world.js'),worldScript=worldSource.replace("import(new URL('./mercenary_core.mjs',scriptUrl).href)",'Promise.resolve(module)');assert.notEqual(worldScript,worldSource);
const fixtureSource=read('test_mercenary_rally_actions.mjs'),fixture=Function('vm','module','script','assert',fixtureSource.slice(fixtureSource.indexOf('async function fixture('),fixtureSource.indexOf('\nfor(const [profession'))+';return fixture;')(vm,coreModule,worldScript,assert);
const watched=['pelvis','head','chest','hand_l','hand_r','foot_l','foot_r'],round=n=>Number(n.toFixed(6));

async function setup(sex){
 const f=await fixture(),m=f.recruit('safecracker'),scene=new THREE.Scene(),car=createDemoCar(THREE,RoundedBoxGeometry);car.profile={...CAR,id:'red_sedan',label:'Kingswell',height:2.22,massKg:1500};car.seats=VEHICLE_SEATS;scene.add(car.object);car.object.position.set(41,0,41);car.object.updateMatrixWorld(true);
 let player={id:'fleet:audit',seatId:'front_left',ready:true};const fleet={records:[{id:'audit',car,state:{speed:0}}]},bridge=createMercenaryVehicleBridge({getFleet:()=>fleet,getPlayer:()=>player,canCross:()=>true});f.api.bindTargets({squadTransport:bridge,canMove:()=>true,groundHeight:()=>0});
 const binding=createNpcTrafficVehicleBinding({THREE,actor:car});Object.assign(m,{_mercenaryVehicleId:'fleet:audit',_mercenaryVehicleSeat:'front_right',_mercenaryVehiclePhase:'drive',_mercenaryVehicleProgress:1});f.tick(.05);
 const npc=createNpcActor({THREE,scene,source:sources[sex],cloneSkeleton:clone,id:'npc_crew_'+m.id,sex,getVehicle:()=>binding});
 const render=dt=>{const life=f.api.decorateEntities([{id:npc.id,hp:m.hp,dead:!!m.dead,deathConfirmed:!!m.deathConfirmed,deadAt:m.deadAt}])[0];npc.update(dt,{time:f.ctx.performance.now()/1000,position:{x:m.c*4.1,y:0,z:m.r*4.1},yaw:Math.PI/2-m.ang,life});return life;};
 return{...f,m,scene,car,bridge,binding,npc,render};
}
const localPose=(npc,car)=>{const context=npc.walker.artistContext(),inverse=car.object.matrixWorld.clone().invert();return {pivot:new THREE.Matrix4().multiplyMatrices(inverse,context.visualPivot.matrixWorld),bones:Object.fromEntries(watched.map(k=>[k,context.worldPosition(k).clone().applyMatrix4(inverse)]))};};
const matrixDelta=(a,b)=>Math.max(...a.elements.map((x,i)=>Math.abs(x-b.elements[i])));
function compareToCurrentLiveSeat(f,sex,label){
 const ref=createNpcActor({THREE,scene:f.scene,source:sources[sex],cloneSkeleton:clone,id:'live_reference_'+sex,sex,getVehicle:()=>f.binding});
 const life=f.api.decorateEntities([{id:f.npc.id,hp:f.m.hp,dead:true,deathConfirmed:true,deadAt:f.m.deadAt}])[0];
 const source={time:f.ctx.performance.now()/1000,position:{x:f.m.c*4.1,y:0,z:f.m.r*4.1},yaw:Math.PI/2-f.m.ang,life:{...life,hp:100,dead:false,deathConfirmed:false,deadAt:undefined,downed:false,lifeState:'alive',medicalDowned:false}};
 ref.update(0,source);const delta=matrixDelta(localPose(f.npc,f.car).pivot,localPose(ref,f.car).pivot);assert(delta<5e-5,label+' physical seat pivot '+delta);ref.dispose();return delta;
}
test('independent actual full-host coldstream and vertical/tilted-car regression',async()=>{
 for(const sex of ['male','female'])for(const warm of [false,true]){
  const f=await setup(sex);f.tick(2);if(warm){f.render(.05);f.tick(.05);f.render(.05);}
  Object.assign(f.m,{hp:0,dead:true,deathConfirmed:true,deadAt:f.ctx.performance.now()-1200});f.render(0);
  const before=localPose(f.npc,f.car),saved=f.npc.saveSurfaceState();assert.equal(saved.deathEntry20?.vehicleBound,true);assert.equal(saved.deathEntry20?.version,2);const coldDelta=compareToCurrentLiveSeat(f,sex,'initial');
  f.car.object.position.add(new THREE.Vector3(4,2.35,-6));f.car.object.rotation.set(0,-.63,0);f.car.object.updateMatrixWorld(true);f.tick(.05);const sourceLife=f.render(.05),sourceBefore=JSON.stringify(sourceLife);f.npc.update(0,{time:f.ctx.performance.now()/1000,position:{x:f.m.c*4.1,y:0,z:f.m.r*4.1},yaw:Math.PI/2-f.m.ang,life:sourceLife});assert.equal(JSON.stringify(sourceLife),sourceBefore);const vertical=localPose(f.npc,f.car),verticalDelta=matrixDelta(before.pivot,vertical.pivot);assert(verticalDelta<5e-5,'pure XYZ/yaw remains car relative '+verticalDelta);f.car.object.rotation.set(.17,-.63,.12);f.car.object.updateMatrixWorld(true);f.tick(.05);f.render(.05);const transformed=localPose(f.npc,f.car),tiltDelta=compareToCurrentLiveSeat(f,sex,'XYZ/pitch/roll'),localPivotRotationDelta=matrixDelta(vertical.pivot,transformed.pivot);
  const localBoneDrift=Math.max(...watched.map(k=>before.bones[k].distanceTo(transformed.bones[k])));assert(localBoneDrift<.45,sex+' body escaped existing cabin envelope '+localBoneDrift);
  report.push({case:'fullhost_'+sex+'_'+(warm?'warm':'cold'),initialPhysicalPivotDelta:coldDelta,pureXYZYawPivotDelta:verticalDelta,tiltedPhysicalPivotDelta:tiltDelta,carLocalPivotDeltaUnderTilt:localPivotRotationDelta,localBoneDriftM:localBoneDrift,completePitchRoll:localPivotRotationDelta<5e-5,sourceUnchanged:true});f.npc.dispose();
 }
});
test('independent actual full-host save while released and streamed with elapsed time',async()=>{
 for(const sex of ['male','female']){
  const f=await setup(sex);Object.assign(f.m,{hp:0,dead:true,deathConfirmed:true,deadAt:f.ctx.performance.now()-1200});f.render(0);const seated=f.npc.saveSurfaceState();assert.equal(seated.deathEntry20.vehicleBound,true);
  const make=()=>createNpcActor({THREE,scene:f.scene,source:sources[sex],cloneSkeleton:clone,id:f.npc.id,sex,getVehicle:()=>f.binding});
  const currentSnapshot=()=>({time:f.ctx.performance.now()/1000,position:{x:f.m.c*4.1,y:0,z:f.m.r*4.1},yaw:Math.PI/2-f.m.ang,life:f.api.decorateEntities([{id:f.npc.id,hp:f.m.hp,dead:true,deathConfirmed:true,deadAt:f.m.deadAt}])[0]});
  const boundRestore=make();boundRestore.restoreSurfaceState(seated,{time:f.ctx.performance.now()/1000});boundRestore.update(0,currentSnapshot());assert.equal(boundRestore.saveSurfaceState().deathEntry20.vehicleBound,true);boundRestore.dispose();
  const before=localPose(f.npc,f.car);for(const key of ['_mercenaryVehicleId','_mercenaryVehicleSeat','_mercenaryVehiclePhase','_mercenaryVehicleProgress'])delete f.m[key];f.tick(.01);f.render(.01);const release0=localPose(f.npc,f.car),releaseJump=Math.max(...watched.map(k=>before.bones[k].distanceTo(release0.bones[k])));assert(releaseJump<.001,'zero-age release continuous');
  f.tick(.12);f.render(.12);const partial=f.npc.saveSurfaceState();assert.equal(partial.deathEntry20.vehicleBound,false);assert(Number.isFinite(partial.deathEntry20.vehicleReleaseAt));
  const restored=make();f.tick(.10);restored.restoreSurfaceState(partial,{time:f.ctx.performance.now()/1000,elapsedSeconds:.10});restored.update(0,currentSnapshot());assert(restored.saveSurfaceState().deathEntry20,'partial release remains within .32s');
  f.tick(.12);restored.update(.12,currentSnapshot());assert.equal(restored.saveSurfaceState().deathEntry20,null,'saved release completes after elapsed .34s');
  const occupied=f.bridge.reservedSeats('fleet:audit');assert(!occupied.includes('front_right'),'authoritatively released body no longer reserves seat');
  const longGap=make();longGap.restoreSurfaceState(partial,{time:f.ctx.performance.now()/1000+5,elapsedSeconds:5.22});longGap.update(0,{...currentSnapshot(),time:f.ctx.performance.now()/1000+5});assert.equal(longGap.saveSurfaceState().deathEntry20,null,'long offscreen gap completes release');
  const bad=structuredClone(seated);bad.deathEntry20.pivotQ=[NaN,0,0,1];const checkpoint=JSON.stringify(restored.saveSurfaceState());assert.throws(()=>restored.restoreSurfaceState(bad,{time:f.ctx.performance.now()/1000}),/Invalid death entry pose/);assert.equal(JSON.stringify(restored.saveSurfaceState()),checkpoint,'invalid restored pose is atomic');
  report.push({case:'fullhost_release_save_'+sex,releaseStartJumpM:releaseJump,partialStreamRestore:true,elapsedReleaseComplete:true,longOffscreenComplete:true,seatReleased:true,invalidRestoreAtomic:true});restored.dispose();longGap.dispose();f.npc.dispose();
 }
});
test('summarize bounded full-host checks',()=>{assert.equal(report.length,6);const output={pass:true,acceptance:'Cold + XYZ/yaw + save/release; complete seat tilt is covered by test_npc_vehicle_tilt23.mjs',production:'dead-seated23-v2',scope:'Actual complete mercenary_world/core/bridge + Kingswell + both GLBs. Actual production actor/death-entry imports. No source overlays. No GPU.',cases:report};console.log(JSON.stringify(output,null,2));});
