import {isNormalizedWalkHudState,normalizeWalkHudState,getWalkHudOpenPanels} from './world_walk_hud_data.mjs';
import {npcAppearanceFromWorld} from './npc_population.mjs';
import {createWalkPlayerHud} from './walk_player_hud.mjs';
import {createWalkHudShell} from './walk_hud_shell.mjs';
import {createWalkStatusDialog} from './walk_status_dialog.mjs';
import {createWalkPortraitRenderer} from './walk_portraits.mjs';
import {loadAppearanceHero} from './walk_hero_appearance.mjs';
import {createWeaponThumbnailRenderer} from './weapon_thumbnails.mjs';
import {createNpcEmpirePortraits} from './npc_empire_portraits.mjs';

export function walkHudGatewayUrl(href){const url=new URL(href,'http://localhost');url.pathname='/world.html';url.searchParams.set('render','3d');url.searchParams.set('renderer','walk');url.hash='';return url.pathname+url.search}
function walkHudViewStateFromNormalized(state){
 const p=state.player,g=state.gang,show=n=>n===null?'—':n;
 return {...state,player:{...p,money:p.cash,timeLabel:state.clock.label},gang:{...g,members:[...g.players,...g.npcs],countLabel:`${show(g.playerCount)}/${show(g.playerMax)} ИГРОКА · ${show(g.npcCount)}/${show(g.npcMax)} NPC`},empires:{count:state.available?state.bosses.length:null,bosses:state.bosses}};
}
// Public callers may supply source data, while the controller already holds a
// canonical snapshot. Keep the adapter boundary for callers and avoid a third
// deep roster/appearance normalization in its 200 ms refresh path.
export function walkHudViewState(raw){return walkHudViewStateFromNormalized(normalizeWalkHudState(raw))}
export const walkAppearanceKey=look=>JSON.stringify(look,Object.keys(look||{}).sort());
// Preserve the exact portrait queue while avoiding three mapped arrays and up
// to 48 short-lived cloned rows on each 200 ms HUD refresh.
export function walkHudRosterRows(state,visit){
 if(typeof visit!=='function')return;let count=0;
 const group=(rows,prefix,portraitNpc,portraitBoss)=>{for(const row of Array.isArray(rows)?rows:[]){if(count>=48)return false;count++;if(visit(row,prefix+row.id,portraitNpc,portraitBoss)===false)return false;}return true;};
 if(!group(state?.bosses,'boss:',true,true))return;
 if(!group(state?.gang?.players,'member:player:'))return;
 group(state?.gang?.npcs,'member:npc:',true);
}

