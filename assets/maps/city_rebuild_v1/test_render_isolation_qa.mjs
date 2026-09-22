// CPU-only lifecycle test: real THREE camera/objects, stub DOM/renderer/probe.
import assert from 'node:assert/strict';
import {pathToFileURL} from 'node:url';
import {createRenderIsolationQa,pointLightCensus,RENDER_ISOLATION_MODES} from './render_isolation_qa.mjs';
const vendor=process.env.MAFIOZI_THREE_VENDOR||'D:/codex_release/artist13_hero_first_DEV_20260907/demo/vendor';
const T=await import(pathToFileURL(vendor+'/build/three.module.js'));
function eventTarget(){const listeners=new Map();return {listeners,addEventListener(type,fn){if(!listeners.has(type))listeners.set(type,new Set());listeners.get(type).add(fn);},removeEventListener(type,fn){listeners.get(type)?.delete(fn)},fire(type){for(const fn of [...(listeners.get(type)||[])])fn({type});}};}
function dom(){
 const doc={...eventTarget(),hidden:false,createElement(tag){return {tagName:tag.toUpperCase(),style:{},dataset:{},attributes:{},children:[],value:'',setAttribute(key,value){this.attributes[key]=String(value)},append(...nodes){for(const node of nodes){this.children.push(node);node.parentNode=this}},remove(){if(this.parentNode){this.parentNode.children=this.parentNode.children.filter(n=>n!==this);this.parentNode=null}}};}};
 doc.body=doc.createElement('body');doc.getElementById=id=>{let found=null;function walk(node){if(node.id===id)found=node;for(const child of node.children)walk(child)}walk(doc.body);return found;};return doc;
}
function fixture(options={}){
 const doc=dom(),win={...eventTarget(),location:{href:options.href||'http://127.0.0.1:18538/world.html?perfqa=1&isolationqa=1'}};
 const camera=new T.PerspectiveCamera(55,2,.1,1000);camera.position.set(7,2,-9);camera.rotation.set(.1,.4,-.03);
 const target=new T.Group(),hidden=new T.Group(),child=new T.Mesh(new T.BoxGeometry(),new T.MeshBasicMaterial());target.add(child);hidden.visible=false;target.userData={hp:70,positionAuthority:'source'};
 const calls=[],state={time:1000,ratio:2,direct:options.direct??true,gpu:options.gpu??true,measurementFrames:0,draws:0,throwAt:null,unstable:false,empty:false,targets:null};
 const event=name=>{calls.push(name);if(state.throwAt===name){state.throwAt=null;throw Error('injected '+name)}};
 const renderer={domElement:{width:2000,height:1000},shadowMap:{enabled:options.shadows??true},getPixelRatio:()=>state.ratio,setPixelRatio(value){state.ratio=value;this.domElement.width=1000*value;this.domElement.height=500*value;event('pixelRatio:'+value)}};
 const probe={getDrawProfilingEnabled:()=>state.direct,setDrawProfilingEnabled(value){state.direct=value;event('drawProfiling:'+value)},reset(){state.measurementFrames=0;event('reset')},snapshot(){event('snapshot');return {timings:{render:{samples:state.measurementFrames,p50:12,p95:16}},frameDraws:{total:state.unstable?11:10,main:8,shadow:2},marker:state.draws}}};
 if(options.withGpu)probe.getGpuTimingEnabled=()=>state.gpu;
 const freeze={active:options.held??true,stop(){this.active=false;event('freeze.stop')}};
 const qa=createRenderIsolationQa({document:doc,window:win,renderer,camera,probe:options.noProbe?null:probe,freeze:options.noFreeze?null:freeze,getTargets(mode){event('targets:'+mode);return state.empty?[]:state.targets??[target,target,hidden,child,null]},now:()=>state.time,...(options.useDefaults?{}:{warmupFrames:options.warmupFrames??1,sampleFrames:options.sampleFrames??3})});
 const f={doc,win,camera,target,hidden,child,calls,state,renderer,probe,freeze,qa,panel:doc.getElementById('render-isolation-qa')};
 f.frame=draw=>{const result=qa.render(()=>{state.draws++;state.measurementFrames++;event('draw');return draw?.()});qa.afterFrame();return result};
 f.frames=(count,draw)=>{for(let i=0;i<count;i++)f.frame(draw)};
 f.toVariant=()=>f.frames((options.warmupFrames??1)+(options.sampleFrames??3));
 f.assertRestored=()=>{assert.equal(target.visible,true);assert.equal(hidden.visible,false);assert.equal(child.visible,true);assert.equal(renderer.shadowMap.enabled,options.shadows??true);assert.equal(state.ratio,2);assert.equal(state.direct,options.direct??true);};
 return f;
}
let passed=0;const failures=[];
function test(name,run){try{run();passed++;console.log('PASS '+name)}catch(error){failures.push({name,error:error.stack});console.error('FAIL '+name+' — '+error.message)}}

