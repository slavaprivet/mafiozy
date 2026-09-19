import fs from 'node:fs';
import assert from 'node:assert/strict';
import test from 'node:test';
import {createHash} from 'node:crypto';
import {performance} from 'node:perf_hooks';
import {registerHooks} from 'node:module';
import {pathToFileURL} from 'node:url';
import {planTowerPublicApproach,applyTowerPublicApproach} from './tower_public_approach.mjs';
import {createWindowedBuildingEntry} from './building_window_integration.mjs';
import {applyBuildingDoorsGlass} from './building_doors_glass.mjs';
import {buildingDoorPrompt} from './building_prompt.mjs';

const root=new URL('../../../',import.meta.url),placementURL=new URL('buildings_placement.v1.json',import.meta.url),placementSource=fs.readFileSync(placementURL,'utf8');
const placement=JSON.parse(placementSource),instances=placement.instances.filter(i=>i.assetId==='compact_podium_glass_tower_v1');
const topologyURL=new URL('topology_for_placement.json',import.meta.url),topologySource=fs.readFileSync(topologyURL,'utf8'),topology=JSON.parse(topologySource);
const snapshotURL=new URL('outputs/roads_logical_20260912/integration_candidate_snapshot.json',root),snapshotBytes=fs.readFileSync(snapshotURL),snapshot=JSON.parse(snapshotBytes);
const M=4.1,R=.38,H=1.8,vendor=process.env.MAFIOZY_THREE_VENDOR||'D:/codex_release/artist13_hero_first_DEV_20260907/demo/vendor/';
registerHooks({resolve(s,c,next){return next(s==='three'?pathToFileURL(vendor+'build/three.module.js').href:s,c)}});
const T=await import(pathToFileURL(vendor+'build/three.module.js')),{GLTFLoader}=await import(pathToFileURL(vendor+'addons/loaders/GLTFLoader.js'));
const hash=b=>createHash('sha256').update(b).digest('hex'),near=(a,b,label)=>assert(Math.abs(a-b)<2e-5,`${label}: ${a} / ${b}`);
const vector=p=>new T.Vector3(p.x,p.y,p.z),rows=[];
const closest=(p,a,b)=>{const dx=b[0]-a[0],dz=b[1]-a[1],t=Math.max(0,Math.min(1,((p.x-a[0])*dx+(p.z-a[1])*dz)/(dx*dx+dz*dz||1)));return Math.hypot(p.x-a[0]-t*dx,p.z-a[1]-t*dz)};
function circleBody(body,p){
 const poly=body.polygonCR?.map(([c,r])=>[c*M,r*M]);if(!poly)return false;let inside=false;
 for(let i=0,j=poly.length-1;i<poly.length;j=i++){const a=poly[i],b=poly[j];if((a[1]>p.z)!==(b[1]>p.z)&&p.x<(b[0]-a[0])*(p.z-a[1])/(b[1]-a[1])+a[0])inside=!inside;if(closest(p,a,b)<R-1e-6)return true}return inside;
}
function blockedAt(p,bodies){return bodies.filter(b=>(b.maxYM??Infinity)>=p.y+.05&&(b.minYM??-Infinity)<=p.y+H&&circleBody(b,p));}
function diskCells(p){const out=[];for(let r=Math.floor((p.z-R)/M);r<=Math.floor((p.z+R)/M);r++)for(let c=Math.floor((p.x-R)/M);c<=Math.floor((p.x+R)/M);c++){
 const dx=Math.max(c*M-p.x,0,p.x-(c+1)*M),dz=Math.max(r*M-p.z,0,p.z-(r+1)*M);if(dx*dx+dz*dz<=R*R)out.push({r,c,tile:topology.grid[r]?.[c],road:!!topology.roadMask[r]?.[c]});
 }return out;}
function counts(group){let draws=0,triangles=0,lights=0;group.traverse(n=>{if(n.isLight)lights++;if(n.isMesh){draws++;triangles+=(n.geometry.index?.count??n.geometry.attributes.position?.count??0)/3*(n.isInstancedMesh?n.count:1)}});return{draws,triangles,lights};}

