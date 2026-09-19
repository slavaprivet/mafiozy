// CPU/structural evidence only. No WebGL context; not a full-scene FPS claim.
import assert from 'node:assert/strict';
import {readFileSync} from 'node:fs';
import {registerHooks} from 'node:module';
import {pathToFileURL} from 'node:url';
const vendor='D:/codex_release/artist13_hero_first_DEV_20260907/demo/vendor/';
registerHooks({resolve(s,c,next){return next(s==='three'?pathToFileURL(vendor+'build/three.module.js').href:s,c)}});
const T=await import('three'),{GLTFLoader}=await import(pathToFileURL(vendor+'addons/loaders/GLTFLoader.js'));
const {RoundedBoxGeometry}=await import('../../../tools/vehicle_fleet_qa/RoundedBoxGeometry.mjs');
const {ARTIST_VEHICLE_PROFILES,createArtistVehicle}=await import('./vehicle_fleet_models.mjs');
const {createVehicleRenderBatches}=await import('./vehicle_render_batches.mjs');
const baseline=[],candidate=[],rows=[],loader=new GLTFLoader();
const camera=new T.OrthographicCamera(-30,30,30,-30,.1,200);camera.position.set(15,12,18);camera.lookAt(0,1,0);camera.updateMatrixWorld(true);
const sun=new T.OrthographicCamera(-90,90,90,-90,1,320);sun.position.set(-75,130,90);sun.lookAt(0,0,0);sun.updateMatrixWorld(true);
const mainFrustum=new T.Frustum().setFromProjectionMatrix(new T.Matrix4().multiplyMatrices(camera.projectionMatrix,camera.matrixWorldInverse)),shadowFrustum=new T.Frustum().setFromProjectionMatrix(new T.Matrix4().multiplyMatrices(sun.projectionMatrix,sun.matrixWorldInverse));
function census(root){
 const counts={main:0,shadow:0,meshes:0};root.updateMatrixWorld(true);
 root.traverse(n=>{
  if(!n.isMesh||!n.layers.test(camera.layers))return;for(let p=n;p;p=p.parent)if(!p.visible)return;
  const materials=Array.isArray(n.material)?n.material:[n.material];if(!materials.some(m=>m.visible))return;counts.meshes++;
  if(!n.frustumCulled||mainFrustum.intersectsObject(n))for(const m of materials)if(m.visible)counts.main+=m.transparent&&m.side===T.DoubleSide&&!m.forceSinglePass?2:1;
  if(n.castShadow&&(!n.frustumCulled||shadowFrustum.intersectsObject(n)))counts.shadow+=materials.filter(m=>m.visible).length;
 });return counts;
}
for(const profile of ARTIST_VEHICLE_PROFILES){
 const bytes=readFileSync(new URL('./models/artist_vehicle_pack/'+profile.modelFile,import.meta.url)),gltf=await loader.parseAsync(bytes.buffer.slice(bytes.byteOffset,bytes.byteOffset+bytes.byteLength),'');
 const beforeCar=createArtistVehicle(T,RoundedBoxGeometry,gltf.scene,profile),afterCar=createArtistVehicle(T,RoundedBoxGeometry,gltf.scene,profile);
 // Capability opt-out allocates precisely the preceding legacy groups, not
 // merely invisible detail batches that would contaminate the CPU baseline.
 const before=createVehicleRenderBatches({THREE:T,root:beforeCar.object,includeDoors:true,includeBody:true,detailOptimization:false}),after=createVehicleRenderBatches({THREE:T,root:afterCar.object,includeDoors:true,includeBody:true});
 assert.equal(before.stats.detailBatches,0);assert.equal(before.stats.detailMembers,0);assert.equal(before.setDetailOptimizationEnabled(true),false);
 baseline.push(before);candidate.push(after);const oldCounts=census(beforeCar.object),newCounts=census(afterCar.object);
 after.setDetailOptimizationEnabled(false);assert.deepEqual(census(afterCar.object),oldCounts,'runtime A/B exactly restores former draw eligibility '+profile.id);after.setDetailOptimizationEnabled(true);assert.deepEqual(census(afterCar.object),newCounts);
 assert.equal(after.stats.archMembers,4,profile.id+' exact four fixed body lips');
 rows.push({id:profile.id,before:oldCounts,after:newCounts,detailBatches:after.stats.detailBatches,detailMembers:after.stats.detailMembers,savedMain:oldCounts.main-newCounts.main,savedShadow:oldCounts.shadow-newCounts.shadow});
}
const run=list=>{for(const api of list)api.update();};
for(let i=0;i<100;i++){run(baseline);run(candidate);}
const samples=[[],[]];for(let i=0;i<600;i++)for(const index of i%2?[1,0]:[0,1]){const started=performance.now();run(index?candidate:baseline);samples[index].push(performance.now()-started);}
const quantiles=values=>{values.sort((a,b)=>a-b);return {p50:values[Math.floor(values.length*.5)],p95:values[Math.floor(values.length*.95)]};};
const totals=rows.reduce((s,r)=>{for(const key of ['savedMain','savedShadow','detailBatches','detailMembers'])s[key]+=r[key];return s;},{savedMain:0,savedShadow:0,detailBatches:0,detailMembers:0});
console.log(JSON.stringify({scenario:'12 actual models, full-car fixed orthographic camera + production-sized sun frustum, includeBody+doors, no GPU',rows,totals,updateCpuMsForAll12:{before:quantiles(samples[0]),after:quantiles(samples[1])},limits:['No WebGL / driver / shadow or transmission GPU cost measured','Submission counts assume working WEBGL_multi_draw; no transmission prepass counted','CPU baseline uses constructor capability opt-out: no new detail groups allocated','Production shader/geometry/collision/animation quality unchanged; full-game LIVE still required']},null,2));
for(const api of [...baseline,...candidate])api.dispose();
