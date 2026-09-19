import assert from 'node:assert/strict';
import test from 'node:test';
import fs from 'node:fs';
import {createHash} from 'node:crypto';
import {fileURLToPath, pathToFileURL} from 'node:url';
import {performance} from 'node:perf_hooks';
import {planCityParkingAccess} from './city_parking_access.mjs';
import {CAR, createCarWorld, carFits} from './car_drive.mjs';
import {cityParkingCarFits} from './city_parking_plan.mjs';
import {trafficRight} from './city_road_traffic_plan.mjs';
import {createCityParking} from './city_parking.mjs';

// Read-only shared-scene fixture: regenerate its source through the coordinator,
// never silently replace it with the smaller 75-building parking-only fixture.
const root = new URL('../../../', import.meta.url);
const fixtureURL = process.env.MAFIOZI_PARKING_ACCESS_SNAPSHOT
  ? pathToFileURL(process.env.MAFIOZI_PARKING_ACCESS_SNAPSHOT)
  : new URL('outputs/roads_logical_20260912/shared_plan_snapshot.json', root);
const read = url => JSON.parse(fs.readFileSync(url, 'utf8'));
const hash = url => createHash('sha256').update(fs.readFileSync(url)).digest('hex');
const snapshot = read(fixtureURL), plan = snapshot.parkingPlan;
const topology = read(new URL('topology_for_placement.json', import.meta.url));
const instances = [...snapshot.buildings, ...snapshot.authoredDecor];
const extraBodies = [...snapshot.decorPlan.colliders, ...snapshot.roadPlan.colliders];
const bodies = [...instances.flatMap(i => i.collision?.worldBodies || []), ...plan.colliders, ...extraBodies];
const world = createCarWorld(topology, bodies, plan.metresPerCell);
const original = JSON.stringify({plan, topology, instances});
const start = performance.now();
const access = planCityParkingAccess({plan, topology, instances, extraBodies});
const initialPlanningMs = performance.now() - start;
const local = (lot, p) => ({u:(p.x-lot.origin.x)*lot.dz-(p.z-lot.origin.z)*lot.dx, v:(p.x-lot.origin.x)*lot.dx+(p.z-lot.origin.z)*lot.dz});
const roadAt = (x,z) => !!topology.roadMask[Math.floor(z/plan.metresPerCell)]?.[Math.floor(x/plan.metresPerCell)];
const angle = a => Math.atan2(Math.sin(a), Math.cos(a));
const issues = {coverage:[], sweptBody:[], roadLanes:[], drivewayLanes:[], gears:[], paint:[], arrows:[], curvature:[]};
function routeRadius(route){let radius=Infinity;for(let i=1;i<route.points.length;i++){const a=route.points[i-1],b=route.points[i],da=Math.abs(angle(b.yaw-a.yaw)),d=Math.hypot(b.x-a.x,b.z-a.z);if(da>1e-9&&d>1e-9)radius=Math.min(radius,d/da);}return radius;}
const beforeCurvature=(plan.access?.routes||[]).map(r=>({id:r.id,minRadiusM:routeRadius(r)}));
const curvature=access.routes.map(r=>({id:r.id,minRadiusM:routeRadius(r),analyticMinRadiusM:r.minRadiusM}));
for(const row of curvature)if(row.minRadiusM<4.3-.001||row.analyticMinRadiusM!==undefined&&row.analyticMinRadiusM<4.3)issues.curvature.push(row);
const routeChanges={removed:(plan.access?.routes||[]).filter(r=>!access.routes.some(n=>n.id===r.id)).map(r=>r.id),added:access.routes.filter(r=>!(plan.access?.routes||[]).some(n=>n.id===r.id)).map(r=>r.id)};
const count = {sampledPoses:0, intermediatePoses:0, roadEndpoints:0, reverseRoutes:0, paintFootprints:0, arrows:0};
const perLot = [];
const provenance = (snapshot.sourceManifest||[]).map(source => ({...source, currentSHA256:hash(new URL(source.file, root))}));
const staleSources = provenance.filter(s => s.currentSHA256 !== s.afterSHA256).map(s => s.file);

