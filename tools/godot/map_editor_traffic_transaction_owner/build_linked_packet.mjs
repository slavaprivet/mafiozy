import fs from 'node:fs';
import path from 'node:path';
import crypto from 'node:crypto';
import {fileURLToPath} from 'node:url';
import {createCityParkingPlan} from '../../../assets/maps/city_rebuild_v1/city_parking_plan.mjs';
import {createLandscapePlan} from '../../../assets/maps/city_rebuild_v1/landscape_plan.mjs';
import {createExplorationRailwayPlan} from '../../../assets/maps/city_rebuild_v1/exploration_railway_plan.mjs';
import {buildConstraints} from './build_constraints.mjs';

const root=path.resolve(path.dirname(fileURLToPath(import.meta.url)),'../../..');
const dir=path.join(root,'assets/maps/city_rebuild_v1');
const load=n=>JSON.parse(fs.readFileSync(path.join(dir,n)));
const hash=v=>crypto.createHash('sha256').update(typeof v==='string'?v:JSON.stringify(v)).digest('hex');
const target='REBUILD-VISUAL-old_town_narrow_townhouse_v1-004';
const delta=[.25,0,0];
const shiftRect=(r,dc,dr)=>{r.minC+=dc;r.maxC+=dc;r.minR+=dr;r.maxR+=dr;};
function shifted(rows){
 const copy=structuredClone(rows),row=copy.find(r=>r.id===target),dc=delta[0]/4.1,dr=delta[2]/4.1;
 row.transform.positionM[0]+=delta[0];row.transform.positionM[2]+=delta[2];
 for(const key of ['footprint','clearance','entryCorridor'])shiftRect(row[key],dc,dr);
 for(const key of ['anchorRC','roadProbeRC']){row.entry[key].c+=dc;row.entry[key].r+=dr;}
 for(const body of row.collision.worldBodies){body.polygonCR=body.polygonCR.map(([c,r])=>[c+dc,r+dr]);shiftRect(body.rectangleRC,dc,dr);}
 return copy;
}
export function buildLinkedPacket(){
 const constraints=buildConstraints();
 const topology=load('topology_for_placement.json'),buildings=load('buildings_placement.v1.json').instances,decor=load('decor_placement.v1.json').instances;
 const railPlan=createExplorationRailwayPlan({topology,landscape:createLandscapePlan()});
 const before=createCityParkingPlan({topology,instances:[...buildings,...decor],railPlan});
 const after=createCityParkingPlan({topology,instances:[...shifted(buildings),...decor],railPlan});
 const stationary=['bays','signs','colliders','surfaceRects','accessKeepouts','roadSupportRects'];
 for(const key of stationary)if(hash(before[key])!==hash(after[key]))throw Error(`linked parked-car geometry changed: ${key}`);
 const lotIds=p=>p.lots.map(l=>l.id),bayIds=p=>p.bays.map(b=>b.id),signIds=p=>p.signs.map(s=>s.id);
 if(hash(lotIds(before))!==hash(lotIds(after))||hash(bayIds(before))!==hash(bayIds(after))||hash(signIds(before))!==hash(signIds(after)))throw Error('source IDs changed');
 const sourceBay=before.bays.find(b=>b.id==='parking:'+target+':bay:0');
 if(!sourceBay||!after.bays.some(b=>b.id===sourceBay.id))throw Error('parked car bay missing');
 const descriptor=JSON.parse(fs.readFileSync(path.join(root,'godot/mafiozi_walk/data/transport/vehicle_descriptors.v1.json')));
 const nativeBay=descriptor.parking.bays.find(b=>b.parking_id===sourceBay.id);
 if(!nativeBay||Math.abs(nativeBay.position_m.x-sourceBay.x)>1e-5||Math.abs(nativeBay.position_m.z-sourceBay.z)>1e-5)throw Error('native parked bay position drift');
 // Native descriptor uses vehicle-forward convention (0 rad here); the
 // source parking plan records road-facing orientation (PI here). Preserve
 // both explicitly instead of rotating the live car to an assumed frame.
 if(Math.abs(nativeBay.yaw_rad)>1e-5||Math.abs(sourceBay.yaw-Math.PI)>1e-5)throw Error('known yaw-frame relation drift');
 const baseline={lots:before.lots,walkingRoutes:before.walkingRoutes,coverage:before.coverage};
 const revised={lots:after.lots,walkingRoutes:after.walkingRoutes,coverage:after.coverage};
 if(hash(baseline)===hash(revised))throw Error('route metadata did not change');
 return {schema:'mafiozi.map-editor-linked-parking-stationary-bay/v1',source_id:target,delta_m:delta,catalog_sha256:constraints.catalog_sha256,descriptor_sha256:constraints.descriptor_sha256,source_pins:constraints.source_pins,lot_ids:lotIds(before),bay_ids:bayIds(before),sign_ids:signIds(before),stationary_sha256:Object.fromEntries(stationary.map(k=>[k,hash(before[k])])),parked_bay:{parking_id:sourceBay.id,position_m:{x:sourceBay.x,y:0,z:sourceBay.z},source_yaw_rad:sourceBay.yaw,native_yaw_rad:nativeBay.yaw_rad},baseline_sha256:hash(baseline),revised_sha256:hash(revised),baseline,revised};
}
if(process.argv[1]&&path.resolve(process.argv[1])===fileURLToPath(import.meta.url)){const p=buildLinkedPacket();console.log(JSON.stringify({bytes:Buffer.byteLength(JSON.stringify(p)),sha256:hash(p),baseline:p.baseline_sha256,revised:p.revised_sha256,ids:{lots:p.lot_ids.length,bays:p.bay_ids.length,signs:p.sign_ids.length}}));}
