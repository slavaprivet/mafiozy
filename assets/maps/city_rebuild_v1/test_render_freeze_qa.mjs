// Local render-only QA lifecycle/input tests. Real THREE camera, stub DOM;
// no renderer, browser, GPU or heavy timing workload.
import assert from 'node:assert/strict';
import fs from 'node:fs';
import vm from 'node:vm';
import {pathToFileURL} from 'node:url';
import {allowRenderFreeze,createRenderFreezeQa} from './render_freeze_qa.mjs';
import {coverElapsedTime} from './hero_cover_motion.mjs';
const vendor=(process.env.MAFIOZI_THREE_VENDOR||'D:/codex_release/artist13_hero_first_DEV_20260907/demo/vendor')+'/';
const THREE=await import(pathToFileURL(vendor+'build/three.module.js'));

function dom(){
 const listeners=new Map();
 const doc={listeners,createElement(tag){return {tagName:tag.toUpperCase(),id:'',style:{},attributes:{},children:[],dataset:{},
  setAttribute(k,v){this.attributes[k]=String(v)},append(node){this.children.push(node);node.parentNode=this},
  remove(){if(this.parentNode){this.parentNode.children=this.parentNode.children.filter(n=>n!==this);this.parentNode=null}}};},
  addEventListener(type,fn,options){const capture=typeof options==='boolean'?options:!!options?.capture;const list=listeners.get(type)||[];list.push({fn,capture,options});listeners.set(type,list)},
  removeEventListener(type,fn,options){const capture=typeof options==='boolean'?options:!!options?.capture;listeners.set(type,(listeners.get(type)||[]).filter(item=>item.fn!==fn||item.capture!==capture))},
  fire(type,target,extras={}){
   const event={type,target,defaultPrevented:false,stopped:false,propagationStopped:false,preventDefault(){this.defaultPrevented=true},stopPropagation(){this.propagationStopped=true},stopImmediatePropagation(){this.stopped=true;this.propagationStopped=true},composedPath:()=>[target,doc.body,doc],...extras};
   for(const entry of [...(listeners.get(type)||[])].filter(e=>e.capture)){entry.fn(event);if(event.stopped)break;}
   if(!event.propagationStopped){if(type==='click')target?.onclick?.(event);for(const entry of [...(listeners.get(type)||[])].filter(e=>!e.capture)){entry.fn(event);if(event.stopped)break;}}
   return event;
  }};
 doc.body=doc.createElement('body');return doc;
}
function fixture({href='http://127.0.0.1:18538/world.html?perfqa=1&previewcity=1',probePresent=true,withDetails=false,withGpu=false,withDraw=false,withWheels=false,withStaticMatrices=false,hooks={}}={}){
 const document=dom(),window={location:{href}},camera=new THREE.PerspectiveCamera(55,16/9,.1,1000),calls=[];
 camera.position.set(14,2.7,-8);camera.rotation.set(.15,.6,-.04);
 const state={ready:true,time:1200,throwAt:null,snapshot:{},detailsEnabled:true,gpuEnabled:true,drawEnabled:true,wheelsEnabled:true,staticMatricesEnabled:true};
 const event=name=>{calls.push(name);if(state.throwAt===name)throw new Error('injected '+name)};
 const probe={begin(){event('begin')},end(){event('end')},reset(){event('reset')}};
 if(withGpu){probe.getGpuTimingEnabled=()=>state.gpuEnabled;probe.setGpuTimingEnabled=enabled=>{const changed=state.gpuEnabled!==enabled;state.gpuEnabled=enabled;event('gpu:'+enabled);if(changed)probe.reset();return enabled;};}
 if(withDraw){probe.getDrawProfilingEnabled=()=>state.drawEnabled;probe.setDrawProfilingEnabled=enabled=>{const changed=state.drawEnabled!==enabled;state.drawEnabled=enabled;event('drawProbe:'+enabled);if(changed)probe.reset();return enabled;};}
 const qa=createRenderFreezeQa({document,window,camera,probe:probePresent?probe:null,isReady:()=>{if(state.throwAt==='ready')throw Error('injected ready');return state.ready},releaseControls:()=>event('release'),...(withDetails?{applyVehicleDetails(enabled){state.detailsEnabled=enabled;event('details:'+enabled)}}:{}),...(withWheels?{applyVehicleWheels(enabled){state.wheelsEnabled=enabled;event('wheels:'+enabled)}}:{}),...(withStaticMatrices?{applyStaticMatrices(enabled){state.staticMatricesEnabled=enabled;event('static:'+enabled)}}:{}),getSnapshot:()=>({loaded:239,pixelRatio:1,...state.snapshot}),now:()=>state.time,...hooks});
 const button=document.body.children.find(n=>n.id==='render-freeze-qa');
 const details=document.body.children.find(n=>n.id==='vehicle-detail-batch-qa');
 const gpu=document.body.children.find(n=>n.id==='gpu-timer-qa');
 return {document,window,camera,calls,state,qa,button,details,gpu,drawProbe:document.body.children.find(n=>n.id==='draw-probe-qa'),staticMatrices:document.body.children.find(n=>n.id==='static-matrix-qa'),wheels:document.body.children.find(n=>n.id==='vehicle-wheel-batch-qa'),start(){document.fire('click',button)},toggleDetails(){return document.fire('click',details)},toggleGpu(){return document.fire('click',gpu)},data(){return JSON.parse(document.body.dataset.renderFreeze)}};
}
let passed=0;const failures=[];
function test(name,fn){try{fn();passed++;console.log('PASS '+name)}catch(error){failures.push({name,error});console.error('FAIL '+name+' — '+error.message)}}