for (const lot of plan.lots) {
  const routes = access.routes.filter(r => r.lotId === lot.id);
  const entries = routes.filter(r => r.kind === 'entry'), exits = routes.filter(r => r.kind === 'exit');
  perLot.push({id:lot.id, layout:lot.layout, entry:entries.length, exit:exits.length});
  if (!entries.length || !exits.length) issues.coverage.push({lotId:lot.id, entry:entries.length, exit:exits.length});
  for (const route of routes) {
    let previous;
    const checkPose = (p, segment, fraction) => {
      const collision = carFits(p.x,p.z,p.yaw,world), supported = cityParkingCarFits(plan,p.x,p.z,p.yaw);
      if (!collision || !supported) issues.sweptBody.push({id:route.id, segment, fraction, collision, supported, ...p});
      count.sampledPoses++;
      if (fraction > 0 && fraction < 1) count.intermediatePoses++;
    };
    checkPose(route.points[0],0,0);
    for (let i=1;i<route.points.length;i++) {
      const a=route.points[i-1], b=route.points[i], distance=Math.hypot(b.x-a.x,b.z-a.z), dyaw=angle(b.yaw-a.yaw);
      // A full CAR rectangle every <=5 cm and <=0.5 degree, including between
      // stored samples. Heading follows the shortest arc across +/-pi.
      const steps=Math.max(1,Math.ceil(distance/.05),Math.ceil(Math.abs(dyaw)/(Math.PI/360)));
      for(let j=1;j<=steps;j++) checkPose({x:a.x+(b.x-a.x)*j/steps,z:a.z+(b.z-a.z)*j/steps,yaw:a.yaw+dyaw*j/steps},i,j/steps);
      const yaw=a.yaw+dyaw/2, travelAlignment=((b.x-a.x)*Math.sin(yaw)+(b.z-a.z)*Math.cos(yaw))/distance;
      if (distance>1e-8 && (route.gear==='reverse' ? travelAlignment>-.985 : travelAlignment<.985)) issues.gears.push({id:route.id, segment:i, travelAlignment, gear:route.gear});
      previous=b;
    }
    if (route.gear==='reverse') {
      count.reverseRoutes++;
      if (lot.layout!=='parallel' || route.kind!=='exit') issues.gears.push({id:route.id, reason:'unexpected_reverse'});
      const entry=entries[0];
      if (JSON.stringify(route.points)!==JSON.stringify(entry.points.slice().reverse())) issues.gears.push({id:route.id, reason:'reverse_must_keep_body_yaw'});
    }
    const p=route.kind==='entry'?route.points[0]:previous;
    count.roadEndpoints++;
    if (!roadAt(p.x,p.z)) issues.roadLanes.push({id:route.id,reason:'endpoint_off_actual_road'});
    // Determine the actual road cross-section at the lot frontage, independently
    // of the access planner's near/far constants. At a junction, scanning from
    // the endpoint could accidentally measure the crossing street's LENGTH.
    // Reverse exits use body yaw:
    // their travel vector is intentionally opposite until the driver resumes.
    let low=-.025,high=-.025;
    while(low>-40 && roadAt(lot.origin.x+lot.dx*(low-.025),lot.origin.z+lot.dz*(low-.025)))low-=.025;
    while(high<40 && roadAt(lot.origin.x+lot.dx*(high+.025),lot.origin.z+lot.dz*(high+.025)))high+=.025;
    const right=trafficRight(Math.sin(p.yaw),Math.cos(p.yaw));
    const offset=(local(lot,p).v-(low+high)/2)*(right.x*lot.dx+right.z*lot.dz);
    const tangent=Math.abs(Math.sin(p.yaw)*lot.dz-Math.cos(p.yaw)*lot.dx);
    if (offset<.05 || tangent<.999) issues.roadLanes.push({id:route.id,reason:'wrong_road_lane',rightOffset:offset,tangent,width:high-low});
    if (lot.layout!=='parallel') {
      const inside=route.kind==='entry'?route.points.at(-1):route.points[0], uv=local(lot,inside);
      const rightInside=trafficRight(Math.sin(inside.yaw),Math.cos(inside.yaw));
      const side=uv.u*(lot.dz*rightInside.x-lot.dx*rightInside.z);
      if(side<CAR.halfWidth)issues.drivewayLanes.push({id:route.id,reason:'body_crosses_driveway_centre',side});
    }
  }
  const marks=access.markings.filter(m=>m.lotId===lot.id);
  const paving={surfaceRects:plan.surfaceRects.filter(r=>r.id===lot.id+':lot'||r.id===lot.id+':driveway'),roadSupportRects:[]};
  for(const m of marks) {
    count.paintFootprints++;
    if(!cityParkingCarFits(paving,m.x,m.z,m.yaw,{halfWidth:m.width/2,halfLength:m.length/2}))issues.paint.push({id:m.id,reason:'paint_rectangle_off_own_paving'});
    if(m.kind==='driveway_yield_line'||m.kind==='driveway_yield_triangle') {
      if(local(lot,m).u<=0)issues.paint.push({id:m.id,reason:'yield_paint_in_incoming_lane'});
    }
  }
  const arrowMarks=marks.filter(m=>m.kind==='driveway_arrow');
  for(let i=0;i<arrowMarks.length;i+=3) {
    const [stem,left,right]=arrowMarks.slice(i,i+3);
    if(!stem||!left||!right){issues.arrows.push({lotId:lot.id,reason:'incomplete_arrow'});continue}
    // Recover the real tip shared by both diagonal paint segments, rather than
    // trusting the mark kind or the planner's direction argument.
    const ends=m=>[-1,1].map(sign=>({x:m.x+sign*Math.sin(m.yaw)*m.length/2,z:m.z+sign*Math.cos(m.yaw)*m.length/2}));
    let pair,distance=Infinity;
    for(const a of ends(left))for(const b of ends(right)){const d=Math.hypot(a.x-b.x,a.z-b.z);if(d<distance){distance=d;pair=[a,b]}}
    const tip={x:(pair[0].x+pair[1].x)/2,z:(pair[0].z+pair[1].z)/2},uv=local(lot,stem),tipUV=local(lot,tip),direction=Math.sign(tipUV.v-uv.v);
    const laneRoutes=routes.filter(r=>Math.sign(local(lot,r.kind==='entry'?r.points.at(-1):r.points[0]).u)===Math.sign(uv.u));
    const expected=laneRoutes.map(r=>r.kind==='entry'?1:-1);
    if(distance>1e-6||!expected.length||expected.some(d=>d!==direction)||Math.sign(uv.u)*direction!==-1)issues.arrows.push({lotId:lot.id,u:uv.u,direction,routeDirections:expected,distance});
    count.arrows++;
  }
}

