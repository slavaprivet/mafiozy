import fs from 'node:fs';
import assert from 'node:assert/strict';
import {performance} from 'node:perf_hooks';
import {registerHooks} from 'node:module';
import {pathToFileURL} from 'node:url';
import {createWindowedBuildingEntry} from './building_window_integration.mjs';
import {applyBuildingDoorsGlass} from './building_doors_glass.mjs';
import {applyHospitalPublicApproach} from './hospital_public_approach.mjs';

// Actual authored GLB, current placement, moving entrance leaves and complete
// entry/storey/furniture bodies. CPU only: no replacement collision fixture.
const vendor='D:/codex_release/artist13_hero_first_DEV_20260907/demo/vendor/';
registerHooks({resolve(s,c,next){return next(s==='three'?pathToFileURL(vendor+'build/three.module.js').href:s,c)}});
const T=await import(pathToFileURL(vendor+'build/three.module.js')),{GLTFLoader}=await import(pathToFileURL(vendor+'addons/loaders/GLTFLoader.js'));
const placement=JSON.parse(fs.readFileSync(new URL('buildings_placement.v1.json',import.meta.url))),instance=placement.instances.find(i=>i.assetId==='hospital'),bytes=fs.readFileSync(new URL('../../..'+instance.binding.url,import.meta.url));
const visual=(await new GLTFLoader().parseAsync(bytes.buffer.slice(bytes.byteOffset,bytes.byteOffset+bytes.byteLength),'')).scene,group=new T.Group(),tr=instance.transform;
visual.position.fromArray(tr.modelLocalOffsetM);group.add(visual);group.position.fromArray(tr.positionM);group.rotation.y=tr.yawDegrees*Math.PI/180;group.scale.setScalar(tr.uniformScale);group.updateMatrixWorld(true);applyBuildingDoorsGlass(visual,instance);
const building=createWindowedBuildingEntry({THREE:T,visual,instance}),entry=building.entry,initial=entry.hospitalPublicApproach;
assert(initial,'factory must install the addressed hospital support');
const closed=entry.getCollisionBodies(),serialized=JSON.stringify(closed),beforeBounds=entry.sampleBounds.clone();
assert.strictEqual(entry.getCollisionBodies(),closed,'support queries preserve collision-array version');
const ramp=entry.object.getObjectByName('Entry_Continuous_Ramp'),material=ramp.material;let initialDisposed=0;initial.geometry.addEventListener('dispose',()=>initialDisposed++);
initial.dispose();initial.dispose();assert.equal(initialDisposed,1);assert.equal(JSON.stringify(entry.getCollisionBodies()),serialized);const legacy=entry.floorHeight.bind(entry),oldGeometry=ramp.geometry;
const started=performance.now(),helper=applyHospitalPublicApproach({THREE:T,entry,visual,instance}),installationMs=performance.now()-started;
assert.strictEqual(applyHospitalPublicApproach({THREE:T,entry,visual,instance}),helper);
assert.strictEqual(ramp.material,material);assert.strictEqual(entry.getCollisionBodies(),closed);assert.equal(JSON.stringify(entry.getCollisionBodies()),serialized);
assert.deepEqual(entry.sampleBounds.min.toArray(),beforeBounds.min.toArray());assert.equal(helper.report.addedDraws,0);assert.equal(helper.report.trianglesBefore,2);assert.equal(helper.report.trianglesAfter,4);
const sourceMeshes=[visual.getObjectByName('PAD_HOSPITAL_EXTERIOR_01'),visual.getObjectByName('ROUTE_HOSPITAL_PUBLIC'),ramp],ray=new T.Raycaster(),M=4.1,radius=.36,height=1.8;
const closest=(p,a,b)=>{const dx=b[0]-a[0],dz=b[1]-a[1],t=Math.max(0,Math.min(1,((p.x-a[0])*dx+(p.z-a[1])*dz)/(dx*dx+dz*dz||1)));return Math.hypot(p.x-a[0]-t*dx,p.z-a[1]-t*dz)};
function overlapsCircle(body,p){const poly=body.polygonCR.map(([c,r])=>[c*M,r*M]);let inside=false;for(let i=0,j=poly.length-1;i<poly.length;j=i++){const a=poly[i],b=poly[j];if((a[1]>p.z)!==(b[1]>p.z)&&p.x<(b[0]-a[0])*(p.z-a[1])/(b[1]-a[1])+a[0])inside=!inside;if(closest(p,a,b)<radius-1e-6)return true}return inside;}
function blockedAt(p,floorFn,bodies){const floor=floorFn(p.x,p.z,p.y??0)??0;return bodies.filter(b=>(b.maxYM??Infinity)>=floor+.05&&(b.minYM??-Infinity)<=floor+height&&overlapsCircle(b,p));}
const door=entry.object.localToWorld(new T.Vector3(0,0,0)),approach=entry.object.localToWorld(new T.Vector3(0,0,1.4));
assert(blockedAt(door,entry.floorHeight,closed).some(b=>b.movingDoor),'closed leaves must physically block the threshold');
assert(entry.interact(approach).accepted);for(let i=0;i<12;i++)entry.update(.1,approach);
assert.equal(entry.report.openFraction,1);const opened=entry.getCollisionBodies();assert.notStrictEqual(opened,closed);assert.equal(opened.length,closed.length);assert.strictEqual(entry.getCollisionBodies(),opened);
const end=entry.object.localToWorld(new T.Vector3(0,0,-.75)),start=helper.report.route[0],routes=[],points=[],beforeBlocked=[],afterBlocked=[],rayErrors=[];let maxRise=0,raySamples=0;
for(const lateral of [-.65,0,.65]){let previousY=0;const samples=[];for(let i=0;i<=240;i++){
 const p={x:door.x+lateral,z:start[2]-1+(end.z-start[2]+1)*i/240},y=entry.floorHeight(p.x,p.z,previousY)??0,pWithY={...p,y};maxRise=Math.max(maxRise,Math.abs(y-previousY));previousY=y;points.push(pWithY);samples.push([p.x,y,p.z]);
 const oldHits=blockedAt(pWithY,legacy,opened),newHits=blockedAt(pWithY,entry.floorHeight,opened);if(oldHits.length)beforeBlocked.push({point:pWithY,nodes:oldHits.map(b=>b.node||b.storeyPart||b.kind||'body')});if(newHits.length)afterBlocked.push({point:pWithY,nodes:newHits.map(b=>b.node||b.storeyPart||b.kind||'body')});
 const ceiling=entry.ceilingHeight(pWithY);assert(ceiling===null||ceiling-y>=height-.03,'approach and opened threshold have standing headroom');
 const support=helper.sample(p.x,p.z);if(support!==null){ray.set(new T.Vector3(p.x,10,p.z),new T.Vector3(0,-1,0));const hit=ray.intersectObjects(sourceMeshes,false)[0];raySamples++;if(!hit||Math.abs(hit.point.y-support)>2e-5)rayErrors.push({point:pWithY,support,ray:hit?.point.y});}
 }routes.push(samples)}
