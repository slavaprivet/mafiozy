import assert from 'node:assert/strict';
import {createWorldWalkMeleeInput} from './world_walk_melee_input.mjs';
let time=10,sourceTime=10,charge=null,seq=0,type='kick',reject=false,blocks=0;const calls=[];
const bridge={setWalkMeleeCharge(active){calls.push(['charge',active]);if(active&&charge===null)charge=sourceTime;if(!active)charge=null;return active},setWalkMeleeBlock(active){blocks+=active?1:-1;return active},beginWalkMelee(request){calls.push(['begin',{...request}]);if(reject||request.heavy&&(charge===null||sourceTime-charge<1.2))return {accepted:false};const chosen=request.airborne?'dropkick':request.heavy?'heavy':type;return {accepted:true,seq:++seq,type:chosen,side:-1,startAt:sourceTime*1000,duration:chosen==='dropkick'?1.25:chosen==='heavy'?.5:.62,contactWindow:chosen==='dropkick'?[160,380]:[180,340]}}};
const input=createWorldWalkMeleeInput({bridge,now:()=>time});
let state=input.press({yaw:.3,airHeight:1});assert(state.started&&state.action.type==='kick');assert.equal(state.start.seq,state.start.id);assert.equal(state.start.sourceStartAt,10000);assert.equal(calls.find(c=>c[0]==='begin')[1].angle,Math.PI/2-.3);
const count=calls.filter(c=>c[0]==='begin').length;input.press();assert.equal(calls.filter(c=>c[0]==='begin').length,count);
time+=.31;sourceTime+=.31;state=input.step();assert(Math.abs(state.action.progress-.5)<1e-10);input.release();assert.equal(charge,null);
time+=1;sourceTime+=1;input.step();input.press();time+=1.21;sourceTime+=1.21;state=input.step();assert(state.started&&state.action.type==='heavy');assert.notEqual(charge,null);time+=2;sourceTime+=2;assert(!input.step().started);input.release();
input.press();time+=1.21;sourceTime+=1.21;state=input.release();assert(state.started&&state.action.type==='heavy');assert.notEqual(charge,null);
input.cancel();time+=1;sourceTime+=1;input.press();time+=1.3;sourceTime+=.1;assert(!input.step().started,'renderer cannot forge source hold time');assert.equal(charge,null);
input.cancel();time+=1;sourceTime+=1;reject=true;assert(!input.press().started);reject=false;input.step({buttons:0});time+=2;sourceTime+=2;assert(!input.step().started,'lost pointerup cannot charge');
state=input.press({airborne:true,airHeight:2.3});assert(state.started&&state.action.type==='dropkick');assert.equal(state.start.airHeight,2.3);assert.deepEqual(state.start.contactWindow,[160,380]);assert.equal(charge,null);
input.cancel();input.step({airborne:false});input.press();input.step({armed:true});assert.equal(charge,null);assert.equal(input.step().action.type,'none');
input.step({armed:false});state=input.block(true);assert(state.action.blocking);assert(!input.press().started);input.cancel();assert.equal(input.step().action.blocking,false);
assert(calls.filter(c=>c[0]==='begin').every(c=>!('elapsed' in c[1])&&!('type' in c[1])));
console.log('PASS world melee input: source-chosen type/duration, yaw/clock mapping, single charge, release ordering, stale buttons/cancel/weapon/block, rejected source, airborne');

