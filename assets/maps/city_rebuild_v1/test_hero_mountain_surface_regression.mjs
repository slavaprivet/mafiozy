import assert from 'node:assert/strict';
import {performance} from 'node:perf_hooks';
import {createLandscapePlan} from './landscape_plan.mjs';
import {createHeroSurfaceMotion} from './hero_surface_motion.mjs';
import {circleFits,movePedestrian} from './walk_motion.mjs';
import {createSurfaceMotion} from './surface_motion.mjs';

const terrain=createLandscapePlan();
const footprintRadius=.36;
const counters={support:0,sample:0,occupy:0,walkable:0,slope:0};
const snapshotQueries=()=>({...counters});
const queryDelta=before=>Object.fromEntries(Object.keys(counters).map(key=>[key,counters[key]-before[key]]));
const supportHeight=(x,z)=>{counters.support++;return terrain.groundHeight(x,z)};
const sample=(x,z)=>{counters.sample++;const floor=terrain.groundHeight(x,z);return {floor,top:floor,waterDepth:terrain.waterAt(x,z)?.depth??0}};
// Match traversalWorld.canOccupy's terrain policy: the footprint must remain in
// the world, while slope admission belongs to hero surface motion rather than
// the old coarse navigation mask. There are no bodies, cars or ceilings in
// this pure terrain fixture.
const canOccupy=p=>{counters.occupy++;return circleFits(p.x,p.z,(x,z)=>terrain.contains(x,z),footprintRadius)};
const walkable=(x,z)=>{counters.walkable++;return terrain.canWalk(x,z)};
const terrainSlopeAt=(x,z)=>{counters.slope++;return terrain.slopeAt(x,z)};
const heroSurface=createHeroSurfaceMotion({supportHeight,canOccupy,sample,walkable,terrainSlopeAt});

const from={x:405,z:-299.6};
from.y=terrain.groundHeight(from.x,from.z);
const target={x:405,z:-299.7};
const targetY=terrain.groundHeight(target.x,target.z);
assert.equal(terrain.waterAt(target.x,target.z),null,'mountain fixture is dry');
assert.equal(terrain.canWalk(target.x,target.z),true,'the target centre is below the legacy terrain threshold');
assert.ok(terrain.slopeAt(target.x,target.z)<.78,'the target centre itself is physically admissible');
assert.ok(terrain.slopeAt(target.x,target.z-.36)>.78,'the leading legacy footprint probe crosses the coarse mask');
assert.equal(circleFits(target.x,target.z,(x,z)=>terrain.canWalk(x,z),footprintRadius),false,'legacy footprint mask creates the invisible wall');

const legacySurface=createSurfaceMotion();
legacySurface.reset(from);
assert.equal(legacySurface.canMove(from,target,terrain.groundHeight,from.y),true,'legacy physical height check accepts the same rise');
assert.deepEqual(movePedestrian(from,{x:0,z:-.1},(x,z)=>terrain.canWalk(x,z),footprintRadius),{x:from.x,z:from.z,moved:false},'legacy horizontal admission sticks at the slope mask');

let phaseQueries=snapshotQueries(),started=performance.now();
const repaired=heroSurface.route(from,target);
const wallFixtureMs=performance.now()-started;
const wallQueries=queryDelta(phaseQueries);
assert.equal(repaired.moved,true,'player surface route admits the physically valid mountain step');
assert.ok(Math.abs(repaired.position.y-targetY)<1e-9,'accepted step follows the rendered terrain height');