test('local + explicit perfqa + identity URL gate; disabled setup is inert',()=>{
 for(const host of ['127.0.0.1','localhost'])assert.equal(allowRenderFreeze('http://'+host+':18538/walk?perfqa=1'),true);
 for(const href of ['https://game.example/walk?perfqa=1','http://localhost.evil/walk?perfqa=1','http://127.0.0.2/walk?perfqa=1','http://localhost/walk','http://localhost/walk?perfqa=0','http://localhost/walk?perfqa=true']){
  assert.equal(allowRenderFreeze(href),false,href);const f=fixture({href});assert.equal(f.qa,null);assert.equal(f.document.body.children.length,0);assert.equal(f.document.listeners.size,0);
 }
 for(const key of ['uid','account_uid','character_uid','initData','init_data','tgWebAppData','world_token','ws_ticket','auth','token','api'])for(const value of ['', 'test'])assert.equal(allowRenderFreeze('http://localhost/walk?perfqa=1&'+key+'='+value),false,key);
 assert.equal(allowRenderFreeze('http://localhost/walk?perfqa=1&%63haracter_uid=123'),false,'encoded character identity key');
 const f=fixture({probePresent:false});assert.equal(f.qa,null);assert.equal(f.document.body.children.length,0);
});
test('cannot hold before loaded; start releases controls/resets samples and records actual camera',()=>{
 const f=fixture();f.state.ready=false;f.start();assert.equal(f.qa.active,false);assert.equal(f.qa.render(()=>assert.fail('not active')),false);assert.deepEqual(f.calls,[]);assert.match(f.button.textContent,/загрузки/);
 f.state.ready=true;f.start();assert.equal(f.qa.active,true);assert.deepEqual(f.calls,['release','reset']);assert.equal(f.button.attributes['aria-pressed'],'true');
 const data=f.data();assert.equal(data.active,true);assert.equal(data.scope,'render-only');assert.equal(data.snapshot.loaded,239);assert.deepEqual(data.snapshot.camera,f.camera.position.toArray());assert.deepEqual(data.snapshot.projection,f.camera.projectionMatrix.toArray());
 f.qa.dispose();
});
test('pending NPC or traffic models cannot start a hold; loaded retry can start',()=>{
 for(const pending of [{npc:{pending:1}},{traffic:{loading:1}},{npc:{pending:3},traffic:{loading:2}}]){
  const f=fixture();f.state.snapshot=pending;f.start();assert.equal(f.qa.active,false);assert.equal(f.qa.render(()=>assert.fail('pending draw')),false);assert.match(f.button.textContent,/жителей и автомобилей/);
  assert.equal(f.calls.filter(x=>x==='reset').length,0,'unloaded snapshot never starts profiling');
  f.state.snapshot={npc:{pending:0,seen:72,visible:16},traffic:{loading:0,actors:27}};f.start();assert.equal(f.qa.active,true);assert.equal(f.calls.filter(x=>x==='reset').length,1);assert.equal(f.data().snapshot.npc.pending,0);assert.equal(f.data().snapshot.traffic.loading,0);f.qa.dispose();
 }
});
test('held draw restores exact camera; bracketed samples, published frame count and retained geometry view',()=>{
 const f=fixture(),position=f.camera.position.toArray(),quaternion=f.camera.quaternion.toArray(),projection=f.camera.projectionMatrix.toArray();f.start();
 for(let i=0;i<30;i++){
  f.camera.position.set(100+i,-6,24);f.camera.rotation.set(.8,1.4,.2);
  assert.equal(f.qa.render(()=>{f.calls.push('draw');assert.deepEqual(f.camera.position.toArray(),position);assert.deepEqual(f.camera.quaternion.toArray(),quaternion);assert.deepEqual(f.camera.projectionMatrix.toArray(),projection)}),true);
 }
 assert.deepEqual(f.calls.slice(2,5),['begin','draw','end']);assert.equal(f.calls.filter(x=>x==='draw').length,30);assert.equal(f.data().frames,30);assert.equal(f.data().active,true);f.qa.dispose();
});
test('button stop and explicit stop release/reset once; inactive render does not consume frame',()=>{
 const f=fixture();f.start();f.start();assert.equal(f.qa.active,false);assert.deepEqual(f.calls,['release','reset','release','reset']);assert.equal(f.data().scope,'gameplay');
 f.qa.stop();assert.equal(f.calls.length,4);assert.equal(f.qa.render(()=>assert.fail('inactive draw')),false);
 f.start();f.qa.stop();assert.equal(f.calls.filter(x=>x==='release').length,4);assert.equal(f.calls.filter(x=>x==='reset').length,4);f.qa.dispose();
});
test('Escape, exact timeout, resize/projection change and readiness loss all release/reset',()=>{
 for(const reason of ['Escape','timeout','resize','not ready']){
  const f=fixture();f.start();
  if(reason==='Escape'){const e=f.document.fire('keydown',f.document.body,{code:'Escape'});assert(e.defaultPrevented&&e.stopped)}
  if(reason==='timeout'){f.state.time+=119999;assert.equal(f.qa.render(()=>{}),true);f.state.time++;assert.equal(f.qa.render(()=>assert.fail('expired draw')),false)}
  if(reason==='resize'){f.camera.aspect=1;f.camera.updateProjectionMatrix();assert.equal(f.qa.render(()=>assert.fail('different projection draw')),false)}
  if(reason==='not ready'){f.state.ready=false;assert.equal(f.qa.render(()=>assert.fail('unloaded draw')),false)}
  assert.equal(f.qa.active,false,reason);assert.equal(f.calls.filter(x=>x==='release').length,2,reason);assert.equal(f.calls.filter(x=>x==='reset').length,2,reason);f.qa.dispose();
 }
});
test('gameplay keyboard/pointer/touch inputs blocked only during hold; both QA buttons remain clickable',()=>{
 const f=fixture(),target=f.document.createElement('canvas'),batch=f.document.createElement('button');batch.id='static-batch-qa';f.document.body.append(batch);let batches=0;batch.onclick=()=>batches++;
 const types=['keydown','keyup','pointerdown','pointerup','mousedown','mouseup','click','mousemove','wheel','touchstart','touchmove'];
 for(const type of types)assert.equal(f.document.fire(type,target,{code:'KeyW'}).stopped,false,'normal '+type);
 f.start();
 for(const type of types){const e=f.document.fire(type,target,{code:'KeyW'});assert(e.defaultPrevented&&e.stopped,'held '+type);}
 const inner=f.document.createElement('span');const e=f.document.fire('click',batch,{composedPath:()=>[inner,batch,f.document.body]});assert.equal(e.stopped,false);assert.equal(batches,1);assert.equal(f.qa.active,true);
 f.document.fire('click',f.button);assert.equal(f.qa.active,false);
 for(const type of types)assert.equal(f.document.fire(type,target,{code:'KeyW'}).stopped,false,'released '+type);f.qa.dispose();
});
test('focusing either QA button never lets movement/weapon keys reach continuing source-world handlers',()=>{
 const f=fixture(),batch=f.document.createElement('button');batch.id='static-batch-qa';f.document.body.append(batch);f.start();
 for(const target of [f.button,batch])for(const type of ['keydown','keyup'])for(const code of ['KeyW','KeyE','KeyQ','KeyG','ArrowUp']){
  const e=f.document.fire(type,target,{code});assert(e.defaultPrevented&&e.stopped,target.id+' '+type+' '+code);
 }
 f.qa.dispose();
});
test('draw exception releases hold and rethrows; sampling end still executes',()=>{
 const f=fixture();f.start();const error=new Error('draw failed');assert.throws(()=>f.qa.render(()=>{throw error}),e=>e===error);
 assert.equal(f.qa.active,false);assert.deepEqual(f.calls,['release','reset','begin','end','release','reset']);assert.equal(f.data().active,false);f.qa.dispose();
});
test('QA button keyboard activation/focus remains native but never bubbles to source handlers',()=>{
 const f=fixture(),batch=f.document.createElement('button');batch.id='static-batch-qa';f.document.body.append(batch);f.start();let sourceKeys=0;
 f.document.addEventListener('keydown',()=>sourceKeys++);f.document.addEventListener('keyup',()=>sourceKeys++);
 for(const target of [f.button,batch])for(const type of ['keydown','keyup'])for(const code of ['Tab','Enter','Space']){
  const e=f.document.fire(type,target,{code});assert.equal(e.defaultPrevented,false,'native activation/focus allowed');assert.equal(e.propagationStopped,true);assert.equal(sourceKeys,0,'no source-world key queued');
 }
 f.qa.dispose();
});
test('probe begin/end or readiness exception cannot leave the input-blocking hold latched',()=>{
 for(const phase of ['begin','end','ready']){
  const f=fixture();f.start();f.state.throwAt=phase;assert.throws(()=>f.qa.render(()=>{}),new RegExp('injected '+phase));assert.equal(f.qa.active,false,phase+' exception must release hold');
  f.state.throwAt=null;assert.equal(f.document.fire('keydown',f.document.body,{code:'KeyW'}).stopped,false);f.qa.dispose();
 }
});
test('dispose is idempotent, releases active hold, removes UI/dataset and all capture listeners',()=>{
 for(const active of [false,true]){
  const f=fixture();if(active)f.start();f.qa.dispose();f.qa.dispose();assert.equal(f.qa.active,false);assert.equal(f.document.body.children.includes(f.button),false);assert.equal(f.document.body.dataset.renderFreeze,undefined);
  assert.equal([...f.document.listeners.values()].flat().length,0);assert.equal(f.qa.render(()=>assert.fail('disposed draw')),false);f.button.onclick?.();assert.equal(f.qa.active,false);
 }
});
test('vehicle-detail comparison is optional and cannot apply before hold or when loading',()=>{
 const absent=fixture();assert.equal(absent.details,undefined);assert.equal(absent.document.body.dataset.vehicleDetailComparison,undefined);absent.qa.dispose();
 const denied=fixture({withDetails:true,href:'https://game.example/?perfqa=1'});assert.equal(denied.details,undefined);assert.equal(denied.qa,null);
 const f=fixture({withDetails:true});assert.equal(f.document.body.dataset.vehicleDetailComparison,'optimized');assert.deepEqual(f.calls,[]);
 f.toggleDetails();assert.deepEqual(f.calls,[]);assert.match(f.details.textContent,/Сначала зафиксируйте/);assert.equal(f.state.detailsEnabled,true);
 f.state.ready=false;f.start();f.toggleDetails();assert.deepEqual(f.calls,[]);f.state.ready=true;f.state.snapshot={npc:{pending:1}};f.start();f.toggleDetails();assert.equal(f.calls.some(x=>x.startsWith('details:')),false);f.qa.dispose();
});
test('vehicle-detail callback applies before probe reset; two-way A/B preserves hold and camera',()=>{
 const f=fixture({withDetails:true}),position=f.camera.position.toArray();f.start();f.toggleDetails();
 assert.deepEqual(f.calls,['release','reset','details:false','reset']);assert.equal(f.qa.active,true);assert.equal(f.document.body.dataset.vehicleDetailComparison,'previous');assert.equal(f.details.attributes['aria-pressed'],'false');
 f.qa.render(()=>assert.deepEqual(f.camera.position.toArray(),position));assert.equal(f.state.detailsEnabled,false);assert.equal(f.calls.filter(x=>x.startsWith('details:')).length,1,'draw does not toggle');
 f.toggleDetails();assert.deepEqual(f.calls.slice(-2),['details:true','reset']);assert.equal(f.qa.active,true);assert.equal(f.document.body.dataset.vehicleDetailComparison,'optimized');assert.equal(f.details.attributes['aria-pressed'],'true');
 f.qa.stop();assert.deepEqual(f.calls.slice(-2),['release','reset'],'already enabled needs no redundant apply');f.qa.dispose();
});
test('vehicle-detail button pointer activation works; gameplay keys block and native keyboard activation stays isolated',()=>{
 const f=fixture({withDetails:true});f.start();const inner=f.document.createElement('span');let sourceKeys=0;f.document.addEventListener('keydown',()=>sourceKeys++);f.document.addEventListener('keyup',()=>sourceKeys++);
 for(const type of ['pointerdown','pointerup','mousedown','mouseup'])assert.equal(f.document.fire(type,f.details).stopped,false,type);
 const click=f.document.fire('click',f.details,{composedPath:()=>[inner,f.details,f.document.body]});assert.equal(click.stopped,false);assert.equal(f.state.detailsEnabled,false);
 for(const type of ['keydown','keyup'])for(const code of ['KeyW','KeyE','KeyQ','KeyG','ArrowUp']){const e=f.document.fire(type,f.details,{code});assert(e.defaultPrevented&&e.stopped);assert.equal(sourceKeys,0);}
 for(const type of ['keydown','keyup'])for(const code of ['Tab','Enter','Space']){const e=f.document.fire(type,f.details,{code});assert.equal(e.defaultPrevented,false);assert.equal(e.propagationStopped,true);assert.equal(sourceKeys,0);}
 f.qa.dispose();
});
test('all normal and error exits restore optimized vehicle details before release/reset',()=>{
 for(const reason of ['button','stop','Escape','timeout','resize','not ready','dispose','draw error','begin error','end error','ready error']){
  const f=fixture({withDetails:true});f.start();f.toggleDetails();const start=f.calls.length;
  if(reason==='button')f.start();
  if(reason==='stop')f.qa.stop();
  if(reason==='Escape')f.document.fire('keydown',f.details,{code:'Escape'});
  if(reason==='timeout'){f.state.time+=120000;assert.equal(f.qa.render(()=>assert.fail('expired')),false)}
  if(reason==='resize'){f.camera.aspect=.5;f.camera.updateProjectionMatrix();assert.equal(f.qa.render(()=>assert.fail('resized')),false)}
  if(reason==='not ready'){f.state.ready=false;assert.equal(f.qa.render(()=>assert.fail('unloaded')),false)}
  if(reason==='dispose')f.qa.dispose();
  if(reason==='draw error')assert.throws(()=>f.qa.render(()=>{throw Error('draw error')}),/draw error/);
  if(['begin error','end error','ready error'].includes(reason)){f.state.throwAt=reason.split(' ')[0];assert.throws(()=>f.qa.render(()=>{}),/injected/);f.state.throwAt=null;}
  assert.equal(f.qa.active,false,reason);assert.equal(f.state.detailsEnabled,true,reason);assert.deepEqual(f.calls.slice(-3),['details:true','release','reset'],reason);assert.equal(f.calls.slice(start).filter(x=>x==='details:true').length,1,reason);
  if(reason!=='dispose')assert.equal(f.document.body.dataset.vehicleDetailComparison,'optimized');
  f.qa.dispose();f.qa.dispose();assert.equal(f.document.body.children.includes(f.details),false);assert.equal(f.document.body.dataset.vehicleDetailComparison,undefined);assert.equal([...f.document.listeners.values()].flat().length,0);f.details.onclick?.();assert.equal(f.state.detailsEnabled,true);
 }
});
test('vehicle-detail label recovers after an early click once hold starts',()=>{
 const f=fixture({withDetails:true});f.toggleDetails();f.start();assert.equal(f.qa.active,true);assert.match(f.details.textContent,/Автодетали:/);f.qa.dispose();
});
test('failed vehicle-detail toggle restores optimized state and releases input blocking',()=>{
 const f=fixture({withDetails:true});f.start();f.state.throwAt='details:false';assert.throws(()=>f.toggleDetails(),/injected details:false/);
 assert.equal(f.qa.active,false,'callback error must release hold');assert.equal(f.state.detailsEnabled,true,'callback rollback to optimized');assert.equal(f.document.fire('keydown',f.document.body,{code:'KeyW'}).stopped,false);f.state.throwAt=null;f.qa.dispose();
});
test('shadow comparison buttons and hold hooks restore on timeout and error',()=>{
 const events=[],f=fixture({hooks:{onHoldStart:()=>events.push('start'),onHoldEnd:()=>events.push('end')}}),vehicle=f.document.createElement('button'),building=f.document.createElement('button');vehicle.id='vehicle-shadow-qa';building.id='building-shadow-qa';f.document.body.append(vehicle);f.document.body.append(building);let vehicleEnabled=true,buildingEnabled=true;vehicle.onclick=()=>{vehicleEnabled=!vehicleEnabled;};building.onclick=()=>{buildingEnabled=!buildingEnabled;};
 f.state.snapshot={npc:{pending:1}};f.start();assert.deepEqual(events,[]);f.state.snapshot={};f.start();assert.deepEqual(events,['start']);f.document.fire('click',vehicle);f.document.fire('click',building);assert.equal(vehicleEnabled,false);assert.equal(buildingEnabled,false);for(const button of [vehicle,building]){assert.equal(f.document.fire('pointerdown',button).stopped,false);assert.equal(f.document.fire('keydown',button,{code:'KeyW'}).stopped,true);for(const code of ['Enter','Space']){const e=f.document.fire('keydown',button,{code});assert.equal(e.defaultPrevented,false);assert.equal(e.propagationStopped,true);}}
 f.state.time+=120000;f.qa.render(()=>{});assert.deepEqual(events,['start','end']);f.qa.stop();assert.equal(events.length,2);f.qa.dispose();
 const fault=fixture({hooks:{onHoldStart(){throw Error('start failure')},onHoldEnd:()=>events.push('error cleanup')}});assert.throws(()=>fault.start(),/start failure/);assert.equal(fault.qa.active,false);assert.equal(events.at(-1),'error cleanup');fault.qa.dispose();
});

