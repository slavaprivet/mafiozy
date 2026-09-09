import {safeHudPortraitUrl} from './walk_player_hud.mjs';

const S = "html[data-walk-player-hud='true']";
// Audited against static markup and the two dynamic world dialog factories.
export const WALK_HUD_SOURCE_MODAL_SURFACES=Object.freeze({gameMainMenu:'.gmm-shell',profileModal:'.card',missionsModal:'.missions-card',newspaperModal:'#newspaperPaper',npcEmpireOverlay:'.ne-card',customGangModal:'.cg-card',policeModal:'.police-card',jobModal:'.job-card',modeModal:'.box'});
export const WALK_HUD_SHELL_CSS = `
/* Source #stage is fixed and therefore traps fixed native dialogs below body
   HUD siblings. In this non-scrolling, full-viewport gateway an absolute stage
   has identical inset bounds but no stacking context when z-index is auto. */
${S} #stage{position:absolute;z-index:auto}
${S} #leftCommandHud{display:none!important}
@media(pointer:fine){${S} :is(#joyL,#joyR,#weaponBar,#fireBtn){display:none!important}}
${S} :is(#profileModal,#newspaperModal,#missionsModal,#npcEmpireOverlay,#customGangModal,#jobModal,#policeModal,#modeModal){z-index:13100;background:#080e14cb;backdrop-filter:blur(7px)}
${S} :is(#profileModal .card,#missionsModal .missions-card,#npcEmpireOverlay .ne-card,#customGangModal .cg-card,#jobModal .job-card,#policeModal .police-card,#modeModal .box){color:#e9e4d8;border:1px solid #a28b5d;border-radius:9px;background:linear-gradient(125deg,#34383cfb,#141b20fc 72%);box-shadow:inset 0 1px #ffffff24,0 24px 70px #000c;max-height:calc(100dvh - 32px);overflow:auto;scrollbar-width:thin;scrollbar-color:#98805a #1b2429}
${S} #gameMainMenu{--menu-gold:#d4b577;--menu-red:#99404e;z-index:12800;padding:clamp(18px,3vw,42px);background-image:radial-gradient(ellipse at 74% 35%,#68454d44,transparent 45%),linear-gradient(90deg,#151d25fa 0%,#172129e8 45%,#0c151ba8 78%,#071017da),url('/assets/loading/city-empire.webp?v=3d117');backdrop-filter:blur(7px) saturate(.75);scrollbar-width:thin;scrollbar-color:#a58e62 #19242c}
${S} #gameMainMenu .gmm-shell{width:min(1080px,100%);gap:clamp(24px,4vw,64px);color:#e9e4d8}
${S} #gameMainMenu :is(.gmm-save,.gmm-profile-plate,.gmm-profile-card,.gmm-confirm-card){border-color:#9e8961;background:linear-gradient(130deg,#343e46f2,#18242bf2);border-radius:7px;box-shadow:inset 0 1px #fff2,0 15px 35px #0007}
${S} #gameMainMenu :is(.gmm-btn,.gmm-back,.gmm-toggle){border-color:#968460;border-radius:5px;background:linear-gradient(110deg,#3e4a51ee,#243039f5);color:#eadebf;box-shadow:inset 0 1px #fff2,0 7px 18px #0005}
${S} #gameMainMenu .gmm-btn.primary{border-color:#b69462;background:linear-gradient(110deg,#763b49,#432e38 72%,#29333b);color:#f5e5c4}
${S} #gameMainMenu .gmm-toggle.on{border-color:#d1b16f;background:linear-gradient(#c7a969,#92743c);color:#201d16}
${S} #gameMainMenu :is(.gmm-btn small,.gmm-save-meta,.gmm-hint,.gmm-profile-state,.gmm-profile-card-meta){color:#bdc8cb;font-size:12px;line-height:1.45}
${S} #gameMainMenu :is(.gmm-kicker,.gmm-profile-label,.gmm-profile-slot){color:#c6b694;letter-spacing:.13em}
${S} #gameMainMenu .gmm-setting input[type=range]{accent-color:#c7a969;min-height:28px}
${S} #gameMainMenu .gmm-setting label{font-size:14px;color:#e9e2d4}
${S} #gameMainMenu .gmm-profile-delete{border-color:#b56872;background:#612e39;color:#f6c5c5}
${S} :is(#gameMainMenu,#profileModal,#missionsModal,#newspaperPaper,#npcEmpireOverlay,#customGangModal,#policeModal,#jobModal,#modeModal) :is(button,input,select,[role=button],.tab):focus-visible{outline:2px solid #edd096;outline-offset:3px}
${S} :is(#gameMainMenu,#profileModal,#missionsModal,#npcEmpireOverlay,#customGangModal,#policeModal,#jobModal,#modeModal) button:disabled{opacity:.48;cursor:default;filter:none}
${S} :is(.profile-dossier-head,.missions-head,.ne-head,.job-head,.police-head){background:linear-gradient(110deg,#51353cf5,#262e33f5);border-bottom:1px solid #a38b5d66;color:#e7d2a6}
${S} :is(#policeModal .police-head,#jobModal .job-head){padding:10px 11px;border-radius:5px;font-size:18px}
${S} :is(#missionsModal .missions-close,#policeModal .police-close,#jobModal .job-close,#npcEmpireOverlay .ne-x,#profileModal .close){border:1px solid #9f8a64;border-radius:5px;background:linear-gradient(#465058,#28353d);color:#ecddbc;min-width:31px;min-height:31px;cursor:pointer}
${S} :is(#missionsModal .mission-item,#npcEmpireOverlay .ne-section,#npcEmpireOverlay .ne-stat,#npcEmpireOverlay .ns-district,#policeModal .police-row,#policeModal .police-stat,#jobModal .job-row){border-color:#6f7674;border-radius:6px;background:linear-gradient(125deg,#34414a,#202d35);box-shadow:inset 0 1px #ffffff10}
${S} #missionsModal .mission-item.active{border-color:#bc9b61;box-shadow:inset 3px 0 #a44858}
${S} #missionsModal .mission-item p{font-size:13px;line-height:1.5;color:#c2cbd0}
${S} #missionsModal .mission-item .mission-route{color:#a0d7b1}
${S} :is(#missionsModal .mission-item button,#npcEmpireOverlay .ne-btn,#policeModal .police-action,#jobModal .job-action,#customGangModal .cg-actions button){min-height:36px;border:1px solid #9d8c69;border-radius:5px;padding:8px 11px;background:linear-gradient(#45545d,#2b3a43);color:#e8dfc9;font-size:12px;line-height:1.35;cursor:pointer}
${S} :is(#npcEmpireOverlay .ne-btn.war,#npcEmpireOverlay .ne-btn.assault,#jobModal .job-action.danger,#customGangModal .cg-actions .cg-danger){border-color:#b26570;background:linear-gradient(#713641,#482731);color:#f5d2d4}
${S} :is(#npcEmpireOverlay .ne-btn.good,#jobModal .job-action.pay){border-color:#68947b;background:linear-gradient(#355b48,#253c32);color:#d5eddd}
${S} #customGangModal .cg-actions .cg-ok{border-color:#c8aa6f;background:linear-gradient(#d4b779,#a18249);color:#272118}
${S} #customGangModal .cg-card input{border:1px solid #8a805f;border-radius:5px;background:#17242c;color:#eee5cf;font-size:16px;line-height:1.4}
${S} #customGangModal :is(.cg-card p,.cg-member){font-size:13px;line-height:1.5;color:#c4ced1}
${S} #customGangModal :is(.cg-label,.cg-k){color:#d9c499;letter-spacing:.075em}
${S} #customGangModal .cg-actions{flex-wrap:wrap}
${S} #customGangModal .cg-actions button{flex:1 1 150px}
${S} #npcEmpireOverlay :is(.ne-head p,.ne-btn small,.ne-stat small,.ne-event,.ne-holding,.ns-district,.ns-rank small){font-size:12px;line-height:1.45;color:#c0c9ce}
${S} #npcEmpireOverlay :is(.ne-section h3,.ne-stat b){color:#e5d0a2}
${S} #npcEmpireOverlay .ne-head h2{color:#efdfbd}
${S} :is(#policeModal .police-note,#policeModal .police-sub,#policeModal .police-rank-xp,#policeModal .police-progress-label,#policeModal .police-section-title span,#policeModal .police-cap small,#policeModal .police-empty,#jobModal .job-note,#jobModal .job-pay){font-size:12px;line-height:1.45;color:#bfcbd0}
${S} #policeModal .police-cap b{font-size:12px}
${S} #policeModal .police-summary{background:linear-gradient(115deg,#304957,#24333d);border-color:#78929b}
${S} #policeModal .police-level-badge{border-color:#a99266;border-radius:7px;background:linear-gradient(#4b6570,#2b414c)}
${S} #modeModal .box{width:min(480px,calc(100vw - 32px));padding:22px}
${S} #modeModal .ttl{font:700 22px/1.25 Georgia,serif;color:#ead6a9}
${S} #modeModal :is(.sub,.opt .row2){font-size:13px;line-height:1.5;color:#c1cbd0}
${S} #modeModal .opt{border-radius:6px;padding:14px;box-shadow:inset 0 1px #fff1}
${S} #modeModal .opt.pvp{border-color:#b86a78;background:linear-gradient(#59323f,#30242f)}
${S} #modeModal .opt.pve{border-color:#789780;background:linear-gradient(#334d41,#202f2c)}
${S} #profileModal :is(.tabs,.inventory-category-nav){background:#1b2329;border-color:#6e6b5b}
${S} #profileModal :is(.tab,.inventory-category-nav button){color:#c8c6bc;border:1px solid #6b6a5f;background:linear-gradient(#3a4349,#232c32);border-radius:5px}
${S} #profileModal :is(.tab.active,.inventory-btn){border-color:#c4a166;background:linear-gradient(#d6b77c,#9a783f);color:#231e16}
${S} #profileModal :is(.inventory-card,.inventory-summary-card,.inventory-armor-command,.stat-card,.item,.profile-said-card,.profile-career-panel,.profile-influence-panel){border-color:#676e70;background:linear-gradient(135deg,#343e46,#1c252c);border-radius:6px;box-shadow:inset 0 1px #ffffff10,0 3px 8px #0005}
${S} #profileModal .inventory-card.equipped{border-color:#c4a166;box-shadow:inset 0 2px #c4a166,0 3px 8px #0005}
${S} #profileModal .inventory-visual{background:radial-gradient(ellipse at 50% 45%,#6e7a8455,#141c2266 75%);border-bottom:1px solid #9ba19f26;position:relative}
${S} #profileModal :is(.inventory-card-name,.profile-section-title,.profile-dossier-title){color:#ead9b3}
${S} #profileModal :is(.inventory-card-meta,.inventory-kicker,.inventory-price,.inventory-armor-note){color:#b8c0c1}
${S} #profileModal .inventory-btn.secondary{color:#e0d7c1;background:linear-gradient(#414a4f,#252e34)}
${S} #profileModal :is(button,.tab):focus-visible,${S} .mfz-walk-gang-drawer button:focus-visible{outline:2px solid #e4c687;outline-offset:2px}
${S} #profileModal canvas[data-walk-thumbnail-ready=true]{display:none!important}
${S} #profileModal .mfz-walk-inventory-photo{display:block;width:100%;height:104px;object-fit:contain;filter:drop-shadow(0 7px 5px #0009);pointer-events:none}
${S} #profileModal .mfz-walk-fist-preview{font-size:0!important}
${S} #profileModal .mfz-walk-fist-preview .inventory-state{font-size:10px}
${S} #newspaperPaper{border:1px solid #bc9a5b;box-shadow:0 24px 70px #000d,inset 0 0 0 5px #8e6f3733;border-radius:5px;background:linear-gradient(120deg,#e7dab8,#cabb94);color:#302b22;max-height:calc(100dvh - 32px);overflow:auto;scrollbar-width:thin;scrollbar-color:#896b3e #d2c29c}
${S} #newspaperPaper .news-summary{font-size:14px;line-height:1.5;color:#302a21}
${S} #newspaperPaper .news-time{font-size:10px;color:#695336}
${S} #newspaperPaper .news-close{border:1px solid #987544;border-radius:5px;background:linear-gradient(#604a36,#382e26);color:#f1e1b6;min-width:32px;min-height:32px}
${S} .mfz-walk-gang-drawer{position:fixed;inset:0;z-index:13000;display:flex;align-items:center;justify-content:flex-start;padding:24px;background:#060c14aa;backdrop-filter:blur(6px);color:#e9e4d8;font:13px system-ui;pointer-events:auto}
${S} .mfz-walk-gang-card{width:min(460px,calc(100vw - 32px));max-height:calc(100dvh - 40px);overflow:auto;border:1px solid #a28b5d;border-radius:9px;background:linear-gradient(135deg,#343b40,#172027);box-shadow:inset 0 1px #ffffff20,0 20px 65px #000b}
${S} .mfz-walk-gang-head{display:flex;align-items:center;justify-content:space-between;gap:12px;padding:14px 16px;border-bottom:1px solid #a28b5d66;background:linear-gradient(110deg,#51363d,#283037);letter-spacing:.12em;font-size:11px;font-weight:750;color:#e6d1a8}
${S} .mfz-walk-gang-close{width:30px;height:30px;flex:none;border:1px solid #a3906c;border-radius:4px;background:linear-gradient(#4a5052,#262e32);color:#e9dfc9;font:20px system-ui;cursor:pointer}
${S} .mfz-walk-gang-content{padding:15px}
${S} .mfz-walk-gang-drawer #gangRosterHud{position:static!important;inset:auto!important;width:100%!important;max-width:none!important;padding:0;border:0;border-radius:0;background:transparent;box-shadow:none;font-size:13px}
${S} .mfz-walk-gang-drawer #gangRosterHud .gr-head{font-size:14px;gap:10px;padding-bottom:12px;color:#e7d3aa}
${S} .mfz-walk-gang-drawer #gangRosterHud .gr-count{font-size:11px;padding:4px 7px;border:1px solid #65836d;color:#b5e2c3}
${S} .mfz-walk-gang-drawer #gangRosterList{max-height:calc(100dvh - 200px);gap:8px;overflow:auto}
${S} .mfz-walk-gang-drawer #gangRosterList .gr-row{min-height:42px;padding:8px;border:1px solid #72736677;border-radius:5px;background:linear-gradient(#364148,#202b32);font-size:12px}
${S} .mfz-walk-gang-drawer #gangRosterList .gr-name{white-space:normal;flex:1}
${S} .mfz-walk-gang-drawer #gangRosterList .gr-dismiss{width:27px;height:27px;font-size:18px;flex:none}
${S} .mfz-walk-gang-drawer #gangRosterList .gr-confirm{font-size:12px;padding:10px;gap:8px}
${S} .mfz-walk-gang-drawer #gangRosterList :is(.gr-confirm button,.armor-equip){min-height:30px;padding:5px 10px;border:1px solid #988366;border-radius:4px;cursor:pointer}
@media(max-width:600px){${S} .mfz-walk-gang-drawer{padding:16px;justify-content:center}${S} #profileModal .mfz-walk-inventory-photo{height:86px}}
@media(max-width:780px){${S} #gameMainMenu{padding:24px 18px;align-items:flex-start}${S} #gameMainMenu .gmm-shell{display:block}${S} #gameMainMenu .gmm-setting{gap:8px}${S} #gameMainMenu .gmm-setting input[type=range]{max-width:35vw}}
@media(max-height:700px){${S} #gameMainMenu{align-items:flex-start}}
@media(prefers-reduced-motion:reduce){${S} #gameMainMenu,${S} #gameMainMenu :is(.gmm-btn,.gmm-back,.gmm-panel){animation:none;transition:none}}
`;

