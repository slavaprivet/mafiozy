#!/usr/bin/env node
// Executes the actual private vehicle_damage.mjs dent closure through an
// in-memory instrumented module. The dent formula is never copied here.
import fs from 'node:fs';
import path from 'node:path';
import assert from 'node:assert/strict';
import {createHash} from 'node:crypto';
import {registerHooks} from 'node:module';
import {fileURLToPath,pathToFileURL} from 'node:url';
const repo=path.resolve(path.dirname(fileURLToPath(import.meta.url)),'../..');
const vendor=process.env.MAFIOZI_THREE_VENDOR??'D:/codex_release/artist13_hero_first_DEV_20260907/demo/vendor';
const sha=p=>createHash('sha256').update(fs.readFileSync(p)).digest('hex');
registerHooks({resolve(specifier,context,next){return next(specifier==='three'?pathToFileURL(path.join(vendor,'build/three.module.js')).href:specifier,context)}});
const T=await import('three');assert.equal(T.REVISION,'180');
const damagePath=path.join(repo,'assets/maps/city_rebuild_v1/vehicle_damage.mjs');
const expectedDamageSha='e029cb4a03dcd23bbdd0fb2f73b7780db92f24f761cf83b030991acb3c403f92',expectedCrashSha='cceffb5b6e65a1d180e8860d471351bf04340439ad605a66d6143daf53b20e44';
assert.equal(sha(damagePath),expectedDamageSha);assert.equal(sha(path.join(repo,'assets/maps/city_rebuild_v1/vehicle_crash.mjs')),expectedCrashSha);
const dependency=name=>pathToFileURL(path.join(path.dirname(damagePath),name)).href;
let instrumented=fs.readFileSync(damagePath,'utf8')
 .replace("'./vehicle_fire_fx.mjs'",JSON.stringify(dependency('vehicle_fire_fx.mjs')))
 .replace("'./glass_breakage.mjs'",JSON.stringify(dependency('glass_breakage.mjs')))
 .replace("'./vehicle_crash.mjs'",JSON.stringify(dependency('vehicle_crash.mjs')))
 .replace("'./vehicle_render_batches.mjs'",JSON.stringify(dependency('vehicle_render_batches.mjs')));
