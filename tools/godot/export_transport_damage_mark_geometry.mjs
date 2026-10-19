#!/usr/bin/env node
// Extracts the two actual private mark geometries/materials from vehicle_damage.
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
const damagePath=path.join(repo,'assets/maps/city_rebuild_v1/vehicle_damage.mjs'),crashPath=path.join(repo,'assets/maps/city_rebuild_v1/vehicle_crash.mjs');
const expectedDamageSha='e029cb4a03dcd23bbdd0fb2f73b7780db92f24f761cf83b030991acb3c403f92',expectedCrashSha='cceffb5b6e65a1d180e8860d471351bf04340439ad605a66d6143daf53b20e44';
assert.equal(sha(damagePath),expectedDamageSha);assert.equal(sha(crashPath),expectedCrashSha);
const dependency=name=>pathToFileURL(path.join(path.dirname(damagePath),name)).href;
let instrumented=fs.readFileSync(damagePath,'utf8')
 .replace("'./vehicle_fire_fx.mjs'",JSON.stringify(dependency('vehicle_fire_fx.mjs')))
 .replace("'./glass_breakage.mjs'",JSON.stringify(dependency('glass_breakage.mjs')))
 .replace("'./vehicle_crash.mjs'",JSON.stringify(dependency('vehicle_crash.mjs')))
 .replace("'./vehicle_render_batches.mjs'",JSON.stringify(dependency('vehicle_render_batches.mjs')));
const originalReturn='return{object,debrisObject,crash,impact,collision,contactImpact,blastImpact,update,reset,dispose,clearDebris,repairPowertrain,';
const oracleReturn='return{__oracleMarks:marks,object,debrisObject,crash,impact,collision,contactImpact,blastImpact,update,reset,dispose,clearDebris,repairPowertrain,';
assert.equal(instrumented.includes(originalReturn),true);instrumented=instrumented.replace(originalReturn,oracleReturn);
const {createVehicleDamage}=await import('data:text/javascript;base64,'+Buffer.from(instrumented).toString('base64'));
const object=new T.Group(),scene=new T.Group();scene.add(object);
const profile={id:'damage_mark_geometry_oracle',massKg:1320,halfWidth:1.1,halfLength:2.2,height:1.6,wheelBase:2.7,wheelTrack:1.7,partPoints:{},componentPoints:{},wheelPositions:{}};
const car={object,profile,wheels:[],doors:new Map(),interior:null,shell:[],trunk:null};
const adapter=createVehicleDamage(T,car,{profile:{maxHp:240,armor:1},scene,allowed:()=>true,getState:()=>({}),groundHeight:()=>0});
assert.equal(adapter.__oracleMarks.length,32);
const attribute=entry=>entry?{item_size:entry.itemSize,normalized:entry.normalized,array:Array.from(entry.array),array_type:entry.array.constructor.name}:null;
const geometry=mesh=>({primitive:'triangles',position:attribute(mesh.geometry.attributes.position),normal:attribute(mesh.geometry.attributes.normal),color:attribute(mesh.geometry.attributes.color),uv:attribute(mesh.geometry.attributes.uv),index:mesh.geometry.index?attribute(mesh.geometry.index):null,groups:mesh.geometry.groups.map(group=>({...group})),draw_range:{...mesh.geometry.drawRange}});
const material=mesh=>({type:mesh.material.type,color_linear:mesh.material.color.toArray(),vertex_colors:mesh.material.vertexColors,roughness:mesh.material.roughness,metalness:mesh.material.metalness,transparent:mesh.material.transparent,opacity:mesh.material.opacity,depth_write:mesh.material.depthWrite,side:mesh.material.side,polygon_offset:mesh.material.polygonOffset,polygon_offset_factor:mesh.material.polygonOffsetFactor,polygon_offset_units:mesh.material.polygonOffsetUnits});
const scratch=adapter.__oracleMarks[0],crater=adapter.__oracleMarks[1];
const scratchGeometry=geometry(scratch),craterGeometry=geometry(crater);
for(const [index,mark] of adapter.__oracleMarks.entries()){assert.deepEqual(geometry(mark),index%3?craterGeometry:scratchGeometry);assert.equal(mark.material,index%3?crater.material:scratch.material)}
const fixture={schema:'mafiozi.transport-damage-mark-geometry.v1',source:{vehicle_damage:{path:path.relative(repo,damagePath).replaceAll('\\','/'),sha256:sha(damagePath),lines:'65-78'},vehicle_crash:{path:path.relative(repo,crashPath).replaceAll('\\','/'),sha256:sha(crashPath)},three_revision:T.REVISION,instrumentation:'in-memory private 32-mark pool extraction; geometry/material formulas not copied'},contract:{pool_size:32,local_plane:'XY with +Z normal',resource_instances_per_car:{geometries:2,materials:2},unsupported_native:['polygonOffset/polygonOffsetFactor exact raster bias']},slot_types:adapter.__oracleMarks.map((_,index)=>index%3?'crater':'scratch'),geometries:{scratch:scratchGeometry,crater:craterGeometry},materials:{scratch:material(scratch),crater:material(crater)}};
const destination=path.join(repo,'godot/mafiozi_walk/data/transport/damage_mark_geometry.json');fs.mkdirSync(path.dirname(destination),{recursive:true});fs.writeFileSync(destination,JSON.stringify(fixture)+'\n');
console.log(JSON.stringify({output:path.relative(repo,destination).replaceAll('\\','/'),sha256:sha(destination),slots:fixture.slot_types.length,scratch_vertices:fixture.geometries.scratch.position.array.length/3,crater_vertices:fixture.geometries.crater.position.array.length/3}));
adapter.dispose();
