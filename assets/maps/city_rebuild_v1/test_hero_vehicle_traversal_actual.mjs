import assert from 'node:assert/strict';
import fs from 'node:fs';
import {pathToFileURL} from 'node:url';
import {registerHooks} from 'node:module';
import {createHeroVehicleSurface} from './hero_vehicle_surface.mjs';
import {createTraversalWorld} from './hero_traversal_world.mjs';
import {planTraversal,stepTraversal} from './hero_traversal.mjs';
import {ARTIST_VEHICLE_PROFILE_BY_ID,createArtistVehicle} from './vehicle_fleet_models.mjs';

const vendor='D:/codex_release/artist13_hero_first_DEV_20260907/demo/vendor/';
registerHooks({resolve(s,c,next){return next(s==='three'?pathToFileURL(vendor+'build/three.module.js').href:s,c)}});
const T=await import(pathToFileURL(vendor+'build/three.module.js'));
const {GLTFLoader}=await import(pathToFileURL(vendor+'addons/loaders/GLTFLoader.js'));
const {RoundedBoxGeometry}=await import('../../../tools/vehicle_fleet_qa/RoundedBoxGeometry.mjs');
const vehicleSurfaceSource=fs.readFileSync(new URL('./hero_vehicle_surface.mjs',import.meta.url),'utf8').replace(/\r\n/g,'\n');
assert(vehicleSurfaceSource.includes('generation++;active.length=0')&&vehicleSurfaceSource.includes('recordList.length=0')&&!/function update\([^)]*\)\{[^]*?new (Set|Map)\(\)/.test(vehicleSurfaceSource),'steady-state vehicle surface update reuses generation records and active array');
const profile=ARTIST_VEHICLE_PROFILE_BY_ID.compact_sedan;
const bytes=fs.readFileSync(new URL('./models/artist_vehicle_pack/'+profile.modelFile,import.meta.url));
const gltf=await new GLTFLoader().parseAsync(bytes.buffer.slice(bytes.byteOffset,bytes.byteOffset+bytes.byteLength),'');
const car=createArtistVehicle(T,RoundedBoxGeometry,gltf.scene,profile),record={id:'car-7',car,state:{speed:0,id:'car-7'}};
const vehicleSurface=createHeroVehicleSurface({THREE:T,getVehicles:()=>[record]});vehicleSurface.update(1);
const world=createTraversalWorld({groundHeight:()=>0,ceilingHeight:()=>Infinity,bodiesAt:()=>[],contains:()=>true,walkable:()=>true,waterAt:()=>null,blocksDynamic:()=>false,inBody:()=>false,vehicleSurface});
const bounds=new T.Box3().setFromObject(car.object),center=bounds.getCenter(new T.Vector3()),radius=Math.hypot(bounds.getSize(new T.Vector3()).x,bounds.getSize(new T.Vector3()).z)*.5;
assert.equal(world.canOccupy({x:center.x,y:0,z:center.z},1.9),false,'actual car blocks an ordinary capsule');
assert.equal(world.canOccupy({x:center.x,y:0,z:center.z},1.9,{ignoreVehicleId:'fleet:car-7'}),true,'only the named source car is ignored through traversal-world context');
assert.notEqual(world.sample(center.x,center.z,0)?.supportKind,undefined,'ordinary sample sees actual car geometry');
assert.equal(world.sample(center.x,center.z,0,{ignoreVehicleId:'fleet:car-7'}).supportKind,undefined,'source-car context also bypasses climb support');
let plan,start,direction;
for(let ray=0;ray<32&&!plan;ray++){
 const angle=ray*Math.PI/16,heading={x:-Math.cos(angle),z:-Math.sin(angle)};
 let lastFree=null;
 for(let distance=radius+1.2;distance>=0;distance-=.035){
  const point={x:center.x-heading.x*distance,y:0,z:center.z-heading.z*distance};
  if(world.canOccupy(point,1.9)){lastFree=point;continue}
  if(lastFree){const candidate=planTraversal({position:lastFree,direction:heading,sample:world.sample,canOccupy:world.canOccupy});if(candidate?.destination.y>.5){plan=candidate;start=lastFree;direction=heading;}break;}
 }
}
assert(plan,'actual compact sedan exposes a reachable hood/roof traversal from its physical outline');
assert(['vault','mantle'].includes(plan.kind));
assert(plan.destination.y>.5&&plan.destination.y<=2.05,'actual vehicle surface height controls the destination');
let state={...plan,elapsed:0};for(let i=0;i<180&&!state.done;i++)state=stepTraversal(state,1/60,world.canOccupy);
assert(state.done&&!state.blocked,'swept capsule completes the actual car climb without crossing its body');
assert(world.canOccupy(state,1.9));

record.state.speed=2;vehicleSurface.update(1.1);
assert.equal(planTraversal({position:start,direction,sample:world.sample,canOccupy:world.canOccupy}),null,'moving car remains a blocker and loses climb support');
console.log('PASS actual compact sedan: physical hood/roof climb, swept body, moving-car rejection');
