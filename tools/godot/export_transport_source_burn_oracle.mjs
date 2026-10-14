#!/usr/bin/env node
// Runs the pinned createVehicleDamage explosion path. The burn formula is not
// copied here: every expected color is read after the actual source update.
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
const expectedDamageSha='e029cb4a03dcd23bbdd0fb2f73b7780db92f24f761cf83b030991acb3c403f92';
assert.equal(sha(damagePath),expectedDamageSha);
const {createVehicleDamage}=await import(pathToFileURL(damagePath));

const f64le=values=>{const buffer=Buffer.alloc(values.length*8);values.forEach((value,index)=>buffer.writeDoubleLE(value,index*8));return buffer.toString('base64')};
const colorValues=color=>[color.r,color.g,color.b];
const target=new T.Color('#100f0e');
const colors=[
 ['black',[0,0,0]],['white',[1,1,1]],['ordinary',[.18,.42,.77]],
 ['target',colorValues(target)],['hdr_negative',[-2,.25,4]],
 ['tiny_large',[Number.MIN_VALUE,1e-200,1e100]],['signed_zero',[-0,+0,-0]],
];

function makeCar(material){
 const geometry=new T.BoxGeometry(.6,.15,.8),door=new T.Mesh(geometry,material);door.name='Door_front_left';
 const object=new T.Group();object.name='Burn_oracle_car';object.add(door);const scene=new T.Group();scene.add(object);scene.updateWorldMatrix(true,true);
 const car={object,profile:{id:'burn_oracle',massKg:1500,halfWidth:1,halfLength:2,height:1.5,partPoints:{},componentPoints:{},wheelPositions:{}},wheels:[],doors:new Map([['front_left',door]]),shell:[],trunk:null};
 return {car,door,geometry,scene};
}
function explode({initial=[.2,.3,.4],transparent=false,transparentBeforeExplosion=null,array=false,replace=false,callbackMutation=null,throwCallback=false}={}){
 const original=new T.MeshStandardMaterial({color:0xffffff,roughness:.41,transparent});original.color.setRGB(...initial);original.name='Burn_original';
 const second=array?new T.MeshStandardMaterial({color:0x445566,roughness:.52}):null;
 const {car,door,geometry,scene}=makeCar(array?[original,second]:original);let callbackSnapshot=null;
 const adapter=createVehicleDamage(T,car,{scene,profile:{maxHp:240,armor:1},groundHeight:()=>0,allowed:()=>true,getState:()=>({speed:0,yaw:0,travelYaw:0}),onExplosion(){
  callbackSnapshot={original_rgb:colorValues(original.color),original_roughness:original.roughness,current_rgb:Array.isArray(door.material)?door.material.map(m=>colorValues(m.color)):colorValues(door.material.color),debris_children:adapter.debrisObject.children.length,door_visible:door.visible};
  if(callbackMutation){door.material.color.setRGB(...callbackMutation)}
  if(throwCallback)throw Error('oracle_callback_throw');
 }});
 let replacement=null;if(replace){replacement=original.clone();replacement.name='Burn_replacement';replacement.color.setRGB(.61,.17,.83);replacement.roughness=.27;door.material=replacement}
 if(transparentBeforeExplosion!==null)original.transparent=transparentBeforeExplosion;
 // An RPG within radius destroys the car without invoking the unrelated local
 // bullet dent/raycast path on our minimal material fixture.
 const point=car.object.getWorldPosition(new T.Vector3());assert.equal(adapter.impact({object:{},point,damage:999,explosive:true,eventId:'burn-oracle'}),true);
 let thrown=null;try{adapter.update(0)}catch(error){thrown=String(error.message)}
 const detached=adapter.debrisObject.children[0]??null,detachedMaterial=detached?.material;
 const result={callback_snapshot:callbackSnapshot,thrown,original_after:{rgb:colorValues(original.color),roughness:original.roughness},current_after:Array.isArray(door.material)?door.material.map(m=>({rgb:colorValues(m.color),roughness:m.roughness})):({rgb:colorValues(door.material.color),roughness:door.material.roughness}),door_visible:door.visible,debris_count:adapter.debrisObject.children.length,detached:Array.isArray(detachedMaterial)?detachedMaterial.map(m=>({rgb:colorValues(m.color),roughness:m.roughness})):detachedMaterial?{rgb:colorValues(detachedMaterial.color),roughness:detachedMaterial.roughness}:null};
 adapter.dispose();original.dispose();second?.dispose();replacement?.dispose();geometry.dispose();return result;
}

const numeric=[];
for(const [label,rgb] of colors){const run=explode({initial:rgb});assert.equal(run.thrown,null);assert.equal(run.debris_count,1);numeric.push({label,input_rgb_f64_le:f64le(rgb),callback_rgb_f64_le:f64le(run.callback_snapshot.original_rgb),after_rgb_f64_le:f64le(run.original_after.rgb),roughness:run.original_after.roughness,callback_before_detach:run.callback_snapshot.debris_children===0&&run.callback_snapshot.door_visible===true})}
const semantics={
 captured_opaque:explode({initial:[.31,.52,.73]}),
 replaced_identity:explode({initial:[.31,.52,.73],replace:true}),
 array_material:explode({initial:[.31,.52,.73],array:true}),
 transparent_material:explode({initial:[.31,.52,.73],transparent:true}),
 captured_opaque_toggled_transparent:explode({initial:[.31,.52,.73],transparent:false,transparentBeforeExplosion:true}),
 captured_transparent_toggled_opaque:explode({initial:[.31,.52,.73],transparent:true,transparentBeforeExplosion:false}),
 callback_mutates_current:explode({initial:[.31,.52,.73],replace:true,callbackMutation:[.05,.6,.2]}),
 callback_throws:explode({initial:[.31,.52,.73],throwCallback:true}),
};
assert.equal(semantics.replaced_identity.detached.rgb[0],.61);
assert.deepEqual(semantics.array_material.original_after.rgb,[.31,.52,.73]);
assert.equal(semantics.transparent_material.debris_count,0);
assert.deepEqual(semantics.captured_opaque_toggled_transparent.original_after.rgb,[.31,.52,.73]);
assert.equal(semantics.captured_transparent_toggled_opaque.original_after.roughness,.99);
assert.equal(semantics.captured_transparent_toggled_opaque.debris_count,0);
assert.equal(semantics.callback_mutates_current.detached.rgb[1],.6);
assert.equal(semantics.callback_throws.debris_count,0);

const fixture={schema:'mafiozi.transport-source-burn-oracle.v1',source:{vehicle_damage:{path:path.relative(repo,damagePath).replaceAll('\\','/'),sha256:sha(damagePath),lines:'55-64,102-127,256-278'},three_revision:T.REVISION,instrumentation:'actual createVehicleDamage impact(explosive)+update; burn formula not copied'},target:{hex:'#100f0e',linear_rgb_f64_le:f64le(colorValues(target))},contract:{roughness:.99,eligibility_supplied_by_host:true,native_albedo_conversion:'host converts linear RGB to sRGB and preserves alpha'},numeric,semantics};
const destination=path.join(repo,'godot/mafiozi_walk/data/transport/source_burn_oracle.json');fs.mkdirSync(path.dirname(destination),{recursive:true});fs.writeFileSync(destination,JSON.stringify(fixture)+'\n');
console.log(JSON.stringify({output:path.relative(repo,destination).replaceAll('\\','/'),sha256:sha(destination),numeric:numeric.length,semantic_cases:Object.keys(semantics).length,target:colorValues(target)}));
