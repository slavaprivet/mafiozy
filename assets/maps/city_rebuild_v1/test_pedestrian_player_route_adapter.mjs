import assert from 'node:assert/strict';
import {createPedestrianSurfaceMotion} from './pedestrian_surface_passability.mjs';
import {createPedestrianPlayerRouteAdapter} from './pedestrian_player_route_adapter.mjs';

const boxContains=(box,x,z)=>x>=box.minX&&x<=box.maxX&&z>=box.minZ&&z<=box.maxZ;
function fixture({terrain=()=>0,slope=()=>0,boxes=[],movingCars=new Set()}={}){
 const supportHeight=(x,z,referenceY,context)=>{let floor=terrain(x,z);for(const box of boxes)if(boxContains(box,x,z)&&box.id!==context?.ignoreVehicleId&&box.top<=referenceY+.34)floor=Math.max(floor,box.top);return floor};
 const sample=(x,z,referenceY,context)=>{let top=terrain(x,z),supportKind;for(const box of boxes)if(boxContains(box,x,z)&&box.id!==context?.ignoreVehicleId){top=Math.max(top,box.top);if(box.vehicle)supportKind='vehicle'}return {floor:terrain(x,z),top,waterDepth:0,walkable:true,supportKind}};
 const canOccupy=(point,height,context)=>!boxes.some(box=>box.id!==context?.ignoreVehicleId&&boxContains(box,point.x,point.z)&&point.y<box.top-.002&&point.y+height>box.bottom+.002);
 return createPedestrianSurfaceMotion({supportHeight,canOccupy,sample,terrainSlopeAt:slope,walkable:()=>true});
}

const curb={minX:.18,maxX:.36,minZ:.18,maxZ:.36,bottom:0,top:.3};
let adapter=createPedestrianPlayerRouteAdapter({motion:fixture({boxes:[curb]})});
let result=adapter.route({from:{x:0,y:0,z:0},delta:{x:.5,z:.5},now:1});
assert(result.moved&&result.mode==='step'&&result.animation?.stepRise===.3&&result.traversal===null,'diagonal curb is a swept auto-step');

const grade=1.6,terrain=x=>(x>0?x*grade:0);
adapter=createPedestrianPlayerRouteAdapter({motion:fixture({terrain,slope:()=>grade})});
result=adapter.route({from:{x:0,y:0,z:0},delta:{x:.2,z:.2},now:2});
assert(result.moved&&result.mode==='scramble'&&result.nextSpeedScale<1&&result.traversal===null,'diagonal supported ascent requests scramble speed');
const reverse=adapter.route({from:result.position,delta:{x:-.2,z:-.2},now:2.01});
assert(reverse.moved&&reverse.mode==='scramble'&&reverse.animation?.kind==='scramble','continuous supported downhill retains controlled scramble-down');
const turnMotion={limits:{bodyHeight:1.9},route(from,to){const forward=to.x>from.x;return {moved:true,reason:'clear',position:{x:to.x,y:from.y,z:to.z},autoStep:false,stepRise:0,maxRise:forward?.1:0,slope:forward?1.2:0,ascentMode:forward?'scramble':'walk',speedScale:forward?.48:1,traversal:null,traversalKind:null}}};
const turnAdapter=createPedestrianPlayerRouteAdapter({motion:turnMotion});turnAdapter.route({from:{x:0,y:0,z:0},delta:{x:.1,z:0},now:2.1});const turned=turnAdapter.route({from:{x:.1,y:0,z:0},delta:{x:-.1,z:0},now:2.11});assert(turned.mode==='walk'&&turned.animation===null&&turnAdapter.animation===null,'turnaround cancels stale scramble metadata when the new surface is walkable');

const xWall={minX:.16,maxX:.5,minZ:-.15,maxZ:.15,bottom:0,top:2.4};
adapter=createPedestrianPlayerRouteAdapter({motion:fixture({boxes:[xWall]})});
result=adapter.route({from:{x:0,y:0,z:0},delta:{x:.3,z:.2},now:3});
assert(result.moved&&result.slide==='z'&&result.position.x===0&&Math.abs(result.position.z-.2)<1e-9&&result.traversal===null,'blocked diagonal safely slides along the free Z axis');

const corner=[{minX:.12,maxX:.5,minZ:-.5,maxZ:.5,bottom:0,top:2.4},{minX:-.5,maxX:.5,minZ:.12,maxZ:.5,bottom:0,top:2.4}];
adapter=createPedestrianPlayerRouteAdapter({motion:fixture({boxes:corner})});
result=adapter.route({from:{x:0,y:0,z:0},delta:{x:.3,z:.3},now:4});
assert(!result.moved&&result.mode==='blocked'&&result.position.x===0&&result.position.z===0&&result.traversal===null,'solid corner blocks without teleport');

const parked={id:'car-7',vehicle:true,minX:.15,maxX:.55,minZ:-.3,maxZ:.3,bottom:0,top:.72};
adapter=createPedestrianPlayerRouteAdapter({motion:fixture({boxes:[parked]})});
const stationary=adapter.route({from:{x:0,y:0,z:0},delta:{x:.4,z:0},now:5});
assert(!stationary.moved&&stationary.mode==='traversal'&&['vault','mantle'].includes(stationary.traversalKind),'stationary car returns one physical traversal');
assert(stationary.traversal&&Object.keys(stationary).filter(key=>key==='traversal').length===1&&stationary.animation?.plan===undefined,'plan exists only in the canonical traversal field');

