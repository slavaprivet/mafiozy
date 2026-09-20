import test from 'node:test';
import assert from 'node:assert/strict';
import {pathToFileURL} from 'node:url';
import {performance} from 'node:perf_hooks';
import {createWorldBloodMarks} from './world_blood_marks.mjs';
const THREE=await import(pathToFileURL((process.env.THREE_VENDOR||'D:/codex_release/artist13_hero_first_DEV_20260907/demo/vendor')+'/build/three.module.js'));
const mark=(r=2,c=3)=>({id:0,r,c,radius:4,rot:.3,life:12000,max:12000,trail:true});
const fixture=options=>{const scene=new THREE.Scene(),calls=[],fx=createWorldBloodMarks({THREE,scene,groundHeight:(x,z)=>{calls.push([x,z]);return 1.2;},...options});return {scene,fx,calls};};
function position(fx,index=0){const matrix=new THREE.Matrix4();fx.object.getMatrixAt(index,matrix);return new THREE.Vector3().setFromMatrixPosition(matrix);}
test('source r/c handedness, real sampled height, no source mutation, one pooled draw',()=>{
 const {fx,calls}=fixture(),src=[mark()],before=JSON.stringify(src);fx.sync(src,{time:5});const p=position(fx);assert(Math.abs(p.x-12.3)<1e-5);assert(Math.abs(p.z-8.2)<1e-5);assert(Math.abs(p.y-1.218)<1e-5);assert.deepEqual(calls,[[12.299999999999999,8.2]]);assert.equal(JSON.stringify(src),before);assert.equal(fx.stats().drawCalls,1);assert.equal(fx.object.material.depthWrite,false);assert.equal(fx.object.material.depthTest,true);fx.dispose();
});
test('unstable source IDs/reordering do not replay, multiply or resample marks',()=>{
 const {fx,calls}=fixture(),src=[mark(),mark(4,5)],geometry=fx.object.geometry,material=fx.object.material;fx.sync(src,{time:1});
 for(let i=0;i<100;i++){fx.sync([{...src[1],id:i},{...src[0],id:100-i},{...src[0],id:99}],{time:1+i*.01});fx.update(1+i*.01);}
 assert.equal(fx.stats().active,2);assert.equal(fx.stats().tracked,2);assert.equal(calls.length,2);assert.equal(fx.object.geometry,geometry);assert.equal(fx.object.material,material);
 fx.sync([src[1]],{time:3});assert.equal(fx.stats().active,1);assert(Math.abs(position(fx).x-20.5)<1e-5);fx.sync([],{time:3.1});assert.equal(fx.stats().active,0);assert.equal(fx.stats().tracked,0);fx.dispose();
});
test('authoritative source life fades to zero and frozen snapshots do not resurrect',()=>{
 const {fx}=fixture(),row={...mark(),life:1000};fx.sync([row],{time:2});const alpha=fx.object.geometry.getAttribute('bloodFade');assert(Math.abs(alpha.array[0]-1000/2200)<1e-6);fx.update(2.5);assert(Math.abs(alpha.array[0]-500/2200)<1e-6);fx.update(3.1);assert.equal(fx.stats().active,0);fx.sync([{...row,id:94}],{time:3.2});assert.equal(fx.stats().active,0);fx.sync([],{time:4});fx.sync([row],{time:5});assert.equal(fx.stats().active,1,'new source generation after explicit clearing');fx.dispose();
});
test('interior space, water/unsuitable ground and unknown heights are never projected arbitrarily',()=>{
 const {fx,calls}=fixture({allowGround:x=>x<20});fx.sync([mark(),mark(4,6),{...mark(5,8),space:'bank_room'}],{time:1});assert.equal(fx.stats().active,1);assert.equal(calls.length,1);
 fx.sync([mark(8,3)],{time:2,exterior:false});assert.equal(fx.stats().active,0);fx.sync([mark(8,3)],{time:3});assert.equal(fx.stats().active,0,'interior legacy coords not resurrected outdoors');fx.sync([],{time:4});fx.sync([{...mark(8,8),elevation:7}],{time:5});assert.equal(fx.stats().active,1);assert(Math.abs(position(fx).y-7.018)<1e-5);assert.equal(calls.length,1,'exact supplied floor does not raycast/guess terrain');fx.dispose();
 const invalid=fixture({groundHeight:()=>NaN});invalid.fx.sync([mark()]);assert.equal(invalid.fx.stats().active,0);invalid.fx.dispose();
});
test('48-instance cap, soot rejection, shader fade and complete idempotent disposal',()=>{
 const {fx,scene}=fixture(),rows=Array.from({length:90},(_,i)=>mark(i,5));fx.sync([{...mark(),soot:true},{...mark(),crater:true},...rows],{time:0});assert.equal(fx.stats().active,48);assert.equal(fx.object.instanceMatrix.count,48);const shader={vertexShader:'#include <common>\n#include <begin_vertex>',fragmentShader:'#include <common>\n#include <color_fragment>'};fx.object.material.onBeforeCompile(shader);assert(shader.vertexShader.includes('vBloodFade = bloodFade'));assert(shader.fragmentShader.includes('diffuseColor.a *= vBloodFade'));let g=0,m=0;fx.object.geometry.addEventListener('dispose',()=>g++);fx.object.material.addEventListener('dispose',()=>m++);fx.dispose();fx.dispose();fx.sync(rows);fx.update(99);assert.equal(fx.stats().active,0);assert.equal(g,1);assert.equal(m,1);assert.equal(scene.getObjectByName('World_Source_Blood_Marks'),undefined);
});
test('bounded CPU cost for 48 marks uses no ground queries between snapshots',()=>{
 const {fx,calls}=fixture(),rows=Array.from({length:48},(_,i)=>mark(i,5));fx.sync(rows,{time:0});const times=[];for(let i=0;i<600;i++){const at=performance.now();fx.update(i/60);times.push(performance.now()-at);}assert.equal(calls.length,48);times.sort((a,b)=>a-b);console.log('Ground blood CPU',JSON.stringify({instances:48,drawCalls:1,p50Ms:times[300],p95Ms:times[570],limits:'CPU presentation only; LIVE GPU/frame time not measured'}));fx.dispose();
});
