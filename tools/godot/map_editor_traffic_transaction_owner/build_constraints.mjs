import fs from 'node:fs';
import path from 'node:path';
import crypto from 'node:crypto';
import {fileURLToPath} from 'node:url';
import {createCityParkingPlan} from '../../../assets/maps/city_rebuild_v1/city_parking_plan.mjs';
import {createLandscapePlan} from '../../../assets/maps/city_rebuild_v1/landscape_plan.mjs';
import {createExplorationRailwayPlan} from '../../../assets/maps/city_rebuild_v1/exploration_railway_plan.mjs';

const root=path.resolve(path.dirname(fileURLToPath(import.meta.url)),'../../..');
const map=path.join(root,'assets/maps/city_rebuild_v1');
const sha=b=>crypto.createHash('sha256').update(b).digest('hex');
const read=(relative)=>fs.readFileSync(path.join(root,relative));
const pins={
 'godot/mafiozi_walk/data/map_editor/catalog.json':'ae089d73eb61131bc6a38ccc6a2b9b18639f7bd8b65079f7c15c1e1cda9cde6e',
 'godot/mafiozi_walk/data/transport/vehicle_descriptors.v1.json':'99d328bc4a581bc65815498b265ae5eec71a25b831512b15d376e1c0f5ac031a',
 'assets/maps/city_rebuild_v1/buildings_placement.v1.json':'90e0b27196b51fc1f09ccc67d4c5f8374d5c37611576106f34b30559e86ed3ca',
 'assets/maps/city_rebuild_v1/decor_placement.v1.json':'9bdd858e781914df73eba62d47f2df8eec7c9e3057e34f98f9c18134122036c8',
 'assets/maps/city_rebuild_v1/topology_for_placement.json':'11f256f20ea5f8f5387fa4829173e84cf688aa2ba554aa5b6aacdb85301d67b6'
};
function verifyPins(){for(const [file,expected] of Object.entries(pins))if(sha(read(file))!==expected)throw Error(`source drift: ${file}`);}
const box=(x0,z0,x1,z1,pad,kind)=>({minX:Math.min(x0,x1)-pad,maxX:Math.max(x0,x1)+pad,minZ:Math.min(z0,z1)-pad,maxZ:Math.max(z0,z1)+pad,kind});
export function buildConstraints(){
 verifyPins();
 const load=name=>JSON.parse(fs.readFileSync(path.join(map,name)));
 const topology=load('topology_for_placement.json');
 const instances=[...load('buildings_placement.v1.json').instances,...load('decor_placement.v1.json').instances];
 const railPlan=createExplorationRailwayPlan({topology,landscape:createLandscapePlan()});
 const parking=createCityParkingPlan({topology,instances,railPlan});
 const catalog=JSON.parse(read('godot/mafiozi_walk/data/map_editor/catalog.json'));
 for(const file of ['assets/maps/city_rebuild_v1/city_parking_plan.mjs','assets/maps/city_rebuild_v1/landscape_plan.mjs','assets/maps/city_rebuild_v1/exploration_railway_plan.mjs']){
  const receipt=catalog.sources.find(row=>row.path===file);
  if(!receipt||sha(read(file))!==receipt.sha256)throw Error(`planner source drift: ${file}`);
 }
 const descriptors=JSON.parse(read('godot/mafiozi_walk/data/transport/vehicle_descriptors.v1.json'));
 if(parking.lots.length!==39||parking.bays.length!==59)throw Error(`parking planner count drift: ${parking.lots.length}/${parking.bays.length}`);
 const ids=new Set(descriptors.parking.bays.map(b=>b.parking_id));
 if(!parking.bays.some(b=>ids.has(b.id))||!ids.has('parking:REBUILD-VISUAL-old_town_narrow_townhouse_v1-004:bay:0'))throw Error('native parking binding drift');
 const rects=[];
 for(const r of [...parking.surfaceRects,...parking.accessKeepouts])rects.push(box(r.minX,r.minZ,r.maxX,r.maxZ,.45,'parking-surface-or-access'));
 for(const route of parking.walkingRoutes)for(let i=1;i<route.points.length;i++){const a=route.points[i-1],b=route.points[i];rects.push(box(a.x,a.z,b.x,b.z,.8,'parking-walk'));}
 for(const lot of parking.lots)for(const entry of lot.entryPaths)for(let i=1;i<entry.length;i++){const a=entry[i-1],b=entry[i];rects.push(box(a.x,a.z,b.x,b.z,2,'parking-drive'));}
 for(const s of [...parking.signs,...catalog.generatedPlans.roadDressing.signs,...catalog.generatedPlans.roadDressing.signals])rects.push(box(s.x,s.z,s.x,s.z,1,'traffic-furniture'));
 if(rects.some(r=>Object.values(r).some(v=>typeof v==='number'&&!Number.isFinite(v))))throw Error('non-finite traffic constraint');
 return {schema:'mafiozi.map-editor-traffic-constraints/v1',catalog_sha256:pins['godot/mafiozi_walk/data/map_editor/catalog.json'],descriptor_sha256:pins['godot/mafiozi_walk/data/transport/vehicle_descriptors.v1.json'],source_pins:pins,lot_count:parking.lots.length,bay_count:parking.bays.length,rects};
}
if(process.argv[1]&&path.resolve(process.argv[1])===fileURLToPath(import.meta.url)){const c=buildConstraints();console.log(JSON.stringify({rects:c.rects.length,lots:c.lot_count,bays:c.bay_count,sha256:sha(Buffer.from(JSON.stringify(c)))}));}