test('GPU timer button is optional, hold-only, resets through probe setter and keeps native keyboard isolated',()=>{
 const absent=fixture();assert.equal(absent.gpu,undefined);absent.qa.dispose();const f=fixture({withGpu:true});assert.equal(f.gpu.style.top,'160px');f.toggleGpu();assert.equal(f.state.gpuEnabled,true);assert.deepEqual(f.calls,[]);
 f.state.ready=false;f.start();f.toggleGpu();assert.deepEqual(f.calls,[]);f.state.ready=true;f.start();const position=f.camera.position.toArray();f.toggleGpu();assert.equal(f.state.gpuEnabled,false);assert.deepEqual(f.calls.slice(-2),['gpu:false','reset']);assert.equal(f.document.body.dataset.gpuTimerComparison,'disabled');assert.equal(f.qa.active,true);f.qa.render(()=>assert.deepEqual(f.camera.position.toArray(),position));
 let source=0;f.document.addEventListener('keydown',()=>source++);f.document.addEventListener('keyup',()=>source++);
 for(const type of ['pointerdown','pointerup','mousedown','mouseup'])assert.equal(f.document.fire(type,f.gpu).stopped,false);
 for(const type of ['keydown','keyup'])for(const code of ['KeyW','KeyE','KeyQ','KeyG'])assert(f.document.fire(type,f.gpu,{code}).stopped);
 for(const type of ['keydown','keyup'])for(const code of ['Tab','Enter','Space']){const e=f.document.fire(type,f.gpu,{code});assert(!e.defaultPrevented&&e.propagationStopped);}assert.equal(source,0);
 f.toggleGpu();assert.equal(f.state.gpuEnabled,true);assert.equal(f.document.body.dataset.gpuTimerComparison,'enabled');f.qa.dispose();assert.equal(f.document.body.dataset.gpuTimerComparison,undefined);assert.equal(f.gpu.parentNode,null);
});
test('GPU timer restores ON on every hold exit/error and callbacks cannot prevent control/listener cleanup',()=>{
 for(const reason of ['button','stop','Escape','timeout','resize','not ready','dispose','draw error','begin error','end error','ready error','toggle error','restore error','details restore error']){
  const f=fixture({withGpu:true,withDetails:true});f.start();f.toggleGpu();
  if(reason==='button')f.start();if(reason==='stop')f.qa.stop();if(reason==='Escape')f.document.fire('keydown',f.gpu,{code:'Escape'});
  if(reason==='timeout'){f.state.time+=120000;f.qa.render(()=>{});}if(reason==='resize'){f.camera.aspect=.5;f.camera.updateProjectionMatrix();f.qa.render(()=>{});}if(reason==='not ready'){f.state.ready=false;f.qa.render(()=>{});}if(reason==='dispose')f.qa.dispose();
  if(reason==='draw error')assert.throws(()=>f.qa.render(()=>{throw Error('draw failed')}));
  if(['begin error','end error','ready error'].includes(reason)){f.state.throwAt=reason.split(' ')[0];assert.throws(()=>f.qa.render(()=>{}));}
  if(reason==='toggle error'){f.state.throwAt='gpu:true';assert.throws(()=>f.toggleGpu());}
  if(reason==='restore error'){f.state.throwAt='gpu:true';assert.throws(()=>f.qa.dispose());}
  if(reason==='details restore error'){f.toggleDetails();f.state.throwAt='details:true';assert.throws(()=>f.qa.stop());}
  assert.equal(f.qa.active,false,reason);assert.equal(f.state.gpuEnabled,true,reason);assert.equal(f.document.fire('keydown',f.document.body,{code:'KeyW'}).stopped,false,reason);f.state.throwAt=null;f.qa.dispose();f.qa.dispose();assert.equal([...f.document.listeners.values()].flat().length,0);assert.equal(f.gpu.parentNode,null);assert.equal(f.document.body.dataset.gpuTimerComparison,undefined);
 }
 const f=fixture({withGpu:true,hooks:{onHoldStart(){throw Error('hold-start failure')}}});assert.throws(()=>f.start());assert.equal(f.qa.active,false);assert.equal(f.state.gpuEnabled,true);f.qa.dispose();
});

