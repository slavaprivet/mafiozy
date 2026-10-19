import assert from 'node:assert/strict';
import fs from 'node:fs';
import {createPedestrianSurfaceMotion} from './pedestrian_surface_passability.mjs';
import {PEDESTRIAN_MOVEMENT_PRIORITY,pedestrianMovementOwner,createPedestrianSurfaceMetadataLatch,createNpcPedestrianSurfaceConsumer} from './pedestrian_surface_integration_contract.mjs';
import {createTraversalWorld} from './hero_traversal_world.mjs';

assert.deepEqual(PEDESTRIAN_MOVEMENT_PRIORITY,['vehicle','jump','ladder','water','cover','surface']);
for(const [state,owner] of [[{occupiedSeat:true,coverActive:true},'vehicle'],[{jump:true,ladderActive:true},'jump'],[{ladderActive:true,swimming:true},'ladder'],[{swimming:true,coverActive:true},'water'],[{coverActive:true},'cover'],[{},'surface']])assert.equal(pedestrianMovementOwner(state),owner);

const latch=createPedestrianSurfaceMetadataLatch();
let frame=latch.update({moved:true,autoStep:true,stepRise:.3,maxRise:.3,ascentMode:'walk'},{now:1,direction:{x:1,z:0}});assert.equal(frame.kind,'step');assert(latch.sample(1.17));assert.equal(latch.sample(1.19),null,'step metadata expires');
frame=latch.update({moved:true,autoStep:false,stepRise:0,maxRise:.4,slope:1.4,ascentMode:'scramble',speedScale:.48},{now:2,direction:{x:1,z:0}});assert.equal(frame.kind,'scramble');
latch.update({moved:true,autoStep:false,stepRise:0,maxRise:0,slope:0,ascentMode:'walk',speedScale:1},{now:2.02,direction:{x:-1,z:0}});assert.equal(latch.cancelReason,null);assert.equal(latch.state,null,'turn-around removes stale scramble metadata');
latch.update({moved:true,ascentMode:'scramble',slope:1.2,maxRise:.1,speedScale:.48},{now:3,direction:{x:1,z:0}});latch.update(null,{now:3.01,owner:'vehicle'});assert.equal(latch.state,null);assert.equal(latch.cancelReason,'owner:vehicle');
const plan={kind:'vault'};frame=latch.update({moved:false,reason:'rise',traversalKind:'vault',traversal:plan},{now:4,direction:{x:1,z:0}});assert.equal(frame.kind,'traversal');assert.equal(latch.consumeTraversal(),plan);assert.equal(latch.consumeTraversal(),null,'traversal intent is one-shot');

const diagonalGrade=1.4,axis=Math.SQRT1_2,ground=(x,z)=>(x+z)*axis*diagonalGrade;
const diagonal=createPedestrianSurfaceMotion({supportHeight:ground,canOccupy:()=>true,walkable:()=>false,terrainSlopeAt:()=>diagonalGrade,sample:(x,z)=>{const floor=ground(x,z);return {floor,top:floor,waterDepth:0,walkable:false}}});
const consumer=createNpcPedestrianSurfaceConsumer({motion:diagonal,groundHeight:ground,worldScale:1,maxUniqueEdgesPerFrame:2,maxCacheEntries:8});
const uphill={from:{r:0,c:0},to:{r:.5,c:.5}},up=consumer.query(uphill);assert(up.moved&&up.ascentMode==='scramble','diagonal steep terrain scrambles');
for(let i=0;i<99;i++)assert.equal(consumer.query(uphill),up,'crowd shares the exact same edge result');
assert.deepEqual(consumer.diagnostics(),{uniqueEdges:1,hits:99,deferred:0,cache:1,maxUniqueEdgesPerFrame:2,maxCacheEntries:8});
const down=consumer.query({from:{r:.5,c:.5,y:ground(.5,.5)},to:{r:0,c:0}});assert(down.moved&&down.ascentMode==='scramble','continuous supported steep downhill uses controlled scramble-down');
assert.equal(consumer.query({from:{r:.1,c:.1},to:{r:.6,c:.6}}).reason,'budget_deferred','per-frame query budget defers rather than hard-blocks');
consumer.beginFrame();assert.equal(consumer.diagnostics().uniqueEdges,0);

