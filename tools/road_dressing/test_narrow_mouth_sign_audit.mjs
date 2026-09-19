import test from 'node:test';
import assert from 'node:assert/strict';
import fs from 'node:fs';
import {createNarrowMouthAuditContext,auditNarrowMouthSign} from './narrow_mouth_sign_audit.mjs';
import {createLandscapePlan} from '../../assets/maps/city_rebuild_v1/landscape_plan.mjs';
import {createExplorationRailwayPlan} from '../../assets/maps/city_rebuild_v1/exploration_railway_plan.mjs';

const snapshot=JSON.parse(fs.readFileSync(new URL('../../outputs/roads_logical_20260912/integration_candidate_snapshot.json',import.meta.url))),topology=JSON.parse(fs.readFileSync(new URL('../../assets/maps/city_rebuild_v1/topology_for_placement.json',import.meta.url))),railPlan=createExplorationRailwayPlan({topology,landscape:createLandscapePlan()}),context=createNarrowMouthAuditContext(snapshot,topology,railPlan),pole=snapshot.roadPlan.signs.find(s=>s.controlPlacement?.mode==='verified_narrow_mouth_verge'),passage=context.passages.find(p=>p.id===pole.passageId),mouth=passage.points[0],out={x:-Math.sin(mouth.yaw),z:-Math.cos(mouth.yaw)};
const reject=(p,c,reason)=>{const result=auditNarrowMouthSign(p,c);assert.equal(result.valid,false);assert.equal(result.reason,reason);};
test('actual final-worker left post validates geometry without the unrelated junction-distance field',()=>{
 assert.equal(pole.controlPlacement.distanceFromJunctionM,undefined);const result=auditNarrowMouthSign(pole,context);assert.equal(result.valid,true);assert.equal(result.side,'left');assert(Math.abs(result.advanceM)<1e-7);assert(result.actualCurbSetbackM>.2&&result.actualCurbSetbackM<.3);
});
test('spoofed identity, facing and a position at another mouth are rejected despite valid mode flags',()=>{
 reject({...pole,passageId:'another-passage'},context,'unknown_passage_identity');
 reject({...pole,allowedDirection:-pole.allowedDirection},context,'wrong_approach_direction');
 reject({...pole,yaw:pole.yaw+Math.PI},context,'wrong_facing');
 reject({...pole,x:pole.x+out.x*3,z:pole.z+out.z*3,controlPlacement:{...pole.controlPlacement,advanceM:3}},context,'outside_same_mouth');
 reject({...pole,controlPlacement:{...pole.controlPlacement,lateralM:1}},context,'inconsistent_placement_metadata');
});
test('the complete 0.2 metre post cannot graze the road while its centre remains dry',()=>{
 const toward={x:out.z,z:-out.x},shift=.1,p={...pole,x:pole.x+toward.x*shift,z:pole.z+toward.z*shift,controlPlacement:{...pole.controlPlacement,lateralM:pole.controlPlacement.lateralM-shift,curbSetbackM:pole.controlPlacement.curbSetbackM-shift}};
 reject(p,context,'post_footprint_off_dry_land');
});
test('a water gap between this mouth and the unchanged dry post cannot be skipped',()=>{
 const t=pole.controlPlacement.lateralM/2,x=mouth.x-out.z*t,z=mouth.z+out.x*t,r=Math.floor(z/4.1),c=Math.floor(x/4.1),changed={...topology,grid:topology.grid.map(row=>[...row]),roadMask:topology.roadMask.map(row=>[...row])};changed.grid[r][c]=7;changed.roadMask[r][c]=0;
 reject(pole,{...context,topology:changed},'not_first_continuous_dry_shoulder');
});
test('building/access reservations, pedestrian landings and the actual physical collider are checked',()=>{
 reject(pole,{...context,reserved:[...context.reserved,{minX:pole.x-.1,maxX:pole.x+.1,minZ:pole.z-.1,maxZ:pole.z+.1}]},'reserved_building_or_access');
 reject(pole,{...context,landings:[...context.landings,{x:pole.x+.5,z:pole.z}]},'crossing_landing');
 reject(pole,{...context,poles:[...context.poles,{id:'another-post',x:pole.x+1,z:pole.z}]},'another_post');
 reject(pole,{...context,colliders:context.colliders.filter(b=>b.id!==pole.id)},'missing_or_displaced_physical_post');
 const shifted=context.colliders.map(b=>b.id!==pole.id?b:{...b,polygonCR:b.polygonCR.map(([c,r])=>[c+.1,r])});reject(pole,{...context,colliders:shifted},'missing_or_displaced_physical_post');
 reject(pole,{...context,railPlan:{blocksPlacement:()=>true}},'rail_keepout');
});