export function createWalkHudController({THREE,loader,cloneSkeleton,document:doc=globalThis.document,window:win=globalThis.window,getBridge=()=>null,getHero=()=>null,getNpcActor=()=>null,
 canSwapHero=()=>false,swapHero=()=>false,openMercenaryMember=()=>false,onInputLock=()=>{},onActionError=()=>{},hudFactory=createWalkPlayerHud,shellFactory=createWalkHudShell,statusFactory=createWalkStatusDialog,portraitFactory=createWalkPortraitRenderer,appearanceLoader=loadAppearanceHero,weaponThumbnailFactory=createWeaponThumbnailRenderer}={}){
 let disposed=false,lastUpdate=-Infinity,lastPortrait=-Infinity,blocked=false,state=normalizeWalkHudState(),loadingLook=null,appliedLook=null,wantedLook=null,pendingHero=null,failedLook=null,rosterBusy=false,lastRosterAt=-Infinity;
 const rosterCache=new Map(),rosterSent=new Map(),rosterFailed=new Set(),rosterWanted=new Map(),abort=new AbortController(),host=doc.createElement('aside');host.id='walk-player-hud';doc.body.append(host);
 const portraits=portraitFactory({THREE,document:doc,cloneSkeleton}),weaponPhotos=weaponThumbnailFactory({THREE,document:doc});
 const empirePortraits=createNpcEmpirePortraits({THREE,loader,cloneSkeleton,portraits,appearanceLoader,signal:abort.signal,isDisposed:()=>disposed});
 const shell=shellFactory({document:doc,getWeaponThumbnail:id=>weaponPhotos.render(id),ensureGangExpanded:()=>getBridge()?.ensureWalkGangExpanded?.(),onClose:()=>update(-Infinity)});
 const connection=doc.createElement('a');connection.className='mfz-dossier-button';connection.textContent='Подключить данные основного мира';connection.href=walkHudGatewayUrl(win?.location?.href||'/walk');connection.style.cssText='margin-top:6px;font-size:11px;text-decoration:none';
 function lock(value){if(value===blocked)return;blocked=value;if(blocked)onInputLock();doc.body.dataset.walkHudBlocked=String(blocked)}
 const performAction=async(action,payload)=>{
  doc.body.dataset.walkHudLastAction=JSON.stringify({action,payload});
  if(action==='gang'&&payload?.id!=null){if(openMercenaryMember(payload.id)===true){onInputLock();return;}const memberId=String(payload.id).replace(/^npc:/,'').replace(/^(npc_crew_|crew_)/,'');if(win?.MafioziMercenaries?.isMercenary?.(memberId)){onActionError('mercenary-member-unavailable');return;}}
  onInputLock();lock(true);
  try{const result=await getBridge()?.performWalkHudAction?.(action,payload);if(!result?.accepted)onActionError(result?.reason||'source-unavailable')}
  catch(error){onActionError(error.message)}
  finally{lastUpdate=-Infinity;update(performance.now())}
 };
 const statusDialog=statusFactory({document:doc,onAction:performAction,onClose:()=>{lastUpdate=-Infinity;update(performance.now())}});
 const hud=hudFactory({document:doc,host,onAction:performAction,onOpenChange:open=>{if(open){onInputLock();lastUpdate=lastPortrait=lastRosterAt=-Infinity;update(performance.now());}}});host.append(connection);
 const previous=win?.MafioziWalkHud,facade={openStatus:()=>{onInputLock();lastUpdate=-Infinity;update(performance.now());if(!state.available)return false;const result=statusDialog.open(state);lock(true);return result!==false},openGang:()=>{onInputLock();statusDialog.close();const result=shell.openGang();if(result)lock(true);return result},closeGang:()=>shell.closeGang(),refresh:()=>{lastUpdate=-Infinity;update(performance.now())},getState:()=>state,getPortrait:()=>({renders:portraits.renders,error:portraits.error}),getNpcPortrait:row=>empirePortraits.get(row),isBlocked:()=>blocked};if(win)win.MafioziWalkHud=facade;
 function refreshHero(now){
  const current=getHero(),look=state.available&&state.player.look,id=state.player.id||'player';
  wantedLook=look?id+'|'+walkAppearanceKey(look):null;
  if(pendingHero&&pendingHero.key!==wantedLook){pendingHero.record.dispose();pendingHero=null}
  if(pendingHero&&canSwapHero()){
   const pending=pendingHero;pendingHero=null;
   if(swapHero(pending.record)){appliedLook=pending.key;lastPortrait=-Infinity;portraits.invalidate()}else{pending.record.dispose();loadingLook=null;failedLook=pending.key}
  }
  if(wantedLook&&wantedLook!==appliedLook&&wantedLook!==loadingLook&&wantedLook!==failedLook&&!pendingHero&&current){
   const key=wantedLook;loadingLook=key;
   appearanceLoader({THREE,loader,cloneSkeleton,look,id,signal:abort.signal}).then(record=>{
    if(disposed||key!==wantedLook){record.dispose();return}pendingHero={key,record};
   }).catch(error=>{if(!disposed){failedLook=key;doc.body.dataset.walkHudAppearanceError=error.message;onActionError('appearance: '+error.message)}}).finally(()=>{if(loadingLook===key)loadingLook=null});
  }
  const hero=getHero();if(hero&&(host.dataset.collapsed!=='true'||statusDialog.isOpen())&&now-lastPortrait>=750){lastPortrait=now;const url=portraits.renderHero(hero.object,{key:appliedLook||'current-hero',rest:hero.artistContext?.().rest});if(url){hud.setPortrait(url);statusDialog.setPortrait?.(url);}if(portraits.error)doc.body.dataset.walkHudPortraitError=portraits.error}
 }
 function refreshRoster(now){
  const rowKey=(row,portraitKey)=>portraitKey+'|'+(row.renderId||'')+'|'+walkAppearanceKey(row.look||{});
  // Update intent even while a GLB is loading: its result may belong to an old snapshot.
  rosterWanted.clear();if(state.available)walkHudRosterRows(state,(row,portraitKey)=>rosterWanted.set(portraitKey,rowKey(row,portraitKey)));
  if(host.dataset.collapsed==='true'||rosterBusy||now-lastRosterAt<100||!state.available)return;
  walkHudRosterRows(state,(row,portraitKey,portraitNpc,portraitBoss)=>{
   if(!row.id)return;const key=rowKey(row,portraitKey);
   if(rosterCache.has(key)){setRosterPhoto(portraitKey,rosterCache.get(key));return}
   if(rosterFailed.has(key))return;
   const actual=getNpcActor(row.renderId||row.id);
   if(actual?.object){const url=portraits.renderNpc(actual.object,{key,rest:actual.walker?.artistContext?.().rest});if(url){rosterCache.set(key,url);setRosterPhoto(portraitKey,url)}else rosterFailed.add(key);lastRosterAt=now;return false}
   if(!row.look)return;
   rosterBusy=true;lastRosterAt=now;
   const appearance=portraitNpc?npcAppearanceFromWorld({id:row.renderId||row.id,look:row.look,role:row.renderRole||'civilian',empireBoss:portraitBoss}):undefined;
   appearanceLoader({THREE,loader,cloneSkeleton,look:row.look,id:row.renderId||row.id,appearance,targetHeight:appearance?.height,signal:abort.signal}).then(record=>{
    try{if(disposed||host.dataset.collapsed==='true'||rosterWanted.get(portraitKey)!==key)return;const url=portraits.renderNpc(record.hero.object,{key,rest:record.hero.artistContext().rest});if(url){rosterCache.set(key,url);setRosterPhoto(portraitKey,url)}else rosterFailed.add(key)}finally{record.dispose()}
   }).catch(()=>rosterFailed.add(key)).finally(()=>{rosterBusy=false;while(rosterCache.size>48)rosterCache.delete(rosterCache.keys().next().value)});return false;
  });
 }
 function setRosterPhoto(id,url){if(rosterSent.get(id)===url)return;rosterSent.set(id,url);hud.setRosterPortrait(id,url);while(rosterSent.size>48)rosterSent.delete(rosterSent.keys().next().value)}
 function update(now=performance.now()){
  if(disposed)return;if(!Number.isFinite(now)){lastUpdate=-Infinity;now=performance.now()}
  if(now-lastUpdate<200)return;lastUpdate=now;
  try{const incoming=getBridge()?.getWalkHudState?.()||{};state=isNormalizedWalkHudState(incoming)?incoming:normalizeWalkHudState(incoming)}catch{state=normalizeWalkHudState()}
  lock(state.ui.blocked||statusDialog.isOpen()||shell.isGangOpen()||getWalkHudOpenPanels(doc).length>0);
  hud.setState(walkHudViewStateFromNormalized(state));statusDialog.setState(state);connection.hidden=state.available;shell.refresh();refreshHero(now);refreshRoster(now);
  doc.body.dataset.walkPlayerHud=JSON.stringify({available:state.available,playerId:state.player.id,blocked,appearanceReady:!!appliedLook,portraitRenders:portraits.renders,rosterPortraits:rosterCache.size});
 }
 update();
 if(win?.dispatchEvent&&win?.CustomEvent)win.dispatchEvent(new win.CustomEvent("mafiozi:walkportraitsready"));
 return {update,closeDialogs(){statusDialog.close();shell.closeGang();lastUpdate=-Infinity;update(performance.now());},isBlocked:()=>blocked,host,getState:()=>state,dispose(){if(disposed)return;disposed=true;abort.abort();pendingHero?.record.dispose();pendingHero=null;statusDialog.dispose();hud.dispose();shell.dispose();empirePortraits.dispose();portraits.dispose();weaponPhotos.dispose();rosterCache.clear();rosterSent.clear();rosterFailed.clear();host.remove();delete doc.body.dataset.walkHudBlocked;delete doc.body.dataset.walkPlayerHud;if(win?.MafioziWalkHud===facade){if(previous)win.MafioziWalkHud=previous;else delete win.MafioziWalkHud}}};
}
