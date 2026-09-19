import assert from 'node:assert/strict';
import fs from 'node:fs';
import {pathToFileURL} from 'node:url';
import {createLandscapePlan} from './landscape_plan.mjs';
import {createExplorationRailwayPlan} from './exploration_railway_plan.mjs';
import {planExplorationDecor} from './exploration_decor_plan.mjs';
import {planEnvironmentGrass,GRASS_LIMITS} from './environment_grass_plan.mjs';
import {createEnvironmentGrass,grassWindOffset,grassDistanceFade,grassContactOffset,GRASS_CONTACT} from './environment_grass.mjs';
const THREE=await import(pathToFileURL('D:/codex_release/artist13_hero_first_DEV_20260907/demo/vendor/build/three.module.js'));
const read=n=>JSON.parse(fs.readFileSync(new URL(n,import.meta.url),'utf8')),topology=read('./topology_for_placement.json'),buildings=read('./buildings_placement.v1.json').instances,existingDecor=read('./decor_placement.v1.json').instances,landscape=createLandscapePlan(),railPlan=createExplorationRailwayPlan({landscape,topology}),decorPlan=planExplorationDecor({terrain:landscape,topology,railPlan,buildings,existingDecor});
const options={topology,landscape,railPlan,buildings,existingDecor,decorPlan},original=JSON.stringify({topology,buildings,existingDecor}),plan=planEnvironmentGrass(options),m=4.1;
let tests=0;function test(name,fn){fn();tests++;console.log('PASS',name);}
test('real source immutable, deterministic lawn cover and island placement have four ecological regions',()=>{assert.equal(JSON.stringify({topology,buildings,existingDecor}),original);assert.deepEqual(plan,planEnvironmentGrass(options));assert.ok(plan.tufts.length>=70000&&plan.tufts.length<=GRASS_LIMITS.maxTufts);assert.ok(plan.patches.length>600);assert.ok(plan.tufts.filter(t=>t.patchId?.startsWith('lawn-understory')).length>=30000);for(const count of Object.values(plan.stats.counts))assert.ok(count>600);assert.ok(plan.tufts.some(t=>t.height>.75));assert.ok(plan.tufts.some(t=>t.height<.25));});
const rects=[];
for(const b of buildings)for(const key of['clearance','footprint','entryCorridor']){const q=b[key];if(q)rects.push({minX:q.minC*m,maxX:q.maxC*m,minZ:q.minR*m,maxZ:q.maxR*m});}
function polygon(p){if(p?.length)rects.push({minX:Math.min(...p.map(v=>v[0]))*m,maxX:Math.max(...p.map(v=>v[0]))*m,minZ:Math.min(...p.map(v=>v[1]))*m,maxZ:Math.max(...p.map(v=>v[1]))*m});}
for(const d of existingDecor){polygon(d.clearancePolygonCR);for(const c of d.collision?.worldBodies||[])polygon(c.polygonCR);}for(const c of decorPlan.colliders)polygon(c.polygonCR);
test('bent leaf envelopes avoid all actual buildings, entrances, decor and tree trunks',()=>{for(const t of plan.tufts)for(const r of rects)assert.ok(Math.hypot(Math.max(r.minX-t.x,0,t.x-r.maxX),Math.max(r.minZ-t.z,0,t.z-r.maxZ))>=t.radius+.15,t.id+' intersects ground object');});
test('grass never on roads, sidewalks, water, police or rail/station/approach envelopes',()=>{
  for(const t of plan.tufts){assert.ok(!railPlan.blocksPlacement(t.x,t.z,t.radius+.35));
    if(t.x>=0&&t.x<738&&t.z>=0&&t.z<820){for(let r=Math.floor((t.z-t.radius)/m);r<=Math.floor((t.z+t.radius)/m);r++)for(let c=Math.floor((t.x-t.radius)/m);c<=Math.floor((t.x+t.radius)/m);c++){if(Math.hypot(Math.max(c*m-t.x,0,t.x-(c+1)*m),Math.max(r*m-t.z,0,t.z-(r+1)*m))>=t.radius)continue;assert.equal(topology.grid[r]?.[c],8,t.id+' native tile');assert.ok(!topology.policeMask?.[r]?.[c]);}}
    else for(let i=0;i<16;i++){const a=i*Math.PI/8,x=t.x+Math.cos(a)*t.radius,z=t.z+Math.sin(a)*t.radius;assert.ok(landscape.contains(x,z));assert.ok(!landscape.waterAt(x,z));const p=landscape.pathAt(x,z);assert.ok(!p.path||p.distance>p.path.width/2+.35,t.id+' obstructs verge');}
    assert.ok(Math.abs(t.y-landscape.groundHeight(t.x,t.z)+.015)<1e-7);
  }
});
test('wind anchors all roots and gives continuous coherent varying tip motion',()=>{
  for(const time of[0,.2,1,3,15,33]){const root=grassWindOffset({x:27,z:18,time,weight:0});assert.equal(Math.hypot(root.x,root.z),0);const a=grassWindOffset({x:27,z:18,time,weight:1,height:.8}),b=grassWindOffset({x:27,z:18,time:time+.0001,weight:1,height:.8});assert.ok(Math.hypot(a.x,a.z)<.2);assert.ok(Math.hypot(a.x-b.x,a.z-b.z)<.0002);}
  assert.notDeepEqual(grassWindOffset({x:27,z:18,time:0}),grassWindOffset({x:27,z:18,time:1}));assert.equal(grassDistanceFade(0),1);assert.equal(grassDistanceFade(105),0);assert.ok(grassDistanceFade(90)>0&&grassDistanceFade(90)<1);
});
const render=createEnvironmentGrass({THREE,plan});
test('solid 9/11 blade meshes, grounded detail pieces and rounded shrubs use pinned root coordinates',()=>{
  const geometries=new Map();let material;for(const chunk of render.object.children)for(const mesh of chunk.children){geometries.set(mesh.geometry.userData.grassStyle,mesh.geometry);material=mesh.material;assert.equal(mesh.castShadow,false);assert.ok(mesh.instanceMatrix.array.every(Number.isFinite));assert.ok(Number.isFinite(mesh.boundingSphere.radius));assert.equal(mesh.geometry.attributes.grassSlope.isInstancedBufferAttribute,true);}
  assert.equal(geometries.size,3);for(const g of geometries.values()){assert.ok(g.attributes.normal.array.every(Number.isFinite));assert.ok(g.boundingBox.max.z-g.boundingBox.min.z>.1);assert.ok(g.index.count/3<=171);assert.equal(g.userData.solidGeometry,true);}assert.equal(geometries.get('grass').userData.blades,9);assert.equal(geometries.get('reed').userData.blades,11);assert.equal(geometries.get('grass').userData.groundPieces,0,'rejected ground clods stay removed');
  const shader={uniforms:{},vertexShader:THREE.ShaderLib.standard.vertexShader};material.onBeforeCompile(shader);assert.ok(shader.vertexShader.includes('grassWeight * grassWeight'));assert.ok(shader.vertexShader.includes('modelMatrix * instanceMatrix * vec4(0.0, 0.0, 0.0, 1.0)'));assert.equal(shader.uniforms.uGrassTime,render.uniforms.uGrassTime);assert.ok(shader.vertexShader.includes('1.0 - smoothstep'));assert.equal(material.transparent,false);
});
const shots=[];
test('actual near-city, station, forests and shore workloads always fit geometry/draw budgets',()=>{
  let time=0;for(const focus of[{x:63,z:373},{x:460,z:213},{x:-130,z:330},{x:280,z:-66},{x:864,z:686},{x:-95,z:15}]){
    render.update({time:time++,focus,force:true});assert.ok(render.stats.visibleTufts>0);assert.ok(render.stats.visibleTufts<=GRASS_LIMITS.maxVisibleTufts);assert.ok(render.stats.visibleTriangles<=GRASS_LIMITS.maxVisibleTriangles);assert.ok(render.stats.visibleBatches<=GRASS_LIMITS.maxVisibleBatches);assert.ok(render.stats.fadeFar<=105);
    const rendered=new Set();let triangles=0;for(const chunk of render.object.children)for(const mesh of chunk.children)if(mesh.visible){assert.equal(mesh.count,mesh.userData.tuftIds.length);triangles+=mesh.count*mesh.geometry.index.count/3;for(const id of mesh.userData.tuftIds){assert.ok(!rendered.has(id));rendered.add(id);}}
    assert.equal(triangles,render.stats.visibleTriangles);assert.equal(rendered.size,render.stats.visibleTufts);shots.push({focus,tufts:render.stats.visibleTufts,triangles,batches:render.stats.visibleBatches,fadeFar:render.stats.fadeFar});
  }
});
test('dynamic blade tips remain in conservative bounds across wind phases',()=>{
  const matrix=new THREE.Matrix4(),v=new THREE.Vector3(),o=new Map(plan.tufts.map(t=>[t.id,t]));
  render.update({time:9,focus:{x:-130,z:330},force:true});
  for(const chunk of render.object.children)for(const mesh of chunk.children)if(mesh.visible)for(let i=0;i<Math.min(mesh.count,30);i++){
    mesh.getMatrixAt(i,matrix);const t=o.get(mesh.userData.tuftIds[i]),p=mesh.geometry.attributes.position;
    for(let j=0;j<p.count;j++)for(const time of[0,1.2,2.7,6]){v.fromBufferAttribute(p,j).applyMatrix4(matrix);const bend=grassWindOffset({x:t.x,z:t.z,time,height:t.height,weight:p.getY(j)});v.x+=bend.x;v.z+=bend.z;assert.ok(Math.hypot(v.x-t.x,v.z-t.z)<t.radius+.002);assert.ok(v.x>=mesh.boundingBox.min.x-.001&&v.x<=mesh.boundingBox.max.x+.001&&v.z>=mesh.boundingBox.min.z-.001&&v.z<=mesh.boundingBox.max.z+.001);}
  }
});
test('time advances on GPU without rebuilding instances, camera/frustum and distance culling work',()=>{
  const focus={x:-130,z:330};render.update({time:10,focus,force:true});const count=render.stats.visibleTufts;render.update({time:10.016,focus});assert.equal(render.uniforms.uGrassTime.value,10.016);assert.equal(render.stats.visibleTufts,count);
  const camera=new THREE.PerspectiveCamera(55,1.7,.1,500);camera.position.set(-130,3,330);camera.lookAt(-130,2,250);render.update({time:11,focus,camera,force:true});assert.ok(render.stats.visibleTriangles<=GRASS_LIMITS.maxVisibleTriangles);assert.ok(render.object.children.some(c=>!c.visible),'frustum excludes chunks');camera.lookAt(-130,2,420);render.update({time:11.016,focus,camera});assert.ok(render.stats.visibleTufts>0);
  render.update({time:12,focus:{x:1e6,z:1e6},force:true});assert.equal(render.stats.visibleTufts,0);assert.equal(render.stats.visibleBatches,0);
});
test('dense worst case caps actual triangles and fades before the selection cutoff',()=>{
  const densePlan={...plan,tufts:Array.from({length:3000},(_,i)=>({...plan.tufts[0],id:'dense-'+i,x:(i%60)*.5,z:Math.floor(i/60)*.5,y:0,height:.8,style:'reed'}))},dense=createEnvironmentGrass({THREE,plan:densePlan});
  dense.update({time:0,focus:{x:15,z:12},force:true});const reed=dense.object.children.flatMap(c=>c.children).find(mesh=>mesh.geometry.userData.grassStyle==='reed'),triangles=reed.geometry.index.count/3;assert.equal(dense.stats.visibleTufts,Math.min(GRASS_LIMITS.maxVisibleTufts,Math.floor(GRASS_LIMITS.maxVisibleTriangles/triangles)));assert.ok(dense.stats.visibleTriangles<=90000);assert.ok(dense.uniforms.uGrassFadeFar.value<105);assert.equal(grassDistanceFade(dense.uniforms.uGrassFadeFar.value,dense.uniforms.uGrassFadeNear.value,dense.uniforms.uGrassFadeFar.value),0);dense.dispose();
});
test('GPU contact anchors roots, compresses tips and recovers completely',()=>{
  const trail=[{x:0,z:0,time:10,radius:1.05}];
  const root=grassContactOffset({x:.2,z:0,time:10,weight:0,trail});assert.equal(Math.hypot(root.x,root.y,root.z),0);
  const a=grassContactOffset({x:.2,z:0,time:10,trail}),b=grassContactOffset({x:.2,z:0,time:12,trail}),c=grassContactOffset({x:.2,z:0,time:14,trail});
  assert.ok(a.x>.45&&a.y<-.2&&a.y>-.5);assert.ok(b.x>0&&b.x<a.x);assert.equal(Math.hypot(c.x,c.y,c.z),0);
  assert.equal(Math.hypot(...Object.values(grassContactOffset({x:3,z:0,time:10,trail}))),0);
  const focus={x:483.366,z:344.004};render.update({time:20,focus,actorPosition:focus,force:true});
  const first=render.uniforms.uGrassTrail.value.find(p=>p.z===20);assert.ok(first);
  const version=render.object.children.flatMap(c=>c.children).find(m=>m.visible).instanceMatrix.version;
  render.update({time:20.016,focus,actorPosition:{x:focus.x+.02,z:focus.z}});assert.equal(first.z,20.016);
  assert.equal(render.object.children.flatMap(c=>c.children).find(m=>m.visible).instanceMatrix.version,version);
  for(let i=1;i<20;i++)render.update({time:20+i*.1,focus,actorPosition:{x:focus.x+i*.5,z:focus.z}});
  assert.equal(render.uniforms.uGrassTrail.value.length,GRASS_CONTACT.samples);
});
test('pressed blades bend aside without being buried and recover completely',()=>{
  const trail=[{x:0,z:0,time:10,radius:GRASS_CONTACT.radius}];
  let vertices=0;
  for(const style of ['grass','reed']){
    const mesh=render.object.children.flatMap(c=>c.children).find(m=>m.geometry.userData.grassStyle===style);
    const positions=mesh.geometry.attributes.position;
    for(const height of [.23,.65,1.01])for(const distance of [0,.2,.45,.75])for(let i=0;i<positions.count;i++){if(mesh.geometry.attributes.grassFlex.getX(i)<.9)continue;
      const weight=positions.getY(i),before=weight*height;
      const progress=mesh.geometry.attributes.grassProgress.getX(i),contact=grassContactOffset({x:distance,z:0,time:10,height,weight,progress,trail});
      const pressed=before+contact.y;
      assert.ok(pressed>=before*.55-1e-8&&pressed<=before+.030001,'pressed blade keeps most of its visible height');
      if(progress>.54)assert.ok(pressed>=before*.55,'bent middle/tip must remain above terrain');
      if(weight===0)assert.equal(Math.hypot(contact.x,contact.y,contact.z),0,'root remains planted');
      const recovered=grassContactOffset({x:distance,z:0,time:14,height,weight,trail});
      assert.equal(before+recovered.y,before,'all blade segments recover');vertices++;
    }
  }
  const shader={uniforms:{},vertexShader:THREE.ShaderLib.standard.vertexShader};
  render.object.children.flatMap(c=>c.children)[0].material.onBeforeCompile(shader);
  assert.match(shader.vertexShader,/environmentGrassPressedHeight\(grassProgress\)/);
  assert.match(shader.vertexShader,/dot\(grassSlope,grassWorld\.xz-grassRoot\.xz\)/);assert.match(shader.vertexShader,/\/0\.280/);
  assert.match(shader.vertexShader,/uGrassFeet\[4\]/);assert.ok(!shader.vertexShader.includes('discard'));
  assert.ok(vertices>1000);
});
test('combined hero pressure and wind fit the actual bent geometry envelopes',()=>{
  const source=new Map(plan.tufts.map(t=>[t.id,t])),matrix=new THREE.Matrix4(),v=new THREE.Vector3();
  render.update({time:25,focus:{x:-130,z:330},force:true});
  for(const chunk of render.object.children)for(const mesh of chunk.children)if(mesh.visible)for(let i=0;i<Math.min(12,mesh.count);i++){
    mesh.getMatrixAt(i,matrix);const t=source.get(mesh.userData.tuftIds[i]),p=mesh.geometry.attributes.position,flex=t.style==='shrub'?.22:1;
    for(let j=0;j<p.count;j++)for(const time of[0,1,3]){
      const vertexFlex=mesh.geometry.attributes.grassFlex.getX(j);v.fromBufferAttribute(p,j).applyMatrix4(matrix);const wind=grassWindOffset({x:t.x,z:t.z,time,height:t.height,weight:p.getY(j)}),contact=grassContactOffset({x:t.x,z:t.z,time,height:t.height,weight:p.getY(j),flex:vertexFlex,trail:[{x:t.x-.001,z:t.z,time,radius:1.05}]});
      v.x+=wind.x*vertexFlex+contact.x;v.z+=wind.z*vertexFlex+contact.z;v.y+=contact.y;
      assert.ok(Math.hypot(v.x-t.x,v.z-t.z)<t.radius+.002,t.id);assert.ok(v.y>=t.y-.001&&v.y<=t.y+t.height+.001);
    }
  }
});
test('user city lawn and cedar lake tour have visible nearby dense grass',()=>{
  const coverage=[];
  for(const focus of[{x:483.366,z:344.004},{x:280,z:-66}]){
    const near=plan.tufts.filter(t=>Math.hypot(t.x-focus.x,t.z-focus.z)<20),close=near.filter(t=>Math.hypot(t.x-focus.x,t.z-focus.z)<10);
    assert.ok(near.length>=100,JSON.stringify({focus,near:near.length}));assert.ok(close.length>=10,JSON.stringify({focus,close:close.length}));
    assert.ok(near.some(t=>t.height>.65));render.update({time:30,focus,force:true});
    coverage.push({focus,within10:close.length,within20:near.length,visible:render.stats.visibleTufts,triangles:render.stats.visibleTriangles,fade:render.stats.fadeFar});
  }
  assert.ok(plan.stats.shrubs>=100);console.log('COVERAGE',JSON.stringify(coverage));
});
console.log(JSON.stringify({tests,plan:plan.stats,totalTriangles:render.stats.totalTriangles,shots}));render.dispose();
