// Opt-in, read-only timing of the actual populated renderer. No simulation changes.
export function createWalkPerformanceProbe({renderer,scene,document,getStartup,now=()=>performance.now()}){
 const gl=renderer.getContext(),timer=gl.getExtension('EXT_disjoint_timer_query_webgl2');
 const device={multiDraw:!!gl.getExtension('WEBGL_multi_draw'),gpuTimer:!!timer,pixelRatio:renderer.getPixelRatio()};
 const samples=[],gpuSamples=[],pending=[],stages={};let start=0,last=0,previous=0,publishAt=0,capture=false,census={},frameNumber=0,disposed=false;
 const originalRender=renderer.render,originalDirect=renderer.renderBufferDirect;let wrappedRender,wrappedDirect;
 const stats=values=>{const a=[...values].sort((x,y)=>x-y);return a.length?{samples:a.length,mean:+(a.reduce((s,v)=>s+v,0)/a.length).toFixed(2),p50:+a[Math.floor((a.length-1)*.5)].toFixed(2),p95:+a[Math.floor((a.length-1)*.95)].toFixed(2)}:null};
 function category(object){let names=[];for(let n=object;n&&n!==scene;n=n.parent){if(n.userData?.instance)return 'native:'+n.userData.instance.assetId;if(n.name)names.unshift(n.name)}return names.slice(0,2).join('/')||'(unnamed)';}
 renderer.renderBufferDirect=wrappedDirect=function(...args){const before=renderer.info.render.calls,beforeTris=renderer.info.render.triangles,result=originalDirect.apply(this,args);if(capture){const key=category(args[4]),row=census[key]??={calls:0,triangles:0};row.calls+=renderer.info.render.calls-before;row.triangles+=renderer.info.render.triangles-beforeTris;}return result;};
 renderer.render=wrappedRender=function(...args){
  if(args[0]!==scene||disposed)return originalRender.apply(this,args);
  const ready=getStartup()?.phase==='rendered',begin=now();let query=null;
  if(ready&&timer&&pending.length<4&&!gl.getQuery(timer.TIME_ELAPSED_EXT,gl.CURRENT_QUERY)){query=gl.createQuery();gl.beginQuery(timer.TIME_ELAPSED_EXT,query)}
  capture=ready&&(frameNumber===1||frameNumber%60===0);if(capture)census={};
  try{return originalRender.apply(this,args)}finally{if(query){gl.endQuery(timer.TIME_ELAPSED_EXT);pending.push(query)}if(ready)stages.render=now()-begin;capture=false;}
 };
 function poll(){if(!timer)return;const disjoint=gl.getParameter(timer.GPU_DISJOINT_EXT);for(let i=pending.length-1;i>=0;i--){const q=pending[i];if(!gl.getQueryParameter(q,gl.QUERY_RESULT_AVAILABLE))continue;if(!disjoint){gpuSamples.push(gl.getQueryParameter(q,gl.QUERY_RESULT)/1e6);if(gpuSamples.length>120)gpuSamples.shift()}gl.deleteQuery(q);pending.splice(i,1)}}
 return {begin(){start=last=now();for(const key of Object.keys(stages))delete stages[key];},mark(name){const end=now();stages[name]=(stages[name]||0)+end-last;last=end;},end(){
  const end=now(),ready=getStartup()?.phase==='rendered';poll();
  if(ready&&start){if(previous)samples.push({interval:end-previous,frame:end-start,...stages});if(samples.length>120)samples.shift();previous=end;frameNumber++;}else previous=0;
  if(end-publishAt<1000)return;publishAt=end;
  const keys=new Set(samples.flatMap(s=>Object.keys(s))),timings=Object.fromEntries([...keys].map(k=>[k,stats(samples.map(s=>s[k]).filter(Number.isFinite))]));
  device.pixelRatio=renderer.getPixelRatio();document.body.dataset.walkPerformance=JSON.stringify({phase:getStartup()?.phase,device,timings,gpuMs:stats(gpuSamples),draws:renderer.info.render.calls,triangles:renderer.info.render.triangles,census:Object.entries(census).sort((a,b)=>b[1].calls-a[1].calls).slice(0,24)});
 },measure(name,run){const begin=now();try{return run()}finally{stages[name]=(stages[name]||0)+now()-begin;}},dispose(){disposed=true;if(renderer.renderBufferDirect===wrappedDirect)renderer.renderBufferDirect=originalDirect;if(renderer.render===wrappedRender)renderer.render=originalRender;for(const q of pending)gl.deleteQuery(q);pending.length=0;}};
}