test('worker metadata uses audited merged door and existing ramp with strict source guards',()=>{
 assert.equal(instances.length,2);
 for(const instance of instances){const copy=structuredClone(instance),plan=planTowerPublicApproach(instance);assert(plan);assert.equal(plan.buildingId,instance.id);assert.deepEqual(instance,copy);assert.equal(plan.suffix.length,3);assert.strictEqual(plan.suffix[0],plan.landing);assert.strictEqual(plan.suffix[2],plan.door);assert.equal(plan.requiresDoorInteraction,true);near(vector(plan.landing).distanceTo(vector(plan.rampToe)),.5,'ground margin');assert(plan.widthM>3.8);
  const old=instance.entry.anchorRC,probe=instance.entry.roadProbeRC,dx=probe.c-old.c,dz=probe.r-old.r,d=Math.hypot(dx,dz),legacy={x:old.c*M+dx/d*.7,z:old.r*M+dz/d*.7};
  assert(diskCells(legacy).some(c=>c.road),'old destination reproduces the road-mask error');assert(diskCells(plan.landing).every(c=>!c.road&&[8,9].includes(c.tile)),'the whole character stands on existing dry ground');
 }
 const source=instances[0];for(const changed of [{...source,assetId:'hospital'},{...source,binding:{...source.binding,sha256:'changed'}},{...source,binding:{...source.binding,lod:1}},{...source,transform:{...source.transform,horizontalScale:[0,1]}},{...source,transform:{...source.transform,positionM:[0,NaN,0]}}])assert.equal(planTowerPublicApproach(changed),null);
 for(const yawDegrees of [0,90,180,270]){const instance={...source,transform:{...source.transform,yawDegrees}},plan=planTowerPublicApproach(instance),a=yawDegrees*Math.PI/180;near(plan.outward.x,Math.sin(a),'world outward x');near(plan.outward.z,Math.cos(a),'world outward z');near((plan.door.x-instance.transform.positionM[0])*Math.sin(a)+(plan.door.z-instance.transform.positionM[2])*Math.cos(a),(plan.doorLocal.z+instance.transform.modelLocalOffsetM[2])*instance.transform.horizontalScale[1],'transformed door');}
});

for(const source of instances)test(`${source.id}: actual factory, ramp support and full character clearance`,async()=>{
 const instance=structuredClone(source),bytes=fs.readFileSync(new URL(instance.binding.url.slice(1),root));assert.equal(hash(bytes),instance.binding.sha256);
 const loader=new GLTFLoader();loader.register(()=>({name:'CPU_TEXTURE_ONLY',loadTexture:()=>Promise.resolve(new T.Texture())}));
 const visual=(await loader.parseAsync(bytes.buffer.slice(bytes.byteOffset,bytes.byteOffset+bytes.byteLength),'')).scene,group=new T.Group(),tr=instance.transform;
 visual.position.fromArray(tr.modelLocalOffsetM);group.add(visual);group.position.fromArray(tr.positionM);group.rotation.y=tr.yawDegrees*Math.PI/180;group.scale.setScalar(tr.uniformScale);group.updateMatrixWorld(true);
 const glass=applyBuildingDoorsGlass(visual,instance),building=createWindowedBuildingEntry({THREE:T,visual,instance}),entry=building.entry,helper=entry.towerPublicApproach,plan=planTowerPublicApproach(instance);
 assert(helper,'normal factory installs the deterministic actual entrance');assert.strictEqual(entry.publicApproach,helper);assert.deepEqual(helper.plan,plan);assert.equal(helper.report.geometryChanged,false);
 const beforeBodies=entry.getCollisionBodies(),beforeSerialized=JSON.stringify(beforeBodies),beforeCounts=counts(group),floorFn=entry.floorHeight,bounds=entry.sampleBounds.clone(),ramp=entry.object.getObjectByName('Entry_Continuous_Ramp'),geometry=ramp.geometry,material=ramp.material;
 assert(vector(plan.door).distanceTo(entry.object.getWorldPosition(new T.Vector3()))<2e-5);ramp.geometry.computeBoundingBox();const bb=ramp.geometry.boundingBox,toe=ramp.localToWorld(new T.Vector3(0,bb.min.y,bb.max.z));assert(toe.distanceTo(vector(plan.rampToe))<2e-5,'metadata matches actual ramp mesh toe');
 helper.dispose();helper.dispose();const started=performance.now(),installed=applyTowerPublicApproach({THREE:T,entry,instance}),installMs=performance.now()-started;
 assert.strictEqual(applyTowerPublicApproach({THREE:T,entry,instance}),installed);assert.deepEqual(counts(group),beforeCounts);assert.strictEqual(entry.floorHeight,floorFn);assert.strictEqual(ramp.geometry,geometry);assert.strictEqual(ramp.material,material);assert.strictEqual(entry.getCollisionBodies(),beforeBodies);assert.equal(JSON.stringify(entry.getCollisionBodies()),beforeSerialized);assert(entry.sampleBounds.equals(bounds));
 const door=vector(plan.door),approach=entry.object.localToWorld(new T.Vector3(0,0,1.3));assert(blockedAt(door,beforeBodies).some(b=>b.movingDoor),'closed real door blocks the threshold');
 const proximity=entry.proximity(approach);assert(proximity);const prompt=buildingDoorPrompt({kind:'building',entry,opening:false});assert(prompt.includes('открыть дверь'));assert(entry.interact(approach).accepted);for(let n=0;n<12;n++)entry.update(.1,approach);assert.equal(entry.report.openFraction,1);
 const opened=entry.getCollisionBodies();assert.notStrictEqual(opened,beforeBodies);assert.strictEqual(entry.getCollisionBodies(),opened);
 // Replace only this entry's conservative source building bodies with the real
 // factory walls, storeys, furniture and articulated doors. Preserve every
 // other final building, decoration, road object and parking collider.
 const otherBodies=[...snapshot.buildings.filter(i=>i.id!==instance.id),...snapshot.authoredDecor].flatMap(i=>i.collision?.worldBodies||[]).concat(snapshot.decorPlan.colliders,snapshot.roadPlan.colliders,snapshot.parkingPlan.colliders),bodies=[...opened,...otherBodies];
 const ray=new T.Raycaster(),end=entry.object.localToWorld(new T.Vector3(0,0,-.75)),failures=[],rayErrors=[];let samples=0,raySamples=0,maxRise=0,terrainChecks=0;
 for(const lateral of [-.65,0,.65]){let previousY=0;for(let n=0;n<=240;n++){
  const t=n/240,p={x:plan.landing.x+(end.x-plan.landing.x)*t+lateral,z:plan.landing.z+(end.z-plan.landing.z)*t};p.y=entry.floorHeight(p.x,p.z,previousY)??0;maxRise=Math.max(maxRise,Math.abs(p.y-previousY));previousY=p.y;samples++;
  const hits=blockedAt(p,bodies);if(hits.length)failures.push({p,nodes:hits.map(b=>b.node||b.storeyPart||b.kind||b.id||'body')});
  const lp=entry.object.worldToLocal(vector(p));if(lp.z>=0&&lp.z<=plan.rampLengthLocal){ray.set(new T.Vector3(p.x,10,p.z),new T.Vector3(0,-1,0));const hit=ray.intersectObject(ramp,false)[0];raySamples++;if(!hit||Math.abs(hit.point.y-p.y)>2e-5)rayErrors.push({p,ray:hit?.point.y});}
  if(lp.z>=plan.rampLengthLocal){assert(diskCells(p).every(c=>!c.road&&[8,9].includes(c.tile)));terrainChecks++;}
  const ceiling=entry.ceilingHeight(p);assert(ceiling===null||ceiling-p.y>=H-.03);
 }}
 const row={id:instance.id,plan,installMs,actualSourceSHA256:hash(bytes),renderBefore:beforeCounts,renderAfter:counts(group),capsule:{radius:R,height:H,samples,fullFinalBodies:bodies.length,failures:failures.slice(0,12),failureCount:failures.length,maxRise,terrainChecks},ramp:{raySamples,errors:rayErrors.slice(0,4),errorCount:rayErrors.length},closedBodyCount:beforeBodies.length,openBodyCount:opened.length};rows.push(row);
 assert.deepEqual(failures,[],'full standing capsule passes landing, real ramp and open threshold');assert.deepEqual(rayErrors,[],'floor sampler matches actual visible ramp surface');assert(maxRise<.03,'continuous support needs no jump');
 assert.equal(entry.interact(door).reason,'door-sweep-occupied');assert.deepEqual(instance,source,'source identity and placement preserved');
 installed.dispose();entry.dispose();entry.dispose();building.roomReveals?.dispose();building.windows?.dispose();glass.dispose();assert.equal(entry.object.parent,null);assert.equal(entry.publicApproach,undefined);
});

