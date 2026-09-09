// Renderer gateway. The containing world.html remains the only AI/WS owner.
// walk starts asynchronously after module evaluation. These diagnostics are
// published after scene assembly and after an actual frame with the loaded hero.
export function watchWorldWalkReady({document:doc,window:win,Observer=globalThis.MutationObserver}){
 let observer,finished=false;
 const stop=()=>{finished=true;observer?.disconnect();win.removeEventListener?.('pagehide',stop);};
 const check=()=>{
  if(finished)return;
  let city,hero;try{city=JSON.parse(doc.body.dataset.rebuildProof||'null');hero=JSON.parse(doc.body.dataset.heroWalk||'null');}catch{return;}
  if(!(city?.planned>0&&city.loaded===city.planned&&city.failed===0&&hero?.loaded===true))return;
  doc.documentElement.dataset.worldWalkReady='first-populated-frame';
  win.MafioziLoading?.complete('Город готов');stop();
 };
 if(Observer){observer=new Observer(check);observer.observe(doc.body,{attributes:true,attributeFilter:['data-rebuild-proof','data-hero-walk']});}
 win.addEventListener?.('pagehide',stop,{once:true});check();return stop;
}
export async function mountWorldWalkHost({document:doc=document,window:win=window,fetch:load=fetch,importWalk=url=>import(url)}={}){
 const params=new URLSearchParams(win.location.search);
 if(params.get('render')!=='3d'||params.get('renderer')!=='walk')return {mounted:false};
 if(win.__mafioziWalkHostPromise)return win.__mafioziWalkHostPromise;
 const boot=(async()=>{
  const stage=doc.getElementById('stage');if(!stage||!win.Mafiozi3DBridge)throw Error('Existing world stage/bridge required');
  const response=await load(new URL('./tools/city_rebuild_walk.html',import.meta.url),{cache:'no-store'});if(!response.ok)throw Error('Walk shell HTTP '+response.status);
  const parsed=new DOMParser().parseFromString(await response.text(),'text/html');
  for(const script of parsed.querySelectorAll('script'))script.remove();
  const host=doc.createElement('div');host.id='mafiozi-walk-host';host.style.cssText='position:absolute;inset:0;z-index:1;pointer-events:auto;';
  const shell=host.attachShadow({mode:'open'}),style=doc.createElement('style');
  style.textContent=':host{display:block;color:#edf5f0;font:14px/1.5 system-ui,sans-serif}';shell.append(style);
  for(const element of parsed.head.querySelectorAll('style,link[rel="stylesheet"]'))shell.append(doc.importNode(element,true));
  for(const node of [...parsed.body.childNodes])shell.append(doc.importNode(node,true));
  const active=doc.getElementById('threePreview');if(active)throw Error('Another world WebGL renderer already mounted');
  stage.append(host);win.MafioziWalkShell=shell;stage.classList.add('three-mode');doc.documentElement.dataset.worldRenderer='walk';
  win.MafioziLoading?.set(52,'Загружаем город и персонажа…');
  const stopWatching=watchWorldWalkReady({document:doc,window:win});
  try{await importWalk(new URL('./assets/maps/city_rebuild_v1/walk_preview.mjs',import.meta.url).href);}
  catch(error){stopWatching();host.remove();delete win.MafioziWalkShell;stage.classList.remove('three-mode');doc.documentElement.dataset.worldRenderer='walk-failed';throw error;}
  return {mounted:true,host,shell};
 })();win.__mafioziWalkHostPromise=boot;return boot;
}
if(typeof window!=='undefined'&&typeof document!=='undefined')mountWorldWalkHost().catch(error=>{
 console.error('[world-walk-host]',error);document.documentElement.dataset.worldWalkError=String(error.message||error);
 const message=document.createElement('div');message.setAttribute('role','alert');message.textContent='Не удалось загрузить новый вид города: '+String(error.message||error);message.style.cssText='position:fixed;bottom:16px;left:16px;z-index:10001;background:#321b1b;color:#fff;padding:12px';document.body.append(message);
});
