import assert from 'node:assert/strict';
import fs from 'node:fs';
import path from 'node:path';
import {pathToFileURL} from 'node:url';
import {createLandscapePlan} from './landscape_plan.mjs';
import {createLandscapeTerrain} from './landscape_terrain.mjs';
import {createSurfaceMotion} from './surface_motion.mjs';
const plan=createLandscapePlan(),second=createLandscapePlan();
assert.deepEqual(plan.grid.heights,second.grid.heights,'deterministic sampler');
const topology=JSON.parse(fs.readFileSync(new URL('./topology_for_placement.json',import.meta.url)));
for(let r=0;r<200;r++)for(let c=0;c<180;c++){const x=(c+.5)*4.1,z=(r+.5)*4.1;assert.equal(plan.groundHeight(x,z),0);assert.equal(plan.contains(x,z),false);assert.equal(plan.waterAt(x,z),null)}
for(const [x,z] of [[738,213],[738,541],[643,820],[738,820]]){assert.equal(plan.insideCity(x,z),false,'maximum edge exceeds native floor indices');assert.equal(plan.contains(x,z),true,'extension owns exact maximum seam');assert.equal(plan.groundHeight(x,z),0,'maximum seam stays level');assert.ok(plan.canWalk(x,z),'seam has no uncategorised blocked line')}
for(const [x,z] of [[0,213],[82,0],[737.999,819.999]]){assert.equal(plan.insideCity(x,z),true,'minimum edge and final cell belong to native masks');assert.equal(plan.contains(x,z),false)}
for(const z of [213,541])assert.ok(plan.canDrive(738,z),'east road admits exact native/extension seam');
for(const [x,z] of [[0,213],[738,213],[738,541],[82,0],[459,0],[574,0]]){assert.equal(plan.groundHeight(x,z),0);const cx=Math.min(179,Math.max(0,Math.floor(x/4.1))),cz=Math.min(199,Math.max(0,Math.floor(z/4.1)));assert.equal(Boolean(topology.roadMask[cz][cx]),true,'native road access');for(const [dx,dz] of [[-.01,0],[.01,0],[0,-.01],[0,.01]])assert.ok(Math.abs(plan.groundHeight(x+dx,z+dz))<.02,'seam continuity')}
let walked=0,maxDriveSlope=0,maxWalkSlope=0;
for(const path of plan.paths){const motion=createSurfaceMotion();const start=path.points[0];motion.reset({...start,y:plan.groundHeight(start.x,start.z)});for(let i=1;i<path.points.length;i++){const a=path.points[i-1],b=path.points[i],distance=Math.hypot(b.x-a.x,b.z-a.z),n=Math.ceil(distance/.15);for(let k=1;k<=n;k++){const x=a.x+(b.x-a.x)*k/n,z=a.z+(b.z-a.z)*k/n;if(!plan.contains(x,z))continue;assert.equal(plan.waterAt(x,z),null,path.id+' dry path');assert.ok(plan.canWalk(x,z),path.id+' traversable');const slope=plan.slopeAt(x,z);maxWalkSlope=Math.max(maxWalkSlope,slope);if(path.drive){maxDriveSlope=Math.max(maxDriveSlope,slope);assert.ok(plan.canDrive(x,z),path.id+' driveable center');const dx=(b.x-a.x)/distance,dz=(b.z-a.z)/distance;for(const side of [-1.25,1.25])assert.ok(!plan.contains(x-dz*side,z+dx*side)||plan.canDrive(x-dz*side,z+dx*side),path.id+' vehicle width')}const frame=motion.update({x,z,dt:1/60,floorHeight:plan.groundHeight});assert.equal(frame.blocked,false,path.id+' actual surface motion');assert.ok(Math.abs(frame.y-plan.groundHeight(x,z))<.06,'no step/fall on path');walked++}}}
assert.ok(maxDriveSlope<.25);assert.ok(maxWalkSlope<.65);
for(const lake of plan.lakes){const water=plan.waterAt(lake.x,lake.z);assert.ok(water.depth>5);assert.equal(water.floor,plan.groundHeight(lake.x,lake.z));assert.equal(plan.canDrive(lake.x,lake.z),false);assert.equal(plan.canWalk(lake.x,lake.z),true)}
for(const p of plan.landmarks){assert.ok(plan.canWalk(p.x,p.z));assert.equal(plan.waterAt(p.x,p.z),null)}
assert.ok(plan.landmarks.find(p=>p.id==='ridge-summit').y>45);
const vendor=process.env.THREE_VENDOR||'D:/codex_release/artist13_hero_first_DEV_20260907/demo/vendor';
const THREE=await import(pathToFileURL(path.join(vendor,'build/three.module.js')).href);
const terrain=createLandscapeTerrain({THREE,plan});terrain.object.updateMatrixWorld(true);
const ground=terrain.object.children.filter(o=>o.userData.landscapeGround),ray=new THREE.Raycaster();let checked=0;
for(let j=7;j<plan.grid.zs.length-2;j+=11)for(let i=5;i<plan.grid.xs.length-2;i+=13){const x=plan.grid.xs[i]+1.1,z=plan.grid.zs[j]+.73;if(!plan.contains(x,z))continue;ray.set(new THREE.Vector3(x,100,z),new THREE.Vector3(0,-1,0));const hit=ray.intersectObjects(ground)[0];assert.ok(hit,'ground mesh exists');assert.ok(Math.abs(hit.point.y-plan.groundHeight(x,z))<1e-5,'ray triangle matches height sampler');checked++}
for(const p of plan.landmarks){ray.set(new THREE.Vector3(p.x,100,p.z),new THREE.Vector3(0,-1,0));const hit=ray.intersectObjects(ground)[0];assert.ok(hit);assert.ok(Math.abs(hit.point.y-p.y)<1e-5)}
for(const mesh of ground){const pos=mesh.geometry.attributes.position,idx=mesh.geometry.index;for(let i=0;i<idx.count;i+=3){const x=(pos.getX(idx.getX(i))+pos.getX(idx.getX(i+1))+pos.getX(idx.getX(i+2)))/3,z=(pos.getZ(idx.getX(i))+pos.getZ(idx.getX(i+1))+pos.getZ(idx.getX(i+2)))/3;assert.equal(plan.insideCity(x,z),false,'no new terrain overlaps protected city')}}
assert.ok(terrain.report.triangleCount<160000,'bounded landscape geometry');assert.ok(terrain.report.chunkCount<80,'bounded draw count');
terrain.dispose();
console.log(JSON.stringify({status:'PASS',protectedCityCells:36000,walkedSamples:walked,maxDriveSlope,maxWalkSlope,rayChecks:checked,...terrain.report},null,2));
