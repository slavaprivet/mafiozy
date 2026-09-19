import test from 'node:test';
import assert from 'node:assert/strict';
import {createMercenarySquad} from './mercenary_core.mjs';

test('vehicle pursuit survives long stationary blockage, resets moving work, and remains cancellable',()=>{
 let time=0;const member={id:'demo',hp:100,position:{x:0,y:0,z:0}},car={id:'car',kind:'vehicle',position:{x:20,y:0,z:0},valid:true},effects=[];
 const squad=createMercenarySquad({now:()=>time,getMember:()=>member,getTarget:()=>car,performEffect:e=>{effects.push(e);return true;}});
 squad.recruit({id:'demo',profession:'demolitions'});squad.command('demo','plant_bomb','car');
 for(time=0;time<120;time++)squad.update();
 assert.equal(squad.getAction('demo').phase,'approach');
 member.position.x=20;squad.update();time+=3;squad.update();assert.equal(squad.getAction('demo').phase,'working');
 // Drive while remaining within the generic work radius: movement itself must
 // invalidate the partial work, not only a failed distance check.
 time+=.1;car.position.x+=.1;squad.update();assert.equal(squad.getAction('demo').phase,'approach');assert.equal(squad.getAction('demo').progress,0);
 time+=.4;squad.update();time+=3.9;squad.update();assert.equal(squad.getAction('demo').armed,false);
 time+=.11;squad.update();assert.equal(squad.getAction('demo').armed,true);
 member.position.x=35;time+=6;squad.update();assert.equal(effects.length,1);
 time+=21;car.position.x=100;squad.command('demo','plant_bomb','car');squad.update();assert(squad.cancel('demo').ok);assert.equal(squad.getAction('demo'),null);
});