const ridge=terrain.paths.find(path=>path.id==='ridge-ascent');
assert(ridge,'authored ridge-ascent path exists');
let position={x:ridge.points[0].x,y:terrain.groundHeight(ridge.points[0].x,ridge.points[0].z),z:ridge.points[0].z};
let ridgeDistance=0;
phaseQueries=snapshotQueries();started=performance.now();
for(let i=1;i<ridge.points.length;i++){
 const point=ridge.points[i];
 ridgeDistance+=Math.hypot(point.x-position.x,point.z-position.z);
 const step=heroSurface.route(position,point);
 assert.equal(step.moved,true,`authored ridge-ascent segment ${i} remains traversable (${step.reason})`);
 position=step.position;
}
const ridgeMs=performance.now()-started;
const ridgeQueries=queryDelta(phaseQueries);
assert.ok(Math.abs(position.x-ridge.points.at(-1).x)<1e-9&&Math.abs(position.z-ridge.points.at(-1).z)<1e-9,'authored ascent reaches the summit');

const cliffFrom={x:405,z:-300.2};
cliffFrom.y=terrain.groundHeight(cliffFrom.x,cliffFrom.z);
const cliffTarget={x:405,z:-300.4};
assert.ok(terrain.slopeAt(cliffTarget.x,cliffTarget.z)>heroSurface.limits.walkSlope,'steep continuous fixture exceeds ordinary walking grade');
assert.ok(terrain.slopeAt(cliffTarget.x,cliffTarget.z)<heroSurface.limits.scrambleSlope,'steep continuous fixture remains within supported scramble geometry');
phaseQueries=snapshotQueries();
const cliff=heroSurface.route(cliffFrom,cliffTarget);
const cliffQueries=queryDelta(phaseQueries);
assert.equal(cliff.moved,true,'continuous steep terrain is no longer an invisible wall');
assert.equal(cliff.ascentMode,'scramble','continuous steep terrain requests the slow scramble presentation');

const faceGrade=3.2,face=createHeroSurfaceMotion({supportHeight:x=>x*faceGrade,canOccupy:()=>true,walkable:()=>false,terrainSlopeAt:()=>faceGrade,sample:x=>({floor:x*faceGrade,top:x*faceGrade,waterDepth:0})});
const faceResult=face.route({x:0,y:0,z:0},{x:1,z:0});
assert.equal(faceResult.moved,false);assert.equal(faceResult.reason,'terrain_face','near-vertical terrain without intermediate support remains traversal/block');
const unsupported=createHeroSurfaceMotion({supportHeight:x=>x*1.3,canOccupy:p=>p.x<.48,walkable:()=>false,terrainSlopeAt:()=>1.3,sample:x=>({floor:x*1.3,top:x*1.3,waterDepth:0})});
const unsupportedResult=unsupported.route({x:0,y:0,z:0},{x:1,z:0});
assert.equal(unsupportedResult.moved,false);assert.equal(unsupportedResult.reason,'collision','steep terrain cannot bypass missing capsule support');
const wall=createHeroSurfaceMotion({supportHeight:()=>0,canOccupy:p=>p.x<.48,sample:x=>({floor:0,top:x>=.48?2.4:0,waterDepth:0,walkable:true})});
const wallResult=wall.route({x:0,y:0,z:0},{x:1,z:0});
assert.equal(wallResult.moved,false);assert.equal(wallResult.traversalKind,null,'over-reach wall stays blocked rather than becoming scramble');

console.log(JSON.stringify({
 status:'PASS',
 wall:{from,target:{...target,y:targetY},centreSlope:terrain.slopeAt(target.x,target.z),leadingSlope:terrain.slopeAt(target.x,target.z-.36),legacyMoved:false,repairedReason:repaired.reason,wallFixtureMs,queries:wallQueries},
 ridge:{segments:ridge.points.length-1,distanceM:ridgeDistance,summit:position,ridgeMs,queries:ridgeQueries},
 cliff:{from:cliffFrom,target:cliffTarget,slope:terrain.slopeAt(cliffTarget.x,cliffTarget.z),reason:cliff.reason,mode:cliff.ascentMode,queries:cliffQueries},
 adversarial:{terrainFace:faceResult.reason,unsupported:unsupportedResult.reason,wall:wallResult.reason},
 totalQueries:counters,
},null,2));
