import assert from 'node:assert/strict';
import {createHeroSurfaceMotion,HERO_SURFACE_LIMITS} from './hero_surface_motion.mjs';
import {createPedestrianSurfaceMotion,PEDESTRIAN_SURFACE_LIMITS} from './pedestrian_surface_passability.mjs';
import {createSurfaceMotion} from './surface_motion.mjs';
import {createLandscapePlan} from './landscape_plan.mjs';
assert.equal(createHeroSurfaceMotion,createPedestrianSurfaceMotion,'hero and NPC share one semantic implementation');
assert.equal(HERO_SURFACE_LIMITS,PEDESTRIAN_SURFACE_LIMITS);

const radius=.33;
const boxes=[];
const terrain=(x,z)=>x<4?Math.max(0,(x-2)*.55):1.1;
const inBox=(b,x,z)=>x+radius>b.minX&&x-radius<b.maxX&&z+radius>b.minZ&&z-radius<b.maxZ;
function supportHeight(x,z,referenceY){let floor=terrain(x,z);for(const b of boxes)if(inBox(b,x,z)&&b.top<=referenceY+HERO_SURFACE_LIMITS.stepHeight+1e-6)floor=Math.max(floor,b.top);return floor;}
function canOccupy(p,height){if(p.x<-1||p.x>12||Math.abs(p.z)>3)return false;return !boxes.some(b=>inBox(b,p.x,p.z)&&p.y<b.top-.002&&p.y+height>b.bottom+.002);}
function sample(x,z,referenceY){let top=terrain(x,z),supportKind;for(const b of boxes)if(inBox(b,x,z)){top=Math.max(top,b.top);supportKind=b.kind;}return {floor:terrain(x,z),top,waterDepth:0,walkable:true,supportKind};}
const motion=createHeroSurfaceMotion({supportHeight,canOccupy,sample});

boxes.push({minX:.5,maxX:.8,minZ:-1,maxZ:1,bottom:0,top:.32});
let result=motion.route({x:0,y:0,z:0},{x:1.1,z:0});
assert.deepEqual(motion.route({x:0,y:0,z:0},{x:1.1,z:0},{actorKind:'pedestrian'}),result,'NPC curb decision matches the player');
assert(result.moved,'32 cm real curb is stepped');
assert.equal(result.position.y,.32);
assert.equal(result.autoStep,true);assert.equal(result.stepRise,.32);assert.equal(result.maxRise,.32);assert.equal(result.ascentMode,'walk');
assert(canOccupy(result.position,1.9),'full capsule clears the curb');

boxes[0].top=.52;
result=motion.route({x:0,y:0,z:0},{x:1.1,z:0});
assert(!result.moved,'medium obstacle is not weakened into an automatic step');
assert(['vault','mantle'].includes(result.traversalKind),'blocked medium obstacle carries animation traversal metadata');
const plan=motion.traversal({x:0,y:0,z:0},{x:1,z:0});
assert(plan&&['vault','mantle'].includes(plan.kind),'medium obstacle forms an explicit traversal plan');

boxes[0].top=2.3;
const wallResult=motion.route({x:0,y:0,z:0},{x:1.1,z:0});
assert.deepEqual(motion.route({x:0,y:0,z:0},{x:1.1,z:0},{actorKind:'pedestrian'}),wallResult,'NPC wall decision matches the player');
assert.equal(motion.traversal({x:0,y:0,z:0},{x:1,z:0}),null,'wall over reach stays solid');

