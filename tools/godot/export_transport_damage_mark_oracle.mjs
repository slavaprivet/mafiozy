#!/usr/bin/env node
// Executes the actual private vehicle_damage.mjs mark closure and contact path
// through an in-memory instrumented module. No mark transform formula is copied.
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
const crashPath=path.join(repo,'assets/maps/city_rebuild_v1/vehicle_crash.mjs');
const expectedDamageSha='e029cb4a03dcd23bbdd0fb2f73b7780db92f24f761cf83b030991acb3c403f92';
const expectedCrashSha='cceffb5b6e65a1d180e8860d471351bf04340439ad605a66d6143daf53b20e44';
assert.equal(sha(damagePath),expectedDamageSha);assert.equal(sha(crashPath),expectedCrashSha);
const dependency=name=>pathToFileURL(path.join(path.dirname(damagePath),name)).href;
let instrumented=fs.readFileSync(damagePath,'utf8')
 .replace("'./vehicle_fire_fx.mjs'",JSON.stringify(dependency('vehicle_fire_fx.mjs')))
 .replace("'./glass_breakage.mjs'",JSON.stringify(dependency('glass_breakage.mjs')))
 .replace("'./vehicle_crash.mjs'",JSON.stringify(dependency('vehicle_crash.mjs')))
 .replace("'./vehicle_render_batches.mjs'",JSON.stringify(dependency('vehicle_render_batches.mjs')));
const originalReturn='return{object,debrisObject,crash,impact,collision,contactImpact,blastImpact,update,reset,dispose,clearDebris,repairPowertrain,';
const oracleReturn='return{__oracleMark:mark,__oracleMarks:marks,__oracleGetCursor:()=>markCursor,__oracleSetCursor:value=>{markCursor=value},__oracleScratch:()=>({point:markLocal.toArray(),normal:markNormal.toArray(),tangent:contactLocalTangent.toArray()}),object,debrisObject,crash,impact,collision,contactImpact,blastImpact,update,reset,dispose,clearDebris,repairPowertrain,';
assert.equal(instrumented.includes(originalReturn),true);instrumented=instrumented.replace(originalReturn,oracleReturn);
const {createVehicleDamage}=await import('data:text/javascript;base64,'+Buffer.from(instrumented).toString('base64'));

const profile={id:'damage_mark_oracle',massKg:1320,halfWidth:1.1,halfLength:2.2,height:1.6,wheelBase:2.7,wheelTrack:1.7,partPoints:{},componentPoints:{},wheelPositions:{}};
const geometry=new T.BoxGeometry(1.2,.7,1.5,2,2,2);const geometryRotation=new T.Euler(.18,.37,.22);geometry.applyQuaternion(new T.Quaternion().setFromEuler(geometryRotation));geometry.userData.vehicleCrashSubdivided=true;
const material=new T.MeshStandardMaterial({color:0x777777,roughness:.7});
const mesh=new T.Mesh(geometry,material);mesh.name='Damage_mark_oracle_panel';mesh.position.set(.31,.42,-.26);mesh.rotation.set(.19,-.41,.13);mesh.scale.set(1.17,.83,1.09);
const object=new T.Group();object.position.set(1.4,.3,-1.8);object.rotation.set(-.05,.57,.06);object.add(mesh);
const scene=new T.Group();scene.add(object);scene.updateWorldMatrix(true,true);
const car={object,profile,wheels:[],doors:new Map(),interior:null,shell:[mesh],trunk:null};
const adapter=createVehicleDamage(T,car,{profile:{maxHp:240,armor:1},scene,allowed:()=>true,getState:()=>({speed:0,yaw:0,travelYaw:0}),groundHeight:()=>0});
assert.equal(typeof adapter.__oracleMark,'function');assert.equal(adapter.__oracleMarks.length,32);
const localPoint=new T.Vector3(.17,.08,.21),localNormal=new T.Vector3(.23,.91,-.34).normalize();
const worldPoint=mesh.localToWorld(localPoint.clone()),worldNormal=localNormal.clone().transformDirection(mesh.matrixWorld);
const snapshot=(kind,input,before)=>{const after=adapter.__oracleGetCursor(),slot=(after-1)%32,entry=adapter.__oracleMarks[slot],scratch=adapter.__oracleScratch();return{kind,input,cursor_before:before,cursor_after:after,slot,local_point:scratch.point,local_normal:scratch.normal,local_tangent:scratch.tangent,position:entry.position.toArray(),quaternion:entry.quaternion.toArray(),scale:entry.scale.toArray(),visible:entry.visible,parent_is_panel:entry.parent===mesh,angle_after_increment:after*2.399}};
const cases=[];
function direct(kind,cursor,{collision=false,damage=24,point=worldPoint,normal=worldNormal}={}){adapter.__oracleSetCursor(cursor);adapter.__oracleMark(mesh,point,normal,collision,damage);cases.push(snapshot(kind,{damage,collision},cursor))}
direct('bullet',0,{damage:0});direct('bullet',2,{damage:49});direct('bullet',31,{damage:100});direct('bullet',32,{damage:25});
direct('bullet_default',5);
direct('bullet_cap_antiparallel',8,{damage:400,normal:new T.Vector3(0,0,-1).transformDirection(mesh.matrixWorld)});
direct('collision_round',30,{collision:true,damage:1});

function contact(kind,cursor,{impactSpeed,slideSpeed,slideDirection}){
 adapter.__oracleSetCursor(cursor);object.updateWorldMatrix(true,true);
 const contactPoint=mesh.localToWorld(new T.Vector3(.6,0,0).applyEuler(geometryRotation));
 const contactNormal=new T.Vector3(1,0,0).applyEuler(geometryRotation).applyNormalMatrix(new T.Matrix3().getNormalMatrix(mesh.matrixWorld)).normalize();
 const accepted=adapter.contactImpact({point:contactPoint,normal:contactNormal,impactSpeed,slideSpeed,slideDirection});
 assert.equal(accepted,true);cases.push(snapshot(kind,{impact_speed:impactSpeed,slide_speed:slideSpeed},cursor));adapter.update(.3);
}
contact('collision_scratch',31,{impactSpeed:10,slideSpeed:4.5,slideDirection:new T.Vector3(.2,.9,.3).normalize()});
contact('collision_round_contact',29,{impactSpeed:8,slideSpeed:0});

const fixture={schema:'mafiozi.transport-damage-mark-oracle.v1',source:{vehicle_damage:{path:path.relative(repo,damagePath).replaceAll('\\','/'),sha256:sha(damagePath),lines:'184-188,229-245'},vehicle_crash:{path:path.relative(repo,crashPath).replaceAll('\\','/'),sha256:sha(crashPath)},three_revision:T.REVISION,instrumentation:'in-memory private mark closure plus actual contactImpact path; formulas not copied'},contract:{pool_size:32,scratch_modulo:3,host_dependencies:['world-to-local point/normal/tangent','contact ray','deformed-surface reprojection','impact authority']},panel:{position:mesh.position.toArray(),quaternion:mesh.quaternion.toArray(),scale:mesh.scale.toArray()},cases};
const destination=path.join(repo,'godot/mafiozi_walk/data/transport/damage_mark_oracle.json');fs.mkdirSync(path.dirname(destination),{recursive:true});fs.writeFileSync(destination,JSON.stringify(fixture)+'\n');
console.log(JSON.stringify({output:path.relative(repo,destination).replaceAll('\\','/'),sha256:sha(destination),cases:cases.length,slots:cases.map(row=>row.slot)}));
adapter.dispose();material.dispose();geometry.dispose();
