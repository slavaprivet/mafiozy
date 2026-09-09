import assert from 'node:assert/strict';
import {readFileSync} from 'node:fs';
import {createLandscapePlan} from './landscape_plan.mjs';
import {createExplorationRailwayPlan} from './exploration_railway_plan.mjs';
import {explorationKeepouts} from './exploration_scene_support.mjs';
import {createSurfaceMotion} from './surface_motion.mjs';

const read=name=>JSON.parse(readFileSync(new URL('./'+name,import.meta.url)));
const topology=read('topology_for_placement.json'),landscape=createLandscapePlan();
const plan=createExplorationRailwayPlan({landscape,topology});
const instances=[...read('buildings_placement.v1.json').instances,...read('decor_placement.v1.json').instances];
const keepouts=explorationKeepouts(instances),M=4.1;
const cell=(mask,x,z)=>mask?.[Math.floor(z/M)]?.[Math.floor(x/M)];
const dry=(x,z)=>landscape.contains(x,z)?!landscape.waterAt(x,z):cell(topology.grid,x,z)!==16||cell(topology.protectedMask,x,z);
const clear=(x,z,r)=>!keepouts.some(b=>x+r>b.minX&&x-r<b.maxX&&z+r>b.minZ&&z-r<b.maxZ);
let urbanMetres=0;
for(let d=0;d<plan.length;d+=.5){
 const p=plan.sample(d);
 if(!landscape.insideCity(p.x,p.z))continue;
 urbanMetres+=.5;
 for(const side of[-1.8,0,1.8]){
  const x=p.x-p.tz*side,z=p.z+p.tx*side;
  assert.ok(dry(x,z),'city train stays over dry ground');
  assert.ok(clear(x,z,.2),'city train preserves existing buildings, entrances and decor');
 }
}
assert.ok(urbanMetres>=120,'a substantial section actually runs inside the city');
const stations=plan.stations.filter(s=>s.x>20&&s.x<718&&s.z>20&&s.z<800);
assert.ok(stations.length,'city station is inside the native city, not only renamed');
const groundHeight=(x,z)=>plan.floorHeight(x,z)??landscape.groundHeight(x,z);
let walked=0;
for(const s of stations){
 const outside=s.width/2+(s.rampLength??24)+2,start={x:s.x+s.nx*outside,z:s.z+s.nz*outside};
 const motion=createSurfaceMotion();motion.reset({...start,y:groundHeight(start.x,start.z)});
 for(let across=outside;across>=0;across-=.1){
  const x=s.x+s.nx*across,z=s.z+s.nz*across;
  assert.ok(dry(x,z),'station access is dry');
  assert.ok(cell(topology.walkableMask,x,z),'existing native walking mask admits station approach');
  assert.ok(clear(x,z,.36),'station approach preserves existing obstacles and entrances');
  const state=motion.update({x,z,dt:1/60,floorHeight:groundHeight});
  assert.equal(state.blocked,false,'actual hero floor solver reaches city platform');
  assert.ok(Math.abs(state.y-groundHeight(x,z))<.06,'no platform teleport or fall');
  walked++;
 }
 let roadNearby=false;
 for(let dx=-12;dx<=12;dx++)for(let dz=-12;dz<=12;dz++)if(cell(topology.roadMask,start.x+dx,start.z+dz))roadNearby=true;
 assert.ok(roadNearby,'city platform approach meets an existing street');
}
console.log(JSON.stringify({status:'PASS',urbanMetres,cityStations:stations.map(s=>s.name),approachSteps:walked,nativeObjectsPreserved:instances.length}));
