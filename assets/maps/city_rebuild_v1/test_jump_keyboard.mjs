import fs from 'node:fs';import vm from 'node:vm';import assert from 'node:assert/strict';
import {jumpDirection,launchJump,tryDiveJump,stepJump} from './hero_jump.mjs';
const source=fs.readFileSync(new URL('walk_preview.mjs',import.meta.url),'utf8');
const binding=source.slice(source.indexOf('const keys=new Set();'),source.indexOf('function updateJump(dt)'));
assert.ok(binding.includes('beginJump(e.timeStamp)'));
function session(){
 const events={};const c={jumpDirection,launchJump,tryDiveJump,performance:{now:()=>9000},
  addEventListener:(name,fn)=>(events[name]??=[]).push(fn),arsenalOpen:()=>false,artistSwimming:()=>false,artistBusy:()=>false,artistAction:{action:{type:'none'}},
  hero:{object:{position:{x:0,y:0,z:0},rotation:{y:0}},reset(){}},heroPosture:{value:0,target:'stand'},surfaceMotion:{state:{grounded:true}},walking:true,occupiedSeat:null,transition:null,jump:null,heroBlast:null,busy:false,jumpCount:0,
  controls:{target:{clone:()=>({sub:()=>({x:0,z:1})})}},camera:{position:{}},$:()=>({hidden:true}),groundHeight:()=>0,buildingQaMove:null,entryHeld:0,pointerHeld:false};
 vm.createContext(c);vm.runInContext(binding,c);
 const event=(name,code,timeStamp,repeat=false)=>{for(const fn of events[name]??[])fn({code,timeStamp,repeat,target:{tagName:'CANVAS'},preventDefault(){}})};
 return {c,event};
}
for(const code of ['KeyW','KeyA','KeyS','KeyD']){
 const {c,event}=session();event('keydown',code,990);event('keydown','Space',1000);
 assert.equal(c.jump.mode,'normal');assert.equal(c.jump.startedAt,1000,'use input timestamp, not delayed render clock');assert.ok(c.jump.directional);
 c.jump=stepJump(c.jump,.1,()=>true);const y=c.jump.y;event('keydown','Space',1100,true);assert.equal(c.jump.mode,'normal','held key cannot double-tap');
 event('keyup','Space',1150);event('keydown','Space',1450);assert.equal(c.jump.mode,'dive',code+' second real press');assert.equal(c.jump.y,y);assert.equal(c.jumpCount,1);
 event('keyup','Space',1460);event('keydown','Space',1470);assert.equal(c.jumpCount,1);
}
const stationary=session();stationary.event('keydown','Space',1000);assert.equal(stationary.c.jump.directional,false);stationary.event('keyup','Space',1010);stationary.event('keydown','Space',1200);assert.equal(stationary.c.jump.mode,'dive');assert.equal(stationary.c.jump.dz,1);
const late=session();late.event('keydown','Space',1000);late.event('keyup','Space',1010);late.event('keydown','Space',1510);assert.equal(late.c.jump.mode,'normal');
const car=session();car.c.occupiedSeat='driver';car.event('keydown','Space',1000);assert.equal(car.c.jump,null);assert.equal(vm.runInContext("keys.has('Space')",car.c),true,'Space remains vehicle handbrake');
console.log('PASS actual /walk keyboard bindings: WASD, normal, repeat ignored, release+second press, delayed handler clock, stationary dive, late press, vehicle handbrake');
