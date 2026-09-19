// Local opt-in comparison of existing natural hover work; never casts a ray.
const owners=new WeakMap();
export function allowNativePickingQa(href){
 const url=new URL(href||'','http://invalid');
 return ['localhost','127.0.0.1'].includes(url.hostname)&&url.searchParams.get('perfqa')==='1'&&url.searchParams.get('nativepick')==='1'&&url.searchParams.get('mercenarypickqa')!=='1'&&
  !['uid','account_uid','character_uid','initData','init_data','tgWebAppData','world_token','ws_ticket','auth','token','api'].some(k=>url.searchParams.has(k));
}
export function createNativePickingQa({document:doc,window:win=doc?.defaultView,now=()=>performance.now()}={}){
 if(!doc?.body||!allowNativePickingQa(win?.location?.href))return null;
 owners.get(doc)?.dispose();
 const button=doc.createElement('button');button.id='native-pick-qa';button.type='button';button.style.cssText='position:fixed;top:274px;left:50%;transform:translateX(-50%);z-index:10000;padding:8px;max-width:90vw';doc.body.append(button);
 let disposed=false,state=null,revision=0,samples=0,blockedSamples=0,failedSamples=0,lastPublish=-Infinity,lastPayload=null,error=null;
 const history=new Float64Array(120);let stored=0,cursor=0;
 const current=()=>{const api=win.MafioziNativeTerrainPicking;return {api,generation:api?.generation,ready:api?.ready===true,enabled:api?.enabled===true};};
 const same=(a,b)=>!!a&&a.api===b.api&&a.generation===b.generation&&a.ready===b.ready&&a.enabled===b.enabled;
 const owns=()=>!disposed&&owners.get(doc)===handle;
 function sync(){const next=current();if(same(state,next))return false;state=next;revision++;samples=blockedSamples=failedSamples=stored=cursor=0;error=null;lastPublish=-Infinity;return true;}
 function publish(time,force=false){
  if(!owns()||!force&&time-lastPublish<1000)return;lastPublish=time;
  const mode=state.ready?(state.enabled?'on':'off'):'waiting',sorted=Array.from(history.subarray(0,stored)).sort((a,b)=>a-b),at=q=>sorted[Math.ceil(sorted.length*q)-1]??null;
  let source=null;try{source=state.api?.stats?.()??null;}catch{error='source-stats-unavailable';}
  const value={version:1,kind:'natural-whole-hover',mode,generation:state.generation??null,revision,samples,blockedSamples,failedSamples,windowSamples:stored,capacity:120,p50Ms:at(.5),p95Ms:at(.95),lastMs:stored?history[(cursor+119)%120]:null,error,source};
  button.disabled=!state.ready||typeof state.api?.setEnabled!=='function';button.textContent=mode==='waiting'?'Поиск рельефа: ожидание города':`Поиск рельефа: ${mode.toUpperCase()} · сравнить`;button.setAttribute('aria-pressed',String(mode==='on'));
  try{lastPayload=JSON.stringify(value);doc.documentElement.dataset.nativePickingHover=lastPayload;}catch{}
 }
 function begin(){
  if(!owns())return null;
  try{sync();publish(now());return state.ready?{state,revision}:null;}catch{return null;}
 }
 function finish(token,{started,ended,blocked=false,failed=false}={}){
  if(!owns()||!token)return;
  try{
   sync();
   // A reload or a toggle during the sampled operation invalidates its label.
   if(token.revision!==revision||!same(token.state,state)){publish(now());return;}
   if(failed)failedSamples++;else if(blocked)blockedSamples++;else if(Number.isFinite(started)&&Number.isFinite(ended)&&ended>=started){samples++;history[cursor]=ended-started;cursor=(cursor+1)%120;stored=Math.min(120,stored+1);}
   publish(now());
  }catch{}
 }
 const stop=e=>{e?.stopPropagation?.();};
 const click=e=>{
  e?.preventDefault?.();stop(e);if(!owns())return;
  try{sync();const before=state;if(!before.ready||typeof before.api?.setEnabled!=='function')return;
   if(!same(before,current())){sync();return;}
   before.api.setEnabled(!before.enabled);sync();
  }catch{error='source-toggle-failed';}
  finally{if(owns())try{publish(now(),true);}catch{}}
 };
 button.addEventListener('click',click);for(const type of ['pointerdown','pointerup','mousedown','mouseup','keydown','keyup'])button.addEventListener(type,stop);
 const handle={begin,finish,dispose(){if(disposed)return;disposed=true;button.removeEventListener('click',click);for(const type of ['pointerdown','pointerup','mousedown','mouseup','keydown','keyup'])button.removeEventListener(type,stop);button.remove();stored=cursor=0;
  if(owners.get(doc)===handle){owners.delete(doc);if(doc.documentElement?.dataset?.nativePickingHover===lastPayload)delete doc.documentElement.dataset.nativePickingHover;}
 }};
 owners.set(doc,handle);try{sync();publish(now(),true);}catch{}return handle;
}