boxes.length=0;
result=motion.route({x:2,y:0,z:0},{x:3,z:0});
assert(result.moved&&Math.abs(result.position.y-.55)<1e-9,'continuous uphill follows physical support');
const incline=(grade,{occupy=()=>true}={})=>createHeroSurfaceMotion({supportHeight:(x)=>x*grade,canOccupy:occupy,terrainSlopeAt:()=>grade,walkable:()=>false,sample:(x)=>({floor:x*grade,top:x*grade,waterDepth:0,walkable:false})});
const hill=incline(.55).route({x:0,y:0,z:0},{x:1,z:0});
assert(hill.moved&&hill.ascentMode==='walk'&&hill.slope>=.55&&hill.maxRise===.55,'exact mountain fixture: ordinary continuous hill walks despite old mask');
const mountain=incline(1.55).route({x:0,y:0,z:0},{x:1,z:0});
assert(mountain.moved&&mountain.ascentMode==='scramble'&&mountain.speedScale<1,'exact mountain fixture: steep supported terrain requests slow scramble');
const npcMountain=incline(1.55).route({x:0,y:0,z:0},{x:1,z:0},{actorKind:'pedestrian'});
assert.deepEqual(npcMountain,mountain,'NPC consumes the exact same mountain route semantics');
const blockedMountain=incline(1.55,{occupy:p=>p.x<.52}).route({x:0,y:0,z:0},{x:1,z:0});
assert(!blockedMountain.moved&&blockedMountain.reason==='collision','slope cannot override capsule collision');
const cliff=incline(3.2).route({x:0,y:0,z:0},{x:1,z:0});
assert(!cliff.moved&&cliff.reason==='terrain_face','near-vertical terrain without intermediate support is traversal/block');

// Exact generated mountain face which the old landscape.canWalk mask rejects.
const landscape=createLandscapePlan(),mountainStart={x:531,z:-271},mountainDirection={x:-.17852961783308585,z:-.983934538247526};mountainStart.y=landscape.groundHeight(mountainStart.x,mountainStart.z);
const mountainTarget={x:mountainStart.x+mountainDirection.x*.4,z:mountainStart.z+mountainDirection.z*.4};
const actualMountain=createPedestrianSurfaceMotion({supportHeight:(x,z)=>landscape.groundHeight(x,z),canOccupy:()=>true,walkable:(x,z)=>landscape.canWalk(x,z),terrainSlopeAt:(x,z)=>landscape.slopeAt(x,z),sample:(x,z)=>{const floor=landscape.groundHeight(x,z);return {floor,top:floor,waterDepth:landscape.waterAt(x,z)?.depth??0,walkable:landscape.canWalk(x,z)}}});
const actualMountainResult=actualMountain.route(mountainStart,mountainTarget);
assert(actualMountainResult.moved&&actualMountainResult.ascentMode==='scramble','actual north ridge becomes a supported scramble instead of an invisible wall');
assert(actualMountainResult.slope>1.16&&actualMountainResult.maxRise>.46);
assert.deepEqual(actualMountain.route(mountainStart,mountainTarget,{actorKind:'pedestrian'}),actualMountainResult,'NPC gets the exact same north-ridge admission');

boxes.push({minX:.5,maxX:.8,minZ:-1,maxZ:1,bottom:0,top:.3,kind:'vehicle'});
const carResult=motion.route({x:0,y:0,z:0},{x:1.1,z:0});
assert.deepEqual(motion.route({x:0,y:0,z:0},{x:1.1,z:0},{actorKind:'pedestrian'}),carResult,'NPC parked-car decision matches the player');
assert.equal(carResult.reason,'vehicle','low vehicle is never an automatic stair');
assert.equal(carResult.autoStep,false,'vehicle climb never reports curb auto-step');
assert(['vault','mantle'].includes(carResult.traversalKind),'parked car remains an explicit climb target');
assert.equal(motion.route({x:0,y:0,z:0},{x:1.1,z:0},{actorKind:'vehicle'}).reason,'pedestrian_only','cars cannot consume mountain/curb semantics');

boxes.length=0;boxes.push({minX:.5,maxX:.55,minZ:-1,maxZ:1,bottom:.1,top:2.4});
assert.equal(motion.route({x:0,y:0,z:0},{x:1.1,z:0}).reason,'collision','thin/extruded collision is distinguished from terrain ascent');