const movingMotion=fixture({boxes:[parked]});
const moving={route(from,to,options){const value=movingMotion.route(from,to,options);return {...value,traversal:null,traversalKind:null}},limits:movingMotion.limits};
adapter=createPedestrianPlayerRouteAdapter({motion:moving});
const movingResult=adapter.route({from:{x:0,y:0,z:0},delta:{x:.4,z:0},now:6});
assert(!movingResult.moved&&movingResult.mode==='blocked'&&movingResult.traversal===null,'moving car remains a hard block');

adapter=createPedestrianPlayerRouteAdapter({motion:fixture({boxes:[parked]})});
const escaped=adapter.route({from:{x:.3,y:0,z:0},delta:{x:.5,z:0},ignoreVehicleId:'car-7',now:7});
assert(escaped.moved&&escaped.position.x===.8&&escaped.mode==='walk'&&escaped.traversal===null,'source-car escape ignores only the named vehicle');

const unsupportedMotion={limits:{bodyHeight:1.9},route:()=>({moved:false,reason:'unsupported',pending:false,traversal:{kind:'mantle'},traversalKind:'mantle'})};
result=createPedestrianPlayerRouteAdapter({motion:unsupportedMotion}).route({from:{x:0,y:0,z:0},delta:{x:.2,z:0},now:8});
assert.equal(result.mode,'unsupported');assert.equal(result.traversal,null,'unsupported never emits traversal');
const pendingMotion={limits:{bodyHeight:1.9},route:()=>({moved:false,reason:'budget_deferred',pending:true,traversal:{kind:'vault'},traversalKind:'vault'})};
result=createPedestrianPlayerRouteAdapter({motion:pendingMotion}).route({from:{x:0,y:0,z:0},delta:{x:.2,z:0},now:9});
assert.equal(result.mode,'pending');assert.equal(result.traversal,null,'pending never emits traversal');

const flat=fixture(),run=dt=>createPedestrianPlayerRouteAdapter({motion:flat}).route({from:{x:1,y:0,z:2},delta:{x:.23,z:-.17},now:10,dt});
assert.deepEqual(run(1/3),run(1/240),'route result depends on displacement, not frame dt');

const pooledAdapter=createPedestrianPlayerRouteAdapter({motion:flat}),pooledWorkspace=pooledAdapter.createWorkspace(),pooledOut=pooledAdapter.createOutput(),pooledInput={from:{x:1,y:0,z:2},delta:{x:.23,z:-.17},now:10,owner:'surface'};
assert.equal(pooledAdapter.routeInto(pooledOut,pooledInput,pooledWorkspace),pooledOut);const pooledSnapshot=JSON.parse(JSON.stringify(pooledOut));assert.deepEqual(pooledSnapshot,run(1/60),'pooled and compatibility routes expose the same result');pooledInput.now=10.1;assert.equal(pooledAdapter.routeInto(pooledOut,pooledInput,pooledWorkspace),pooledOut,'hot route preserves output identity');
const publicA=pooledAdapter.route({...pooledInput,now:11}),publicB=pooledAdapter.route({...pooledInput,now:12});publicA.position.x=99;assert.notEqual(publicB.position.x,99,'compatibility route results remain independent');

const teleportMotion={limits:{bodyHeight:1.9},route:()=>({moved:true,reason:'clear',position:{x:999,y:0,z:999},ascentMode:'walk',speedScale:1})};
result=createPedestrianPlayerRouteAdapter({motion:teleportMotion}).route({from:{x:0,y:0,z:0},delta:{x:.1,z:.1},now:11});
assert(!result.moved&&result.position.x===0&&result.position.z===0&&result.reason==='invalid_result'&&result.traversal===null,'out-of-segment motion result cannot teleport the player');

const ledgeHeight=x=>x<=0?10:0,ledgeMotion=createPedestrianSurfaceMotion({supportHeight:ledgeHeight,canOccupy:()=>true,terrainSlopeAt:()=>100,sample:x=>({floor:ledgeHeight(x),top:ledgeHeight(x),waterDepth:0,walkable:true})});
result=createPedestrianPlayerRouteAdapter({motion:ledgeMotion}).route({from:{x:0,y:10,z:0},delta:{x:.1,z:0},now:12});
assert(result.moved&&result.mode==='free-fall'&&result.reason==='free_fall'&&result.position.y===10&&result.verticalTransition?.fallDistance===10&&result.traversal===null,'adapter exposes one explicit fall transition and preserves root Y');

const timings=[];for(let batch=-10;batch<80;batch++){const bench=createPedestrianPlayerRouteAdapter({motion:flat}),workspace=bench.createWorkspace(),out=bench.createOutput(),input={from:{x:1,y:0,z:2},delta:{x:.023,z:-.017},now:0},started=performance.now();for(let i=0;i<1000;i++){input.now=i/60;bench.routeInto(out,input,workspace)}if(batch>=0)timings.push(performance.now()-started)}timings.sort((a,b)=>a-b);const cpu={batchSize:1000,p50Ms:timings[Math.floor(timings.length*.5)],p95Ms:timings[Math.floor(timings.length*.95)]};

console.log('PASS player route adapter: diagonal curb/scramble, safe axis slide, full block, car traversal/block/escape, turnaround, pending/unsupported, dt parity');
console.log(JSON.stringify({flatPlayerRoutesCpu:cpu}));
