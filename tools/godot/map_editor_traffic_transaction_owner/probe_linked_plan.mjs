import fs from 'node:fs';
import path from 'node:path';
import crypto from 'node:crypto';
import {fileURLToPath} from 'node:url';
import {createCityParkingPlan} from '../../../assets/maps/city_rebuild_v1/city_parking_plan.mjs';
import {createLandscapePlan} from '../../../assets/maps/city_rebuild_v1/landscape_plan.mjs';
import {createExplorationRailwayPlan} from '../../../assets/maps/city_rebuild_v1/exploration_railway_plan.mjs';
const root=path.resolve(path.dirname(fileURLToPath(import.meta.url)),'../../..');
const map=path.join(root,'assets/maps/city_rebuild_v1');
const load=name=>JSON.parse(fs.readFileSync(path.join(map,name)));
const topology=load('topology_for_placement.json');
const buildings=load('buildings_placement.v1.json').instances;
const decor=load('decor_placement.v1.json').instances;
const railway=createExplorationRailwayPlan({topology,landscape:createLandscapePlan()});
const target='REBUILD-VISUAL-old_town_narrow_townhouse_v1-004';
const shiftRect=(r,dc,dr)=>{r.minC+=dc;r.maxC+=dc;r.minR+=dr;r.maxR+=dr;};
function shifted(dx,dz){const rows=structuredClone(buildings),row=rows.find(r=>r.id===target),dc=dx/4.1,dr=dz/4.1;row.transform.positionM[0]+=dx;row.transform.positionM[2]+=dz;for(const key of ['footprint','clearance','entryCorridor'])shiftRect(row[key],dc,dr);for(const key of ['anchorRC','roadProbeRC']){row.entry[key].c+=dc;row.entry[key].r+=dr;}for(const body of row.collision.worldBodies){body.polygonCR=body.polygonCR.map(([c,r])=>[c+dc,r+dr]);shiftRect(body.rectangleRC,dc,dr);}return rows;}
const base=createCityParkingPlan({topology,instances:[...buildings,...decor],railPlan:railway});
const hash=value=>crypto.createHash('sha256').update(JSON.stringify(value)).digest('hex').slice(0,16);
const summarise=p=>{const lot=p.lots.find(l=>l.buildingId===target),bays=p.bays.filter(b=>b.lotId===lot?.id),signs=p.signs.filter(s=>s.lotId===lot?.id);return {lots:p.lots.length,bays:p.bays.length,lot:lot?{id:lot.id,origin:lot.origin,rect:lot.rect,served:lot.servedBuildingIds}:null,baysForTarget:bays.map(b=>({id:b.id,x:b.x,z:b.z,yaw:b.yaw})),signIds:signs.map(s=>s.id),covered:p.coverage.find(c=>c.buildingId===target)};};
console.log(JSON.stringify({offset:[0,0],result:summarise(base)}));
for(const [dx,dz] of [[.25,0],[0,.25],[1,0],[0,1],[2,0],[0,2]]){const changed=createCityParkingPlan({topology,instances:[...shifted(dx,dz),...decor],railPlan:railway});console.log(JSON.stringify({offset:[dx,dz],result:summarise(changed),same:{lots:hash(changed.lots)===hash(base.lots),bays:hash(changed.bays)===hash(base.bays),signs:hash(changed.signs)===hash(base.signs),colliders:hash(changed.colliders)===hash(base.colliders),surfaces:hash(changed.surfaceRects)===hash(base.surfaceRects),support:hash(changed.roadSupportRects)===hash(base.roadSupportRects),access:hash(changed.accessKeepouts)===hash(base.accessKeepouts),walkingRoutes:hash(changed.walkingRoutes)===hash(base.walkingRoutes)}}));}