test('wheel comparison is opt-in, hold-only, resets samples and preserves native control inputs',()=>{
 assert.equal(fixture().wheels,undefined);
 const f=fixture({withWheels:true});f.document.fire('click',f.wheels);assert(!f.calls.includes('wheels:false'));f.start();
 for(const key of ['Enter','Space','Tab']){const event=f.document.fire('keydown',f.wheels,{code:key});assert(!event.defaultPrevented);assert(event.propagationStopped);}
 f.document.fire('click',f.wheels);assert.equal(f.state.wheelsEnabled,false);assert.equal(f.document.body.dataset.vehicleWheelComparison,'previous');assert.equal(f.calls.at(-1),'reset');
 f.document.fire('click',f.wheels);assert.equal(f.state.wheelsEnabled,true);assert.equal(f.document.body.dataset.vehicleWheelComparison,'optimized');f.qa.dispose();assert.equal(f.document.body.dataset.vehicleWheelComparison,undefined);
});
test('wheel optimization restores on every hold exit, including failures of other controls',()=>{
 for(const reason of ['manual','Escape','timeout','projection','not ready','draw error','dispose','details restore error']){
  const f=fixture({withWheels:true,withDetails:true,withGpu:true});f.start();f.document.fire('click',f.wheels);
  const stop=()=>{if(reason==='Escape')f.document.fire('keydown',f.document.body,{code:'Escape'});else if(reason==='timeout'){f.state.time+=120000;f.qa.render(()=>{});}else if(reason==='projection'){f.camera.fov=60;f.camera.updateProjectionMatrix();f.qa.render(()=>{});}else if(reason==='not ready'){f.state.ready=false;f.qa.render(()=>{});}else if(reason==='draw error')f.qa.render(()=>{throw Error('draw');});else if(reason==='dispose')f.qa.dispose();else if(reason==='details restore error'){f.toggleDetails();f.state.throwAt='details:true';f.qa.stop();}else f.qa.stop();};
  if(reason.includes('error'))assert.throws(stop);else stop();assert.equal(f.qa.active,false,reason);assert.equal(f.state.wheelsEnabled,true,reason);assert.equal(f.state.gpuEnabled,true,reason);f.state.throwAt=null;f.qa.dispose();
 }
 const f=fixture({withWheels:true});f.start();f.state.throwAt='wheels:false';assert.throws(()=>f.document.fire('click',f.wheels));assert.equal(f.qa.active,false);assert.equal(f.state.wheelsEnabled,true);f.state.throwAt=null;f.qa.dispose();
});
const staticFixture=options=>fixture({withStaticMatrices:true,href:'http://127.0.0.1:18538/world.html?perfqa=1&previewcity=1&staticmatrix=1',...options});
test('static matrices require exact local perfqa+staticmatrix opt-in, are hold-only and preserve wheel position',()=>{
 for(const options of [{withStaticMatrices:false},{href:'http://localhost/world.html?perfqa=1'},{href:'http://localhost/world.html?perfqa=1&staticmatrix=0'},{href:'http://localhost/world.html?perfqa=1&staticmatrix=true'},{href:'https://game.example/?perfqa=1&staticmatrix=1'},{href:'http://localhost/?staticmatrix=1'},{href:'http://localhost/?perfqa=1&staticmatrix=1&uid='}]){const f=staticFixture(options);assert.equal(f.staticMatrices,undefined);assert.equal(f.document.body.dataset.staticMatrixComparison,undefined);f.qa?.dispose();}
 const f=staticFixture({withWheels:true});assert.equal(f.staticMatrices.style.top,'236px');assert.equal(f.wheels.style.top,'198px');assert.equal(f.document.body.dataset.staticMatrixComparison,'optimized');assert.deepEqual(f.calls,[]);
 f.document.fire('click',f.staticMatrices);assert.deepEqual(f.calls,[]);assert.match(f.staticMatrices.textContent,/Сначала зафиксируйте/);
 f.state.snapshot={npc:{pending:1}};f.start();f.document.fire('click',f.staticMatrices);assert.equal(f.calls.some(c=>c.startsWith('static:')),false);
 f.state.snapshot={};f.start();assert.match(f.staticMatrices.textContent,/Статика:/);
 const camera=f.camera.position.toArray();f.document.fire('click',f.staticMatrices);assert.equal(f.state.staticMatricesEnabled,false);assert.deepEqual(f.calls.slice(-2),['static:false','reset']);assert.equal(f.document.body.dataset.staticMatrixComparison,'previous');assert.equal(f.qa.active,true);
 f.qa.render(()=>assert.deepEqual(f.camera.position.toArray(),camera));f.document.fire('click',f.staticMatrices);assert.equal(f.state.staticMatricesEnabled,true);assert.deepEqual(f.calls.slice(-2),['static:true','reset']);assert.equal(f.document.body.dataset.staticMatrixComparison,'optimized');f.qa.dispose();assert.equal(f.document.body.dataset.staticMatrixComparison,undefined);assert.equal(f.staticMatrices.parentNode,null);f.staticMatrices.onclick();assert.equal(f.state.staticMatricesEnabled,true);
});
test('static matrix pointer/native activation stays isolated from gameplay keys during hold',()=>{
 const f=staticFixture();f.start();let sourceKeys=0;f.document.addEventListener('keydown',()=>sourceKeys++);f.document.addEventListener('keyup',()=>sourceKeys++);
 for(const type of ['pointerdown','pointerup','mousedown','mouseup'])assert.equal(f.document.fire(type,f.staticMatrices).stopped,false);
 for(const type of ['keydown','keyup'])for(const code of ['Enter','Space','Tab']){const event=f.document.fire(type,f.staticMatrices,{code});assert(!event.defaultPrevented&&event.propagationStopped);}
 for(const type of ['keydown','keyup'])for(const code of ['KeyE','KeyW','KeyQ','KeyG','ArrowUp'])assert(f.document.fire(type,f.staticMatrices,{code}).stopped);assert.equal(sourceKeys,0);f.qa.dispose();
});
test('all static matrix exits restore initial ON with wheel/GPU/details even if another restoration throws',()=>{
 for(const reason of ['button','stop','Escape','timeout','projection','not ready','dispose','draw error','begin error','end error','ready error','toggle error','restore error','details restore error','wheels restore error','gpu restore error']){
  const f=staticFixture({withWheels:true,withDetails:true,withGpu:true});f.start();f.document.fire('click',f.staticMatrices);f.document.fire('click',f.wheels);f.toggleDetails();f.toggleGpu();
  const end=()=>{
   if(reason==='button')f.start();else if(reason==='Escape')f.document.fire('keydown',f.staticMatrices,{code:'Escape'});
   else if(reason==='timeout'){f.state.time+=120000;f.qa.render(()=>{});}else if(reason==='projection'){f.camera.aspect=.5;f.camera.updateProjectionMatrix();f.qa.render(()=>{});}else if(reason==='not ready'){f.state.ready=false;f.qa.render(()=>{});}else if(reason==='dispose')f.qa.dispose();else if(reason==='draw error')f.qa.render(()=>{throw Error('draw failed');});
   else if(['begin error','end error','ready error'].includes(reason)){f.state.throwAt=reason.split(' ')[0];f.qa.render(()=>{});}
   else if(reason==='toggle error'){f.state.throwAt='static:true';f.document.fire('click',f.staticMatrices);}
   else if(reason==='restore error'){f.state.throwAt='static:true';f.qa.dispose();}
   else if(reason==='details restore error'){f.state.throwAt='details:true';f.qa.stop();}else if(reason==='wheels restore error'){f.state.throwAt='wheels:true';f.qa.stop();}else if(reason==='gpu restore error'){f.state.throwAt='gpu:true';f.qa.stop();}else f.qa.stop();
  };
  if(reason.includes('error'))assert.throws(end);else end();assert.equal(f.qa.active,false,reason);assert.equal(f.state.staticMatricesEnabled,true,reason);assert.equal(f.state.wheelsEnabled,true,reason);assert.equal(f.state.detailsEnabled,true,reason);assert.equal(f.state.gpuEnabled,true,reason);assert.equal(f.document.fire('keydown',f.document.body,{code:'KeyW'}).stopped,false);f.state.throwAt=null;f.qa.dispose();f.qa.dispose();assert.equal([...f.document.listeners.values()].flat().length,0);assert.equal(f.document.body.dataset.staticMatrixComparison,undefined);assert.equal(f.staticMatrices.parentNode,null);
 }
 const toggle=staticFixture();toggle.start();toggle.state.throwAt='static:false';assert.throws(()=>toggle.document.fire('click',toggle.staticMatrices));assert.equal(toggle.state.staticMatricesEnabled,true);assert.equal(toggle.qa.active,false);toggle.state.throwAt=null;toggle.qa.dispose();
 const start=staticFixture({hooks:{onHoldStart(){throw Error('start failed')}}});assert.throws(()=>start.start());assert.equal(start.state.staticMatricesEnabled,true);assert.equal(start.qa.active,false);start.qa.dispose();
});
test('draw probe is optional and hold-only; two-way mode changes reset samples and isolate all inputs',()=>{
 const absent=fixture();assert.equal(absent.drawProbe,undefined);assert.equal(absent.document.body.dataset.drawProbeComparison,undefined);absent.qa.dispose();
 const denied=fixture({withDraw:true,href:'https://game.example/?perfqa=1'});assert.equal(denied.qa,null);assert.equal(denied.drawProbe,undefined);
 const f=fixture({withDraw:true}),toggle=()=>f.document.fire('click',f.drawProbe);assert.equal(f.drawProbe.style.top,'312px');assert.equal(f.document.body.dataset.drawProbeComparison,'detailed');toggle();assert.deepEqual(f.calls,[]);assert.equal(f.state.drawEnabled,true);
 f.state.ready=false;f.start();toggle();assert.deepEqual(f.calls,[]);f.state.ready=true;f.state.snapshot={npc:{pending:1}};f.start();toggle();assert(!f.calls.some(x=>x.startsWith('drawProbe:')));f.state.snapshot={};f.start();assert.match(f.drawProbe.textContent,/Замер каждой/);
 const position=f.camera.position.toArray(),quaternion=f.camera.quaternion.toArray();toggle();assert.equal(f.qa.active,true);assert.equal(f.state.drawEnabled,false);assert.deepEqual(f.calls.slice(-2),['drawProbe:false','reset']);assert.equal(f.document.body.dataset.drawProbeComparison,'frame-only');assert.equal(f.drawProbe.attributes['aria-pressed'],'false');
 f.qa.render(()=>{assert.deepEqual(f.camera.position.toArray(),position);assert.deepEqual(f.camera.quaternion.toArray(),quaternion);});let source=0;for(const type of ['keydown','keyup'])f.document.addEventListener(type,()=>source++);
 for(const type of ['pointerdown','pointerup','mousedown','mouseup'])assert.equal(f.document.fire(type,f.drawProbe).stopped,false);
 for(const type of ['keydown','keyup'])for(const code of ['KeyW','KeyE','KeyQ','KeyG','ArrowUp']){const e=f.document.fire(type,f.drawProbe,{code});assert(e.stopped&&e.defaultPrevented);}
 for(const type of ['keydown','keyup'])for(const code of ['Tab','Enter','Space']){const e=f.document.fire(type,f.drawProbe,{code});assert(!e.defaultPrevented&&e.propagationStopped);}assert.equal(source,0);
 const child=f.document.createElement('span');f.document.fire('click',f.drawProbe,{composedPath:()=>[child,f.drawProbe,f.document.body]});assert.equal(f.state.drawEnabled,true);assert.deepEqual(f.calls.slice(-2),['drawProbe:true','reset']);assert.equal(f.document.body.dataset.drawProbeComparison,'detailed');
 f.qa.dispose();assert.equal(f.drawProbe.parentNode,null);assert.equal(f.document.body.dataset.drawProbeComparison,undefined);f.drawProbe.onclick();assert.equal(f.state.drawEnabled,true);
});
test('draw probe restores ON on all exits and despite other-control restore errors; cleanup remains complete',()=>{
 for(const reason of ['button','stop','Escape','timeout','projection','not ready','draw error','begin error','end error','ready error','dispose','toggle error','draw restore error','details restore error','wheels restore error','static restore error','gpu restore error','hold end error','release error','reset error']){
  const f=staticFixture({withDraw:true,withDetails:true,withWheels:true,withGpu:true,hooks:reason==='hold end error'?{onHoldEnd(){throw Error('hold end failure')}}:{}});f.start();f.document.fire('click',f.drawProbe);const before=f.calls.length;
  if(reason==='button')f.start();if(reason==='stop')f.qa.stop();if(reason==='Escape')f.document.fire('keydown',f.drawProbe,{code:'Escape'});
  if(reason==='timeout'){f.state.time+=120000;f.qa.render(()=>{});}if(reason==='projection'){f.camera.aspect=.5;f.camera.updateProjectionMatrix();f.qa.render(()=>{});}if(reason==='not ready'){f.state.ready=false;f.qa.render(()=>{});}if(reason==='dispose')f.qa.dispose();
  if(reason==='draw error')assert.throws(()=>f.qa.render(()=>{throw Error('draw failure')}));
  if(['begin error','end error','ready error'].includes(reason)){f.state.throwAt=reason.split(' ')[0];assert.throws(()=>f.qa.render(()=>{}));}
  if(reason==='toggle error'){f.state.throwAt='drawProbe:true';assert.throws(()=>f.document.fire('click',f.drawProbe));}
  if(reason==='draw restore error'){f.state.throwAt='drawProbe:true';assert.throws(()=>f.qa.dispose());}
  for(const [name,button,error]of [['details restore error',f.details,'details:true'],['wheels restore error',f.wheels,'wheels:true'],['static restore error',f.staticMatrices,'static:true'],['gpu restore error',f.gpu,'gpu:true']])if(reason===name){f.document.fire('click',button);f.state.throwAt=error;assert.throws(()=>f.qa.stop());}
  if(reason==='hold end error')assert.throws(()=>f.qa.stop());if(reason==='release error'||reason==='reset error'){f.state.throwAt=reason.split(' ')[0];assert.throws(()=>f.qa.stop());}
  assert.equal(f.qa.active,false,reason);assert.equal(f.state.drawEnabled,true,reason);assert(f.calls.slice(before).includes('drawProbe:true'),reason);assert.equal(f.document.fire('keydown',f.document.body,{code:'KeyW'}).stopped,false,reason);
  f.state.throwAt=null;f.qa.dispose();f.qa.dispose();assert.equal(f.drawProbe.parentNode,null);assert.equal(f.document.body.dataset.drawProbeComparison,undefined);assert.equal([...f.document.listeners.values()].flat().length,0);
 }
 const f=fixture({withDraw:true,hooks:{onHoldStart(){throw Error('start failure')}}});assert.throws(()=>f.start());assert.equal(f.qa.active,false);assert.equal(f.state.drawEnabled,true);f.qa.dispose();
});

