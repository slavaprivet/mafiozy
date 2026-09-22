import assert from 'node:assert/strict';
import {createWalkPerformanceProbe} from './walk_performance_probe.mjs';
let time=0,phase='compiling',disposed=0;
const scene={updateMatrixWorld(){time+=3;}},document={body:{dataset:{}}},native={userData:{instance:{assetId:'house'}},parent:scene},mesh={parent:native};
const gl={getExtension:()=>null,deleteQuery(){disposed++;}};
const renderer={info:{autoReset:true,render:{calls:0,triangles:0},memory:{geometries:24,textures:11},programs:[{},{}]},getPixelRatio:()=>1.5,getContext:()=>gl,
 renderBufferDirect(){time+=2;this.info.render.calls++;this.info.render.triangles+=12;},
 shadowMap:{render(){time+=5;renderer.renderBufferDirect(null,null,null,null,mesh);}},
 render(target){if(phase!=='rendered')return;target.updateMatrixWorld();this.shadowMap.render();this.info.render.calls=0;this.info.render.triangles=0;this.renderBufferDirect(null,null,null,null,mesh);}};
const originalMatrix=scene.updateMatrixWorld,originalShadow=renderer.shadowMap.render;
const original=renderer.render,direct=renderer.renderBufferDirect;
const probe=createWalkPerformanceProbe({renderer,scene,document,getStartup:()=>({phase}),now:()=>time});
for(let i=0;i<8;i++){time+=1000;probe.begin();time+=1;probe.mark('source');renderer.render(scene);probe.end();}
let report=JSON.parse(document.body.dataset.walkPerformance);
assert.deepEqual(report.timings,{},'empty compiling frames are never a successful FPS sample');
assert.equal(report.gpuMs,null,'unavailable GPU timer must not report zero GPU cost');
phase='rendered';
for(let i=0;i<65;i++){time+=1000;probe.begin();time+=7;probe.mark('source');renderer.render(scene);probe.end();}
report=JSON.parse(document.body.dataset.walkPerformance);
assert.equal(report.timings.render.p50,12);assert.equal(report.timings.source.p50,7);
assert.equal(report.timings.renderMatrix.p50,3);assert.equal(report.timings.renderShadow.p50,7);
assert.equal(report.timings.renderShadowSubmit.p50,2);assert.equal(report.timings.renderMainSubmit.p50,2);
assert.equal(report.device.pixelRatio,1.5);assert.equal(report.census[0][0],'native:house');
assert.deepEqual(report.memory,{geometries:24,textures:11,programs:2},'live probe reports renderer-owned memory counters without inventing unavailable values');
assert.equal(report.census[0][1].calls,2);assert.equal(report.census[0][1].shadowCalls,1);assert.equal(report.census[0][1].triangles,24);
assert.equal(report.draws,1,'renderer.info counts main pass after shadow reset; census explicitly retains both passes');
assert.deepEqual(report.frameDraws,{total:2,shadow:1,main:1,triangles:24,shadowTriangles:12},'fresh frame totals include shadows even when Three resets renderer.info before main');
assert.equal(report.renderGroups.environment.calls,2);
assert.equal(report.renderGroups.environment.submitMs,4);
let shadowReport=JSON.parse(document.body.dataset.walkShadowSubmissions);assert.equal(shadowReport.status,'ok');assert.deepEqual(shadowReport.totals,{submissions:1,triangles:12});assert.deepEqual(shadowReport.expected,shadowReport.totals);assert.equal(shadowReport.categories.other.submissions,1);
native.userData.sourceVehicleId='traffic-test';
probe.reset();
for(let i=0;i<3;i++){time+=1000;probe.begin();time+=19;probe.mark('source');renderer.render(scene);probe.end();}
report=JSON.parse(document.body.dataset.walkPerformance);
assert.equal(report.timings.source.samples,2,'comparison starts a new sample window without a cross-mode interval');
assert.equal(report.timings.source.p50,19,'previous-mode timings must not contaminate the new comparison');
assert.equal(report.frameDraws.total,2,'per-frame counts do not accumulate across a comparison window');
assert.equal(report.renderGroups.traffic.calls,2,'traffic ownership is found through mesh ancestors');
assert.equal(report.renderGroups.traffic.shadowCalls,1);
assert.equal(report.renderGroups.traffic.submitMs,4);
assert.equal(report.renderGroups.traffic.shadowSubmitMs,2);
shadowReport=JSON.parse(document.body.dataset.walkShadowSubmissions);assert.equal(shadowReport.status,'ok');assert.equal(shadowReport.categories.transport.submissions,1);assert.equal(shadowReport.categories.other.submissions,0);
delete native.userData.sourceVehicleId;
probe.dispose();assert.equal(renderer.render,original);assert.equal(renderer.renderBufferDirect,direct);assert.equal(disposed,0);
assert.equal(scene.updateMatrixWorld,originalMatrix);assert.equal(renderer.shadowMap.render,originalShadow);
assert.equal(document.body.dataset.walkShadowSubmissions,undefined,'dispose removes the diagnostic dataset');
const laterProbe=createWalkPerformanceProbe({renderer,scene,document,getStartup:()=>({phase}),now:()=>time});
const newer=()=>{};renderer.render=newer;laterProbe.dispose();assert.equal(renderer.render,newer,'teardown does not erase another owner\'s later wrapper');
console.log('PASS read-only renderer profiling: excludes compile frames, reports unavailable GPU timing honestly, measures actual draws, restores own hooks.');