const ignoredVehicleContexts=[];
const rememberContext=context=>{ignoredVehicleContexts.push(context);return context};
const ignoreVehicleMotion=createPedestrianSurfaceMotion({supportHeight:(x,z,y,context)=>(rememberContext(context),0),canOccupy:(point,height,context)=>(rememberContext(context),true),sample:(x,z,y,context)=>(rememberContext(context),{floor:0,top:0,waterDepth:0,walkable:true})});
const ignoreVehicleConsumer=createNpcPedestrianSurfaceConsumer({motion:ignoreVehicleMotion,groundHeight:()=>0,worldScale:1});
assert(ignoreVehicleConsumer.query({from:{r:0,c:0},to:{r:0,c:.2},ignoreVehicleId:'moving-car-7'}).moved);
assert(ignoredVehicleContexts.length>0&&ignoredVehicleContexts.every(context=>context.ignoreVehicleId==='moving-car-7'),'current moving vehicle is ignored only through the capsule context');

let storeyCalls=0;
const storeyMotion={limits:{bodyHeight:1.9},route(from,to,options){storeyCalls++;return {moved:true,reason:'clear',position:{x:to.x,y:from.y,z:to.z},height:options.height}}};
const storeyConsumer=createNpcPedestrianSurfaceConsumer({motion:storeyMotion,groundHeight:(x,z,referenceY=0)=>referenceY,worldScale:1,maxUniqueEdgesPerFrame:8,maxCacheEntries:8});
const edge={from:{r:2,c:3,y:0},to:{r:2,c:3.1,y:0}};
const groundEdge=storeyConsumer.query(edge),upperEdge=storeyConsumer.query({from:{...edge.from,y:4},to:{...edge.to,y:4}}),tallEdge=storeyConsumer.query({...edge,height:2.2});
assert.equal(storeyCalls,3,'same x/z edge on another storey or with another capsule height cannot reuse cache');
assert.notEqual(groundEdge,upperEdge);assert.equal(tallEdge.height,2.2);

const flatCertificateMotion=createPedestrianSurfaceMotion({supportHeight:()=>0,canOccupy:()=>true,sample:()=>({floor:0,top:0,waterDepth:0,walkable:true}),walkable:()=>true,terrainSlopeAt:()=>0});
const flatCertificateConsumer=createNpcPedestrianSurfaceConsumer({motion:flatCertificateMotion,groundHeight:()=>0,worldScale:1});
for(const to of [{r:0,c:0,y:3},{r:0,c:.1,y:3}]){
 const mismatch=flatCertificateConsumer.query({from:{r:0,c:0,y:0},to});
 assert(!mismatch.moved&&mismatch.blocked&&!mismatch.pending&&mismatch.reason==='endpoint_storey_mismatch','explicit target Y must be certified by endpoint support');
}
let zeroEndpointCalls=0;
const zeroBlockedMotion={limits:{bodyHeight:1.9},route(from){zeroEndpointCalls++;return {moved:false,reason:'collision',position:{...from},workUnits:1}}};
const zeroBlockedConsumer=createNpcPedestrianSurfaceConsumer({motion:zeroBlockedMotion,groundHeight:()=>0,worldScale:1});
const zeroBlocked=zeroBlockedConsumer.query({from:{r:0,c:0,y:0},to:{r:0,c:0,y:0}});
assert.equal(zeroEndpointCalls,1,'zero-length edges still ask motion to certify endpoint occupancy');
assert(!zeroBlocked.moved&&zeroBlocked.blocked&&zeroBlocked.reason==='collision');
const zeroClear=flatCertificateConsumer.query({from:{r:1,c:1,y:0},to:{r:1,c:1,y:0}});
assert(zeroClear.moved&&!zeroClear.blocked&&zeroClear.reason==='clear'&&zeroClear.workUnits===14,'supported occupiable zero-length endpoint is a measured terminal clear edge');

