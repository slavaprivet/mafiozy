import assert from 'node:assert/strict';
import fs from 'node:fs';
import {pathToFileURL} from 'node:url';
import {registerHooks} from 'node:module';
import {createLandscapePlan} from './landscape_plan.mjs';
import {planExplorationDecor,EXPLORATION_DECOR_TYPES,TREE_SPECIES,TREE_SIZE_CLASSES} from './exploration_decor_plan.mjs';
import {createExplorationDecor} from './exploration_decor.mjs';
import {createExplorationRailwayPlan} from './exploration_railway_plan.mjs';
const read=n=>JSON.parse(fs.readFileSync(new URL(n,import.meta.url),'utf8'));
const terrain=createLandscapePlan(),topology=read('./topology_for_placement.json'),buildings=read('./buildings_placement.v1.json').instances,existingDecor=read('./decor_placement.v1.json').instances;
const source={terrain,topology,buildings,existingDecor},before=JSON.stringify({topology,buildings,existingDecor}),plan=planExplorationDecor(source),m=4.1;
let tests=0;function test(name,fn){fn();tests++;console.log('PASS',name);}
test('real city ledger remains immutable and generated plan deterministic',()=>{assert.equal(JSON.stringify({topology,buildings,existingDecor}),before);assert.deepEqual(plan,planExplorationDecor(source));});
test('all five forests populated, city furniture varied, every object on map',()=>{
  assert.ok(plan.stats.trees>=1900);assert.equal(plan.stats.cityVignettes,18);assert.ok(plan.stats.ruralVignettes>=15);
  for(const f of terrain.forestZones)assert.ok(plan.objects.filter(p=>p.zone===f.id&&TREE_SPECIES.includes(p.kind)).length>=250,f.id);
  for(const kind of Object.keys(EXPLORATION_DECOR_TYPES))assert.ok(plan.objects.some(p=>p.kind===kind),kind);
  assert.equal(plan.mapFeatures.length,plan.objects.length);assert.equal(new Set(plan.mapFeatures.map(p=>p.id)).size,plan.objects.length);
});
const overlap=(o,b)=>Math.hypot(Math.max(b.minX-o.x,0,o.x-b.maxX),Math.max(b.minZ-o.z,0,o.z-b.maxZ))<o.radius;
const polygonRect=p=>({minX:Math.min(...p.map(v=>v[0]))*m,maxX:Math.max(...p.map(v=>v[0]))*m,minZ:Math.min(...p.map(v=>v[1]))*m,maxZ:Math.max(...p.map(v=>v[1]))*m});
test('full ground/canopy clearances avoid every road, water tile and police cell',()=>{
  for(const o of plan.objects.filter(o=>o.zone==='city')){
    for(let r=Math.floor((o.z-o.radius)/m);r<=Math.floor((o.z+o.radius)/m);r++)for(let c=Math.floor((o.x-o.radius)/m);c<=Math.floor((o.x+o.radius)/m);c++){
      if(!overlap(o,{minX:c*m,maxX:(c+1)*m,minZ:r*m,maxZ:(r+1)*m}))continue;
      assert.ok([8,9,14].includes(topology.grid[r]?.[c]),o.id+' native tile');assert.ok(!topology.policeMask?.[r]?.[c],o.id+' police');
    }
  }
});
test('actual building entries, complete exteriors, existing decor and red bridge stay clear',()=>{
  const rects=[];for(const b of buildings)for(const r of[b.clearance,b.footprint,b.entryCorridor])if(r)rects.push({minX:r.minC*m,maxX:r.maxC*m,minZ:r.minR*m,maxZ:r.maxR*m});
  for(const b of existingDecor){if(b.clearancePolygonCR)rects.push(polygonRect(b.clearancePolygonCR));for(const c of b.collision?.worldBodies||[])rects.push(polygonRect(c.polygonCR));}
  rects.push({minX:78.25*m,maxX:101.75*m,minZ:47*m,maxZ:57*m});
  for(const o of plan.objects)for(const r of rects)assert.ok(!overlap(o,r),o.id+' overlaps host ledger');
});
test('forest and destination clearance rings remain dry, traversable and off trails',()=>{
  for(const o of plan.objects.filter(o=>o.zone!=='city')){
    assert.equal(o.y,terrain.groundHeight(o.x,o.z));assert.ok(terrain.canWalk(o.x,o.z),o.id+' on steep inaccessible slope');
    for(let i=0;i<24;i++){const a=i*Math.PI/12,x=o.x+Math.cos(a)*o.radius,z=o.z+Math.sin(a)*o.radius;
      assert.ok(terrain.contains(x,z),o.id+' beyond bounds');assert.ok(!terrain.waterAt(x,z),o.id+' wet');const p=terrain.pathAt(x,z);assert.ok(p.distance>=(p.path?.width??4)/2+1.95,o.id+' blocks path');
    }
  }
});
test('all objects maintain visible walking gaps; no duplicated overlapping scatter',()=>{for(let i=0;i<plan.objects.length;i++)for(let j=i+1;j<plan.objects.length;j++){const a=plan.objects[i],b=plan.objects[j];assert.ok(Math.hypot(a.x-b.x,a.z-b.z)>=a.radius+b.radius+.6-1e-6,a.id+' / '+b.id);}});
test('trees collide only with authored trunk, never with canopy envelope',()=>{
  for(const o of plan.objects.filter(o=>TREE_SPECIES.includes(o.kind))){const c=plan.colliders.find(c=>c.id===o.id);assert.ok(c);assert.ok(c.groundRadius<o.radius*.3);assert.equal(c.minYM,o.y);assert.ok(c.maxYM>c.minYM);}
});
test('actual railway embankment, station and approach exclusion stays clear with giant trees',()=>{
  const railPlan=createExplorationRailwayPlan({landscape:terrain}),withRail=planExplorationDecor({...source,railPlan});
  assert.ok(withRail.stats.treeSizeCounts.giant>=15);
  for(const o of withRail.objects){
    assert.ok(!railPlan.blocksPlacement(o.x,o.z,o.radius+.8),o.id+' occupies actual rail');
    // Independent unbucketed distance catches a broad giant crown missed by narrow rail indexing.
    let nearest=Infinity;for(let i=0;i<railPlan.points.length;i++){const a=railPlan.points[i],b=railPlan.points[(i+1)%railPlan.points.length],dx=b.x-a.x,dz=b.z-a.z,t=Math.max(0,Math.min(1,((o.x-a.x)*dx+(o.z-a.z)*dz)/(dx*dx+dz*dz)));nearest=Math.min(nearest,Math.hypot(o.x-a.x-dx*t,o.z-a.z-dz*t));}
    assert.ok(nearest>=10+o.radius+.79,o.id+' full canopy intersects railway bank');
  }
});
test('four authored height classes and seven species; willows stay by lake shores',()=>{
  assert.equal(TREE_SPECIES.length,7);assert.ok(plan.stats.treeSizeCounts.giant>=15&&plan.stats.treeSizeCounts.giant<=30);
  assert.ok(plan.stats.treeSizeCounts.sapling>350);assert.ok(plan.stats.treeSizeCounts.adult>500);assert.ok(plan.stats.treeSizeCounts.large>50);
  for(const o of plan.objects.filter(o=>o.sizeClass)){const s=TREE_SIZE_CLASSES[o.sizeClass];assert.ok(o.height>=s.min-1e-6&&o.height<=s.max+1e-6,o.id+' declared height');}
  for(const o of plan.objects.filter(o=>o.kind==='willow'))assert.ok(terrain.lakes.some(l=>{const r=terrain.lakeRadius(l,o.x,o.z);return r>1&&(r-1)*Math.min(l.rx,l.rz)<32;}),o.id+' willow far from shore');
});
test('optional railway exclusion reserves full tree crowns and furniture footprints',()=>{
  const railPlan={blocksPlacement:(x,z,r)=>x+r>-75&&x-r<-20&&z+r>50&&z-r<650};
  assert.ok(plan.objects.some(o=>railPlan.blocksPlacement(o.x,o.z,o.radius)), 'fixture must intercept real existing placements');
  const withRail=planExplorationDecor({...source,railPlan});
  assert.ok(withRail.objects.length>1800);
  for(const o of withRail.objects)assert.ok(!railPlan.blocksPlacement(o.x,o.z,o.radius+.8),o.id+' occupies rail clearance');
});
const deps='D:/codex_release/artist13_hero_first_DEV_20260907/demo/vendor';
registerHooks({resolve(specifier,context,nextResolve){return nextResolve(specifier==='three'?pathToFileURL(deps+'/build/three.module.js').href:specifier,context);}});
const THREE=await import(pathToFileURL(deps+'/build/three.module.js'));
// Transform/batch checks use a box stand-in, as the host's RoundedBox addon is browser CDN-backed.
class RoundedBoxGeometry extends THREE.BoxGeometry { constructor(w,h,d){super(w,h,d);} }
const render=createExplorationDecor({THREE,RoundedBoxGeometry,plan});
test('actual Three renderer finite matrices and bounds, complete objects in instancing batches',()=>{
  const ids=new Set();for(const chunk of render.object.children)for(const mesh of chunk.children){assert.ok(mesh.isInstancedMesh);assert.ok(mesh.instanceMatrix.array.every(Number.isFinite));assert.ok(mesh.instanceColor.array.every(Number.isFinite));assert.ok(Number.isFinite(mesh.boundingSphere.radius));const b=chunk.userData.bounds;assert.ok(mesh.boundingBox.min.x>=b.minX&&mesh.boundingBox.max.x<=b.maxX&&mesh.boundingBox.min.z>=b.minZ&&mesh.boundingBox.max.z<=b.maxZ,'chunk bounds cover actual giant crowns');for(const id of mesh.userData.objectIds)ids.add(id);}
  assert.equal(ids.size,plan.objects.length);assert.ok(render.stats.drawCalls<650);assert.equal(render.stats.dynamicLights,0);assert.equal(render.stats.shadowCasters,0);assert.ok(render.stats.triangles<2600000);
});
test('actual tree vertices fit full crown clearances and their authored size class heights',()=>{
  const trees=new Map(plan.objects.filter(o=>o.sizeClass).map(o=>[o.id,{...o,minY:Infinity,maxY:-Infinity,maxRadius:0}])),matrix=new THREE.Matrix4(),v=new THREE.Vector3();
  for(const chunk of render.object.children)for(const mesh of chunk.children)for(let i=0;i<mesh.count;i++){
    const o=trees.get(mesh.userData.objectIds[i]);if(!o)continue;mesh.getMatrixAt(i,matrix);const vertices=mesh.geometry.attributes.position;
    for(let j=0;j<vertices.count;j++){v.fromBufferAttribute(vertices,j).applyMatrix4(matrix);o.minY=Math.min(o.minY,v.y);o.maxY=Math.max(o.maxY,v.y);o.maxRadius=Math.max(o.maxRadius,Math.hypot(v.x-o.x,v.z-o.z));}
  }
  for(const o of trees.values()){assert.ok(o.maxRadius<=o.radius+.02,o.kind+' '+o.sizeClass+' visual crown '+o.maxRadius+' > '+o.radius);assert.ok(Math.abs(o.maxY-o.y-o.height)<.035,o.kind+' actual height '+(o.maxY-o.y)+' expected '+o.height);assert.ok(o.minY>=o.y-.025,o.kind+' root below declared ground');}
});
test('spatial culling removes distant forest geometry while retaining near chunks',()=>{
  render.update({focus:{x:370,z:410},maxDistance:360});assert.ok(render.stats.visibleTriangles<render.stats.triangles*.55);assert.ok(render.stats.visibleChunks<render.stats.chunks);
  render.update({focus:{x:-130,z:330},maxDistance:190});assert.ok(render.stats.visibleTriangles<render.stats.triangles*.4);
  for(const chunk of render.object.children){const b=chunk.userData.bounds;if(-130>=b.minX&&-130<=b.maxX&&330>=b.minZ&&330<=b.maxZ)assert.equal(chunk.visible,true);}
  render.update({focus:{x:1e6,z:1e6}});assert.equal(render.stats.visibleDrawCalls,0);assert.equal(render.stats.visibleTriangles,0);
});
console.log(JSON.stringify({tests,stats:render.stats}));render.dispose();
