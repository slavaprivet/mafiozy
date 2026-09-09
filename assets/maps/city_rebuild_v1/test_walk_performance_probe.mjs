import assert from 'node:assert/strict';
import {createWalkPerformanceProbe} from './walk_performance_probe.mjs';
let time=0,phase='compiling',disposed=0;
const scene={},document={body:{dataset:{}}},native={userData:{instance:{assetId:'house'}},parent:scene},mesh={parent:native};
const gl={getExtension:()=>null,deleteQuery(){disposed++;}};
const renderer={info:{render:{calls:0,triangles:0}},getPixelRatio:()=>1.5,getContext:()=>gl,
 renderBufferDirect(){time+=2;this.info.render.calls++;this.info.render.triangles+=12;},
 render(target){this.info.render.calls=0;this.info.render.triangles=0;if(phase!=='rendered')return;this.renderBufferDirect(null,null,null,null,mesh);}};
const original=renderer.render,direct=renderer.renderBufferDirect;
const probe=createWalkPerformanceProbe({renderer,scene,document,getStartup:()=>({phase}),now:()=>time});
for(let i=0;i<8;i++){time+=1000;probe.begin();time+=1;probe.mark('source');renderer.render(scene);probe.end();}
let report=JSON.parse(document.body.dataset.walkPerformance);
assert.deepEqual(report.timings,{},'empty compiling frames are never a successful FPS sample');
assert.equal(report.gpuMs,null,'unavailable GPU timer must not report zero GPU cost');
phase='rendered';
for(let i=0;i<65;i++){time+=1000;probe.begin();time+=7;probe.mark('source');renderer.render(scene);probe.end();}
report=JSON.parse(document.body.dataset.walkPerformance);
assert.equal(report.timings.render.p50,2);assert.equal(report.timings.source.p50,7);
assert.equal(report.device.pixelRatio,1.5);assert.equal(report.census[0][0],'native:house');
assert.equal(report.census[0][1].calls,1);assert.equal(report.census[0][1].triangles,12);
probe.dispose();assert.equal(renderer.render,original);assert.equal(renderer.renderBufferDirect,direct);assert.equal(disposed,0);
const laterProbe=createWalkPerformanceProbe({renderer,scene,document,getStartup:()=>({phase}),now:()=>time});
const newer=()=>{};renderer.render=newer;laterProbe.dispose();assert.equal(renderer.render,newer,'teardown does not erase another owner\'s later wrapper');
console.log('PASS read-only renderer profiling: excludes compile frames, reports unavailable GPU timing honestly, measures actual draws, restores own hooks.');
