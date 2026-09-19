import assert from 'node:assert/strict';
import fs from 'node:fs';
import vm from 'node:vm';
import {createWalkCollisionIndex} from './walk_collision_index.mjs';
import {createIncrementalWalkCollisionIndex} from './incremental_walk_collision_index.mjs';
import {createNpcSweptFootprint} from './npc_swept_footprint.mjs';
import {createNpcNativeNavigation} from './npc_native_navigation.mjs';
const body=(polygonCR,minYM=0,maxYM=3)=>({polygonCR,minYM,maxYM});
const thin=body([[3.998,3.6],[4.002,3.6],[4.002,4.5],[3.998,4.5]]),concave=body([[8,0],[11,0],[11,3],[10,3],[10,1],[9,1],[9,3],[8,3]]),upper=body([[0,0],[1,0],[1,1],[0,1]],2,3);
const original=[thin,concave,upper,thin],door=body([[3.2,3.8],[3.4,3.8],[3.4,4.2],[3.2,4.2]]);
const dynamic=createIncrementalWalkCollisionIndex();dynamic.replaceGroup('base',original,{order:0});dynamic.replaceGroup('door',[door],{order:1});
function parity(collections){
 const fixed=createWalkCollisionIndex(collections);
 for(const box of [[3.5,3.5,4.5,4.5],[4,4,4,4],[0,0,12,8],[-8,-4,0,0],[8,0,12,4]]){
  const candidates=dynamic.queryBounds(...box);
  assert.deepEqual(candidates,fixed.queryBounds(...box),'stable bucket/source order and duplicates');
  for(const b of collections.flat()){
   const cs=b.polygonCR.map(p=>p[0]),rs=b.polygonCR.map(p=>p[1]);
   if(Math.max(...cs)>=box[0]&&Math.min(...cs)<=box[2]&&Math.max(...rs)>=box[1]&&Math.min(...rs)<=box[3])assert(candidates.includes(b),'bounds broadphase contains every linear AABB overlap including edge contact');
  }
 }
 assert.deepEqual(dynamic.queryBounds(NaN,0,1,1),[]);assert.deepEqual(dynamic.queryBounds(2,0,1,1),[]);
}
parity([original,[door]]);const moved=body([[16,0],[17,0],[17,1],[16,1]]);dynamic.replaceGroup('door',[moved],{order:1});parity([original,[moved]]);assert(!dynamic.queryBounds(3,3,4,4).includes(door),'old door buckets invalidated');dynamic.removeGroup('door');parity([original]);
const footprint=createNpcSweptFootprint();
footprint.set({r:4,c:3.7},{r:4,c:4.3});assert(footprint.overlaps(thin.polygonCR),'thin boundary-crossing solid');
footprint.set({r:2,c:9.5},{r:2.6,c:9.5});assert(!footprint.overlaps(concave.polygonCR),'concave empty notch is not filled by a convex hull of obstacle');
footprint.set({r:2,c:9.5},{r:.5,c:9.5});assert(footprint.overlaps(concave.polygonCR),'concave notch floor blocks');
footprint.set({r:0,c:0},{r:0,c:0});assert(footprint.overlaps([[-.01,-.01],[.01,-.01],[.01,.01],[-.01,.01]]),'small obstacle wholly inside footprint');
assert(footprint.overlaps([[.18,-1],[.19,-1],[.19,1],[.18,1]]),'edge touching is conservative contact');
let floor=0;
const containsBody=()=>false; // Sweep must use exact polygons, not point samples.
const nav=createNpcNativeNavigation({groundHeight:()=>floor,bodiesAt:dynamic,bodiesInBounds:dynamic.queryBounds,containsBody});
const sweep=(from,to)=>nav.query({mode:'sweep',from,to,radius:.18});
assert(sweep({r:4,c:3.7},{r:4,c:4.3}).blocked);floor=3;nav.beginFrame();assert(!sweep({r:4,c:3.7},{r:4,c:4.3}).blocked,'walk on solid top');
floor=0;nav.beginFrame();assert(!sweep({r:.5,c:.2},{r:.5,c:.8}).blocked,'overhead solid clears actual capsule height');
floor=.2;nav.beginFrame();assert(sweep({r:.5,c:.2},{r:.5,c:.8}).blocked,'rising floor reduces vertical headroom');
floor=NaN;nav.beginFrame();assert(sweep({r:4,c:3.7},{r:4,c:4.3}).blocked,'invalid support is blocked');
// The front footprint corners reach a walkable platform before the centre does.
// Using centre support for the entire swept body falsely walls off hospital ramps.
const plinth=body([[-.3,1],[.3,1],[.3,2],[-.3,2]],.54,.61);
const ramp=createNpcNativeNavigation({worldScale:1,groundHeight:(_x,z)=>.61+(z-1)*.51,bodiesInBounds:()=>[plinth],containsBody});
assert(!ramp.query({mode:'sweep',from:{r:.7,c:0},to:{r:1.2,c:0}}).blocked,'sloping support at actual front contact clears platform');
const wall=body(plinth.polygonCR,0,3);
const rampWall=createNpcNativeNavigation({worldScale:1,groundHeight:(_x,z)=>.61+(z-1)*.51,bodiesInBounds:()=>[wall],containsBody});
assert(rampWall.query({mode:'sweep',from:{r:.7,c:0},to:{r:1.2,c:0}}).blocked,'same slope still blocks a real wall');
// Actual source hook adds only a static check; previous point gates and custom
// callbacks still run, including own-vehicle-ignore/medical door exceptions.
const source=fs.readFileSync(new URL('../../../world.html',import.meta.url),'utf8').replace(/\r\n/g,'\n');
const start=source.indexOf('function _npcPathPassable('),end=source.indexOf('\n}',start)+2;
let pointAllowed=true,sweepCalls=0;const pass=()=>true,custom=()=>true;
const scope={Math,npcPassable:pass,npcPassableForSnitch:()=>true,_npcBodyPassable:()=>pointAllowed,_walkNpcNavigationResolver:()=>{sweepCalls++;return {swept:true,blocked:true};}};
vm.createContext(scope);vm.runInContext(source.slice(start,end),scope);
assert(!scope._npcPathPassable(0,0,0,.1,pass));assert.equal(sweepCalls,1);
assert(scope._npcPathPassable(0,0,0,.1,custom));assert.equal(sweepCalls,1,'custom callbacks do not lose their semantics');
pointAllowed=false;assert(!scope._npcPathPassable(0,0,0,.1,pass));assert.equal(sweepCalls,1,'terrain/water/dynamic refusal remains prior and authoritative');
console.log('PASS exact NPC sweep: thin/concave/contained/touching solids, bounds parity/dirty groups, real height and source custom passage guards');
