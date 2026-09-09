import assert from 'node:assert/strict';
import {installFastWalkStartup} from './point_light_loop.mjs';
let released=0,renders=0,resolveCompile;
const material={dispose(){released++;}},scene={traverse(fn){fn({material});}},camera={};
const renderer={render(){renders++;},compileAsync(){return new Promise(resolve=>{resolveCompile=resolve;});}};
const startup=installFastWalkStartup({THREE:{REVISION:'other',ShaderChunk:{}},renderer,scene,camera,isReady:()=>true});
renderer.render(scene,camera);await Promise.resolve();assert.equal(startup.report.phase,'compiling');
material.dispose();material.dispose();assert.equal(released,0,'streaming eviction must not invalidate the pending Three program');
resolveCompile();await new Promise(resolve=>setImmediate(resolve));
assert.equal(released,1,'deferred material resources released exactly once');
assert.equal(startup.report.phase,'ready');renderer.render(scene,camera);assert.equal(renders,1);assert.equal(startup.report.phase,'rendered');
material.dispose();assert.equal(released,2,'normal disposal restored after startup');
let timerCallback,cleared=false;const realSet=globalThis.setTimeout,realClear=globalThis.clearTimeout;
try{
 globalThis.setTimeout=fn=>{timerCallback=fn;return 123;};globalThis.clearTimeout=id=>{cleared=id===123;};
 const stuck={render(){renders++;},compileAsync:()=>new Promise(()=>{})};
 const recovery=installFastWalkStartup({THREE:{REVISION:'other',ShaderChunk:{}},renderer:stuck,scene,camera,isReady:()=>true});
 stuck.render(scene,camera);await Promise.resolve();timerCallback();assert(cleared);stuck.render(scene,camera);assert.equal(recovery.report.phase,'rendered');assert.match(recovery.report.error,/timed out/);
}finally{globalThis.setTimeout=realSet;globalThis.clearTimeout=realClear;}
console.log('PASS async shader warm-up: streamed material disposal retained, released once, render restored, stalled-promise fallback');