const THREE=await import(pathToFileURL((process.env.MAFIOZI_THREE_VENDOR||'D:/codex_release/artist13_hero_first_DEV_20260907/demo/vendor')+'/build/three.module.js'));
const before=createCityParking({THREE,plan:{...plan,access:null}}), after=createCityParking({THREE,plan:{...plan,access}});
const render={before:{draws:before.stats.totalDraws,triangles:before.stats.triangles},after:{draws:after.stats.totalDraws,triangles:after.stats.triangles},lights:0,unbatchedMeshes:0,matchedPaintMatrices:0};
after.object.traverse(n=>{if(n.isLight)render.lights++;if(n.isMesh&&!n.isInstancedMesh)render.unbatchedMeshes++});
const matrix=new THREE.Matrix4(),expectedMatrix=new THREE.Matrix4(),q=new THREE.Quaternion(),e=new THREE.Euler(),position=new THREE.Vector3(),scale=new THREE.Vector3();
for(const mark of access.markings) {
  expectedMatrix.compose(position.set(mark.x,.075,mark.z),q.setFromEuler(e.set(0,mark.yaw,0)),scale.set(mark.width,.012,mark.length));
  const mesh=after.object.children.find(n=>n.name===`ParkingBatch:${Math.floor(mark.x/128)},${Math.floor(mark.z/128)}:box`);
  let matches=0;
  for(let i=0;i<(mesh?.count||0);i++){mesh.getMatrixAt(i,matrix);if(matrix.elements.every((v,j)=>Math.abs(v-expectedMatrix.elements[j])<.0002))matches++}
  if(matches===1)render.matchedPaintMatrices++;else issues.paint.push({id:mark.id,reason:'rendered_matrix_mismatch',matches});
}
const percentile=(a,p)=>a.slice().sort((x,y)=>x-y)[Math.min(a.length-1,Math.floor(a.length*p))];
const timings=(renderer,moving)=>{
  const samples=[];
  for(let i=0;i<1020;i++){const focus=moving?{x:100+i*.1,z:100+i*.07}:{x:100,z:100};const t=performance.now();renderer.update({focus});if(i>=20)samples.push(performance.now()-t)}
  return {p50:percentile(samples,.5),p95:percentile(samples,.95)};
};
render.updateMs={before:{moving:timings(before,true),idle:timings(before,false)},after:{moving:timings(after,true),idle:timings(after,false)}};
const report={createdAt:new Date().toISOString(),scope:'CPU and actual THREE instance geometry only; populated-scene performance / GPU not checked',fixture:fileURLToPath(fixtureURL),fixtureCreatedAt:snapshot.createdAt,sourceStableAtFixtureBuild:snapshot.sourceStable,staleSources,sourceManifest:provenance,accessSourceSHA256:hash(new URL('city_parking_access.mjs',import.meta.url)),buildingCount:snapshot.buildings.length,authoredDecorCount:snapshot.authoredDecor.length,finalBodies:bodies.length,carShape:CAR,stats:access.stats,count,perLot,issues,beforeCurvature,curvature,routeChanges,initialPlanningMs,render};
const reportURL=new URL('outputs/roads_logical_20260912/parking_access_audit.json',root);
fs.mkdirSync(new URL('.',reportURL),{recursive:true});fs.writeFileSync(reportURL,JSON.stringify(report,null,2)+'\n');
const none=(key,message)=>assert.deepEqual(issues[key].slice(0,8),[],message+` (${issues[key].length} failures)`);

