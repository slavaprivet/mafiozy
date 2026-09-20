// Natural-hover A/B only: never schedules or casts additional rays.
export function allowNpcSkinPickingQa(href){
 const url=new URL(href||'','http://invalid');
 return ['localhost','127.0.0.1'].includes(url.hostname)&&url.searchParams.get('perfqa')==='1'&&url.searchParams.get('npcskinpick')==='1'&&url.searchParams.get('mercenarypickqa')!=='1'&&
  !['uid','account_uid','character_uid','initData','init_data','tgWebAppData','world_token','ws_ticket','auth','token','api'].some(k=>url.searchParams.has(k));
}
export function createNpcSkinPickingQa({document:doc,window:win=doc?.defaultView,createMemo,now=()=>performance.now()}={}){
 if(!doc?.body||!allowNpcSkinPickingQa(win?.location?.href))return null;
 const memo=createMemo();memo.setEnabled(false);
 const button=doc.createElement('button');button.id='npc-skin-pick-qa';button.type='button';
 button.style.cssText='position:fixed;top:314px;left:50%;transform:translateX(-50%);z-index:10000;padding:8px;max-width:90vw';doc.body.append(button);
 const values=new Float64Array(120);let cursor=0,stored=0,samples=0,blockedSamples=0,failedSamples=0,revision=0,enabled=false,disposed=false,lastPublish=-Infinity,lastPayload=null,lastTargetId=null;
 function publish(force=false){
  const time=now();if(disposed||!force&&time-lastPublish<1000)return;lastPublish=time;
  const sorted=Array.from(values.subarray(0,stored)).sort((a,b)=>a-b),at=q=>sorted[Math.ceil(sorted.length*q)-1]??null;
  button.textContent=`Точный поиск NPC: ${enabled?'ВКЛ':'ВЫКЛ'} · сравнить`;button.setAttribute('aria-pressed',String(enabled));
  const value={version:1,kind:'natural-whole-hover',mode:enabled?'on':'off',revision,samples,blockedSamples,failedSamples,windowSamples:stored,p50Ms:at(.5),p95Ms:at(.95),lastTargetId,source:memo.stats()};
  try{lastPayload=JSON.stringify(value);doc.documentElement.dataset.npcSkinPicking=lastPayload;}catch{}
 }
 const stop=e=>e?.stopPropagation?.();
 const click=e=>{e?.preventDefault?.();stop(e);if(disposed)return;enabled=memo.setEnabled(!enabled)===true;revision++;cursor=stored=samples=blockedSamples=failedSamples=0;lastTargetId=null;publish(true);};
 button.addEventListener('click',click);for(const type of ['pointerdown','pointerup','mousedown','mouseup','keydown','keyup'])button.addEventListener(type,stop);
 publish(true);
 return {memo,begin(){return disposed?null:{revision};},finish(token,{started,ended,blocked=false,failed=false,targetId=null}={}){
  if(disposed||!token||token.revision!==revision)return;
  if(failed)failedSamples++;else if(blocked)blockedSamples++;else if(Number.isFinite(started)&&Number.isFinite(ended)&&ended>=started){samples++;values[cursor]=ended-started;cursor=(cursor+1)%120;stored=Math.min(120,stored+1);lastTargetId=targetId;}
  publish();
 },dispose(){if(disposed)return;disposed=true;memo.dispose();button.removeEventListener('click',click);for(const type of ['pointerdown','pointerup','mousedown','mouseup','keydown','keyup'])button.removeEventListener(type,stop);button.remove();if(doc.documentElement?.dataset?.npcSkinPicking===lastPayload)delete doc.documentElement.dataset.npcSkinPicking;}};
}