const bounded=createHeroSurfaceMotion({supportHeight:()=>0,canOccupy:p=>p.x<=4.1,sample:()=>({floor:0,top:0,waterDepth:0,walkable:true})});
assert(bounded.route({x:4,y:0,z:0},{x:4.08,z:0}).moved,'movement stays inside a real 4.1 m native cell bound');
assert(!bounded.route({x:4,y:0,z:0},{x:4.2,z:0}).moved,'sweep cannot skip a scale-4.1 world bound');
let zeroOccupyCalls=0;
const zeroClearMotion=createHeroSurfaceMotion({supportHeight:()=>0,canOccupy:()=>{zeroOccupyCalls++;return true},sample:()=>({floor:0,top:0,waterDepth:0,walkable:true})}),zeroClearResult=zeroClearMotion.route({x:1,y:0,z:1},{x:1,y:0,z:1});
assert.equal(zeroClearResult.reason,'still');assert.equal(zeroClearResult.workUnits,14);assert.equal(zeroOccupyCalls,1,'zero-distance route certifies endpoint support and capsule occupancy');
const zeroBlockedResult=createHeroSurfaceMotion({supportHeight:()=>0,canOccupy:()=>false,sample:()=>({floor:0,top:0,waterDepth:0,walkable:true})}).route({x:1,y:0,z:1},{x:1,y:0,z:1});
assert.equal(zeroBlockedResult.reason,'collision');assert.equal(zeroBlockedResult.workUnits,14,'blocked zero-distance endpoint remains inside measured work contract');

const invalidStart=createHeroSurfaceMotion({supportHeight:()=>NaN,canOccupy:()=>true,sample:()=>({floor:0,top:0,waterDepth:0,walkable:true})}).route({x:0,y:0,z:0},{x:.1,z:0});
assert.equal(invalidStart.reason,'unsupported');assert.equal(invalidStart.traversal,null,'missing starting support cannot become a traversal');
let supportCalls=0;const invalidProbe=createHeroSurfaceMotion({supportHeight:()=>++supportCalls===1?0:NaN,canOccupy:()=>true,sample:()=>({floor:0,top:0,waterDepth:0,walkable:true})}).route({x:0,y:0,z:0},{x:.1,z:0});
assert.equal(invalidProbe.reason,'unsupported');assert.equal(invalidProbe.traversal,null,'missing swept support fails closed');
for(const invalidSample of [null,{floor:NaN,top:0,waterDepth:0},{floor:0,top:NaN,waterDepth:0},{floor:0,top:0,waterDepth:NaN}]){const invalid=createHeroSurfaceMotion({supportHeight:()=>0,canOccupy:()=>true,sample:()=>invalidSample}).route({x:0,y:0,z:0},{x:.1,z:0});assert.equal(invalid.reason,'unsupported');assert.equal(invalid.traversal,null)}

const ledgeHeight=x=>x<=0?10:0,ledge=createHeroSurfaceMotion({supportHeight:ledgeHeight,canOccupy:()=>true,terrainSlopeAt:()=>100,sample:x=>({floor:ledgeHeight(x),top:ledgeHeight(x),waterDepth:0,walkable:true})});
const playerLedge=ledge.route({x:0,y:10,z:0},{x:.1,z:0},{ledgePolicy:'free-fall'});assert(playerLedge.moved&&playerLedge.reason==='free_fall'&&playerLedge.position.y===10&&playerLedge.position.x>0&&playerLedge.verticalTransition.fallDistance===10&&playerLedge.traversal===null,'10m player ledge starts physics fall without root-y snap');
const npcLedge=ledge.route({x:0,y:10,z:0},{x:.1,z:0},{actorKind:'pedestrian'});assert(!npcLedge.moved&&npcLedge.reason==='ledge_drop'&&npcLedge.position.y===10&&npcLedge.verticalTransition.kind==='free-fall'&&npcLedge.traversal===null,'NPC blocks at the same ledge instead of teleporting down');
const descentHeight=x=>x<.04?.3:0,descent=createHeroSurfaceMotion({supportHeight:descentHeight,canOccupy:()=>true,terrainSlopeAt:()=>0,sample:x=>({floor:descentHeight(x),top:descentHeight(x),waterDepth:0,walkable:true})}).route({x:0,y:.3,z:0},{x:.1,z:0},{ledgePolicy:'free-fall'});assert(descent.moved&&descent.reason==='clear'&&descent.position.y===0&&descent.descentStep===.3,'small curb descent remains supported');
const downGrade=1.55,downHeight=x=>10-x*downGrade,downhill=createHeroSurfaceMotion({supportHeight:downHeight,canOccupy:()=>true,terrainSlopeAt:()=>downGrade,sample:x=>({floor:downHeight(x),top:downHeight(x),waterDepth:0,walkable:true})});
const playerDown=downhill.route({x:0,y:10,z:0},{x:.5,z:0},{ledgePolicy:'free-fall'}),npcDown=downhill.route({x:0,y:10,z:0},{x:.5,z:0},{actorKind:'pedestrian'});assert(playerDown.moved&&playerDown.ascentMode==='scramble'&&playerDown.speedScale===.48&&Math.abs(playerDown.position.y-9.225)<1e-9);assert.deepEqual(npcDown,playerDown,'continuous steep supported downhill has player/NPC parity');