const ART_IDS = new Set(['none','nagan','tt_pistol','revolver','deagle','golden_colt','sawn_off','shotgun','uzi','golden_uzi','ak74','m16','tommy_gun','sniper','rpg']);
const SOURCE_ALIASES = Object.freeze({pistol:'tt_pistol',tt:'tt_pistol',pm:'tt_pistol',glock:'tt_pistol',pistol_heavy:'deagle',desert_eagle:'deagle',pistol_gold:'golden_colt',golden_pistol:'golden_colt',smg:'uzi',ump:'uzi',mp5:'uzi',rifle:'ak74',ak:'ak74',m4:'m16',bazooka:'rpg',golden_tommy:'tommy_gun',golden_ak:'ak74',fists:'none',unarmed:'none',melee:'none'});
export function walkInventoryArtId(sourceId) {const id=String(sourceId??'');return ART_IDS.has(id)?id:SOURCE_ALIASES[id]||null;}
// Read a tightly constrained source handler as metadata, never evaluate it.
export function profileWeaponActionId(handler) {const match=String(handler||'').match(/^\s*_selectProfileWeapon\(\s*(['"])([a-z0-9_-]*)\1\s*,\s*(?:true|false)\s*\)\s*;?\s*$/i);return match?match[2]||'none':null;}

export function createWalkHudShell({document:doc=globalThis.document,onClose=()=>{},getWeaponThumbnail,ensureGangExpanded}={}) {
 if(!doc?.createElement||!doc.documentElement||!doc.body)throw new Error('HUD shell requires document');
 const root=doc.documentElement,previousFlag=root.getAttribute('data-walk-player-hud');root.setAttribute('data-walk-player-hud','true');
 const style=doc.createElement('style');style.textContent=WALK_HUD_SHELL_CSS;doc.head.append(style);
 let disposed=false,drawer=null,roster=null,originalParent=null,originalNext=null,previousFocus=null,queued=false;
 const thumbnails=new Map(),attributes=new Map(),modalIds=['gameMainMenu','profileModal','missionsModal','newspaperPaper','npcEmpireOverlay','customGangModal','jobModal','policeModal','modeModal'];
 const restoreAttribute=(node,name,value)=>value===null?node.removeAttribute(name):node.setAttribute(name,value);
 const mark=(node,name,value)=>{let old=attributes.get(node);if(!old){old=new Map();attributes.set(node,old);}if(!old.has(name))old.set(name,node.getAttribute(name));if(node.getAttribute(name)!==value)node.setAttribute(name,value);};
 const connected=node=>node?.isConnected!==false;
 const Observer=doc.defaultView?.MutationObserver||globalThis.MutationObserver;
 const schedule=doc.defaultView?.queueMicrotask?.bind(doc.defaultView)||globalThis.queueMicrotask||((callback)=>Promise.resolve().then(callback));
 // Only inventory redraws and new top-level dialogs matter. Do not observe
 // continuously changing source HUD/chat/NPC trees on every game frame.
 const observe=()=>{if(disposed||!observer)return;observer.observe(doc.body,{childList:true});const profile=doc.getElementById('profileContent');if(profile)observer.observe(profile,{subtree:true,childList:true});};
 const observer=Observer?new Observer(()=>{if(disposed||queued)return;queued=true;schedule(()=>{queued=false;if(!disposed)refresh();});}):null;
 const restoreThumbnail=record=>{record.image?.remove();if(record.canvas)restoreAttribute(record.canvas,'data-walk-thumbnail-ready',record.previousMarker);if(record.fist&&!record.hadFistClass)record.visual.classList.remove('mfz-walk-fist-preview');};
 const enhance=(visual,canvas,id)=>{
  if(!getWeaponThumbnail||!id)return;const target=canvas||visual,existing=thumbnails.get(target);if(existing?.id===id)return;if(existing)restoreThumbnail(existing);
  const record={id,visual,canvas,fist:!canvas,previousMarker:canvas?.getAttribute('data-walk-thumbnail-ready')??null,hadFistClass:visual.classList.contains('mfz-walk-fist-preview'),image:null};thumbnails.set(target,record);
  const install=value=>{const url=safeHudPortraitUrl(value);if(disposed||!url||!connected(target)||thumbnails.get(target)!==record)return;const image=doc.createElement('img');image.className='mfz-walk-inventory-photo';image.src=url;image.alt='';image.setAttribute('aria-hidden','true');image.decoding='async';record.image=image;image.addEventListener('error',()=>{if(thumbnails.get(target)===record)restoreThumbnail(record);},{once:true});visual.append(image);if(canvas)canvas.setAttribute('data-walk-thumbnail-ready','true');else visual.classList.add('mfz-walk-fist-preview');};
  try {const result=getWeaponThumbnail(id);if(result?.then)result.then(install,()=>{});else install(result);}catch{} // Existing source canvas remains a usable fallback.
 };
 const refresh=()=>{
  if(disposed)return;observer?.disconnect();try{
   for(const [target,record]of thumbnails)if(!connected(target)){restoreThumbnail(record);thumbnails.delete(target);}
   for(const [node]of attributes)if(!connected(node))attributes.delete(node);
   for(const id of modalIds){const modal=doc.getElementById(id);if(modal){if(!modal.hasAttribute('role'))mark(modal,'role','dialog');if(!modal.hasAttribute('aria-modal'))mark(modal,'aria-modal','true');mark(modal,'data-walk-ui','source-dialog');}}
   const profile=doc.getElementById('profileContent');if(profile&&getWeaponThumbnail)for(const card of profile.querySelectorAll('.inventory-card')){
    const canvas=card.querySelector('canvas[data-inventory-weapon]'),action=card.querySelector('button[onclick]'),raw=profileWeaponActionId(action?.getAttribute('onclick'));
    const id=walkInventoryArtId(raw??canvas?.getAttribute('data-inventory-weapon')),visual=card.querySelector('.inventory-visual');
    if(visual&&(canvas||raw==='none'))enhance(visual,canvas,id);
   }
   if(drawer&&doc.getElementById('customGangModal')?.classList.contains('show'))closeGang(false);
  }finally{observe();}
 };
 const closeGang=(restoreFocus=true)=>{if(!drawer)return false;const closing=drawer;drawer=null;if(roster&&originalParent){originalParent.insertBefore(roster,originalNext?.parentNode===originalParent?originalNext:null);}roster=null;originalParent=null;originalNext=null;closing.remove();doc.removeEventListener('keydown',onKeydown,true);if(restoreFocus&&connected(previousFocus))previousFocus?.focus?.();previousFocus=null;onClose();return true;};
 const onKeydown=event=>{if(!drawer)return;if(event.key==='Escape'){event.preventDefault();event.stopPropagation();closeGang();return;}if(event.key!=='Tab')return;const items=[...drawer.querySelectorAll('button,input,select,textarea,[tabindex]')].filter(node=>!node.disabled&&!node.hidden&&node.getAttribute('tabindex')!=='-1');const first=items[0],last=items.at(-1);if(!first)return;if(event.shiftKey&&doc.activeElement===first){event.preventDefault();last.focus();}else if(!event.shiftKey&&doc.activeElement===last){event.preventDefault();first.focus();}};
 const openGang=()=>{
  if(disposed)return false;if(drawer)return true;roster=doc.getElementById('gangRosterHud');if(!roster?.parentNode){roster=null;return false;}
  originalParent=roster.parentNode;originalNext=roster.nextSibling;previousFocus=doc.activeElement;
  drawer=doc.createElement('section');drawer.className='mfz-walk-gang-drawer';drawer.dataset.walkUi='gang-dialog';drawer.setAttribute('role','dialog');drawer.setAttribute('aria-modal','true');drawer.setAttribute('aria-label','Моя банда — состав и управление');
  const card=doc.createElement('div'),header=doc.createElement('div'),title=doc.createElement('span'),close=doc.createElement('button'),content=doc.createElement('div');card.className='mfz-walk-gang-card';header.className='mfz-walk-gang-head';title.textContent='МОЯ БАНДА / ЛИЧНЫЙ СОСТАВ';close.className='mfz-walk-gang-close';close.type='button';close.textContent='×';close.setAttribute('aria-label','Закрыть состав банды');close.addEventListener('click',()=>closeGang());content.className='mfz-walk-gang-content';header.append(title,close);content.append(roster);card.append(header,content);drawer.append(card);drawer.addEventListener('click',event=>{if(event.target===drawer)closeGang();else schedule(()=>{if(!disposed&&drawer&&doc.getElementById('customGangModal')?.classList.contains('show'))closeGang(false);});});doc.body.append(drawer);
  if(ensureGangExpanded)ensureGangExpanded();else if(!roster.querySelector('.gr-dismiss')&&!roster.querySelector('.armor-equip'))roster.querySelector('.gr-head')?.click();
  doc.addEventListener('keydown',onKeydown,true);close.focus();return true;
 };
 refresh();return {openGang,closeGang,refresh,isGangOpen:()=>!!drawer,dispose(){if(disposed)return;observer?.disconnect();closeGang(false);disposed=true;for(const record of thumbnails.values())restoreThumbnail(record);thumbnails.clear();for(const[node,attrs]of attributes)for(const[name,value]of attrs)restoreAttribute(node,name,value);attributes.clear();restoreAttribute(root,'data-walk-player-hud',previousFlag);style.remove();}};
}