function gpuFixture({available=true}={}){
 let time=1000,id=0;const state={active:null,ready:false,disjoint:false,throwAt:null,drawError:false,duringDraw:null},calls=[],deleted=new Set(),doc={body:{dataset:{}}},scene={};
 const timer={TIME_ELAPSED_EXT:1,GPU_DISJOINT_EXT:2};
 const event=name=>{calls.push(name);if(state.throwAt===name){state.throwAt=null;throw Error('injected '+name);}};
 const gl={CURRENT_QUERY:3,QUERY_RESULT_AVAILABLE:4,QUERY_RESULT:5,getExtension:name=>name==='EXT_disjoint_timer_query_webgl2'&&available?timer:null,
  getQuery(){event('getQuery');return state.active},getParameter(){event('getParameter');return state.disjoint},
  createQuery(){event('createQuery');return {id:++id}},beginQuery(_,q){event('beginQuery');assert.equal(state.active,null,'no overlapping query');state.active=q},
  endQuery(){event('endQuery');assert(state.active);state.active=null},deleteQuery(q){event('deleteQuery');assert(!deleted.has(q),'query deleted once');deleted.add(q)},
  getQueryParameter(_,key){event('getQueryParameter');return key===4?state.ready:8e6}};
 const renderer={getContext:()=>gl,getPixelRatio:()=>1,info:{render:{calls:0,triangles:0},memory:{}},renderBufferDirect(){time+=2;this.info.render.calls++;this.info.render.triangles+=3;},render(){state.duringDraw?.();if(state.drawError)throw Error('draw failed');this.renderBufferDirect(null,null,null,null,{parent:scene});}};
 const probe=createWalkPerformanceProbe({renderer,scene,document:doc,getStartup:()=>({phase:'rendered'}),now:()=>time});
 return {probe,state,calls,deleted,renderer,scene,frame(){time+=1000;probe.begin();time+=3;probe.mark('source');try{renderer.render(scene)}finally{probe.end()}},report:()=>JSON.parse(doc.body.dataset.walkPerformance)};
}
{
 const f=gpuFixture();assert.equal(f.probe.getGpuTimingEnabled(),true);f.frame();f.frame();assert.equal(f.deleted.size,0,'unavailable results remain pending');
 f.probe.setGpuTimingEnabled(false);assert.equal(f.deleted.size,2,'OFF clears pending queries');const count=f.calls.length;
 for(let i=0;i<3;i++)f.frame();assert.equal(f.calls.length,count,'OFF has zero per-frame GL query/getParameter/poll calls');
 const off=f.report();assert.equal(off.gpuTiming,'disabled');assert.equal(off.gpuMs,null);assert.equal(off.timings.source.samples,2);assert.equal(off.timings.source.p50,3);assert.equal(off.timings.render.p50,2);assert.equal(off.frameDraws.total,1);
 f.probe.setGpuTimingEnabled(true);f.state.ready=true;f.frame();assert.equal(f.report().timings.source,undefined,'new mode has no old interval');assert.equal(f.report().gpuMs.p50,8);f.frame();assert.equal(f.report().gpuTiming,'enabled');assert.equal(f.report().timings.source.samples,1);f.probe.dispose();
}
{
 const f=gpuFixture();for(let i=0;i<6;i++)f.frame();assert.equal(f.calls.filter(x=>x==='createQuery').length,4,'pending cap retained');f.probe.reset();assert.equal(f.deleted.size,4);
 f.state.active={external:true};f.frame();assert.equal(f.calls.filter(x=>x==='createQuery').length,4,'existing external query never overlapped');f.state.active=null;
 f.state.ready=true;f.state.disjoint=true;f.frame();assert.equal(f.report().gpuMs,null,'disjoint sample discarded');f.probe.dispose();assert.equal(f.deleted.size,5);
}
for(const error of ['getQuery','createQuery','beginQuery','endQuery','getParameter','getQueryParameter']){
 const f=gpuFixture();f.state.throwAt=error;f.frame();assert.equal(f.probe.getGpuTimingEnabled(),false,error+' safely disables failed instrumentation');assert.match(f.report().gpuTimingError,/injected/);assert.equal(f.state.active,null,error+' leaves no own active query');
 const count=f.calls.length;f.frame();assert.equal(f.calls.length,count,error+' no polling after failure');assert.equal(f.report().gpuMs,null);assert.equal(f.report().frameDraws.total,1);f.probe.dispose();
}
{
 const f=gpuFixture();f.state.drawError=true;assert.throws(()=>f.frame(),/draw failed/);assert.equal(f.state.active,null,'render failure closes query');f.probe.setGpuTimingEnabled(false);assert.equal(f.deleted.size,1);f.probe.dispose();
 const mid=gpuFixture();mid.state.duringDraw=()=>mid.probe.setGpuTimingEnabled(false);mid.frame();assert.equal(mid.state.active,null);assert.equal(mid.deleted.size,1);assert.equal(mid.calls.filter(x=>x==='endQuery').length,1,'disable during render ends query once');mid.probe.dispose();
 const unavailable=gpuFixture({available:false});assert.equal(unavailable.probe.getGpuTimingEnabled(),false);assert.equal(unavailable.probe.setGpuTimingEnabled(true),false);unavailable.frame();assert.equal(unavailable.report().gpuTiming,'unavailable');assert.equal(unavailable.calls.length,0);unavailable.probe.dispose();assert.equal(unavailable.probe.setGpuTimingEnabled(true),false);
}
console.log('PASS GPU timer ON/OFF: query-free disabled frames, reset isolation, pending disposal, nonoverlap, unavailable/disjoint/errors, preserved CPU stages/draws.');

