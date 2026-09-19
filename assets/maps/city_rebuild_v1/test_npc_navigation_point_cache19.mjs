import assert from 'node:assert/strict';
import {createNpcNativeNavigation} from './npc_native_navigation.mjs';

let vehicle=true,floor=0,water=1,wall=false,samples=0;
const nav=createNpcNativeNavigation({worldScale:1,
 groundHeight:()=>{samples++;return floor;},waterAt:()=>({level:water}),
 bodiesAt:()=>wall?[{polygonCR:[]}]:[],containsBody:()=>true,
 blocksDynamic:(x,z,body)=>vehicle&&body.ignoreId!=='own-car',
 surfaceAt:()=> 'land'});
const point={r:1.123456789,c:2.123456789};
const blocked=nav.query(point);
assert.equal(blocked.blocked,true);
assert.strictEqual(nav.query({...point}),blocked,'identical fractional coordinates reuse result');
assert.equal(samples,1);
const ignored=nav.query({...point,ignoreVehicleId:'own-car'});
assert.equal(ignored.blocked,false,'ignoring own vehicle is independent from ordinary query');
assert.strictEqual(nav.query({...point,ignoreVehicleId:'own-car'}),ignored);
assert.equal(nav.query({...point,ignoreVehicleId:'other-car'}).blocked,true);
assert.notStrictEqual(nav.query({r:point.r+Number.EPSILON,c:point.c}),blocked,'no coordinate quantization');
const zero=nav.query({r:0,c:-0});
assert.strictEqual(nav.query({r:-0,c:0,ignoreVehicleId:''}),zero,'signed zero and falsy ignore ID match previous keys');
const numericId=nav.query({...point,ignoreVehicleId:7});
assert.strictEqual(nav.query({...point,ignoreVehicleId:'7'}),numericId,'previous string identity coercion retained');
const beforeInvalid=samples;
for(const r of [NaN,Infinity,-Infinity,'1'])assert.deepEqual(nav.query({r,c:0}),{blocked:true,depth:0});
assert.equal(samples,beforeInvalid,'invalid coordinates never reach providers');
vehicle=false;water=3;floor=1;
assert.strictEqual(nav.query(point),blocked,'cache lifetime remains the current frame');
nav.beginFrame();
assert.deepEqual(nav.query(point),{blocked:false,depth:2,surface:'land'},'next frame refreshes vehicle, support and water');
wall=true;nav.beginFrame();
assert.equal(nav.query({...point,ignoreVehicleId:'own-car'}).blocked,true,'ignoring vehicle cannot retain stale door/solid admission');

let calls=0;
const capped=createNpcNativeNavigation({containsBody:()=>false,groundHeight:()=>{calls++;return 0;}});
for(let i=0;i<29999;i++)capped.query({r:i,c:.123});
capped.query({r:0,c:0,ignoreVehicleId:'car'});
const full=calls;
capped.query({r:0,c:.123});capped.query({r:0,c:0,ignoreVehicleId:'car'});
assert.equal(calls,full,'ordinary and ignored entries remain readable at cap');
for(let i=0;i<2;i++)capped.query({r:30001,c:0});
for(let i=0;i<2;i++)capped.query({r:0,c:0,ignoreVehicleId:'new-car'});
assert.equal(calls,full+4,'30,000-result cap is shared across all vehicle identities');
capped.beginFrame();
const reset=calls;
capped.query({r:30001,c:0});capped.query({r:30001,c:0});
assert.equal(calls,reset+1,'next frame restores insertion capacity');
console.log('NPC point cache: fractional identity, signed zero, ignored vehicles, live frame invalidation and shared cap PASS');