const pooledMotion=createHeroSurfaceMotion({supportHeight:()=>0,canOccupy:()=>true,sample:flatSample,walkable:()=>true,terrainSlopeAt:()=>0}),pooledWorkspaceA=pooledMotion.createWorkspace(),pooledWorkspaceB=pooledMotion.createWorkspace(),pooledOutA=pooledMotion.createOutput(),pooledOutB=pooledMotion.createOutput();
const pooledA=pooledMotion.routeInto(pooledOutA,{x:0,y:0,z:0},{x:.1,z:.03},{},pooledWorkspaceA),pooledB=pooledMotion.routeInto(pooledOutB,{x:2,y:0,z:1},{x:2.2,z:.9},{},pooledWorkspaceB);assert.equal(pooledA,pooledOutA);assert.equal(pooledB,pooledOutB);assert.deepEqual({moved:pooledA.moved,reason:pooledA.reason,position:{...pooledA.position}},{moved:true,reason:'clear',position:{x:.1,y:0,z:.03}});assert.deepEqual({moved:pooledB.moved,reason:pooledB.reason,position:{...pooledB.position}},{moved:true,reason:'clear',position:{x:2.2,y:0,z:.9}});
pooledMotion.routeInto(pooledOutA,{x:0,y:0,z:0},{x:.2,z:0},{},pooledWorkspaceA);assert.equal(pooledOutB.position.x,2.2,'separate route workspaces are safely interleaved');
const independentA=pooledMotion.route({x:0,y:0,z:0},{x:.1,z:0}),independentB=pooledMotion.route({x:0,y:0,z:0},{x:.2,z:0});independentA.position.x=99;assert.equal(independentB.position.x,.2,'legacy route returns an independent result');

function flatSample(){return {floor:0,top:0,waterDepth:0,walkable:true}}const flatNew=createHeroSurfaceMotion({supportHeight:()=>0,canOccupy:()=>true,sample:flatSample}),flatOld=createSurfaceMotion();
const from={x:0,y:0,z:0},to={x:.04,z:.02},batchSize=1000,batches=120,quantile=(a,q)=>a.slice().sort((x,y)=>x-y)[Math.floor((a.length-1)*q)],measure=fn=>{const samples=[];for(let batch=-20;batch<batches;batch++){const started=performance.now();for(let i=0;i<batchSize;i++)fn();if(batch>=0)samples.push((performance.now()-started)*1000/batchSize)}return {p50:quantile(samples,.5),p95:quantile(samples,.95)}};
const pooledFlatWorkspace=flatNew.createWorkspace(),pooledFlatOut=flatNew.createOutput(),oldUs=measure(()=>flatOld.canMove(from,to,()=>0,0)),newUs=measure(()=>flatNew.routeInto(pooledFlatOut,from,to,{},pooledFlatWorkspace));
console.log('PASS pedestrian surface: curb, walk hill, scramble mountain, cliff, shared NPC semantics, car/wall, scale-4.1 bound, unsupported/NaN rejection');
console.log(JSON.stringify({actualMountain:{start:mountainStart,target:mountainTarget,slope:actualMountainResult.slope,maxRise:actualMountainResult.maxRise,mode:actualMountainResult.ascentMode},flatQueryMicroseconds:{old:oldUs,new:newUs},batches,batchSize}));
