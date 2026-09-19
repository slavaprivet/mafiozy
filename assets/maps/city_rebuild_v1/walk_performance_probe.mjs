// Opt-in, read-only timing of the actual populated renderer. No simulation changes.
export function createWalkPerformanceProbe({renderer,scene,document,getStartup,now=()=>performance.now()}){
 const gl=renderer.getContext(),timer=gl.getExtension('EXT_disjoint_timer_query_webgl2');
 const debugRenderer=gl.getExtension('WEBGL_debug_renderer_info');
 const device={graphicsRenderer:debugRenderer?gl.getParameter(debugRenderer.UNMASKED_RENDERER_WEBGL):null,graphicsVendor:debugRenderer?gl.getParameter(debugRenderer.UNMASKED_VENDOR_WEBGL):null,multiDraw:!!gl.getExtension('WEBGL_multi_draw'),gpuTimer:!!timer,pixelRatio:renderer.getPixelRatio()};
 const samples=[],gpuSamples=[],pending=[],stages={},frameDraws={total:0,shadow:0,main:0,triangles:0,shadowTriangles:0};let start=0,last=0,previous=0,publishAt=0,capture=false,census={},renderGroups={},materialGroups={},frameNumber=0,disposed=false,gpuTimingEnabled=!!timer,activeQuery=null,gpuTimingError=null,directProfiling=true,drawContext=null;
 const originalRender=renderer.render,originalDirect=renderer.renderBufferDirect,originalMatrix=scene.updateMatrixWorld,originalShadow=renderer.shadowMap?.render;let wrappedRender,wrappedDirect,wrappedMatrix,wrappedShadow,renderDepth=0,shadowDepth=0;
 const addTime=(key,value)=>{stages[key]=(stages[key]||0)+value;};
 if(originalMatrix)scene.updateMatrixWorld=wrappedMatrix=function(...args){const begin=now();try{return originalMatrix.apply(this,args)}finally{if(renderDepth)addTime('renderMatrix',now()-begin)}};
 // Shadow counts are sampled around the whole pass, not around every draw.
 // Three resets renderer.info after shadows when autoReset is enabled.
 if(originalShadow)renderer.shadowMap.render=wrappedShadow=function(...args){const begin=now(),context=drawContext,before=renderer.info.render.calls,beforeTris=renderer.info.render.triangles;shadowDepth++;try{return originalShadow.apply(this,args)}finally{shadowDepth--;if(renderDepth)addTime('renderShadow',now()-begin);if(context){context.shadow+=renderer.info.render.calls-before;context.shadowTriangles+=renderer.info.render.triangles-beforeTris;}}};
 const stats=values=>{const a=[...values].sort((x,y)=>x-y);return a.length?{samples:a.length,mean:+(a.reduce((s,v)=>s+v,0)/a.length).toFixed(2),p50:+a[Math.floor((a.length-1)*.5)].toFixed(2),p95:+a[Math.floor((a.length-1)*.95)].toFixed(2)}:null};
 const deleteQuery=q=>{try{gl.deleteQuery(q)}catch(error){gpuTimingError=String(error?.message||error)}};
 function clearQueries(){if(activeQuery){const q=activeQuery;activeQuery=null;try{gl.endQuery(timer.TIME_ELAPSED_EXT)}catch(error){gpuTimingError=String(error?.message||error)}finally{deleteQuery(q)}}for(const q of pending)deleteQuery(q);pending.length=0;}
 function reset(){samples.length=0;gpuSamples.length=0;previous=0;frameNumber=0;publishAt=0;capture=false;census={};renderGroups={};materialGroups={};clearQueries();}
 function gpuFailure(error){gpuTimingEnabled=false;gpuTimingError=String(error?.message||error);reset();}
 function category(object){let names=[];for(let n=object;n&&n!==scene;n=n.parent){if(n.userData?.instance)return 'native:'+n.userData.instance.assetId;if(n.name)names.unshift(n.name)}return names.slice(0,2).join('/')||'(unnamed)';}
 function renderFamily(object){for(let n=object;n&&n!==scene;n=n.parent){if(n.userData?.sourceVehicleId)return 'traffic';if(n.userData?.vehicleFleetId)return 'fleet';if(/^NPC_/.test(n.name||''))return 'residents';if(/^Artist13_Walk_Hero/.test(n.name||''))return 'player';}return 'environment';}
 renderer.renderBufferDirect=wrappedDirect=function(camera,renderScene,geometry,material,object,group){
  // Keep this delegate installed: an outer shadow-culling wrapper can own it.
  // OFF performs no clock/stat/census reads and allocates no rest argument array.
  if(!directProfiling||disposed)return originalDirect.call(this,camera,renderScene,geometry,material,object,group);
  const begin=now(),before=renderer.info.render.calls,beforeTris=renderer.info.render.triangles;
  try{return originalDirect.call(this,camera,renderScene,geometry,material,object,group)}finally{
   if(directProfiling){const submitElapsed=now()-begin;if(renderDepth)addTime(shadowDepth?'renderShadowSubmit':'renderMainSubmit',submitElapsed);
    if(capture){const key=category(object),row=census[key]??={calls:0,triangles:0,shadowCalls:0};const calls=renderer.info.render.calls-before;row.calls+=calls;row.triangles+=renderer.info.render.triangles-beforeTris;if(shadowDepth)row.shadowCalls+=calls;const family=renderFamily(object),entry=renderGroups[family]??={calls:0,triangles:0,shadowCalls:0,submitMs:0,shadowSubmitMs:0};entry.calls+=calls;entry.triangles+=renderer.info.render.triangles-beforeTris;entry.submitMs+=submitElapsed;if(shadowDepth){entry.shadowCalls+=calls;entry.shadowSubmitMs+=submitElapsed;}
     const materialKey=[shadowDepth?'shadow':'main',material?.type||'unknown',material?.transparent?'transparent':'opaque'].join(':'),bucket=materialGroups[materialKey]??={calls:0,triangles:0,submitMs:0};bucket.calls+=calls;bucket.triangles+=renderer.info.render.triangles-beforeTris;bucket.submitMs+=submitElapsed;
    }
   }
  }
 };
 renderer.render=wrappedRender=function(...args){
  if(args[0]!==scene||disposed)return originalRender.apply(this,args);
  const ready=getStartup()?.phase==='rendered',begin=now();let query=null;
  if(ready&&gpuTimingEnabled&&pending.length<4&&!activeQuery){try{if(!gl.getQuery(timer.TIME_ELAPSED_EXT,gl.CURRENT_QUERY)){query=gl.createQuery();if(query){gl.beginQuery(timer.TIME_ELAPSED_EXT,query);activeQuery=query}}}catch(error){if(query)deleteQuery(query);query=null;gpuFailure(error)}}
  capture=directProfiling&&ready&&(frameNumber===1||frameNumber%60===0);if(capture){census={};renderGroups={};materialGroups={};}
  const parentContext=drawContext,context={before:renderer.info.render.calls,beforeTriangles:renderer.info.render.triangles,shadow:0,shadowTriangles:0};drawContext=context;
  renderDepth++;try{return originalRender.apply(this,args)}finally{
   renderDepth--;drawContext=parentContext;
   const info=renderer.info,main=info.autoReset===true?info.render.calls:info.render.calls-context.before-context.shadow,mainTriangles=info.autoReset===true?info.render.triangles:info.render.triangles-context.beforeTriangles-context.shadowTriangles;
   frameDraws.main+=main;frameDraws.shadow+=context.shadow;frameDraws.shadowTriangles+=context.shadowTriangles;frameDraws.total+=main+context.shadow;frameDraws.triangles+=mainTriangles+context.shadowTriangles;
   if(query&&activeQuery===query){try{gl.endQuery(timer.TIME_ELAPSED_EXT);activeQuery=null;pending.push(query)}catch(error){gpuFailure(error)}}if(ready)addTime('render',now()-begin);capture=false;
  }
 };
 function poll(){if(!gpuTimingEnabled||disposed)return;try{const disjoint=gl.getParameter(timer.GPU_DISJOINT_EXT);for(let i=pending.length-1;i>=0;i--){const q=pending[i];if(!gl.getQueryParameter(q,gl.QUERY_RESULT_AVAILABLE))continue;if(!disjoint){gpuSamples.push(gl.getQueryParameter(q,gl.QUERY_RESULT)/1e6);if(gpuSamples.length>120)gpuSamples.shift()}deleteQuery(q);pending.splice(i,1)}}catch(error){gpuFailure(error)}}
 function snapshot(){
  const keys=new Set(samples.flatMap(s=>Object.keys(s))),timings=Object.fromEntries([...keys].map(k=>[k,stats(samples.map(s=>s[k]).filter(Number.isFinite))]));
  const info=renderer.info,memory=info.memory||{};
  device.pixelRatio=renderer.getPixelRatio();return {phase:getStartup()?.phase,device:{...device},timings,directProfiling,gpuTiming:!timer?'unavailable':gpuTimingEnabled?'enabled':'disabled',gpuTimingError,gpuMs:gpuTimingEnabled?stats(gpuSamples):null,draws:info.render.calls,triangles:info.render.triangles,frameDraws:{...frameDraws},memory:{geometries:Number.isFinite(memory.geometries)?memory.geometries:null,textures:Number.isFinite(memory.textures)?memory.textures:null,programs:Array.isArray(info.programs)?info.programs.length:null},...(directProfiling?{renderGroups,materialGroups,census:Object.entries(census).sort((a,b)=>b[1].calls-a[1].calls).slice(0,24)}:{})};
 }
 return {snapshot,begin(){start=last=now();for(const key of Object.keys(frameDraws))frameDraws[key]=0;for(const key of Object.keys(stages))delete stages[key];},mark(name){const end=now();stages[name]=(stages[name]||0)+end-last;last=end;},end(){
  const end=now(),ready=getStartup()?.phase==='rendered';poll();
  if(ready&&start){if(previous)samples.push({interval:end-previous,frame:end-start,...stages});if(samples.length>120)samples.shift();previous=end;frameNumber++;}else previous=0;
  if(end-publishAt<1000)return;publishAt=end;
  document.body.dataset.walkPerformance=JSON.stringify(snapshot());
 },reset,getDrawProfilingEnabled(){return directProfiling&&!disposed},setDrawProfilingEnabled(enabled){if(disposed)return false;enabled=!!enabled;if(enabled!==directProfiling){directProfiling=enabled;delete stages.renderMainSubmit;delete stages.renderShadowSubmit;reset();}return directProfiling;},getGpuTimingEnabled(){return gpuTimingEnabled&&!disposed},setGpuTimingEnabled(enabled){if(disposed)return false;enabled=!!enabled&&!!timer;if(enabled!==gpuTimingEnabled){gpuTimingEnabled=enabled;gpuTimingError=null;reset();}return gpuTimingEnabled;},measure(name,run){const begin=now();try{return run()}finally{stages[name]=(stages[name]||0)+now()-begin;}},dispose(){if(disposed)return;disposed=true;gpuTimingEnabled=false;if(renderer.renderBufferDirect===wrappedDirect)renderer.renderBufferDirect=originalDirect;if(renderer.render===wrappedRender)renderer.render=originalRender;if(wrappedMatrix&&scene.updateMatrixWorld===wrappedMatrix)scene.updateMatrixWorld=originalMatrix;if(wrappedShadow&&renderer.shadowMap.render===wrappedShadow)renderer.shadowMap.render=originalShadow;clearQueries();}};
}