const shoreFloor=x=>x<.5?-1:.6,shore=createPedestrianSurfaceMotion({supportHeight:shoreFloor,canOccupy:()=>true,sample:x=>({floor:shoreFloor(x),top:shoreFloor(x),waterDepth:x<.5?1:0,walkable:true})});
const shoreResult=shore.route({x:0,y:-1,z:0},{x:1,z:0},{swimming:true});assert.equal(pedestrianMovementOwner({swimming:true}),'water');assert.equal(shoreResult.traversalKind,'shore','water owner receives an explicit shore transition rather than terrain walking');

const wallTop=x=>x>.45&&x<.75?1.1:0,wallMotion=createPedestrianSurfaceMotion({supportHeight:()=>0,canOccupy:p=>!(p.x>.45&&p.x<.75&&p.y<1.1)&&p.y+1.9<2.05,sample:x=>({floor:0,top:wallTop(x),waterDepth:0,walkable:true})});
const wallResult=wallMotion.route({x:0,y:0,z:0},{x:1,z:0});assert(!wallResult.moved,'wall plus overhang remains blocked');
const carMotion=createPedestrianSurfaceMotion({supportHeight:x=>x>.4?.8:0,canOccupy:p=>p.x<=.4,sample:x=>({floor:0,top:x>.4?.8:0,waterDepth:0,walkable:true,...(x>.4?{supportKind:'vehicle'}:{})})});
const movingCar=carMotion.route({x:0,y:0,z:0},{x:1,z:0});assert.equal(movingCar.reason,'vehicle');assert.equal(movingCar.traversalKind,null,'moving-car occupancy removes climb destination');

// Read-only extraction pins the current minimal host sites. The test fails if
// a future owner moves/removes them before applying the documented hook.
const walk=fs.readFileSync(new URL('./walk_preview.mjs',import.meta.url),'utf8').replace(/\r\n/g,'\n'),native=fs.readFileSync(new URL('./npc_native_navigation.mjs',import.meta.url),'utf8').replace(/\r\n/g,'\n'),world=fs.readFileSync(new URL('../../../world.html',import.meta.url),'utf8').replace(/\r\n/g,'\n');
for(const anchor of ['const traversalWorld=createTraversalWorld(','function moveHeroOnFoot(delta){','const covered=heroCover.move(','if(!occupiedSeat&&!sourceVehicleActive()&&!transition&&!jump&&!heroBlast&&!verticalNavigation.active'])assert(walk.includes(anchor),'missing player host anchor: '+anchor);
for(const anchor of ['npcNativeNavigation=createNpcNativeNavigation(','npcBridge?.registerWalkNpcNavigationResolver?.(npcNativeNavigation.query)','npcVehicleNavigation=createNpcVehicleNavigation('])assert(walk.includes(anchor),'missing NPC host anchor: '+anchor);
assert(native.includes("if(mode==='sweep')return sweep(from,to,radius);"),'NPC semantic edge hook remains after exact sweep dispatch');
assert(world.includes("_walkNpcNavigationResolver({mode:'sweep',from:{r:fromR,c:fromC},to:{r:toR,c:toC},radius:.18})"),'world path edge invokes native resolver');
const pathStart=world.indexOf('function _npcPathPassable('),pathEnd=world.indexOf('\nfunction _recoverNpcFromCollision',pathStart),pathHook=world.slice(pathStart,pathEnd);
assert(pathHook.indexOf('_npcBodyPassable(fromR+')<pathHook.indexOf("_walkNpcNavigationResolver({mode:'sweep'"),'point/body guards remain before semantic edge hook');
const contractSource=fs.readFileSync(new URL('./pedestrian_surface_integration_contract.mjs',import.meta.url),'utf8');
assert(contractSource.includes('const cache=new Map()')&&!/function beginFrame\(\)\{[^}]*new Map/.test(contractSource),'frame reset reuses the cache Map');

const crowdSamples=[];for(let batch=-20;batch<120;batch++){consumer.beginFrame();const started=performance.now();for(let i=0;i<1000;i++)consumer.query(uphill);if(batch>=0)crowdSamples.push(performance.now()-started);}crowdSamples.sort((a,b)=>a-b);
const crowdCpu={batchSize:1000,p50Ms:crowdSamples[Math.floor(crowdSamples.length*.5)],p95Ms:crowdSamples[Math.floor(crowdSamples.length*.95)]};