// Emulate Three's actual pass order: prior info counters survive the shadow
// pass, autoReset clears them afterwards, transmission then main accumulate.
for(const autoReset of [true,false]){
 let clock=1000,clockReads=0,skip=false;const doc={body:{dataset:{}}},scene={updateMatrixWorld(){clock+=3}},shadowCamera={},view={},mesh={name:'wheel',parent:scene},hidden={name:'culled',parent:scene};
 const opaque={type:'MeshStandardMaterial',transparent:false},transparent={type:'MeshPhysicalMaterial',transparent:true},depth={type:'MeshDepthMaterial',transparent:false};
 const renderer={info:{autoReset,render:{calls:91,triangles:999},memory:{}},getContext:()=>({getExtension:()=>null}),getPixelRatio:()=>1,
  renderBufferDirect(camera,world,geometry,material,object,group){assert.equal(this,renderer);assert.equal(arguments.length,6);clock+=2;this.info.render.calls+=group.calls;this.info.render.triangles+=group.triangles;return object;},
  shadowMap:{render(){renderer.renderBufferDirect(shadowCamera,scene,null,depth,mesh,{calls:3,triangles:30});renderer.renderBufferDirect(shadowCamera,scene,null,depth,hidden,{calls:2,triangles:20});}},
  render(world,camera){world.updateMatrixWorld();this.shadowMap.render([],world,camera);if(this.info.autoReset){this.info.render.calls=0;this.info.render.triangles=0;}this.renderBufferDirect(camera,world,null,opaque,mesh,{calls:4,triangles:40});this.renderBufferDirect(camera,world,null,opaque,mesh,{calls:4,triangles:40});this.renderBufferDirect(camera,world,null,transparent,mesh,{calls:1,triangles:6});}
 };
 const probe=createWalkPerformanceProbe({renderer,scene,document:doc,getStartup:()=>({phase:'rendered'}),now:()=>{clockReads++;return clock}}),delegate=renderer.renderBufferDirect;
 // Culler installs later and captures the probe delegate, as in walk.
 const outer=function(camera,world,geometry,material,object,group){if(skip&&camera===shadowCamera&&object===hidden)return;return delegate.call(this,camera,world,geometry,material,object,group);};renderer.renderBufferDirect=outer;
 const report=()=>JSON.parse(doc.body.dataset.walkPerformance);
 for(const profiling of [true,false,true])for(const cull of [false,true]){
  probe.setDrawProfilingEnabled(profiling);probe.reset();skip=cull;
  for(let i=0;i<3;i++){clock+=1000;probe.begin();renderer.render(scene,view);renderer.render(scene,view);probe.end();}
  const result=report(),shadow=cull?3:5;
  assert.equal(renderer.renderBufferDirect,outer,'toggle never removes an outer culling owner');assert.equal(result.directProfiling,profiling);
  assert.deepEqual(result.frameDraws,{total:(shadow+9)*2,shadow:shadow*2,main:18,triangles:(shadow*10+86)*2,shadowTriangles:shadow*20},'multiple renders/passes/frames retain exact counts in both modes and autoReset variants');
  const shadowResult=JSON.parse(doc.body.dataset.walkShadowSubmissions);assert.equal(shadowResult.status,profiling?'ok':'disabled');if(profiling){assert.deepEqual(shadowResult.totals,{submissions:shadow*2,triangles:shadow*20});assert.deepEqual(shadowResult.expected,shadowResult.totals);}
  assert.equal(result.timings.render.p50,cull?22:26);assert.equal(result.timings.renderMatrix.p50,6);assert.equal(result.timings.renderShadow.p50,cull?4:8);
  if(profiling){assert(result.timings.renderMainSubmit);assert(result.census);assert.equal(result.materialGroups['main:MeshStandardMaterial:opaque'].calls,8);assert.equal(result.materialGroups['main:MeshPhysicalMaterial:transparent'].calls,1);assert.equal(result.materialGroups['shadow:MeshDepthMaterial:opaque'].calls,shadow);}
  else{assert.equal(result.timings.renderMainSubmit,undefined);assert.equal(result.timings.renderShadowSubmit,undefined);for(const key of ['census','renderGroups','materialGroups'])assert(!Object.hasOwn(result,key),'OFF omits '+key);}
 }
 probe.setDrawProfilingEnabled(false);const before=clockReads;assert.equal(renderer.renderBufferDirect(view,scene,null,opaque,mesh,{calls:1,triangles:3}),mesh);assert.equal(clockReads,before,'OFF direct delegate makes zero clock calls');
 probe.setDrawProfilingEnabled(true);const on=clockReads;renderer.renderBufferDirect(view,scene,null,opaque,mesh,{calls:1,triangles:3});assert.equal(clockReads,on+2,'ON direct delegate retains submit timing');
 probe.dispose();assert.equal(renderer.renderBufferDirect,outer,'disposal never overwrites newer culler');assert.equal(probe.setDrawProfilingEnabled(true),false);assert.equal(probe.getDrawProfilingEnabled(),false);
 const after=clockReads;renderer.renderBufferDirect(view,scene,null,opaque,mesh,{calls:1,triangles:3});assert.equal(clockReads,after,'captured disposed delegate remains query/timer-free');
}
{
 const f=gpuFixture();f.state.ready=true;assert.equal(f.probe.getDrawProfilingEnabled(),true);
 for(const gpu of [false,true])for(const draw of [false,true,false]){
  f.probe.setGpuTimingEnabled(gpu);f.probe.setDrawProfilingEnabled(draw);assert.equal(f.probe.getGpuTimingEnabled(),gpu,'draw mode never changes GPU mode');
  const calls=f.calls.length;for(let i=0;i<3;i++)f.frame();const result=f.report();assert.equal(result.directProfiling,draw);assert.equal(result.gpuTiming,gpu?'enabled':'disabled');assert.equal(result.frameDraws.total,1);
  if(gpu){assert.equal(result.gpuMs.p50,8);assert(f.calls.length>calls);}else assert.equal(f.calls.length,calls,'GPU OFF remains query-free with either draw mode');
  if(!draw)assert.equal(result.timings.renderMainSubmit,undefined);
 }
 f.probe.setDrawProfilingEnabled(true);f.frame();f.probe.setDrawProfilingEnabled(false);f.frame();assert.equal(f.report().timings.render,undefined,'mode switch resets prior rolling samples');f.frame();assert.equal(f.report().timings.render.samples,1);f.probe.dispose();
}
console.log('PASS direct profiling ON/OFF: zero-clock OFF hop, outer-culler preservation, full counters across autoReset/multi-pass/multi-render frames, no stale census/submit stages, GPU-mode orthogonality and capture-only material buckets.');
