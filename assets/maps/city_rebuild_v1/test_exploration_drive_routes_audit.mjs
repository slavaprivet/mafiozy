// Read-only diagnostic: reports real path traversal through the production car world.
import {readFileSync} from 'node:fs';
import {createLandscapePlan} from './landscape_plan.mjs';
import {createExplorationVehicleWorld} from './exploration_vehicle_support.mjs';
import {carFits} from './car_drive.mjs';
import {planExplorationDecor} from './exploration_decor_plan.mjs';
const topology=JSON.parse(readFileSync(new URL('./topology_for_placement.json',import.meta.url)));
const plan=createLandscapePlan(),world=createExplorationVehicleWorld({topology,bodies:[],terrain:plan}),continuous=(x,z)=>world(x,z);
const reports=[];
for(const path of plan.paths.filter(p=>p.drive)){
  const report={id:path.id,width:path.width,points:path.points.length,pointFails:0,samples:0,fails:0,rasterOnlyFails:0,continuousFails:0,examples:[]};
  function inspect(x,z,yaw,isPoint=false){const ok=carFits(x,z,yaw,world),fine=carFits(x,z,yaw,continuous);if(isPoint){if(!ok)report.pointFails++;return}report.samples++;if(!ok){report.fails++;if(fine)report.rasterOnlyFails++;if(report.examples.length<4)report.examples.push({x:+x.toFixed(3),z:+z.toFixed(3),yaw:+yaw.toFixed(3),centerAllowed:world(x,z),continuousFits:fine,contact:world.contactAt(x,z,yaw)})}if(!fine)report.continuousFails++}
  for(let i=0;i<path.points.length;i++){const a=path.points[Math.max(0,i-1)],b=path.points[Math.min(path.points.length-1,i+1)],p=path.points[i];inspect(p.x,p.z,Math.atan2(b.x-a.x,b.z-a.z),true)}
  for(let i=1;i<path.points.length;i++){const a=path.points[i-1],b=path.points[i],yaw=Math.atan2(b.x-a.x,b.z-a.z),n=Math.ceil(Math.hypot(b.x-a.x,b.z-a.z)/.5);for(let k=0;k<n;k++)inspect(a.x+(b.x-a.x)*k/n,a.z+(b.z-a.z)*k/n,yaw)}
  reports.push(report);
}
const buildings=JSON.parse(readFileSync(new URL('./buildings_placement.v1.json',import.meta.url))).instances,existingDecor=JSON.parse(readFileSync(new URL('./decor_placement.v1.json',import.meta.url))).instances;
const decor=planExplorationDecor({terrain:plan,topology,buildings,existingDecor}),types={};for(const f of decor.mapFeatures)types[f.kind]=(types[f.kind]||0)+1;
console.log(JSON.stringify({routes:reports,decorMap:{features:decor.mapFeatures.length,kinds:types,first:decor.mapFeatures[0],vignettes:decor.vignettes.slice(0,3)},terrainTypes:[...new Set(plan.mapFeatures.map(f=>f.type))]},null,2));
