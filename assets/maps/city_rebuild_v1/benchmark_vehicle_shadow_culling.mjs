// Real geometry, synthetic positions, no GPU: estimates eligible draw savings
// and the CPU overhead of the guard. This is not a populated-game FPS test.
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
const {createVehicleShadowCulling}=await import('./vehicle_shadow_culling.mjs');
const scene=new T.Scene(),sun=new T.DirectionalLight();sun.position.set(-75,130,90);scene.add(sun,sun.target);sun.castShadow=true;
Object.assign(sun.shadow.camera,{left:-90,right:90,top:90,bottom:-90,near:1,far:320});sun.shadow.mapSize.set(2048,2048);sun.shadow.bias=-.0003;sun.shadow.normalBias=.04;
const loader=new GLTFLoader(),cars=[];
for(const [i,profile] of ARTIST_VEHICLE_PROFILES.entries()){
 const data=readFileSync(new URL('./models/artist_vehicle_pack/'+profile.modelFile,import.meta.url)),gltf=await loader.parseAsync(data.buffer.slice(data.byteOffset,data.byteOffset+data.byteLength),'');
 const car=createArtistVehicle(T,RoundedBoxGeometry,gltf.scene,profile);car.object.userData.sourceVehicleId='bench_'+i;car.object.position.set([-30,0,30][i%3],0,[-45,-15,15,45][Math.floor(i/3)]);car.object.rotation.y=(i%4)*Math.PI/2;scene.add(car.object);
 const batches=createVehicleRenderBatches({THREE:T,root:car.object,includeBody:true,includeDoors:true});cars.push({car,batches});
}
const camera=new T.PerspectiveCamera(45,16/9,.2,1500);camera.position.set(0,2.7,4);scene.updateMatrixWorld(true);sun.shadow.camera.updateProjectionMatrix();sun.shadow.updateMatrices(sun);
const shadowFrustum=sun.shadow.getFrustum();let calls=0;
const renderer={shadowMap:{type:T.PCFSoftShadowMap,render(lights,s,c){
 s.traverseVisible(o=>{if(!o.isMesh||!o.castShadow||!o.layers.test(c.layers)||o.frustumCulled&&!shadowFrustum.intersectsObject(o))return;
  for(const m of Array.isArray(o.material)?o.material:[o.material])if(m.visible)renderer.renderBufferDirect(sun.shadow.camera,s,o.geometry,m,o,null);
 });
}},renderBufferDirect(){calls++;}};
const helper=createVehicleShadowCulling({THREE:T,renderer,scene,sun}),rows=[];
const run=()=>{calls=0;renderer.shadowMap.render([sun],scene,camera);return calls;};
const q=values=>{values.sort((a,b)=>a-b);return {p50:values[Math.floor(values.length*.5)],p95:values[Math.floor(values.length*.95)]};};
for(const yaw of [0,Math.PI/2,Math.PI,Math.PI*1.5]){
 camera.lookAt(Math.sin(yaw)*20,1.7,4-Math.cos(yaw)*20);camera.updateMatrixWorld(true);
 helper.setEnabled(false);const before=run();helper.setEnabled(true);const after=run(),stats={...helper.stats};assert(after<=before);
 for(let i=0;i<40;i++){helper.setEnabled(false);run();helper.setEnabled(true);run();}
 const times=[[],[]];for(let i=0;i<200;i++)for(const enabled of i%2?[true,false]:[false,true]){helper.setEnabled(enabled);const start=performance.now();run();times[+enabled].push(performance.now()-start);}
 rows.push({yaw,beforeShadowCalls:before,afterShadowCalls:after,saved:before-after,guard:stats,cpuNoDriverBefore:q(times[0]),cpuNoDriverAfter:q(times[1])});
}
console.log(JSON.stringify({rows,scenario:'12 actual car models, synthetic 3x4 grid, four fixed camera directions, existing sun shadow frustum',scope:'No GPU or real population; guard overhead and eligible submissions only'},null,2));
helper.dispose();for(const {batches} of cars)batches.dispose();