test('local perfqa + isolationqa identity gate; missing dependencies create no UI/listeners',()=>{
 for(const href of ['https://game.example/?perfqa=1&isolationqa=1','http://localhost/?perfqa=1','http://localhost/?isolationqa=1','http://localhost/?perfqa=1&isolationqa=0','http://localhost/?perfqa=1&isolationqa=true',...['uid','account_uid','character_uid','auth','token','initData'].map(key=>'http://localhost/?perfqa=1&isolationqa=1&'+key+'=')]){
  const f=fixture({href});assert.equal(f.qa,null,href);assert.equal(f.doc.body.children.length,0);assert.equal(f.doc.listeners.size,0);assert.equal(f.win.listeners.size,0);
 }
 for(const option of [{noProbe:true},{noFreeze:true}]){const f=fixture(option);assert.equal(f.qa,null);assert.equal(f.doc.body.children.length,0);}
});
test('point-light census matches renderer visibility, zero intensity and bounded source groups',()=>{
 const camera=new T.PerspectiveCamera();camera.layers.set(0);
 const root=new T.Group(),hiddenParent=new T.Group();hiddenParent.visible=false;root.add(hiddenParent);
 const lights=[];
 for(const [name,intensity,parent,layer] of [
  ['StreetLamp_PooledLight_0',0,root,0],['StreetLamp_PooledLight_1',2,root,0],['Entry_Light_Slot',0,root,0],['HiddenLight',3,hiddenParent,0],['LayerLight',4,root,2],['',1,root,0]
 ]){const light=new T.PointLight(0xffffff,intensity);light.name=name;light.layers.set(layer);parent.add(light);lights.push(light);}
 const duplicate=lights[0],notLight=new T.Group(),census=pointLightCensus([...lights,duplicate,notLight,null],camera,{maxGroups:2});
 assert.deepEqual({...census,groups:undefined},{targets:6,rendererVisible:4,visibleZeroIntensity:2,visiblePositiveIntensity:2,hiddenByHierarchy:1,cameraLayerMismatch:1,groups:undefined});
 assert.equal(census.groups.length,3);assert.deepEqual(census.groups[0],{name:'StreetLamp_PooledLight',total:2,rendererVisible:2,visibleZeroIntensity:1,visiblePositiveIntensity:1,hiddenByHierarchy:0,cameraLayerMismatch:0});
 assert.equal(census.groups[2].name,'(other)');assert.equal(census.groups.reduce((sum,group)=>sum+group.total,0),6);
});
test('completed point-light isolation publishes its start-time census',()=>{
 const f=fixture(),parent=new T.Group(),active=new T.PointLight(0xffffff,2),idle=new T.PointLight(0xffffff,0);active.name='Entry_Light_Slot';idle.name='Entry_Light_Slot';parent.add(active,idle);f.state.targets=[active,idle];
 assert.equal(f.qa.start('pointlights'),true);f.frames(12);const census=f.qa.report().last.targetCensus;assert.equal(census.targets,2);assert.equal(census.rendererVisible,2);assert.equal(census.visibleZeroIntensity,1);assert.equal(census.visiblePositiveIntensity,1);assert.equal(census.groups[0].name,'Entry_Light_Slot');assert.match(f.doc.body.dataset.renderIsolation,/targetCensus/);f.assertRestored();f.qa.dispose();
});
test('requires active freeze and valid populated mode; UI start delegates selected mode',()=>{
 const f=fixture({held:false}),mode=f.doc.getElementById('render-isolation-mode'),start=f.doc.getElementById('render-isolation-start');assert(f.panel&&mode&&start);assert.equal(mode.children.length,Object.keys(RENDER_ISOLATION_MODES).length);
 assert.equal(f.qa.start('residents'),false);assert.deepEqual(f.calls,[]);f.freeze.active=true;assert.equal(f.qa.start('invalid'),false);f.state.empty=true;assert.equal(f.qa.start('residents'),false);assert.equal(f.state.direct,true);
 f.state.empty=false;mode.value='vehicles';start.onclick();assert.equal(f.qa.report().active,true);assert.equal(start.disabled,true);assert.equal(mode.disabled,true);assert.equal(f.state.direct,false);assert.equal(f.qa.start('water'),false);f.qa.stop();assert.equal(start.disabled,false);f.assertRestored();f.qa.dispose();
});
for(const isolation of ['residents','vehicles','interiors','water','pointlights'])test(isolation+': transient visibility, deduplication, three exact windows and no gameplay mutation',()=>{
 const f=fixture(),savedUserData=JSON.stringify(f.target.userData),position=f.camera.position.toArray(),quaternion=f.camera.quaternion.toArray();assert.equal(f.qa.start(isolation),true);
 f.frames(4,()=>{assert.equal(f.target.visible,true);assert.equal(f.child.visible,true);assert.equal(f.hidden.visible,false)});
 f.frames(4,()=>{assert.equal(f.target.visible,false);assert.equal(f.child.visible,false);assert.equal(f.hidden.visible,false)});
 assert.equal(f.target.visible,true);assert.equal(f.child.visible,true);assert.equal(f.hidden.visible,false);
 f.frames(4,()=>assert.equal(f.target.visible,true));const report=f.qa.report();assert.equal(report.active,false);assert.equal(report.last.status,'complete');assert.equal(report.last.targets,3);
 assert.deepEqual(report.last.phases.map(p=>p.name),['baseline-before','variant','baseline-after']);assert.deepEqual(report.last.phases.map(p=>p.profile.timings.render.samples),[3,3,3]);assert.equal(report.results.length,1);assert.equal(f.calls.filter(x=>x==='snapshot').length,3);assert.equal(JSON.stringify(f.target.userData),savedUserData);assert.deepEqual(f.camera.position.toArray(),position);assert.deepEqual(f.camera.quaternion.toArray(),quaternion);f.assertRestored();f.qa.dispose();
});
test('shadows disabled only during variant draw and restore an initially disabled state too',()=>{
 for(const shadows of [true,false]){const f=fixture({shadows});f.qa.start('shadows');f.toVariant();f.frame(()=>assert.equal(f.renderer.shadowMap.enabled,false));assert.equal(f.renderer.shadowMap.enabled,shadows);f.qa.stop();f.assertRestored();f.qa.dispose();}
});
test('resolution changes once entering variant; exact original dimensions and prior OFF profiling restored',()=>{
 const f=fixture({direct:false});f.qa.start('resolution');f.frames(4,()=>assert.equal(f.state.ratio,2));assert.equal(f.state.ratio,1);f.frames(4,()=>assert.equal(f.state.ratio,1));assert.equal(f.state.ratio,2);f.frames(4);assert.equal(f.calls.filter(x=>x==='pixelRatio:1').length,1);
 assert.deepEqual(f.qa.report().last.phases.map(p=>[p.width,p.height]),[[2000,1000],[1000,500],[2000,1000]]);f.assertRestored();f.qa.dispose();
});
test('inactive render always passes through draw and afterFrame does not start a run',()=>{
 const f=fixture();assert.equal(f.qa.render(()=>17),17);f.qa.afterFrame();assert.equal(f.qa.report().active,false);assert.deepEqual(f.calls,[]);f.qa.dispose();
});
test('manual/cancel/hold loss/timeout/camera/projection/hidden/pagehide restore all owned state',()=>{
 for(const reason of ['stop','cancel','hold','timeout','camera','projection','hidden-event','hidden-render','pagehide','dispose']){
  const f=fixture();f.qa.start('resolution');f.toVariant();assert.equal(f.state.ratio,1);
  if(reason==='stop')f.qa.stop('manual');if(reason==='cancel')f.panel.children.find(n=>n.tagName==='BUTTON'&&n.id!=='render-isolation-start').onclick();
  if(reason==='hold'){f.freeze.active=false;f.qa.afterFrame();}if(reason==='timeout'){f.state.time+=110000;f.qa.afterFrame();}
  if(reason==='camera'){f.camera.position.x++;f.qa.afterFrame();}if(reason==='projection'){f.camera.aspect=1;f.camera.updateProjectionMatrix();f.qa.afterFrame();}
  if(reason==='hidden-event'){f.doc.hidden=true;f.doc.fire('visibilitychange');}if(reason==='hidden-render'){f.doc.hidden=true;assert.equal(f.qa.render(()=>23),23);}
  if(reason==='pagehide')f.win.fire('pagehide');if(reason==='dispose')f.qa.dispose();
  assert.equal(f.qa.report().active,false,reason);assert.equal(f.qa.report().last.status,'aborted',reason);f.assertRestored();f.qa.dispose();
 }
});
test('variant draw exception restores target flags/shadows and prior modes before rethrow',()=>{
 for(const mode of ['residents','pointlights','shadows','resolution']){const f=fixture();f.qa.start(mode);f.toVariant();assert.throws(()=>f.qa.render(()=>{throw Error('draw failed')}),/draw failed/);assert.equal(f.qa.report().active,false);assert.equal(f.qa.report().last.status,'aborted');f.assertRestored();f.qa.dispose();}
});
test('phase-end snapshot and resolution-set exceptions abort and restore instead of latching',()=>{
 for(const reason of ['snapshot','pixelRatio:1','reset']){
  const f=fixture();f.qa.start('resolution');f.frames(3);f.state.throwAt=reason;assert.throws(()=>f.frame(),new RegExp('injected '+reason));assert.equal(f.qa.report().active,false,reason);assert.equal(f.qa.report().last.status,'aborted',reason);f.assertRestored();f.qa.dispose();
 }
});
test('start failure restores saved modes and remains cancellable/disposable',()=>{
 const f=fixture();f.state.throwAt='drawProfiling:false';assert.throws(()=>f.qa.start('residents'),/injected/);assert.equal(f.qa.report().active,false);f.assertRestored();f.qa.dispose();
});
test('disposal cleanup survives renderer restoration exception and is idempotent',()=>{
 const f=fixture();f.qa.start('resolution');f.toVariant();f.state.throwAt='pixelRatio:2';assert.throws(()=>f.qa.dispose(),/injected/);assert.equal(f.qa.report().active,false);f.assertRestored();assert.equal(f.panel.parentNode,null);assert.equal(f.doc.body.dataset.renderIsolation,undefined);assert.equal([...f.doc.listeners.values()].reduce((s,x)=>s+x.size,0),0);assert.equal([...f.win.listeners.values()].reduce((s,x)=>s+x.size,0),0);f.qa.dispose();assert.equal(f.qa.start('residents'),false);
});
test('changed baseline draw counts reject completed comparison without retaining it as valid result',()=>{
 const f=fixture();f.qa.start('residents');f.frames(8);f.state.unstable=true;f.frames(4);assert.equal(f.qa.report().last.status,'aborted');assert.match(f.qa.report().last.reason,/Baseline draw totals changed/);assert.equal(f.qa.report().results.length,0);f.assertRestored();f.qa.dispose();
});
test('zero warmup keeps complete sample window in each phase',()=>{
 const f=fixture({warmupFrames:0,sampleFrames:3});f.qa.start('shadows');f.frames(9);assert.equal(f.qa.report().last.status,'complete');assert.deepEqual(f.qa.report().last.phases.map(p=>p.profile.timings.render.samples),[3,3,3]);f.assertRestored();f.qa.dispose();
});
test('production defaults use 45 warmup +121 sample frames in each of three phases',()=>{
 const f=fixture({useDefaults:true});f.qa.start('shadows');f.frames(165);assert.equal(f.calls.filter(x=>x==='snapshot').length,0);f.frame();assert.equal(f.calls.filter(x=>x==='snapshot').length,1);f.frames(166*2);assert.equal(f.qa.report().last.status,'complete');assert.deepEqual(f.qa.report().last.phases.map(p=>p.profile.timings.render.samples),[121,121,121]);f.assertRestored();f.qa.dispose();
});
test('normal disposal removes panel, datasets, document/window listeners and prevents restart',()=>{
 for(const active of [false,true]){const f=fixture();if(active)f.qa.start('water');f.qa.dispose();f.qa.dispose();assert.equal(f.qa.start('water'),false);assert.equal(f.panel.parentNode,null);assert.equal(f.doc.body.dataset.renderIsolation,undefined);assert.equal([...f.doc.listeners.values()].reduce((s,x)=>s+x.size,0),0);assert.equal([...f.win.listeners.values()].reduce((s,x)=>s+x.size,0),0);f.assertRestored();}
});
test('canvas-only resize aborts baseline and half-resolution variant with unchanged camera',()=>{
 for(const mode of ['residents','resolution'])for(const dimension of ['width','height']){
  const f=fixture();f.qa.start(mode);if(mode==='resolution')f.toVariant();const projection=f.camera.projectionMatrix.toArray();f.renderer.domElement[dimension]+=2;f.qa.afterFrame();assert.equal(f.qa.report().active,false);assert.equal(f.qa.report().last.status,'aborted');assert.equal(f.qa.report().results.length,0);assert.deepEqual(f.camera.projectionMatrix.toArray(),projection);f.assertRestored();f.qa.dispose();
 }
});
test('GPU timing and direct-profiling mutations abort instead of mixing measurement modes',()=>{
 for(const initialGpu of [true,false])for(const mutation of ['gpu','direct']){
  const f=fixture({withGpu:true,gpu:initialGpu});f.qa.start('residents');f.toVariant();if(mutation==='gpu')f.state.gpu=!initialGpu;else f.state.direct=true;let drawn=false;f.qa.render(()=>{drawn=true;assert.equal(f.target.visible,true)});assert.equal(drawn,true);assert.equal(f.qa.report().active,false);assert.equal(f.qa.report().last.status,'aborted');assert.equal(f.qa.report().results.length,0);f.assertRestored();f.qa.dispose();
 }
 const f=fixture({withGpu:true,gpu:false});f.qa.start('residents');f.frames(12);assert.equal(f.qa.report().last.status,'complete');assert.equal(f.state.gpu,false);f.qa.dispose();
});
test('target identity changes reject a phase even when counts match; order and duplicates do not',()=>{
 for(const changedAt of [0,1,2])for(const change of ['replace','remove','add']){
  const f=fixture();f.qa.start('vehicles');f.frames(4*changedAt);f.state.targets=change==='replace'?[new T.Group(),f.hidden,f.child]:change==='remove'?[f.target,f.hidden]:[f.target,f.hidden,f.child,new T.Group()];f.frames(4);assert.equal(f.qa.report().active,false);assert.equal(f.qa.report().last.status,'aborted');assert.match(f.qa.report().last.reason,/target membership changed/);assert.equal(f.qa.report().last.phases.length,changedAt);assert.equal(f.qa.report().results.length,0);f.assertRestored();f.qa.dispose();
 }
 const f=fixture();f.qa.start('vehicles');f.state.targets=[null,f.child,f.hidden,f.target,f.hidden];f.frames(12);assert.equal(f.qa.report().last.status,'complete');f.assertRestored();f.qa.dispose();
});
test('shadows and resolution do not invalidate comparison for unrelated target-list changes',()=>{
 for(const mode of ['shadows','resolution']){const f=fixture();f.qa.start(mode);f.state.targets=[new T.Group()];f.frames(12);assert.equal(f.qa.report().last.status,'complete');f.assertRestored();f.qa.dispose();}
});
test('actual input guards block competing QA controls only during a run; own panel, hold stop and Escape pass',()=>{
 const f=fixture(),types=['pointerdown','pointerup','mousedown','mouseup','click','keydown','keyup','change'];
 function dispatch(type,target,path,code){const outcome={prevented:0,stopped:0};const event={type,target,code,preventDefault(){outcome.prevented++},stopImmediatePropagation(){outcome.stopped++}};if(path)event.composedPath=()=>path;for(const fn of f.doc.listeners.get(type)||[])fn(event);return outcome;}
 const external={id:'gpu-timer-qa'};
 for(const type of types){assert.equal(f.doc.listeners.get(type)?.size,1);assert.deepEqual(dispatch(type,external,[external,f.doc.body],'KeyG'),{prevented:0,stopped:0});}
 f.qa.start('residents');
 for(const type of types){
  for(const id of ['gpu-timer-qa','draw-probe-qa','vehicle-detail-batch-qa','unrelated-gameplay']){const target={id};assert.deepEqual(dispatch(type,target,[target,f.doc.body],'KeyG'),{prevented:1,stopped:1},type+' '+id);}
  assert.deepEqual(dispatch(type,external,null,'KeyQ'),{prevented:1,stopped:1},'target-only event '+type);
  for(const own of f.panel.children)assert.deepEqual(dispatch(type,own,[own,f.panel,f.doc.body],'Enter'),{prevented:0,stopped:0},'own panel '+type);
  assert.deepEqual(dispatch(type,f.panel,null,'Space'),{prevented:0,stopped:0},'panel target fallback '+type);
  const hold={id:'render-freeze-qa'},icon={};assert.deepEqual(dispatch(type,icon,[icon,hold,f.doc.body],'Enter'),{prevented:0,stopped:0},'nested hold stop '+type);
  assert.deepEqual(dispatch(type,external,[external,f.doc.body],'Escape'),{prevented:0,stopped:0},'Escape '+type);
 }
 assert.equal(f.qa.report().active,true);const cancel=f.panel.children.find(n=>n.tagName==='BUTTON'&&n.id!=='render-isolation-start');cancel.onclick();assert.equal(f.qa.report().active,false);
 for(const type of types)assert.deepEqual(dispatch(type,external,[external],'KeyG'),{prevented:0,stopped:0});
 f.qa.start('residents');f.qa.dispose();for(const type of types){assert.equal(f.doc.listeners.get(type)?.size,0);assert.deepEqual(dispatch(type,external,[external],'KeyG'),{prevented:0,stopped:0});}f.assertRestored();
});
console.log(JSON.stringify({passed,failed:failures.length,scope:'real THREE objects/camera; mocked renderer/DOM/probe; no browser or GPU'}));
if(failures.length){for(const failure of failures)console.error(failure.error);process.exitCode=1;}