test('shared fixture preserves all 78 buildings and provides physical entry plus exit for every lot',()=>{
  assert.equal(snapshot.buildings.length,78);assert.equal(plan.lots.length,39);assert.deepEqual(access.issues,[]);none('coverage','incomplete lot');
  assert.equal(JSON.stringify({plan,topology,instances}),original,'planning must not mutate source or parking ownership');
  assert.equal(new Set(access.routes.map(r=>r.id)).size,access.routes.length);assert.deepEqual(structuredClone(access),access,'worker data must remain serializable');
  for(const lot of plan.lots)assert.ok(instances.some(i=>i.id===lot.buildingId));
});
test('the full sedan body remains collision-free and supported between every path sample',()=>{
  assert.ok(count.intermediatePoses>10000);none('sweptBody','intermediate rectangle is blocked or unsupported');
});
test('road endpoints and driveway bodies keep the canonical right-hand lanes',()=>{
  assert.equal(count.roadEndpoints,access.routes.length);none('roadLanes','road endpoint lane mismatch');none('drivewayLanes','driveway lane mismatch');
  for(const route of access.routes){const lot=plan.lots.find(l=>l.id===route.lotId);assert.equal(route.rule,route.kind==='exit'?'yield_to_road_and_pedestrians':lot.layout!=='parallel'&&route.side===1?'yield_to_oncoming_and_pedestrians':'yield_to_pedestrians');}
});
test('reverse exits preserve body heading and use a travel vector opposite the bonnet',()=>{
  assert.equal(count.reverseRoutes,plan.lots.filter(l=>l.layout==='parallel').length);none('gears','gear and pose mismatch');
});
test('every parking turn respects the physical 4.3m turning radius',()=>{
  assert.equal(curvature.length,access.routes.length);none('curvature','parking curve exceeds the sedan steering range');
});
test('every physical arrow follows its route and every paint rectangle is supported by its own lot',()=>{
  assert.equal(count.paintFootprints,access.markings.length);assert.equal(count.arrows,plan.lots.filter(l=>l.layout!=='parallel').length*2);none('paint','paint outside the surface or wrong render transform');none('arrows','arrow points against the route');
});
test('all added markings share existing spatial batches with no light or per-mark draw calls',()=>{
  assert.equal(render.lights,0);assert.equal(render.unbatchedMeshes,0);assert.equal(render.matchedPaintMatrices,access.markings.length);
  assert.equal(render.after.triangles-render.before.triangles,access.markings.length*12);
  assert.ok(render.after.draws-render.before.draws<=4,'paint must reuse spatial box buckets');
  before.dispose();before.dispose();after.dispose();after.dispose();assert.equal(before.object.children.length,0);assert.equal(after.object.children.length,0);
});
console.log(JSON.stringify({report:fileURLToPath(reportURL),stats:access.stats,count,failures:Object.fromEntries(Object.entries(issues).map(([k,v])=>[k,v.length])),beforeTooTight:beforeCurvature.filter(r=>r.minRadiusM<4.3).length,minimumRadiusM:Math.min(...curvature.map(r=>r.minRadiusM)),routeChanges,staleSources,render,initialPlanningMs},null,2));