test('actual static matrix walk setup remains opt-in and updates exposed counts only on comparison',()=>{
 const source=fs.readFileSync(new URL('./walk_preview.mjs',import.meta.url),'utf8').replace(/\r/g,'');
 const expression=source.match(/const staticMatrixOptimization=([^;]+);/)?.[1];assert(expression);
 for(const [href,expected] of [['http://localhost/?perfqa=1&staticmatrix=1',true],['http://localhost/?perfqa=1',false],['http://localhost/?staticmatrix=1',false],['http://localhost/?perfqa=1&staticmatrix=0',false],['https://game.example/?perfqa=1&staticmatrix=1',false],['http://localhost/?perfqa=1&staticmatrix=1&token=x',false]])for(const batching of [false,true]){const url=new URL(href);assert.equal(vm.runInNewContext(expression,{staticRenderBatching:batching,allowRenderFreeze,location:{href,search:url.search},URLSearchParams}),batching&&expected);}
 assert(source.includes('applyStaticMatrices:staticMatrixOptimization?enabled=>{staticRenderBatches?.setLocalMatrixOptimizationEnabled(enabled);if(staticRenderBatches)document.body.dataset.staticRenderBatches=JSON.stringify(staticRenderBatches.stats());}:undefined'));
 assert(source.includes("staticRenderBatches=createStaticRenderBatches({THREE,root:content,instances,minInstances:3,maxDistance:220,localMatrixOptimization:staticMatrixOptimization,shadowCensus:performanceProbe?.tagShadowBatch,multiDraw:renderer.extensions.has('WEBGL_multi_draw')})"));
});

