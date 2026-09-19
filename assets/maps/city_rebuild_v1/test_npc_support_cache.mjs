import assert from 'node:assert/strict';
import fs from 'node:fs';
import {performance} from 'node:perf_hooks';
import {createNpcSupportCache} from './npc_support_cache.mjs';
import {createNpcNativeNavigation} from './npc_native_navigation.mjs';
import {createExplorationRailwayPlan} from './exploration_railway_plan.mjs';
import {createCivilianNativeFixture} from './test_civilian_native_fixture.mjs';
let calls=0,value=0;
const environment={scene:{},buildingIndex:{},railway:{},railPlan:{},landscape:{},topology:{},entries:[{floorHeight:()=>0}]};
const cache=createNpcSupportCache({sample:()=>{calls++;return value;},getEnvironment:()=>environment,maxPoints:3});
assert.equal(cache.sample(1,2),0);cache.beginFrame();assert.equal(cache.sample(1,2),0);assert.equal(calls,1,'support retained across frames');
assert.equal(cache.sample(1+Number.EPSILON,2),0);assert.equal(calls,2,'no coordinate rounding');
for(const key of ['scene','buildingIndex','railway','railPlan','landscape','topology']){value++;environment[key]={};cache.beginFrame();assert.equal(cache.sample(1,2),value,key+' replacement invalidates');}
environment.entries[0].floorHeight=()=>9;value=9;cache.beginFrame();assert.equal(cache.sample(1,2),9,'floor function replacement invalidates');
value=10;environment.entries[0].npcSupportRevision=1;cache.beginFrame();assert.equal(cache.sample(1,2),10,'explicit in-place floor revision invalidates');
environment.entries.push({floorHeight:()=>0});value=11;cache.beginFrame();assert.equal(cache.sample(1,2),11,'new entry invalidates');
environment.entries.reverse();value=12;cache.beginFrame();assert.equal(cache.sample(1,2),12,'floor precedence reorder invalidates');
for(let i=0;i<20;i++)cache.sample(i,i);assert.equal(cache.diagnostics().size,3);assert(cache.diagnostics().evictions>0,'bounded FIFO capacity');
cache.invalidate();value=NaN;cache.sample(1,2);value=14;assert.equal(cache.sample(1,2),14,'unready support is never retained');

// Production navigation receives only cached support. All other gates must
// observe current state, including same-identity/in-place door edits.
let floor=0,water=0,terrain=true,car=false,train=false;
const env={entries:[{floorHeight:()=>0}],scene:{}};
const support=createNpcSupportCache({sample:()=>floor,getEnvironment:()=>env});
const door={minYM:0,maxYM:2,polygonCR:[[0,0],[2,0],[2,2],[0,2]]};let bodies=[];
const nav=createNpcNativeNavigation({worldScale:1,groundHeight:support.sample,waterAt:()=>({level:water}),terrainAllows:()=>terrain,bodiesAt:()=>bodies,containsBody:()=>true,blocksDynamic:()=>car||train});
const frame=()=>{support.beginFrame();nav.beginFrame();return nav.query({r:1,c:1});};
assert(!frame().blocked);car=true;assert(frame().blocked);car=false;train=true;assert(frame().blocked);train=false;assert(!frame().blocked);
bodies.push(door);assert(frame().blocked);door.minYM=3;assert(!frame().blocked,'door narrowphase remains live despite same array');
water=2;assert.equal(frame().depth,2,'water remains live');terrain=false;assert(frame().blocked);terrain=true;
floor=3;door.maxYM=5;env.entries[0].npcSupportRevision=1;assert(frame().blocked,'new support changes overhead collision');
door.minYM=0;door.maxYM=2;assert(!frame().blocked,'walkable platform remains supported');assert.equal(frame().depth,0);

const fixture=await createCivilianNativeFixture(),anchor=fixture.entry.approachPoint(),actualSupport=createNpcSupportCache({sample:fixture.floor,getEnvironment:()=>({scene:fixture.scene,entries:[fixture.entry],topology:fixture.top})});
const actualPoints=Array.from({length:256},(_,i)=>({x:anchor.x+(i%16-8)*.3,z:anchor.z+(Math.floor(i/16)-8)*.3}));
for(const p of actualPoints)assert.equal(actualSupport.sample(p.x,p.z),fixture.floor(p.x,p.z));
const closedBodies=fixture.entry.getCollisionBodies();fixture.entry.interact(anchor);
for(let i=0;i<25;i++)fixture.nextFrame(.05);
assert.notEqual(fixture.entry.getCollisionBodies(),closedBodies,'actual hospital door physically changed');actualSupport.beginFrame();
for(const p of actualPoints)assert.equal(actualSupport.sample(p.x,p.z),fixture.floor(p.x,p.z),'real hospital ramp/platform floor unchanged by opening leaves');

const topology=JSON.parse(fs.readFileSync(new URL('./topology_for_placement.json',import.meta.url))),rail=createExplorationRailwayPlan({topology}),report={regions:{},limits:'CPU actual rail/landscape support only, same coordinates and warmup; no loaded-game FPS. Includes 640-entry identity scan per batch.'};
for(const [name,origin]of Object.entries({hospital:{x:675,z:40},westRail:{x:35,z:365},westForest:{x:-190,z:200}})){
 const points=Array.from({length:1600},(_,i)=>({x:origin.x+((i%40)-20)*.5125,z:origin.z+(Math.floor(i/40)-20)*.5125}));
 const sample=(x,z)=>rail.floorHeight(x,z)??rail.landscape.groundHeight(x,z),env={railPlan:rail,landscape:rail.landscape,topology,entries:Array.from({length:640},()=>({floorHeight:()=>null}))};
 const cached=createNpcSupportCache({sample,getEnvironment:()=>env});
 for(const p of points)assert.equal(cached.sample(p.x,p.z),sample(p.x,p.z),'actual support unchanged');
 const before=[],after=[];let checksum=0;
 for(let pass=0;pass<35;pass++){
  let t=performance.now();for(const p of points)checksum+=sample(p.x,p.z);const raw=performance.now()-t;
  t=performance.now();cached.beginFrame();for(const p of points)checksum+=cached.sample(p.x,p.z);const hit=performance.now()-t;
  if(pass>=5){before.push(raw);after.push(hit);}
 }
 assert(Number.isFinite(checksum));const stats=a=>{a.sort((x,y)=>x-y);return{p50Ms:a[15],p95Ms:a[28]};};
 report.regions[name]={queriesPerBatch:1600,before:stats(before),after:stats(after),cache:cached.diagnostics()};
}
assert(report.regions.westRail.after.p50Ms<report.regions.westRail.before.p50Ms*.5,'meaningful western support saving');
fs.writeFileSync(new URL('../../../outputs/npc_support_cache_20260919.json',import.meta.url),JSON.stringify(report,null,2));console.log(JSON.stringify(report,null,2));
console.log('PASS NPC-only support cache: exact coordinates, bounded storage, scene/floor invalidation and live collision/water gates');