const unaffected=[];for(let dx=-18;dx<=18;dx+=3)for(let dz=-20;dz<=22;dz+=3)for(const referenceY of [0,4,8]){const x=door.x+dx,z=door.z+dz;if(helper.sample(x,z)!==null)continue;assert.equal(entry.floorHeight(x,z,referenceY),legacy(x,z,referenceY));unaffected.push([x,z,referenceY]);}
const benchmark=fn=>{for(let i=0;i<1000;i++){const p=points[i%points.length];fn(p.x,p.z,p.y)}const costs=[];let sum=0;for(let b=0;b<31;b++){const begin=performance.now();for(let i=0;i<1000;i++){const p=points[i%points.length];sum+=fn(p.x,p.z,p.y)??0}costs.push((performance.now()-begin)/1000)}costs.sort((a,b)=>a-b);return {p50Ms:costs[15],p95Ms:costs[29],checksum:sum}};
const report={hospital:instance.id,source:'actual current GLB + factory entry/storeys/furniture + real animated door leaves',support:helper.report,installationMs,capsule:{radius,height,samples:points.length,beforeBlocked:beforeBlocked.length,afterBlocked:afterBlocked.length,firstBefore:beforeBlocked[0],afterFailures:afterBlocked.slice(0,8),maxRise},geometry:{raySamples,rayErrors:rayErrors.length},collision:{bodiesBefore:closed.length,bodiesAfter:opened.length,identityPreservedUntilDoorMoves:true},unaffectedFloorQueries:unaffected.length,cpu:{before:benchmark(legacy),after:benchmark(entry.floorHeight)},limits:'CPU local hospital path only. Full NPC ambulance destination integration has a separate actual-GLB test. No GPU/frame-time acceptance.'};
fs.mkdirSync(new URL('../../../outputs/hospital_public_approach_20260912/',import.meta.url),{recursive:true});fs.writeFileSync(new URL('../../../outputs/hospital_public_approach_20260912/actual_route_report.json',import.meta.url),JSON.stringify(report,null,2));console.log(JSON.stringify(report,null,2));
assert(beforeBlocked.length>0,'regression must reproduce the original approach obstruction');assert.equal(afterBlocked.length,0,'real capsule clears the preserved collision bodies');assert.equal(rayErrors.length,0,'support heights match actual visible triangles');assert(maxRise<.28,'walking never requires a jump');
assert.equal(entry.interact(door).reason,'door-sweep-occupied','standing in the opened threshold still prevents closing through the character');
assert.equal(applyHospitalPublicApproach({THREE:T,entry,visual,instance:{...instance,assetId:'bank'}}),helper,'non-hospital invocation is inert');
let geometryDisposals=0,oldDisposals=0;helper.geometry.addEventListener('dispose',()=>geometryDisposals++);oldGeometry.addEventListener('dispose',()=>oldDisposals++);
helper.dispose();entry.dispose();entry.dispose();building.windows?.dispose();building.roomReveals?.dispose();assert.equal(geometryDisposals,1);assert.equal(oldDisposals,1);assert.equal(entry.object.parent,null,'detaching helper does not skip original entry teardown');
console.log('PASS actual hospital approach, raycast support, door collision, scoped floors and teardown');
