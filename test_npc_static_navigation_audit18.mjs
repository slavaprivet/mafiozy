import fs from 'node:fs';
import assert from 'node:assert/strict';
import {performance} from 'node:perf_hooks';
import {loadStaticNavigationCandidate} from './test_npc_static_navigation_candidate18.mjs';
import {createNpcNativeNavigation as baseline} from './assets/maps/city_rebuild_v1/npc_native_navigation.mjs';
import {createWalkCollisionIndex} from './assets/maps/city_rebuild_v1/walk_collision_index.mjs';
import {pointInPolygon} from './assets/maps/city_rebuild_v1/car_drive.mjs';
const {createNpcNativeNavigation:candidate}=await loadStaticNavigationCandidate();
const containsBody=(b,r,c)=>pointInPolygon(c,r,b.polygonCR);
let revision=0,wall=true,dynamic=false,floor=0,waterLevel=0,terrain=true,surface='land';
let groundCalls=0,bodyCalls=0,dynamicCalls=0;
const wallBody={polygonCR:[[0,0],[1,0],[1,1],[0,1]],minYM:0,maxYM:3};
const opts={worldScale:1,getStaticRevision:()=>revision,groundHeight:()=>{groundCalls++;return floor},waterAt:()=>({level:waterLevel}),terrainAllows:()=>terrain,surfaceAt:()=>surface,bodiesAt:()=>{bodyCalls++;return wall?[wallBody]:[]},bodiesInBounds:()=>wall?[wallBody]:[],containsBody,blocksDynamic:()=>{dynamicCalls++;return dynamic}};
const nav=candidate(opts),p={r:.5,c:.5},edge={mode:'sweep',from:{r:.5,c:-.5},to:{r:.5,c:1.5},radius:.18};
nav.beginFrame();assert(nav.query(p).blocked);assert(nav.query(edge).blocked);
const initialCalls=bodyCalls;nav.beginFrame();assert(nav.query(p).blocked);assert(nav.query(edge).blocked);assert.equal(bodyCalls,initialCalls);
wall=false;revision++;nav.beginFrame();assert(!nav.query(p).blocked);assert(!nav.query(edge).blocked);
dynamic=true;nav.beginFrame();assert(nav.query(p).blocked);dynamic=false;nav.beginFrame();assert(!nav.query(p).blocked);
waterLevel=2;nav.beginFrame();assert.equal(nav.query(p).depth,2);waterLevel=0;nav.beginFrame();assert.equal(nav.query(p).depth,0);
terrain=false;nav.beginFrame();assert(nav.query(p).blocked);terrain=true;surface='road';nav.beginFrame();assert.equal(nav.query(p).surface,'road');
floor=3;wall=true;revision++;nav.beginFrame();assert(!nav.query(p).blocked);assert(!nav.query(edge).blocked,'raised support affects sweep');
floor=0;revision++;nav.beginFrame();assert(nav.query(p).blocked);assert(nav.query(edge).blocked);
nav.invalidateStatic();wall=false;nav.beginFrame();assert(!nav.query(p).blocked,'explicit invalidate handles same-token replacement');
// Non-opt-in remains original cross-frame fresh even without any published token.
const uncached=candidate({...opts,getStaticRevision:null});uncached.beginFrame();assert(!uncached.query(p).blocked);wall=true;uncached.beginFrame();assert(uncached.query(p).blocked);
assert(dynamicCalls>4);
const snapshot=JSON.parse(fs.readFileSync('./outputs/roads_logical_20260912/integration_candidate_snapshot.json','utf8'));
const bodies=[...snapshot.buildings,...snapshot.authoredDecor].flatMap(x=>x.collision?.worldBodies||[]).concat(snapshot.decorPlan.colliders,snapshot.roadPlan.colliders,snapshot.parkingPlan.colliders);
const index=createWalkCollisionIndex([bodies]);
const points=[];for(let r=135.5;r<165;r+=.5)for(let c=155.5;c<185;c+=.5)points.push({r,c});
function bench(make,cached){let pointCalls=0,sweepCalls=0,dynamics=0;const n=make({getStaticRevision:cached?()=>0:null,groundHeight:()=>0,waterAt:()=>null,bodiesAt:(c,r)=>{pointCalls++;return index(c,r)},bodiesInBounds:(...b)=>{sweepCalls++;return index.queryBounds(...b)},containsBody,blocksDynamic:()=>{dynamics++;return false}});const frames=[],checks=[];for(let f=0;f<24;f++){const start=performance.now();n.beginFrame();let sum=0;for(let i=0;i<points.length;i++){const q=points[i];sum+=+n.query(q).blocked;if(i%3===0)sum+=+n.query({mode:'sweep',from:q,to:{r:q.r,c:q.c+.5},radius:.18}).blocked;}frames.push(performance.now()-start);checks.push(sum)}return{pointCalls,sweepCalls,dynamics,checks,p50:frames.slice(4).sort((a,b)=>a-b)[10],p95:frames.slice(4).sort((a,b)=>a-b)[19],totalMs:frames.reduce((a,b)=>a+b,0)}}
// Alternate runs to expose warm-up variance, not a single fortunate sample.
const results=[];for(let i=0;i<3;i++){const a=bench(baseline,false),b=bench(candidate,true);assert.deepEqual(a.checks,b.checks);assert.equal(a.dynamics,b.dynamics);results.push({baseline:a,candidate:b});}
console.log(JSON.stringify({status:'PASS',bodies:bodies.length,queriesPerFrame:points.length,safety:'revision invalidation, same-token explicit clear, raised support, dynamic obstacles, water, terrain, surface, opt-out',results},null,2));
