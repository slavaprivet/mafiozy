// /walk enters the original world, which owns NPC AI, identity and networking.
// Explicit standalone=1 keeps the isolated renderer test scene available.
export function walkEntrySelection(href,{hasSession=false}={}){
 const url=new URL(href,'http://localhost');
 if(url.searchParams.get('standalone')==='1')return {mode:'standalone',url:null};
 const identityKeys=['uid','account_uid','character','character_uid','initData','init_data','tgWebAppData','world_token','ws_ticket','auth','token','api'];
 const localMonitor=['127.0.0.1','localhost'].includes(url.hostname)&&url.port==='18538';
 const identified=hasSession||identityKeys.some(key=>url.searchParams.has(key))||/tgWebAppData|initData|world_token/.test(url.hash);
 if(localMonitor&&!identified&&!url.searchParams.has('direct')&&!url.searchParams.has('previewcity')){
  url.searchParams.set('direct','1');url.searchParams.set('previewcity','1');
 }
 url.pathname='/world.html';url.searchParams.set('render','3d');url.searchParams.set('renderer','walk');
 return {mode:'world',url:url.pathname+url.search+url.hash};
}
export async function bootWalkEntry({location=globalThis.location,importPreview=()=>import('./walk_preview.mjs'),window:win=globalThis.window}={}){
 let hasSession=!!win?.Telegram?.WebApp?.initData;
 try{hasSession=hasSession||!!win?.sessionStorage?.getItem('mafiozi_steam_session_v1')}catch{hasSession=true}
 const entry=walkEntrySelection(location.href,{hasSession});
 if(entry.mode==='world'){location.replace(entry.url);return entry}
 await importPreview();return entry;
}
if(typeof window!=='undefined')bootWalkEntry().catch(error=>{
 console.error('[walk-entry]',error);
 const output=document.getElementById('errors');if(output)output.textContent='Не удалось открыть проверочную сцену: '+String(error?.message||error);
});
