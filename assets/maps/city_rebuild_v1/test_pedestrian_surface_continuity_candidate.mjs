import assert from 'node:assert/strict';
import {createPedestrianSurfaceMotion} from './pedestrian_surface_passability.mjs';
import {createPedestrianSurfaceContinuityCandidate} from './pedestrian_surface_continuity_candidate.mjs';

function make({height,slope=()=>0,surface=true}={}){
 const supportHeight=(x,z)=>height(x,z),sample=(x,z)=>surface?{floor:height(x,z),top:height(x,z),waterDepth:0,walkable:true}:null;
 const motion=createPedestrianSurfaceMotion({supportHeight,sample,canOccupy:()=>true,walkable:()=>true,terrainSlopeAt:slope});
 return createPedestrianSurfaceContinuityCandidate({motion,supportHeight,sample,terrainSlopeAt:slope});
}

const ledge=make({height:x=>x<=0?10:0,slope:()=>100});
let result=ledge.route({x:0,y:10,z:0},{x:.1,z:0},{ledgePolicy:'free-fall'});
assert(result.moved&&result.reason==='free_fall'&&result.movementMode==='free-fall'&&result.position.y===10&&result.position.x>0,'player crosses edge horizontally without snapping root down');
assert.equal(result.verticalTransition.fallDistance,10);assert.equal(result.traversal,null);
const npcLedge=ledge.route({x:0,y:10,z:0},{x:.1,z:0},{ledgePolicy:'block'});
assert(!npcLedge.moved&&npcLedge.reason==='ledge_drop'&&npcLedge.position.y===10&&npcLedge.verticalTransition.kind==='free-fall','ordinary NPC cannot cache a ledge as walkable or teleport down');

const curb=make({height:x=>x<.04?.3:0,slope:()=>0});result=curb.route({x:0,y:.3,z:0},{x:.1,z:0},{ledgePolicy:'free-fall'});
assert(result.moved&&result.position.y===0&&result.descentStep===.3&&result.reason==='clear','small descending curb remains a supported step-down');

const grade=1.55,downhill=make({height:x=>10-x*grade,slope:()=>grade});result=downhill.route({x:0,y:10,z:0},{x:.5,z:0},{ledgePolicy:'free-fall'});
assert(result.moved&&result.movementMode==='scramble'&&result.ascentMode==='scramble'&&result.speedScale===.48&&Math.abs(result.position.y-9.225)<1e-9,'continuous steep downhill requests controlled scramble-down');
assert.deepEqual(downhill.route({x:0,y:10,z:0},{x:.5,z:0},{ledgePolicy:'block'}),result,'player/NPC share continuous supported downhill semantics');

const gap=make({height:()=>NaN,surface:false});result=gap.route({x:0,y:10,z:0},{x:.1,z:0},{ledgePolicy:'free-fall'});
assert(!result.moved&&result.reason==='unsupported'&&result.position.y===10&&result.traversal===null,'unknown gap fails closed without y teleport');

const started=performance.now();for(let i=0;i<10000;i++)downhill.route({x:0,y:10,z:0},{x:.1,z:0},{ledgePolicy:'block'});const elapsed=performance.now()-started;
console.log('PASS vertical continuity candidate: 10m free-fall/block policy, curb descent, steep supported downhill, unsupported gap, no y teleport');
console.log(JSON.stringify({routes:10000,elapsedMs:elapsed,averageMicroseconds:elapsed*1000/10000}));
