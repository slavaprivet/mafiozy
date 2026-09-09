import assert from 'node:assert/strict';
import fs from 'node:fs';
import {createHash} from 'node:crypto';
import {registerHooks} from 'node:module';
import {pathToFileURL} from 'node:url';
import {createLandscapePlan} from './landscape_plan.mjs';
import {planExplorationDecor} from './exploration_decor_plan.mjs';
import {createExplorationDecor} from './exploration_decor.mjs';
import {createExplorationRailwayPlan} from './exploration_railway_plan.mjs';
import {explorationKeepouts} from './exploration_scene_support.mjs';
import {circleFits,movePedestrian} from './walk_motion.mjs';
import {createWalkCollisionIndex} from './walk_collision_index.mjs';

const read=name=>JSON.parse(fs.readFileSync(new URL(name,import.meta.url)));
const topology=read('topology_for_placement.json'),terrain=createLandscapePlan();
const instances=[...read('buildings_placement.v1.json').instances,...read('decor_placement.v1.json').instances];
const plan=planExplorationDecor({terrain,topology,keepouts:explorationKeepouts(instances),railPlan:createExplorationRailwayPlan({landscape:terrain,topology})});
const furniture=plan.objects.filter(o=>['bench','picnic'].includes(o.kind));
const bodies=new Map(plan.colliders.map(b=>[b.id,b]));
const vendor=process.env.THREE_VENDOR||'D:/codex_release/artist13_hero_first_DEV_20260907/demo/vendor/';
registerHooks({resolve(s,c,next){return next(s==='three'?pathToFileURL(vendor+'build/three.module.js').href:s,c)}});
const THREE=await import(pathToFileURL(vendor+'build/three.module.js'));
const {RoundedBoxGeometry}=await import('../../../tools/vehicle_fleet_qa/RoundedBoxGeometry.mjs');
const renderer=createExplorationDecor({THREE,RoundedBoxGeometry,plan:{...plan,objects:furniture}});
const matrix=new THREE.Matrix4(),vertex=new THREE.Vector3(),bounds=new Map(furniture.map(o=>[o.id,{object:o,minX:Infinity,maxX:-Infinity,minZ:Infinity,maxZ:-Infinity}]));
let vertices=0;
for(const chunk of renderer.object.children)for(const mesh of chunk.children)for(let i=0;i<mesh.count;i++){
  const b=bounds.get(mesh.userData.objectIds[i]),o=b.object,c=Math.cos(o.yaw),s=Math.sin(o.yaw);
  mesh.getMatrixAt(i,matrix);
  const position=mesh.geometry.attributes.position;
  for(let j=0;j<position.count;j++){
    vertex.fromBufferAttribute(position,j).applyMatrix4(matrix);
    const dx=(vertex.x-o.x)/o.scale,dz=(vertex.z-o.z)/o.scale,x=dx*c-dz*s,z=dx*s+dz*c;
    assert.ok(inside(vertex.x/4.1,vertex.z/4.1,bodies.get(o.id).polygonCR),o.id+' actual visible vertex inside transformed physical collider '+JSON.stringify({x,z}));
    b.minX=Math.min(b.minX,x);b.maxX=Math.max(b.maxX,x);b.minZ=Math.min(b.minZ,z);b.maxZ=Math.max(b.maxZ,z);vertices++;
  }
}
function inside(c,r,p){let hit=false;for(let i=0,j=p.length-1;i<p.length;j=i++){const a=p[i],b=p[j];if((a[1]>r)!==(b[1]>r)&&c<(b[0]-a[0])*(r-a[1])/(b[1]-a[1])+a[0])hit=!hit;}return hit;}
const world=(o,x,z)=>({x:o.x+(x*Math.cos(o.yaw)+z*Math.sin(o.yaw))*o.scale,z:o.z+(-x*Math.sin(o.yaw)+z*Math.cos(o.yaw))*o.scale});
const legacy=({placementKeepoutPolygonCR,...b})=>({...b,polygonCR:placementKeepoutPolygonCR||b.polygonCR});
assert.ok(furniture.length>50,'exercise real city and countryside furniture');
let paths=0;
for(const o of furniture){
  const b=bodies.get(o.id),bb=bounds.get(o.id),half=o.kind==='bench'?[1.3,.39]:[1.35,.99];
  assert.equal(b.polygonCR.length,4,o.id+' has an oriented furniture footprint');
  assert.ok(bb.minX>=-half[0]-.0001&&bb.maxX<=half[0]+.0001&&bb.minZ>=-half[1]-.0001&&bb.maxZ<=half[1]+.0001,o.id+' all actual visible vertices fit collider');
  const index=createWalkCollisionIndex([[b]]),allows=(x,z)=>!index(x/4.1,z/4.1).some(c=>inside(x/4.1,z/4.1,c.polygonCR));
  const oldAllows=(x,z)=>!inside(x/4.1,z/4.1,b.placementKeepoutPolygonCR);
  for(const side of[-1,1]){
    const front=(o.kind==='bench'?1.1:1.45)*side,p=world(o,0,front);
    assert.ok((Math.abs(front)-Math.max(Math.abs(bb.minZ),Math.abs(bb.maxZ)))*o.scale>.36,o.id+' entire hero footprint clear of visible geometry');
    assert.equal(circleFits(p.x,p.z,oldAllows),false,o.id+' reproduces old invisible obstacle');
    assert.equal(circleFits(p.x,p.z,allows),true,o.id+' clear beside actual furniture');
    const start=world(o,-.7,front),end=world(o,.7,front),walk=movePedestrian(start,{x:end.x-start.x,z:end.z-start.z},allows);
    assert.ok(Math.hypot(walk.x-end.x,walk.z-end.z)<1e-6,o.id+' movement follows clear edge');paths++;
  }
  const solid=world(o,0,0);assert.equal(circleFits(solid.x,solid.z,allows),false,o.id+' real furniture still solid');
  const crossingStart=world(o,0,2.5),crossingEnd=world(o,0,-2.5),walk=movePedestrian(crossingStart,{x:crossingEnd.x-crossingStart.x,z:crossingEnd.z-crossingStart.z},allows);
  assert.ok(Math.hypot(walk.x-crossingEnd.x,walk.z-crossingEnd.z)>.2,o.id+' cannot walk straight through real solid furniture');
}
assert.deepEqual(explorationKeepouts([{collision:{worldBodies:plan.colliders}}]),explorationKeepouts([{collision:{worldBodies:plan.colliders.map(legacy)}}]),'road dressing placement envelopes remain exactly unchanged');
console.log(JSON.stringify({status:'PASS',objects:plan.objects.length,objectsSHA256:createHash('sha256').update(JSON.stringify(plan.objects)).digest('hex'),benches:furniture.filter(o=>o.kind==='bench').length,picnics:furniture.filter(o=>o.kind==='picnic').length,vertices,clearPaths:paths,samples:furniture.slice(0,3).map(o=>({id:o.id,x:o.x,z:o.z,yaw:o.yaw,visibleBounds:bounds.get(o.id)}))}));
renderer.dispose();
