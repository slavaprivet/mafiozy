import fs from 'node:fs';
import vm from 'node:vm';
import assert from 'node:assert/strict';
import {stepExitBody} from './car_exit.mjs';
import {createVehicleExitSurface,createExitPoseFloorSampler,createExitSwimHandoff} from './vehicle_exit_surface.mjs';
const source=fs.readFileSync(new URL('./walk_preview.mjs',import.meta.url),'utf8');
const binding=source.slice(source.indexOf('function updateMovingExit(dt)'),source.indexOf('function updateCarInteraction(dt)'));
for(const water of [false,true]){
 const groundHeight=x=>x>1?-7:0,waterAt=x=>water&&x>1?{level:0,depth:7,floor:-7}:null;
 const position={x:0,y:0,z:0},samples=[];let complete=false;
 const context={transition:{exiting:true,phase:'body',kind:'tumble',doorId:'front_left',body:{...position,vx:10,vz:0,elapsed:0,kind:'tumble',heading:Math.PI/2,rolls:2,done:false},surface:createVehicleExitSurface({position,groundHeight,waterAt})},stepExitBody,createExitPoseFloorSampler,pedestrianAllowed:()=>true,exitQaMode:false,car:{setDoorById(){}},finishExit(){complete=true;},hero:{object:{position:{...position,set(x,y,z){Object.assign(this,{x,y,z});}},rotation:{}},tumblePose(progress,rolls,{floorHeight}){const p=this.object.position;samples.push({...p,progress,floor:floorHeight(p.x,p.z)});},update(){}}};
 vm.createContext(context);vm.runInContext(binding,context);
 for(let i=0;i<250&&!complete;i++)vm.runInContext('updateMovingExit(.02)',context);
 assert(complete,'actual host exit must complete after landing');
 assert(samples.some(p=>p.x>1),'actual exit inertia crosses shore/cliff');
 for(let i=1;i<samples.length;i++)assert(samples[i].y>=samples[i-1].y-.45,'no instant ground-height teleport in host');
 if(water)assert(Math.min(...samples.map(p=>p.y))>=-.051,'actual host holds above deep riverbed throughout recovery');
 else assert(Math.min(...samples.map(p=>p.y))<-6.9,'cliff falls to lower support instead of floating');
}
console.log('PASS actual updateMovingExit integration: continuous cliff fall, deep-water support, skin sampler, recovery completion');
{
 const finish=source.slice(source.indexOf('function finishExit()'),source.indexOf('function abortExit()'));
 const swim=source.slice(source.indexOf('function heroSwimHeight('),source.indexOf('function artistUpdate('));
 const c={createExitSwimHandoff,exitSwimHandoff:null,artistSurfaceFrameDt:1/60,transition:{},occupiedSeat:null,car:{setDoorById(){}},hero:{height:1.9,object:{position:{x:4,y:-.05,z:0},rotation:{}},reset(){}},heroGroundHeight:()=>-7,groundHeight:()=>-7,waterAt:()=>({level:0,depth:7}),artistSurfaceState:{swim:{liftWorld:0}},surfaceMotion:{reset(){}},setWalking(){},ensureVehicleExitVisible(){},THREE:{},camera:{},controls:{},postureEyeHeight:()=>1.64,keys:new Set(),$:()=>({}),exitQaMode:false};
 vm.createContext(c);vm.runInContext(finish+'\n'+swim,c);vm.runInContext('finishExit()',c);
 assert(c.hero.object.position.y>=-.051,'actual finishExit must not drop to a cold swimming bed');
 let previous=c.hero.object.position.y;
 for(let i=0;i<100;i++){
  c.sample={liftWorld:6.1*Math.min(1,i/24)};
  const y=vm.runInContext('heroSwimHeight(4,0,sample)',c);
  assert(y>=-1.051,'cold swim transition remains visible');assert(Math.abs(y-previous)<=.168);previous=y;
 }
 assert(Math.abs(previous+.9)<1e-8);assert.equal(c.exitSwimHandoff,null);
 console.log('PASS actual finishExit/swim hooks: deep-water cold start remains above waterbed and hands over continuously');
}
