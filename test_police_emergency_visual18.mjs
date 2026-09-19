import fs from 'node:fs';
import assert from 'node:assert/strict';
import {performance} from 'node:perf_hooks';
import vm from 'node:vm';
import {registerHooks} from 'node:module';
import {pathToFileURL} from 'node:url';
import {stagePoliceEmergencyVisuals} from './test_police_emergency_visual18_candidate.mjs';
const original=fs.readFileSync('assets/maps/city_rebuild_v1/world_traffic_presentation.mjs','utf8'),applied=original.includes('function createTrafficEmergencyLamps(root)'),candidate=applied?original:stagePoliceEmergencyVisuals(original);
const helperSource=candidate.slice(candidate.indexOf('function createTrafficEmergencyLamps(root)'),candidate.indexOf('export function createWorldTrafficPresentation('));
const createTrafficEmergencyLamps=vm.runInNewContext('('+helperSource+')');
const vendor=process.env.MAFIOZY_THREE_VENDOR||'D:/codex_release/artist13_hero_first_DEV_20260907/demo/vendor/';
registerHooks({resolve(s,c,next){return next(s==='three'?pathToFileURL(vendor+'build/three.module.js').href:s,c)}});
const T=await import(pathToFileURL(vendor+'build/three.module.js')),{GLTFLoader}=await import(pathToFileURL(vendor+'addons/loaders/GLTFLoader.js'));
const loader=new GLTFLoader(),rows=[];
for(const id of ['police_interceptor','city_ambulance','fire_engine']){
 const bytes=fs.readFileSync('assets/maps/city_rebuild_v1/models/artist_vehicle_pack/'+id+'.glb'),source=(await loader.parseAsync(bytes.buffer.slice(bytes.byteOffset,bytes.byteOffset+bytes.byteLength),'' )).scene;
 const root=source.clone(true),lamps=[];root.traverse(n=>{if(/_Lightbar(?:Red|Blue)$/.test(n.name))lamps.push(n)});
 const prior=lamps.map(n=>n.material),state=createTrafficEmergencyLamps(root);assert.equal(state.count,2);assert(lamps.every((n,i)=>n.material!==prior[i]));
 assert(lamps.every(n=>n.material.emissiveIntensity===0));assert.equal(state.update(false,0),false);assert(state.update(true,.01));
 const values=lamps.map(n=>n.material.emissiveIntensity);assert.equal(values.filter(x=>x===3.2).length,1);assert.equal(state.update(true,.1),false);assert(state.update(true,.18));assert.notDeepEqual(lamps.map(n=>n.material.emissiveIntensity),values);assert(state.update(false,.19));assert(lamps.every(n=>n.material.emissiveIntensity===0));assert(prior.every(m=>m.emissiveIntensity>1));
 const t=performance.now();for(let i=0;i<100000;i++)state.update(true,i/60);rows.push({id,lamps:state.count,cpuMs100k:performance.now()-t});
}
// Test the real presentation lifecycle through staged load hook, including
// stationary snapshots, wrecking, removal and no calls to wheel update.
const moduleURL=new URL('./assets/maps/city_rebuild_v1/world_traffic_presentation.mjs?emergency18',import.meta.url);
const hook=registerHooks({load(url,context,next){const result=next(url,context);return url===moduleURL.href||url.endsWith('/world_traffic_presentation.mjs')?{...result,source:candidate}:result;}});
const {createWorldTrafficPresentation}=await import(moduleURL.href);
await import('./assets/maps/city_rebuild_v1/test_world_traffic_presentation.mjs?emergency18');
await import('./assets/maps/city_rebuild_v1/test_npc_traffic_steering18.mjs?emergency18');
hook.deregister();
let wheelUpdates=0;const actors=[];
const fleet=createWorldTrafficPresentation({scene:new T.Scene(),loader:{async loadAsync(){return{scene:new T.Group()}}},vehicleFactory:()=>{
 const object=new T.Group();for(const suffix of ['Red','Blue']){const mesh=new T.Mesh(new T.BoxGeometry(1,1,1),new T.MeshStandardMaterial({emissive:0xff0000,emissiveIntensity:1.4}));mesh.name='LOD0_police_interceptor_Lightbar'+suffix;object.add(mesh)}
 const actor={object,profile:{wheelBase:2.5},update(){wheelUpdates++}};actors.push(actor);return actor;
}});
const row={id:'service_test',model:'police',r:1,c:1,ang:0,parked:true,emergency:'police',emergencyLights:false};
fleet.sync([row]);await fleet.whenIdle();fleet.update(.1);const car=actors[0],mats=car.object.children.map(n=>n.material);assert(mats.every(m=>m.emissiveIntensity===0));const priorWheels=wheelUpdates;
fleet.sync([{...row,emergencyLights:true}]);fleet.update(.1);assert.equal(mats.filter(m=>m.emissiveIntensity===3.2).length,1);fleet.update(.1);fleet.update(.1);assert.equal(wheelUpdates,priorWheels,'lights independent of drive changes');
fleet.sync([{...row,emergencyLights:true,wrecked:true}]);fleet.update(.1);assert(mats.every(m=>m.emissiveIntensity===0));fleet.sync([]);assert.equal(fleet.getActor(row.id),null);fleet.dispose();
console.log(JSON.stringify({pass:true,applied,rows,checks:['actual3GLBlamps','private-materials','off-active-off','stationary-flash','no-wheel-edits','wreck-off','remove-dispose'],limits:'CPU only; no LIVE/GPU or siren audio'},null,2));