let actualPointFits=0;
const actualWorld=createTraversalWorld({groundHeight:()=>0,ceilingHeight:()=>Infinity,bodiesAt:()=>[],contains:()=>true,walkable:()=>true,waterAt:()=>null,blocksDynamic:()=>{actualPointFits++;return false},inBody:()=>false});
const actualMotion=createPedestrianSurfaceMotion({supportHeight:actualWorld.supportHeight,canOccupy:actualWorld.canOccupy,sample:actualWorld.sample});
const actualConsumer=createNpcPedestrianSurfaceConsumer({motion:actualMotion,groundHeight:()=>0,worldScale:1,maxUniqueEdgesPerFrame:1000,maxCacheEntries:1000});
const diverseStarted=performance.now();for(let i=0;i<1000;i++){const r=(i%25)*.031,c=Math.floor(i/25)*.029;const result=actualConsumer.query({from:{r,c,y:0},to:{r:r+.017+(i%3)*.001,c:c+.041,y:0}});assert(result.moved)}const diverseMs=performance.now()-diverseStarted;
assert.equal(actualConsumer.diagnostics().uniqueEdges,1000);assert(actualPointFits>1000,'diverse benchmark executes the real swept capsule query');
const boundedActual=createNpcPedestrianSurfaceConsumer({motion:actualMotion,groundHeight:()=>0,worldScale:1}),boundedStarted=performance.now();for(let i=0;i<64;i++)assert(boundedActual.query({from:{r:i*.01,c:4,y:0},to:{r:i*.01+.02,c:4.04,y:0}}).moved);const bounded64Ms=performance.now()-boundedStarted;assert(boundedActual.query({from:{r:1,c:4,y:0},to:{r:1.02,c:4.04,y:0}}).pending);

const cadence={};for(const hz of [3,5,7,15,60]){const grade=1.2,terrain=(x)=>x*grade,cadenceMotion=createPedestrianSurfaceMotion({supportHeight:terrain,canOccupy:()=>true,walkable:()=>false,terrainSlopeAt:()=>grade,sample:x=>({floor:terrain(x),top:terrain(x),waterDepth:0,walkable:false})}),cadenceConsumer=createNpcPedestrianSurfaceConsumer({motion:cadenceMotion,groundHeight:terrain,worldScale:1});let position={r:0,c:0,y:0},mode='walk';for(let i=1;i<=hz;i++){cadenceConsumer.beginFrame();const next={r:0,c:i/hz,y:terrain(i/hz)},result=cadenceConsumer.query({from:position,to:next});assert(result.moved);position={...next,y:result.position.y};if(result.ascentMode==='scramble')mode='scramble'}cadence[hz]={x:position.c,y:position.y,mode};}
for(const value of Object.values(cadence)){assert(Math.abs(value.x-1)<1e-12&&Math.abs(value.y-1.2)<1e-9&&value.mode==='scramble','3/5/7/15/60 Hz route semantics stay equal')}

const defaultBudget=createNpcPedestrianSurfaceConsumer({motion:storeyMotion,groundHeight:()=>0,worldScale:1});for(let i=0;i<64;i++)assert(!defaultBudget.query({from:{r:i,c:0,y:0},to:{r:i,c:.1,y:0}}).pending);const pending=defaultBudget.query({from:{r:65,c:0,y:0},to:{r:65,c:.1,y:0}});assert.deepEqual({pending:pending.pending,blocked:pending.blocked,retry:pending.retry,booleanHookCompatible:pending.booleanHookCompatible},{pending:true,blocked:true,retry:'next_frame',booleanHookCompatible:false});

console.log('PASS integration contract: priority/lifetimes, storey-safe cache, no frame Map allocation, cadence parity, bounded budget, full vehicle-context propagation, water, wall/overhang, moving car, read-only host anchors');
console.log(JSON.stringify({crowdCachedEdgeCpu:crowdCpu,diverse1000ActualCapsule:{milliseconds:diverseMs,pointFits:actualPointFits},default64ActualCapsuleMs:bounded64Ms,cadence}));
