import assert from 'node:assert/strict';
import {createPedestrianSurfaceMotion} from './pedestrian_surface_passability.mjs';
import {createNpcPedestrianEdgeProbe} from './npc_pedestrian_edge_probe.mjs';

function measuredFlat({wallAt=Infinity}={}){
 const calls={support:0,sample:0,occupy:0,walkable:0,slope:0};
 const motion=createPedestrianSurfaceMotion({supportHeight:x=>(calls.support++,0),sample:x=>(calls.sample++,{floor:0,top:0,waterDepth:0,walkable:true}),canOccupy:p=>(calls.occupy++,p.x<wallAt),walkable:()=>(calls.walkable++,true),terrainSlopeAt:()=>(calls.slope++,0)});
 return {motion,calls,weighted:()=>calls.support+calls.sample+calls.occupy*13+calls.walkable+calls.slope};
}

const flat=measuredFlat(),probe=createNpcPedestrianEdgeProbe({motion:flat.motion,groundHeight:()=>0,worldScale:4.1,maxChunkDistance:.55,maxWorkUnitsPerFrame:512,maxChunksPerCall:16});
const request={from:{r:0,c:0,y:0},to:{r:0,c:8,y:0}},pendingFrames=[];let retryToken=null,result,guard=0;
const started=performance.now();do{probe.beginFrame();result=probe.probe({...request,retryToken});if(result.pending){assert(result.blocked&&!result.terminal&&result.retry==='next_frame'&&!result.booleanHookCompatible&&result.retryToken,'pending is retry state, never clear or terminal block');pendingFrames.push({work:result.frameWorkUnits,c:result.retryToken.cursor.c});retryToken=result.retryToken}guard++;assert(guard<200)}while(result.pending);const elapsed=performance.now()-started;
assert(result.moved&&!result.blocked&&result.terminal&&result.accepted.x===32.8&&result.retryToken===null,'8-cell edge completes only after every short segment clears');
assert(pendingFrames.length>0&&pendingFrames.every((value,index)=>index===0||value.c>pendingFrames[index-1].c),'retry token advances monotonically');
assert.equal(result.chunks,Math.ceil(32.8/.55),'retry cursor covers each bounded segment exactly once');
assert.equal(result.workUnits,flat.weighted(),'reported work units exactly equal weighted support/sample/capsule/walk/slope calls');
assert(pendingFrames.every(value=>value.work<=512),'clear chunks respect the strict per-frame work budget');
const longSummary={meters:32.8,frames:guard,pendingFrames:pendingFrames.length,chunks:result.chunks,workUnits:result.workUnits,elapsedMs:elapsed};

const blockedFixture=measuredFlat({wallAt:10}),blockedProbe=createNpcPedestrianEdgeProbe({motion:blockedFixture.motion,groundHeight:()=>0,worldScale:4.1,maxChunkDistance:.55,maxWorkUnitsPerFrame:512});retryToken=null;guard=0;const blockedFrameWork=[];
do{blockedProbe.beginFrame();result=blockedProbe.probe({...request,retryToken});blockedFrameWork.push(result.frameWorkUnits);retryToken=result.retryToken;guard++;assert(guard<100)}while(result.pending);
assert(!result.moved&&result.blocked&&result.terminal&&result.reason==='collision'&&result.retryToken===null,'long edge becomes a real block only when a physical chunk fails');
assert(blockedFrameWork.every(work=>work<=512),'hard work cap includes terminal collision frames');
assert.throws(()=>createNpcPedestrianEdgeProbe({motion:flat.motion,groundHeight:()=>0,maxChunkDistance:.55,maxWorkUnitsPerFrame:100}),/chunk exceeds hard work budget/,'configuration cannot admit a chunk larger than its hard cap');

const stale=probe.probe({...request,to:{r:0,c:7,y:0},retryToken:pendingFrames.length?{version:1,signature:'wrong',cursor:{r:0,c:1,y:0},workUnits:1,chunks:1}:null});
assert.equal(stale.reason,'stale_retry_token');assert(stale.terminal&&stale.blocked&&!stale.pending);

