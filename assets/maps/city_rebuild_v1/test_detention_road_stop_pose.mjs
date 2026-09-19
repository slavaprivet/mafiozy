import test from 'node:test';
import assert from 'node:assert/strict';
import fs from 'node:fs';
import {getDetentionRoadStopPose} from './detention_road_stop_pose.mjs';
const read=name=>JSON.parse(fs.readFileSync(new URL(name,import.meta.url),'utf8'));
test('authored stops face with near-side traffic and keep existing pedestrian handoffs on the passenger side',()=>{
 const sites=read('./detention_native_sites.v1.json').instances,registry=read('./detention_destinations.v1.json').destinations;
 const expected={southside:{x:639.62,z:432,yaw:-Math.PI/2},iron_harbor:{x:270.58,z:625.65,yaw:Math.PI/2},chinatown:{x:18.95,z:360.82,yaw:Math.PI}};
 for(const site of sites){const p=getDetentionRoadStopPose(site),e=expected[site.districtId],d=registry.find(d=>d.instanceId===site.id);
  for(const key of ['x','z','yaw'])assert.ok(Math.abs(p[key]-e[key])<1e-8,site.id+' '+key);
  assert.ok(Math.abs(d.stop.r*4.1-p.z)<3e-8&&Math.abs(d.stop.c*4.1-p.x)<3e-8);
  assert.ok(Math.abs(Math.sin(Math.PI/2-d.stop.angle-p.yaw))<1e-8);
  // Forward +Z has the passenger side at local -X (left-hand driver +X).
  const rightDistance=-(d.handoff.c*4.1-p.x)*Math.cos(p.yaw)+(d.handoff.r*4.1-p.z)*Math.sin(p.yaw);
  assert.ok(rightDistance>2.3&&rightDistance<2.6,site.id+' passenger-side handoff');
 }
});