const originalReturn='return{object,debrisObject,crash,impact,collision,contactImpact,blastImpact,update,reset,dispose,clearDebris,repairPowertrain,';
const oracleReturn='return{__oracleDent:dent,__oracleGeometryRest:geometryRest,__oracleScratch:()=>({local:dentLocal.toArray(),normal:dentNormal.toArray()}),object,debrisObject,crash,impact,collision,contactImpact,blastImpact,update,reset,dispose,clearDebris,repairPowertrain,';
assert.equal(instrumented.includes(originalReturn),true);instrumented=instrumented.replace(originalReturn,oracleReturn);
const moduleUrl='data:text/javascript;base64,'+Buffer.from(instrumented).toString('base64');
const {createVehicleDamage}=await import(moduleUrl);
const profile={id:'local_dent_oracle',massKg:1320,halfWidth:1.188,halfLength:2.4542,height:1.9659721119020948,wheelBase:2.7404,wheelTrack:1.836,partPoints:{},componentPoints:{},wheelPositions:{}};
const bits=new ArrayBuffer(4),view=new DataView(bits);
const f32=x=>Math.fround(x);
function adjacent(value,direction){value=f32(value);view.setFloat32(0,value,false);let raw=view.getUint32(0,false);raw+=((value>0)===(direction>0))?1:-1;view.setUint32(0,raw,false);return view.getFloat32(0,false)}
const damage=64,radius=.10+Math.min(.20,Math.sqrt(damage)*.014),pointLocal=new T.Vector3(.02,.01,-.015),normalLocal=new T.Vector3(.21,-.17,.962).normalize();
const relative=[
 [0,0,0],[.04,0,0],[0,.04,0],
 [adjacent(radius,-1),0,0],[f32(radius),.002,0],[adjacent(radius,1),0,0],
 [-.07,.03,.01],[-.04,-.06,.02],[.03,.02,.045],
 [.12,.08,-.03],[-.14,.02,.04],[.04,-.13,-.02],
 [.22,.04,.03],[-.24,-.02,.01],[.01,.23,-.04],
 [.35,0,0],[0,.35,0],[0,0,.35],
];
const initial=[];for(const p of relative)initial.push(f32(pointLocal.x+p[0]),f32(pointLocal.y+p[1]),f32(pointLocal.z+p[2]));
const geometry=new T.BufferGeometry();geometry.setAttribute('position',new T.Float32BufferAttribute(initial,3));geometry.userData.vehicleCrashSubdivided=true;geometry.computeVertexNormals();geometry.computeBoundingBox();geometry.computeBoundingSphere();
const material=new T.MeshStandardMaterial({color:0x777777,roughness:.7});const mesh=new T.Mesh(geometry,material);mesh.name='Local_dent_oracle_panel';mesh.position.set(.43,.31,-.27);mesh.rotation.set(.23,-.38,.17);mesh.scale.set(1.21,.79,1.13);
const object=new T.Group();object.name='Local_dent_oracle_vehicle';object.position.set(1.7,.2,-2.1);object.rotation.set(-.04,.61,.08);object.add(mesh);const scene=new T.Group();scene.add(object);scene.updateWorldMatrix(true,true);
const car={object,profile,wheels:[],doors:new Map(),interior:null,shell:[mesh],trunk:null};
const adapter=createVehicleDamage(T,car,{profile:{maxHp:240,armor:1},scene,allowed:()=>true,getState:()=>({speed:0,yaw:0,travelYaw:0}),groundHeight:()=>0});
assert.equal(typeof adapter.__oracleDent,'function');
const worldPoint=pointLocal.clone();mesh.localToWorld(worldPoint);const worldNormal=normalLocal.clone().transformDirection(mesh.matrixWorld);
const values=()=>Array.from(mesh.geometry.attributes.position.array);
const state=()=>{const rest=adapter.__oracleGeometryRest.get(mesh);return rest?{base:Array.from(rest.base),offset:Array.from(rest.offset),max_depth:rest.maxDepth}:null};
const bounds=()=>({min:mesh.geometry.boundingBox.min.toArray(),max:mesh.geometry.boundingBox.max.toArray(),sphere:{center:mesh.geometry.boundingSphere.center.toArray(),radius:mesh.geometry.boundingSphere.radius}});
const steps=[];
function apply(label,{point=worldPoint,normal=worldNormal,damage=64,collision=null}={}){
 const before=values();adapter.__oracleDent(mesh,point,normal,damage,collision);const scratch=adapter.__oracleScratch();steps.push({label,damage,collision,before,local_point:scratch.local,local_normal:scratch.normal,after:values(),state:state(),bounds:bounds()});
}
apply('bullet_first');apply('bullet_repeat');
// A structural/cage edit changes the current Float32 positions while the old
// local dent offset persists. The next actual dent must rebase around it.
const cage=mesh.geometry.attributes.position.array;for(const [index,delta] of [[0,.013],[1,-.007],[8,.009],[19,.004]])cage[index]=f32(cage[index]+delta);mesh.geometry.attributes.position.needsUpdate=true;
apply('bullet_after_external_cage',{damage:36});
apply('collision_first',{damage:1,collision:{impactSpeed:12}});
apply('collision_cap_2',{damage:1,collision:{impactSpeed:30}});apply('collision_cap_3',{damage:1,collision:{impactSpeed:30}});
// Geometry-object replacement clears base/offset but maxDepth remains .40.
const replacement=mesh.geometry.clone();replacement.userData.vehicleCrashSubdivided=true;mesh.geometry=replacement;
apply('bullet_after_geometry_replacement',{damage:49});
// The JS source accepts a zero direction. It changes no positions but still
// updates normals/bounds. Future pure provider intentionally rejects it.
apply('source_zero_normal',{damage:25,normal:new T.Vector3(0,0,0)});
const fixture={schema:'mafiozi.transport-local-dent-oracle.v1',source:{vehicle_damage:{path:path.relative(repo,damagePath).replaceAll('\\','/'),sha256:sha(damagePath),lines:'170-182'},vehicle_crash:{path:'assets/maps/city_rebuild_v1/vehicle_crash.mjs',sha256:sha(path.join(repo,'assets/maps/city_rebuild_v1/vehicle_crash.mjs'))},three_revision:T.REVISION,instrumentation:'in-memory private dent closure export; formula not copied'},scope:'position-buffer core only; prepared geometry flagged vehicleCrashSubdivided; subdivision/normals/bounds are host dependencies',profile:{max_vertices:90000},mesh:{initial_positions:initial,transform:{vehicle_position:object.position.toArray(),vehicle_quaternion:object.quaternion.toArray(),panel_position:mesh.position.toArray(),panel_quaternion:mesh.quaternion.toArray(),panel_scale:mesh.scale.toArray()},point_local_requested:pointLocal.toArray(),normal_local_requested:normalLocal.toArray(),radius_theoretical:radius,radius_f32:[adjacent(radius,-1),f32(radius),adjacent(radius,1)]},steps};
const destination=path.join(repo,'godot/mafiozi_walk/data/transport/local_dent_oracle.json');fs.mkdirSync(path.dirname(destination),{recursive:true});fs.writeFileSync(destination,JSON.stringify(fixture)+'\n');
console.log(JSON.stringify({output:path.relative(repo,destination).replaceAll('\\','/'),sha256:sha(destination),steps:steps.length,vertices:initial.length/3,max_depth:state().max_depth}));
adapter.dispose();material.dispose();geometry.dispose();if(replacement!==geometry)replacement.dispose();