test('actual walk import/readiness/pagehide and early frame guard preserve normal health/NPC/mercenary flow',()=>{
 const source=fs.readFileSync(new URL('./walk_preview.mjs',import.meta.url),'utf8').replace(/\r/g,'');
 assert(source.includes('renderWeaponView(renderer,scene,camera,null,updateEntryLightsForRenderCamera)'),'held render refreshes entry lights for its final camera instead of retaining a stale impact or recoil view');
 assert(source.includes('renderWeaponView(renderer,scene,camera,combat.allowed?combat.recoil:null,updateEntryLightsForRenderCamera)'),'normal render refreshes entry lights after temporary camera presentation transforms');
 assert(source.includes('const vehicleShadowEnabled=vehicleShadowCullingEnabled(location.search),buildingShadowEnabled=buildingShadowCullingEnabled(location.search);'),'building shadow-volume candidate has an independent URL gate');
 assert(source.includes('buildingEnabled:buildingShadowEnabled'),'walk passes the default-off building gate into the accepted vehicle shadow owner');
 assert(source.includes('vehicleShadowCulling?.setBuildingEnabled(buildingShadowEnabled)'),'freeze QA restores the configured building candidate after every comparison');
 assert(source.includes("top:274px"),'building shadow control stays between the static-matrix and draw-probe rows without covering the GPU timer');
 assert.match(source,/import \{createRenderFreezeQa,allowRenderFreeze\} from '\.\/render_freeze_qa\.mjs'/);
 assert(source.includes("const wheelRenderOptimization=allowRenderFreeze(location.href)&&new URLSearchParams(location.search).get('wheelbatched')==='1'&&renderer.extensions.has('WEBGL_multi_draw');"),'wheel candidate requires explicit local unauthenticated performance QA and multi-draw');
 assert(source.includes('applyVehicleWheels:wheelRenderOptimization?enabled=>'),'wheel comparison is absent by default');
 assert(source.includes('fleet?.active?.renderBatches?.update();fleet?.active?.wheelRenderBatches?.update();'),'active wheel batches follow active vehicle damage/tyre updates, not only parked fleet updates');
 assert(source.includes('vehicleFactory:wheelRenderOptimization?(...args)=>createArtistVehicle(...args,{wheelRenderOptimization:true}):undefined'),'factory sharing occurs before fleet damage snapshot only when explicitly enabled');
 assert.match(source,/const renderFreezeQa=createRenderFreezeQa\(/);assert.match(source,/isReady:\(\)=>startup\.report\.phase==='rendered'&&!busy/);
 assert.match(source,/addEventListener\('pagehide',\(\)=>renderFreezeQa\?\.dispose\(\)/);
 assert(source.includes('onHoldStart:()=>{npcPopulation?.markPoseInterrupted();resetVehicleShadowQa();}'),'QA hold marks a real pose interruption');
 assert(source.includes("onHoldEnd:()=>{renderIsolationQa?.stop('hold ended');resetVehicleShadowQa();}"),'isolation and shadow optimization restore on hold exit');
 assert(source.includes('async function refresh(){if(renderFreezeQa?.active||busy||'),'15-second placement polling cannot release or replace a held A/B scene');
 assert(source.includes("document.addEventListener('visibilitychange',()=>{if(document.hidden){releaseControls();npcPopulation?.markPoseInterrupted()}})"),'hidden page marks a real interruption without treating every slow frame as one');
 const begin=source.indexOf('function frame(){'),guard=source.indexOf('if(renderFreezeQa?.render(',begin),health=source.indexOf('updateWorldWalkHealth()',begin),npc=source.indexOf('updateNpcPopulation(dt)',begin),mercenaries=source.indexOf('updateMercenaries(dt)',begin);
 assert(begin>=0&&guard>begin&&health>guard&&mercenaries>guard&&npc>guard,'freeze before health, mercenaries and actual NPC hook');
 assert(source.includes('function updateMercenaries(dt)'));
 const prefixEnd=source.indexOf("performanceProbe?.mark('healthHud');",guard)+"performanceProbe?.mark('healthHud');".length;
 assert(prefixEnd>guard);const prefix=source.slice(begin,prefixEnd);
const events=[],context={requestAnimationFrame(){},frameInteraction:null,frameEntrySpot:null,clock:{getDelta:()=>.016},frameCount:0,frameElapsed:0,frameLongest:0,exitQaMode:false,vehicleVisualQa:null,document:{hidden:false},waterImpactCapture:{paused:false},renderIsolationQa:null,renderFreezeQa:{render(fn){events.push('freeze');if(context.held){fn();return true}return false}},updateEntryLightsForRenderCamera(){events.push('entry-lights')},renderWeaponView(renderer,scene,camera,recoil,beforeRender){beforeRender?.(camera);events.push('render')},renderer:{},scene:{},camera:{},carQa:{update(){events.push('car')}},carState:{},performanceProbe:{begin(){events.push('begin')},mark(){events.push('mark')},measure(name,fn){return fn()}},updateWorldWalkHealth(){events.push('health')},walkPlayerHud:{update(){events.push('hud')}},performance:{now:()=>0},updateMercenaries(){events.push('mercenaries')},hudInputBlocked:()=>false,releaseControls(){events.push('release')},held:true};
 Object.assign(context,{coverElapsedTime,coverMovementScale:1});
 vm.createContext(context);vm.runInContext(prefix+'\n}',context);vm.runInContext('frame()',context);assert.deepEqual(events,['freeze','entry-lights','render']);
 events.length=0;context.held=false;vm.runInContext('frame()',context);assert.deepEqual(events,['freeze','car','begin','health','hud','mercenaries','mark']);
});
console.log(JSON.stringify({passed,failed:failures.length,scope:'actual THREE camera; stub DOM and extracted walk frame prefix; CPU only, no LIVE/GPU acceptance'}));
if(failures.length)process.exitCode=1;