probe.beginFrame();const short=probe.probe({from:{r:1,c:1,y:0},to:{r:1,c:1.05,y:0}});assert(short.moved&&!short.pending&&short.workUnits>0,'short edge completes synchronously');

for(const to of [{r:0,c:0,y:3},{r:0,c:.1,y:3}]){
 probe.beginFrame();const mismatch=probe.probe({from:{r:0,c:0,y:0},to});
 assert(!mismatch.moved&&mismatch.blocked&&mismatch.terminal&&!mismatch.pending&&mismatch.reason==='endpoint_storey_mismatch','same/near-XZ edge cannot clear on another storey');
}
let zeroEndpointCalls=0;
const zeroBlockedMotion={limits:flat.motion.limits,route(from){zeroEndpointCalls++;return {moved:false,reason:'collision',position:{...from},workUnits:1}}};
const zeroBlockedProbe=createNpcPedestrianEdgeProbe({motion:zeroBlockedMotion,groundHeight:()=>0,worldScale:1});
zeroBlockedProbe.beginFrame();const zeroBlocked=zeroBlockedProbe.probe({from:{r:0,c:0,y:0},to:{r:0,c:0,y:0}});
assert.equal(zeroEndpointCalls,1,'zero-length edge asks motion to certify endpoint occupancy');
assert(!zeroBlocked.moved&&zeroBlocked.blocked&&zeroBlocked.terminal&&zeroBlocked.reason==='collision');
probe.beginFrame();const zeroClear=probe.probe({from:{r:2,c:2,y:0},to:{r:2,c:2,y:0}});
assert(zeroClear.moved&&!zeroClear.blocked&&zeroClear.terminal&&zeroClear.reason==='clear'&&zeroClear.workUnits===14,'supported occupiable zero-length endpoint clears inside measured work budget');

const zeroBudgetFixture=measuredFlat(),zeroBudgetProbe=createNpcPedestrianEdgeProbe({motion:zeroBudgetFixture.motion,groundHeight:()=>0,worldScale:1,maxWorkUnitsPerFrame:512,maxChunkDistance:.55});zeroBudgetProbe.beginFrame();
for(let i=0;i<36;i++){const clear=zeroBudgetProbe.probe({from:{r:0,c:i,y:0},to:{r:0,c:i,y:0}});assert(clear.moved&&!clear.pending&&clear.frameWorkUnits===(i+1)*14)}
const deferredZeroRequest={from:{r:0,c:36,y:0},to:{r:0,c:36,y:0}},deferredZero=zeroBudgetProbe.probe(deferredZeroRequest);
assert(deferredZero.pending&&!deferredZero.terminal&&deferredZero.blocked&&deferredZero.reason==='work_budget'&&deferredZero.frameWorkUnits===504,'37th zero edge defers before its 14-unit endpoint certificate');
assert.equal(zeroBudgetFixture.weighted(),504,'deferred endpoint performs no hidden physical work');
zeroBudgetProbe.beginFrame();const retriedZero=zeroBudgetProbe.probe({...deferredZeroRequest,retryToken:deferredZero.retryToken});
assert(retriedZero.moved&&!retriedZero.pending&&retriedZero.frameWorkUnits===14&&retriedZero.workUnits===14,'deferred zero edge retries and clears next frame within budget');

const unsupportedMotion={limits:flat.motion.limits,route:()=>({moved:false,reason:'unsupported',workUnits:1,traversal:{kind:'mantle'},traversalKind:'mantle'})};
const unsupported=createNpcPedestrianEdgeProbe({motion:unsupportedMotion,groundHeight:()=>0}).probe({from:{r:0,c:0,y:0},to:{r:0,c:.1,y:0}});assert.equal(unsupported.reason,'unsupported');assert.equal(unsupported.traversal,null);

console.log('PASS NPC edge probe: 8-cell chunk/retry, exact weighted work, monotonic token, physical block, stale token, short edge, unsupported safety');
console.log(JSON.stringify({longEdge:longSummary,clearFrameWork:pendingFrames,blockedFrameWork}));
