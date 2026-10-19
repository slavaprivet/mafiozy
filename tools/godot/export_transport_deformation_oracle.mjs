#!/usr/bin/env node
// Actual createVehicleCrash deformation oracle for the native presentation adapter.
import fs from 'node:fs';
import path from 'node:path';
import assert from 'node:assert/strict';
import {createHash} from 'node:crypto';
import {registerHooks} from 'node:module';
import {fileURLToPath,pathToFileURL} from 'node:url';
const repo=path.resolve(path.dirname(fileURLToPath(import.meta.url)),'../..');
const vendor=process.env.MAFIOZI_THREE_VENDOR??'D:/codex_release/artist13_hero_first_DEV_20260907/demo/vendor';
const hash=p=>createHash('sha256').update(fs.readFileSync(p)).digest('hex');
registerHooks({resolve(specifier,context,next){return next(specifier==='three'?pathToFileURL(path.join(vendor,'build/three.module.js')).href:specifier,context)}});
const T=await import('three');assert.equal(T.REVISION,'180');
const crashPath=path.join(repo,'assets/maps/city_rebuild_v1/vehicle_crash.mjs');
const mechanicsPath=path.join(repo,'assets/maps/city_rebuild_v1/vehicle_crash_mechanics.mjs');
const {createVehicleCrash}=await import(pathToFileURL(crashPath));
const profile={id:'oracle_vehicle',massKg:1320,halfWidth:1.188,halfLength:2.4542,height:1.9659721119020948,wheelBase:2.7404,wheelTrack:1.836,partPoints:{},componentPoints:{},wheelPositions:{}};
const attributes={
 position:{item_size:3,values:[-.34,.46,1.78,.34,.46,1.78,.34,1.08,1.78,-.34,1.08,1.78]},
 normal:{item_size:3,values:[0,0,1,0,0,1,0,0,1,0,0,1]},
 tangent:{item_size:4,values:[1,0,0,1,1,0,0,1,1,0,0,1,1,0,0,1]},
 color:{item_size:4,values:[1,.2,.1,1,.2,1,.1,.8,.1,.2,1,.6,1,1,.1,.4]},
 uv:{item_size:2,values:[0,0,1,0,1,1,0,1]},
};
const indices=[0,1,2,0,2,3],groups=[{start:0,count:3,material_index:0},{start:3,count:3,material_index:1}];
const geometry=new T.BufferGeometry();
for(const [name,row] of Object.entries(attributes))geometry.setAttribute(name,new T.Float32BufferAttribute(row.values,row.item_size));
geometry.setIndex(indices);for(const g of groups)geometry.addGroup(g.start,g.count,g.material_index);
const materials=[new T.MeshStandardMaterial({vertexColors:true}),new T.MeshStandardMaterial({vertexColors:true})];
const mesh=new T.Mesh(geometry,materials);mesh.name='Oracle_panel';mesh.position.set(.11,.04,-.09);mesh.rotation.set(.08,.17,-.035);mesh.scale.set(1.04,.93,1.08);
const object=new T.Group();object.name='Oracle_car';object.add(mesh);object.updateWorldMatrix(true,true);
const scene=new T.Group();scene.add(object);
const crash=createVehicleCrash(T,{object,profile,wheels:[],doors:new Map(),interior:null},{scene,getState:()=>({speed:0,yaw:0,travelYaw:0})});
const contact={point:{x:.08,y:.76,z:2.18},normal:{x:0,y:0,z:1},impactSpeed:14,eventId:'deformation-oracle-impact'};
assert.equal(crash.contactImpact(contact),true);
const output=mesh.geometry;
assert.equal(output.userData.vehicleCrashSubdivided,true);
const outputAttributes=Object.fromEntries(Object.entries(output.attributes).map(([name,a])=>[name,{item_size:a.itemSize,values:Array.from(a.array)}]));
const native=v=>[-v.x,v.y,-v.z];
const fixture={
 schema:'mafiozi.transport-vehicle-deformation-oracle.v1',
 source:{vehicle_crash:{path:path.relative(repo,crashPath).replaceAll('\\','/'),sha256:hash(crashPath)},vehicle_crash_mechanics:{path:path.relative(repo,mechanicsPath).replaceAll('\\','/'),sha256:hash(mechanicsPath)},three_revision:T.REVISION},
 profile,input:{attributes,indices,groups,mesh_transform:{position:mesh.position.toArray(),quaternion:mesh.quaternion.toArray(),scale:mesh.scale.toArray()}},contact,
 snapshot:{vehicle_id:'oracle-vehicle-1',life_generation:1,profile_id:profile.id,revision:crash.state.revision,positions_native:crash.state.nodes.map(n=>native(n.position)),rest_native:crash.state.nodes.map(n=>native(n.rest))},
 expected:{attributes:outputAttributes,groups:output.groups.map(g=>({start:g.start,count:g.count,material_index:g.materialIndex})),bounding_box:{min:output.boundingBox.min.toArray(),max:output.boundingBox.max.toArray()},bounding_sphere:{center:output.boundingSphere.center.toArray(),radius:output.boundingSphere.radius}},
};
const destination=path.join(repo,'godot/mafiozi_walk/data/transport/vehicle_deformation_oracle.json');
fs.mkdirSync(path.dirname(destination),{recursive:true});fs.writeFileSync(destination,JSON.stringify(fixture)+'\n');
console.log(JSON.stringify({output:path.relative(repo,destination).replaceAll('\\','/'),sha256:hash(destination),vertices:output.attributes.position.count,revision:crash.state.revision,groups:output.groups.length}));
crash.dispose();for(const material of materials)material.dispose();geometry.dispose();