test('contract creates no frame work, and current source map stays unchanged',()=>{
 assert.equal(fs.readFileSync(placementURL,'utf8'),placementSource);assert.equal(fs.readFileSync(topologyURL,'utf8'),topologySource);assert.equal(placement.instances.length,75);assert.equal(snapshot.buildings.length,78);
 for(let i=0;i<1000;i++)planTowerPublicApproach(instances[i%2]);const costs=[];for(let b=0;b<31;b++){const started=performance.now();for(let i=0;i<10000;i++)planTowerPublicApproach(instances[i%2]);costs.push((performance.now()-started)/10000)}costs.sort((a,b)=>a-b);
 const report={createdAt:new Date().toISOString(),source:'two actual bound GLBs and normal factory with final 78-building candidate colliders',snapshotSHA256:hash(snapshotBytes),snapshotChangedDuringRun:hash(fs.readFileSync(snapshotURL))!==hash(snapshotBytes),rows,cpu:{planP50Ms:costs[15],planP95Ms:costs[29],perFrameUpdates:0},limits:'CPU actual geometry and deterministic metadata only. No GPU, populated scene frame-time acceptance or new terrain/placement.'};
 const output=new URL('outputs/tower_public_approach_20260913/actual_route_report.json',root);fs.mkdirSync(new URL('./',output),{recursive:true});fs.writeFileSync(output,JSON.stringify(report,null,2));console.log(JSON.stringify({towers:rows.map(r=>({id:r.id,samples:r.capsule.samples,failures:r.capsule.failureCount,rayErrors:r.ramp.errorCount,landing:r.plan.landing})),cpu:report.cpu}));
});
