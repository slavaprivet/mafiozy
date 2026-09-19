// Keep opt-in diagnostic controls available without covering the playable HUD.
// Explicit selectors only: gameplay prompts, badges, timers and maps stay visible.
export const WALK_DEBUG_PANEL_SELECTORS=[
 '#npc-combat-session','#npc-transport-qa','#mercenary-qa',
 '[data-walk-hud="mercenary-showcase"]',
 '#static-batch-qa','#building-camera-index-qa','#render-freeze-qa',
 '#vehicle-detail-batch-qa','#vehicle-shadow-qa','#gpu-timer-qa',
 '#draw-probe-qa','#vehicle-wheel-batch-qa','#static-matrix-qa','#render-isolation-qa',
 '#building-qa','#car-physics-qa','#cover-qa','#traversal-qa','#animation-qa',
];

export function installWalkDebugPanels({document:doc,href,releaseControls=()=>{}}={}){
 const url=new URL(href||'http://invalid');
 const localQa=['localhost','127.0.0.1','[::1]'].includes(url.hostname)&&
   [...url.searchParams].some(([key,value])=>/qa$/.test(key)&&value==='1');
 const style=doc.createElement('style');style.id='walk-debug-panels-style';
 // Gameplay keeps contextual door prompts, but no idle district/vehicle overlay.
 const minimalHud=`#districtRepHud,#drive-status:empty,#onlineTag,#errorBanner{display:none!important}
 #toast{position:fixed;left:auto;right:16px;bottom:300px;transform:none;width:230px;max-width:calc(100vw - 32px);box-sizing:border-box;padding:11px 13px;background:linear-gradient(130deg,#1b302cf5,#30281ff5);border:1px solid #bba46d99;border-radius:9px;color:#eee6d7;font:12px/1.45 system-ui,sans-serif;box-shadow:0 5px 18px #0005;z-index:35}
 #toast.show{animation:walkNoticeIn .18s ease-out}#toast .tx{background:#423c2f;border:1px solid #bba46d99;color:#eee6d7}
 @keyframes walkNoticeIn{from{opacity:0;transform:translateY(5px)}to{opacity:1;transform:none}}
 @media(max-width:700px){#toast{right:8px;bottom:250px;width:190px;max-width:calc(100vw - 16px)}}
 @media(prefers-reduced-motion:reduce){#toast.show{animation:none}}`;
 let expanded=false,disposed=false;
 function publish(){
  style.textContent=minimalHud+(expanded?'':WALK_DEBUG_PANEL_SELECTORS.join(',')+'{display:none!important}');
  doc.body.dataset.walkDebugPanels=expanded?'expanded':'collapsed';
 }
 const keydown=e=>{
  if(disposed||!localQa||e.repeat||!e.ctrlKey||!e.shiftKey||e.altKey||e.metaKey||(e.code||e.key)!=='F9')return;
  const path=e.composedPath?.()||[e.target];
  if(path.some(n=>n?.isContentEditable||/^(INPUT|TEXTAREA|SELECT)$/.test(n?.tagName||'')))return;
  e.preventDefault();e.stopImmediatePropagation?.();releaseControls();expanded=!expanded;publish();
 };
 // Measure only this notice when its text wraps; commands stack above it without
 // a frame loop or a fixed-height guess that could cover a long witness message.
 const toast=doc.getElementById?.('toast'),ResizeObserverType=doc.defaultView?.ResizeObserver||globalThis.ResizeObserver;
 const toastObserver=toast&&ResizeObserverType?new ResizeObserverType(entries=>{
  const entry=entries[0],box=entry?.borderBoxSize,first=Array.isArray(box)?box[0]:box;
  const height=first?.blockSize??((entry?.contentRect?.height||0)+24);
  if(height>0)doc.body.style?.setProperty('--walk-world-toast-height',Math.ceil(height)+'px');
 }):null;
 toastObserver?.observe(toast);
 doc.addEventListener('keydown',keydown,true);doc.head.append(style);publish();
 return{get expanded(){return expanded;},dispose(){if(disposed)return;disposed=true;toastObserver?.disconnect();doc.body.style?.removeProperty('--walk-world-toast-height');doc.removeEventListener('keydown',keydown,true);style.remove();delete doc.body.dataset.walkDebugPanels;}};
}
