import test from 'node:test';
import assert from 'node:assert/strict';
import fs from 'node:fs';
import vm from 'node:vm';
import * as module from './mercenary_core.mjs';

const source=fs.readFileSync(new URL('./mercenary_world.js',import.meta.url),'utf8').replace("import(new URL('./mercenary_core.mjs',scriptUrl).href)",'Promise.resolve(module)');
const fixtureSource=fs.readFileSync(new URL('./test_mercenary_rally_actions.mjs',import.meta.url),'utf8');
const fixture=Function('vm','module','script','assert',fixtureSource.slice(fixtureSource.indexOf('async function fixture('),fixtureSource.indexOf('\nfor(const [profession'))+';return fixture;')(vm,module,source,assert);

test('followers fill three passenger seats, chase overflow, catch up and leave beside the car',async()=>{
 const f=await fixture({qa:true});for(const profession of ['medic','bruiser','engineer','safecracker','demolitions'])f.recruit(profession);
 f.api.bindTargets({canMove:()=>true,groundHeight:()=>0});
 const car={id:'crew-car',x:10,y:10,ang:.4,passenger_uids:[]};f.ctx.questCars=new Map([[car.id,car]]);f.ctx.myDrivingCarId=car.id;f.ctx.myIsPassenger=false;f.ctx._walkVehicleSeatId='front_left';f.ctx.QP.uid='me';
 f.ctx._myGang.forEach((member,index)=>{member.c=10+(index+1)*.1;member.r=10;});f.api.follow();f.tick();
 const seated=f.ctx._myGang.filter(member=>member._mercenaryVehicleSeat),overflow=f.ctx._myGang.filter(member=>!member._mercenaryVehicleSeat);
 assert.equal(seated.length,3);assert.equal(new Set(seated.map(member=>member._mercenaryVehicleSeat)).size,3);assert.deepEqual(new Set(seated.map(member=>member._mercenaryVehicleSeat)),new Set(['front_right','rear_left','rear_right']));assert.equal(overflow.length,2);assert(overflow.every(member=>member._mercenaryVehicleChase));
 const snapshots=f.api.decorateEntities(f.ctx._myGang.map(member=>({id:'crew_'+member.id,hp:member.hp})));assert.equal(snapshots.filter(row=>row.civilianTripRiding).length,3);assert(snapshots.filter(row=>row.civilianTripRiding).every(row=>row.civilianTripCarId==='quest_crew-car'&&row.weapon==='none'));
 car.x=100;car.y=100;f.ctx.player.c=100;f.ctx.player.r=100;f.tick(3);
 assert(overflow.every(member=>Math.hypot(member.c-car.x,member.r-car.y)*4.1<7),'fighters without seats catch up near the moving leader after sustained separation');
 f.ctx.myDrivingCarId=null;f.tick();assert(f.ctx._myGang.every(member=>!member._mercenaryVehicleSeat&&!member._mercenaryVehicleId));assert(f.ctx._myGang.every(member=>Math.hypot(member.c-f.ctx.player.c,member.r-f.ctx.player.r)*4.1<=6.1));
});

test('player passenger seat remains reserved for the player',async()=>{
 const f=await fixture({qa:true});for(const profession of ['medic','bruiser','engineer'])f.recruit(profession);f.api.bindTargets({canMove:()=>true,groundHeight:()=>0});
 const car={id:'taxi',x:10,y:10,ang:0,passenger_uids:['me']};Object.assign(f.ctx,{questCars:new Map([[car.id,car]]),myDrivingCarId:car.id,myIsPassenger:true,_walkVehicleSeatId:'front_right'});f.ctx.QP.uid='me';f.ctx._myGang.forEach(member=>{member.c=10;member.r=10;});f.api.follow();f.tick();
 assert(!f.ctx._myGang.some(member=>member._mercenaryVehicleSeat==='front_right'));assert.equal(f.ctx._myGang.filter(member=>member._mercenaryVehicleSeat).length,2);
});
