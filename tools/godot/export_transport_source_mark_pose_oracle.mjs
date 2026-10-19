#!/usr/bin/env node
// Builds pose matrices with the actual Three r180 Matrix4.compose implementation.
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
const markFixturePath=path.join(repo,'godot/mafiozi_walk/data/transport/damage_mark_oracle.json');
const expectedMarkFixtureSha='85762dbdd103f86428d16e89225384355f96fa46662f7f514b205dbd26d9750d';
assert.equal(sha(markFixturePath),expectedMarkFixtureSha);
const markFixture=JSON.parse(fs.readFileSync(markFixturePath,'utf8'));
assert.equal(markFixture.source.vehicle_damage.sha256,'e029cb4a03dcd23bbdd0fb2f73b7780db92f24f761cf83b030991acb3c403f92');
const compose=(position,quaternion,scale)=>Array.from(new T.Matrix4().compose(new T.Vector3(...position),new T.Quaternion(...quaternion),new T.Vector3(...scale)).elements);
const f64le=values=>{const bytes=Buffer.alloc(values.length*8);values.forEach((value,index)=>bytes.writeDoubleLE(value,index*8));return bytes.toString('base64')};
const encode=row=>({...row,position_f64_le:f64le(row.position),raw_quaternion_f64_le:f64le(row.raw_quaternion),scale_f64_le:f64le(row.scale),matrix_f64_le:f64le(row.matrix)});
const rows=markFixture.cases.map((row,index)=>encode({label:`mark_${index}_${row.kind}`,position:row.position,raw_quaternion:row.quaternion,scale:row.scale,matrix:compose(row.position,row.quaternion,row.scale),source_slot:row.slot}));
const signSource=rows[1];
for(const synthetic of [
 {label:'quaternion_sign_pair',position:signSource.position,raw_quaternion:signSource.raw_quaternion.map(value=>-value),scale:signSource.scale},
 {label:'identity_with_asymmetric_scale',position:[-.25,.5,1.75],raw_quaternion:[0,0,0,1],scale:[.5,2.25,4]},
 {label:'raw_zero_quaternion',position:[0,0,0],raw_quaternion:[0,0,0,0],scale:[1,2,3]},
])rows.push(encode({...synthetic,matrix:compose(synthetic.position,synthetic.raw_quaternion,synthetic.scale),source_slot:null}));
const parentPosition=[2.4,-.7,1.1],parentQuaternion=new T.Quaternion().setFromEuler(new T.Euler(.27,-.61,.19)).toArray(),parentScale=[1.3,.82,1.11];
const parentMatrix=new T.Matrix4().compose(new T.Vector3(...parentPosition),new T.Quaternion(...parentQuaternion),new T.Vector3(...parentScale));
const scratchRow=rows.find(row=>row.label.includes('collision_scratch'));
const parentMatrixValues=Array.from(parentMatrix.elements),scratchWorldValues=Array.from(parentMatrix.clone().multiply(new T.Matrix4().fromArray(scratchRow.matrix)).elements);
const parent={position:parentPosition,raw_quaternion:parentQuaternion,scale:parentScale,matrix:parentMatrixValues,scratch_world_matrix:scratchWorldValues,position_f64_le:f64le(parentPosition),raw_quaternion_f64_le:f64le(parentQuaternion),scale_f64_le:f64le(parentScale),matrix_f64_le:f64le(parentMatrixValues),scratch_world_matrix_f64_le:f64le(scratchWorldValues),scratch_label:scratchRow.label};
const fixture={schema:'mafiozi.transport-source-mark-pose-oracle.v1',source:{three_revision:T.REVISION,mark_fixture:{path:path.relative(repo,markFixturePath).replaceAll('\\','/'),sha256:sha(markFixturePath)},vehicle_damage_sha256:markFixture.source.vehicle_damage.sha256,instrumentation:'actual Three r180 Matrix4.compose and Matrix4.multiply'},contract:{matrix_layout:'column-major',local_frame:'same explicit panel-local frame; no axis flip',scale:'finite positive mark scales only',quaternion:'raw finite xyzw; never normalized'},rows,parent,invalid_cases:['nonfinite_position','nonfinite_quaternion','nonfinite_scale','zero_scale','negative_scale','wrong_lengths']};
const destination=path.join(repo,'godot/mafiozi_walk/data/transport/source_mark_pose_oracle.json');fs.mkdirSync(path.dirname(destination),{recursive:true});fs.writeFileSync(destination,JSON.stringify(fixture)+'\n');
console.log(JSON.stringify({output:path.relative(repo,destination).replaceAll('\\','/'),sha256:sha(destination),rows:rows.length,scratch_quaternion_length:Math.hypot(...scratchRow.raw_quaternion)}));
