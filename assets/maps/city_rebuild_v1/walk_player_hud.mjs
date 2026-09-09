// Presentation only. Source world remains the owner of money, health and membership.
export const WALK_PLAYER_HUD_CSS = `
.mfz-player-hud{position:absolute;top:16px;left:18px;z-index:42;width:min(294px,calc(100vw - 36px));color:#e9e4d8;font:12px/1.25 system-ui,sans-serif;pointer-events:auto;filter:drop-shadow(0 10px 20px #0008)}
.mfz-player-hud *{box-sizing:border-box}.mfz-player-hud [hidden]{display:none!important}.mfz-player-hud button{font:inherit;color:inherit;cursor:pointer}.mfz-player-hud button:disabled{cursor:default;opacity:.58}.mfz-player-hud button:focus-visible{outline:2px solid #f0cf83;outline-offset:2px}.mfz-player-hud button:hover:not(:disabled){border-color:#d5b678;filter:brightness(1.13)}
.mfz-dossier{border:1px solid #8d7953;border-radius:9px;overflow:hidden;background:linear-gradient(120deg,#303336f7,#15191cf7 75%);box-shadow:inset 0 1px #ede4cd20,inset 0 -3px #080b0d}
.mfz-dossier-header{display:flex;justify-content:space-between;align-items:center;padding:9px 11px 7px;border-bottom:1px solid #b3945f30;background:linear-gradient(90deg,#413a2e88,#151b1e88)}.mfz-dossier-brand{font-size:9px;font-weight:800;letter-spacing:.16em;color:#ccb98e}.mfz-dossier-toggle{width:24px;height:21px;border:1px solid #807359;border-radius:4px;background:#282d30;font-size:16px!important;line-height:15px!important}
.mfz-dossier-body{padding:8px;max-height:calc(100dvh - 172px);overflow:auto;scrollbar-width:thin;scrollbar-color:#8d7953 #181e20}.mfz-dossier-nav{display:grid;grid-template-columns:1fr 1fr;gap:6px;margin-bottom:8px}.mfz-dossier-button{display:flex;align-items:center;justify-content:center;gap:7px;min-height:31px;padding:5px 8px;border:1px solid #777266;border-radius:5px;background:linear-gradient(#41464a,#242a2e);box-shadow:inset 0 1px #ffffff15,0 2px #0b1013;font-size:11px!important;font-weight:650!important}.mfz-dossier-button--gold{color:#302718!important;border-color:#b79b60;background:linear-gradient(#e3c790,#a98a50);text-shadow:0 1px #ffffff35}.mfz-dossier-icon{flex:none;width:22px;height:22px;filter:drop-shadow(0 2px 1px #0008)}
.mfz-dossier-identity{position:relative;display:grid;grid-template-columns:72px minmax(0,1fr);gap:10px;padding:9px;border:1px solid #86525a;border-left:3px solid #aa4754;border-radius:6px;background:linear-gradient(110deg,#542a32bb,#23282dcc 55%);box-shadow:inset 0 1px #ddaca618}.mfz-dossier-portrait{display:grid;place-items:center;overflow:hidden;width:72px;height:88px;padding:0;border:1px solid #baa06c;border-radius:6px;background:radial-gradient(ellipse at 50% 38%,#6d675844,#111719 72%);box-shadow:inset 0 0 0 3px #181c21,inset 0 0 15px #0009}.mfz-dossier-portrait img{width:100%;height:100%;object-fit:contain;filter:drop-shadow(0 5px 3px #0008)}.mfz-dossier-portrait .mfz-dossier-icon{width:41px;height:55px;opacity:.45}.mfz-dossier-name{display:block;overflow:hidden;text-overflow:ellipsis;white-space:nowrap;font:700 17px/1.2 Georgia,serif;letter-spacing:.025em;margin:1px 0 5px}.mfz-dossier-rank{font-size:10px;color:#c8b792}.mfz-dossier-health-heading{display:flex;justify-content:space-between;gap:5px;margin-top:8px;font-size:9px;letter-spacing:.055em;color:#c6c9c6}.mfz-dossier-health-heading b{font:700 10px ui-monospace,monospace;color:#e9e4d8}.mfz-dossier-health{height:10px;border:1px solid #938276;border-radius:8px;padding:2px;margin-top:4px;background:#110e12;box-shadow:0 1px #ffffff12}.mfz-dossier-health-fill{height:100%;width:0;border-radius:6px;background:linear-gradient(#eb8280,#aa303e);box-shadow:0 0 5px #c9353b55;transition:width .15s linear}.mfz-dossier-health[data-unknown=true]{opacity:.45}.mfz-dossier-wallet{display:flex;align-items:center;gap:5px;font:700 12px ui-monospace,monospace;color:#e4c681;margin-top:7px}.mfz-dossier-wallet .mfz-dossier-icon{width:17px;height:17px}.mfz-dossier-time{margin-left:auto;font-size:11px;white-space:nowrap;color:#d2c7ad}
.mfz-dossier-tools{display:grid;grid-template-columns:1fr 1fr 1fr;gap:5px;margin:8px 0}.mfz-dossier-tools .mfz-dossier-button{padding:5px 3px;min-height:39px;flex-direction:column;gap:2px;font-size:9px!important}.mfz-dossier-tools .mfz-dossier-icon{width:21px;height:20px}.mfz-dossier-panel{overflow:hidden;border:1px solid #6b675a;border-radius:6px;margin-top:7px;background:linear-gradient(115deg,#30363a,#181f23);box-shadow:inset 0 1px #ffffff0a}.mfz-dossier-panel--empires{border-color:#a88e54;background:linear-gradient(120deg,#52473388,#202629)}.mfz-dossier-panel--gang{border-color:#586f64}.mfz-dossier-panel--status{border-color:#568273}.mfz-dossier-section-button{display:flex;align-items:center;gap:9px;width:100%;padding:8px;border:0;background:transparent;text-align:left}.mfz-dossier-section-button .mfz-dossier-icon{width:29px;height:29px}.mfz-dossier-section-copy{flex:1;min-width:0}.mfz-dossier-eyebrow{display:block;font-size:8px;letter-spacing:.13em;color:#c8b887;font-weight:750}.mfz-dossier-section-title{display:block;margin-top:2px;font-size:12px;font-weight:750;overflow:hidden;text-overflow:ellipsis;white-space:nowrap}.mfz-dossier-count{flex:none;min-width:25px;padding:4px;border:1px solid #b48a71;border-radius:5px;background:linear-gradient(#783b43,#46252c);text-align:center;font:700 10px ui-monospace,monospace}.mfz-dossier-count--gang{max-width:110px;border-color:#557666;background:#1a342b;font:650 9px system-ui;color:#a7d8b9}.mfz-dossier-strip{display:flex;gap:5px;overflow-x:auto;padding:0 8px 7px;scrollbar-width:thin;scrollbar-color:#8d7953 #181e20}.mfz-dossier-person{flex:0 0 52px;min-width:0;padding:0;border:1px solid #696557;border-radius:4px;background:linear-gradient(135deg,#414243,#20262a);overflow:hidden;text-align:center}.mfz-dossier-person-portrait{height:47px;display:grid;place-items:center;background:radial-gradient(ellipse,#797a642f,transparent 75%)}.mfz-dossier-person-portrait img{width:100%;height:100%;object-fit:contain}.mfz-dossier-person-portrait .mfz-dossier-icon{width:28px;height:35px;opacity:.5}.mfz-dossier-person-name{display:block;padding:3px 2px;max-width:50px;overflow:hidden;text-overflow:ellipsis;white-space:nowrap;border-top:1px solid #b19c6c30;font-size:8px;color:#d9d1bc}.mfz-dossier-empty,.mfz-dossier-detail{margin:0;padding:0 9px 8px;font-size:10px;line-height:1.4;color:#b6c0bc}.mfz-dossier-source{margin:8px 2px 1px;font-size:9px;line-height:1.4;color:#c4b28e}.mfz-player-hud[data-available=false] .mfz-dossier-identity{border-color:#777063}.mfz-dossier-mode-label{max-width:80px;overflow:hidden;white-space:nowrap;text-overflow:ellipsis}
@media(max-width:760px){.mfz-player-hud{top:8px;left:8px;width:260px}.mfz-dossier-body{max-height:calc(100dvh - 241px)}.mfz-dossier-identity{grid-template-columns:62px minmax(0,1fr);gap:8px}.mfz-dossier-portrait{width:62px;height:84px}.mfz-dossier-name{font-size:15px}}
@media(prefers-reduced-motion:reduce){.mfz-dossier-health-fill{transition:none}}
.mfz-dossier-wallet{flex-wrap:wrap}.mfz-dossier-money{min-width:0;max-width:calc(100% - 22px);overflow-wrap:anywhere;white-space:normal;font-size:11px}.mfz-dossier-member-role{padding:0 9px 7px;font-size:10px;color:#b4ceb9;overflow-wrap:anywhere}.mfz-dossier-count{max-width:110px;overflow-wrap:anywhere}.mfz-dossier-section-title{white-space:normal;overflow-wrap:anywhere}
`;

const ICONS = {
 menu: ['M5 5h22v22H5z', 'M9 10h14M9 16h14M9 22h10'],
 newspaper: ['M7 4h21v24H7zM4 10h3v18H4z', 'M11 8h13v6H11zM11 18h5M19 18h5M11 22h5M19 22h5'],
 inventory: ['M5 11h22v16H5zM11 6h10v5H11z', 'M5 17h22M14 15h4v5h-4zM8 23h3M21 23h3'],
 missions: ['M8 5h18v24H6V7h2M11 3h10v5H11z', 'm10 14 2 2 4-4M19 14h4m-13 8 2 2 4-4M19 22h4'],
 mode: ['M7 5 16 2l9 3v10c0 7-9 14-9 14S7 22 7 15z', 'm11 10 10 10m0-10L11 20M16 6v2'],
 coin: ['M16 3C8 3 5 8 5 16s3 13 11 13 11-5 11-13S24 3 16 3z', 'M16 7v18M21 10h-8l-2 3 2 3h6l2 3-2 3h-8'],
 crown: ['m3 10 7 5 6-10 6 10 7-5-4 16H7z', 'M8 23h16M10 18h2m3 0h2m3 0h2M7 28h18'],
 gang: ['M12 4a5 5 0 1 0 0 10 5 5 0 0 0 0-10M3 28V19l5-3h8l5 3v9z', 'M23 7a4 4 0 0 1 0 8M23 18l5 3v7M9 18l3 7 3-7'],
 status: ['M8 3h16v13l-8 5-8-5zM12 20l-3 9 7-3 7 3-3-9', 'm16 6 2 3 4 1-3 3v4l-3-2-3 2v-4l-3-3 4-1z'],
 portrait: ['M16 3a7 7 0 0 0-7 7v4a7 7 0 0 0 14 0v-4a7 7 0 0 0-7-7M4 30v-6l7-5h10l7 5v6z', 'm11 20 5 8 5-8M11 10h3m4 0h3M13 16h6'],
};
const text = value => value === undefined || value === null || value === '' ? '—' : String(value);
const finite = value => value !== undefined && value !== null && value !== '' && Number.isFinite(Number(value)) ? Number(value) : null;
// The HUD and open status dialog read the same source balance repeatedly.  ICU
// formatter construction is comparatively expensive and its options never vary.
const moneyFormatter = new Intl.NumberFormat('ru-RU',{maximumFractionDigits:20});
export function playerHudMoney(value){
 let amount=null;
 if(typeof value==='bigint')amount=value;
 else if(typeof value==='string'&&/^-?\d+$/.test(value.trim()))amount=BigInt(value.trim());
 else if(typeof value==='number'||typeof value==='string'&&value.trim()!=='')amount=finite(value);
 return amount===null?'—':moneyFormatter.format(amount)+' $';
}
export function playerHudRole(role,isLeader=false){const labels={leader:'Лидер',boss:'Босс',member:'Участник',officer:'Офицер',deputy:'Заместитель',recruit:'Новобранец',civilian:'Гражданский',police:'Полиция',mafia:'Мафия',gang_fighter:'Боец банды',player:'Игрок',npc:'Боец NPC'};return isLeader?'Лидер':Object.hasOwn(labels,role)?labels[role]:String(role||'')}
export function playerHudMemberKey(item,kind='member'){return kind+':'+(kind==='member'&&['player','npc'].includes(item.kind)?item.kind+':':'')+String(item.id)}
export function playerHudHealth(hp, maxHp) {
 const current = finite(hp), maximum = finite(maxHp);
 return {label: `${text(current)} / ${text(maximum)}`, known: current !== null && maximum !== null && maximum > 0,
  percent: current !== null && maximum > 0 ? Math.min(100, Math.max(0, current / maximum * 100)) : 0};
}
export function safeHudPortraitUrl(value) {
 if (typeof value !== 'string' || /[\u0000-\u001f]/.test(value)) return null;
 return /^(?:data:image\/(?:png|webp|jpeg);base64,|blob:|\/(?!\/)|\.\.?\/|https?:\/\/)/i.test(value) ? value : null;
}
export function createWalkPlayerHud({document: doc = globalThis.document, host, onAction = () => {}} = {}) {
 if (!doc?.createElement || !host) throw new Error('Player HUD requires document and host');
 let disposed = false, snapshot = {available: false}, collapsed = false, portraitUrl = null;
 const rosterUrls = new Map(), cards = new Map(), buttons = [];
 const el = (tag, cls, value) => {const node = doc.createElement(tag); if (cls) node.className = cls; if (value !== undefined) node.textContent = value; return node;};
 const icon = name => {const svg = doc.createElementNS('http://www.w3.org/2000/svg', 'svg');svg.setAttribute('viewBox','0 0 32 32');svg.setAttribute('class','mfz-dossier-icon');svg.setAttribute('aria-hidden','true');svg.setAttribute('focusable','false');for (const [i,d] of (ICONS[name] || ICONS.portrait).entries()) {const path = doc.createElementNS('http://www.w3.org/2000/svg','path');path.setAttribute('d',d);path.setAttribute('fill',i ? 'none' : '#a98b53');path.setAttribute('stroke',i ? '#ebd5a5' : '#e0c18a');path.setAttribute('stroke-width',i ? '1.3' : '.8');path.setAttribute('stroke-linejoin','round');svg.append(path);}return svg;};
 const permitted = action => snapshot.available === true && snapshot.actions?.[action] === true;
 const button = (action,label,cls='mfz-dossier-button',payload) => {const node=el('button',cls);node.type='button';node.dataset.action=action;node.setAttribute('aria-label',label);node.addEventListener('click',()=>{if(!disposed&&permitted(action))onAction(action,payload);});buttons.push({node,action});return node;};
 const style=el('style');style.textContent=WALK_PLAYER_HUD_CSS;doc.head.append(style);
 host.classList.add('mfz-player-hud');host.dataset.walkUi='player-hud';host.setAttribute('aria-label','Личное дело игрока');
 const shell=el('section','mfz-dossier'),header=el('div','mfz-dossier-header'),brand=el('span','mfz-dossier-brand','MAFIOZI / ЛИЧНОЕ ДЕЛО'),toggle=el('button','mfz-dossier-toggle','−'),body=el('div','mfz-dossier-body');
 toggle.type='button';toggle.setAttribute('aria-label','Свернуть личное дело');toggle.setAttribute('aria-expanded','true');toggle.addEventListener('click',()=>{if(disposed)return;collapsed=!collapsed;body.hidden=collapsed;toggle.textContent=collapsed?'+':'−';toggle.setAttribute('aria-expanded',String(!collapsed));toggle.setAttribute('aria-label',collapsed?'Развернуть личное дело':'Свернуть личное дело');});header.append(brand,toggle);shell.append(header,body);host.replaceChildren(shell);
 const nav=el('nav','mfz-dossier-nav');nav.setAttribute('aria-label','Игровое меню');for(const [action,label] of [['menu','Меню'],['newspaper','Газета']]){const node=button(action,label,'mfz-dossier-button'+(action==='newspaper'?' mfz-dossier-button--gold':''));node.append(icon(action),el('span','',label));nav.append(node);}body.append(nav);
 const identity=el('div','mfz-dossier-identity'),portrait=button('profile','Открыть профиль игрока','mfz-dossier-portrait'),info=el('div'),name=el('b','mfz-dossier-name'),rank=el('span','mfz-dossier-rank'),healthHeading=el('div','mfz-dossier-health-heading'),hpLabel=el('b'),bar=el('div','mfz-dossier-health'),fill=el('div','mfz-dossier-health-fill'),wallet=el('div','mfz-dossier-wallet'),money=el('span','mfz-dossier-money'),clock=el('span','mfz-dossier-time');
 portrait.append(icon('portrait'));healthHeading.append(el('span','','ЗДОРОВЬЕ'),hpLabel);bar.setAttribute('role','progressbar');bar.setAttribute('aria-label','Здоровье');bar.append(fill);wallet.append(icon('coin'),money,clock);info.append(name,rank,healthHeading,bar,wallet);identity.append(portrait,info);body.append(identity);
 const tools=el('div','mfz-dossier-tools');let modeLabel;for(const [action,label] of [['inventory','Инвентарь'],['missions','Миссии'],['mode','PvP']]){const node=button(action,label),labelNode=el('span',action==='mode'?'mfz-dossier-mode-label':'',label);node.append(icon(action),labelNode);tools.append(node);if(action==='mode')modeLabel=labelNode;}body.append(tools);
 const panel = (action,title,eyebrow,iconName) => {const section=el('section',`mfz-dossier-panel mfz-dossier-panel--${action}`),trigger=button(action,title,'mfz-dossier-section-button'),copy=el('span','mfz-dossier-section-copy'),heading=el('span','mfz-dossier-section-title',title),badge=el('span','mfz-dossier-count'+(action==='gang'?' mfz-dossier-count--gang':''));copy.append(el('span','mfz-dossier-eyebrow',eyebrow),heading);trigger.append(icon(iconName),copy,badge);section.append(trigger);body.append(section);return {section,trigger,heading,badge};};
 const empires=panel('empires','Империи города','КАРТА КРИМИНАЛЬНОЙ ВЛАСТИ','crown'),bossStrip=el('div','mfz-dossier-strip');bossStrip.setAttribute('aria-label','Боссы города');empires.section.append(bossStrip);
 const gang=panel('gang','Моя банда','ЛЮДИ И ВЛИЯНИЕ','gang'),memberStrip=el('div','mfz-dossier-strip'),gangRole=el('div','mfz-dossier-member-role'),gangEmpty=el('p','mfz-dossier-empty');memberStrip.setAttribute('aria-label','Моя банда — бойцы');gang.section.append(gangRole,memberStrip,gangEmpty);
 const status=panel('status','—','СТАТУС','status'),detail=el('p','mfz-dossier-detail'),source=el('p','mfz-dossier-source');status.section.append(detail);body.append(source);
 const showPortrait=(container,url,label)=>{const safe=safeHudPortraitUrl(url);container.replaceChildren();if(safe){const image=el('img');image.src=safe;image.alt=label||'';image.decoding='async';image.addEventListener('error',()=>{if(!disposed&&image.parentNode===container)container.replaceChildren(icon('portrait'));},{once:true});container.append(image);}else container.append(icon('portrait'));};
 const updateCards=(container,list,kind)=>{
  const items=Array.isArray(list)?list:[],seen=new Set();let position=0;
  for(const item of items){
   if(item?.id===undefined||item?.id===null)continue;const key=playerHudMemberKey(item,kind);if(seen.has(key))continue;seen.add(key);
   let card=cards.get(key);
   if(!card){const node=button(kind==='boss'?'boss':'gang',text(item.name),'mfz-dossier-person',{id:item.id}),image=el('span','mfz-dossier-person-portrait'),label=el('span','mfz-dossier-person-name');node.dataset.memberKey=key;node.append(image,label);card={node,image,label,url:null,id:String(item.id),kind};cards.set(key,card)}
   const memberName=text(item.name),self=item.isSelf===true,online=item.online===undefined||item.online===null?'unknown':String(item.online===true),role=playerHudRole(item.role,item.isLeader),memberKind=item.kind==='npc'?'Боец NPC':item.kind==='player'?'Игрок':null,hp=finite(item.hp),maxHp=finite(item.maxHp),canKick=item.canKick===true&&!self;
   if(card.memberName!==memberName){card.memberName=memberName;card.label.textContent=memberName}
   if(card.self!==self){card.self=self;card.node.dataset.self=String(self)}
   if(card.online!==online){card.online=online;card.node.dataset.online=online}
   // A 5 Hz source refresh commonly repeats the same roster. Avoid title/ARIA
   // DOM writes for unchanged cards, while keeping every confirmed role, HP,
   // online and permission change immediately visible on the next refresh.
   if(card.titleName!==memberName||card.titleSelf!==self||card.titleRole!==role||card.titleKind!==memberKind||card.titleOnline!==online||card.titleHp!==hp||card.titleMaxHp!==maxHp||card.titleCanKick!==canKick){
    card.titleName=memberName;card.titleSelf=self;card.titleRole=role;card.titleKind=memberKind;card.titleOnline=online;card.titleHp=hp;card.titleMaxHp=maxHp;card.titleCanKick=canKick;
    card.node.title=[memberName,self?'Вы':null,role,memberKind,online==='false'?'Не в сети':online==='true'?'В сети':null,hp!==null?'Здоровье '+playerHudHealth(hp,maxHp).label:null,canKick?'Можно исключить из банды':null].filter(Boolean).join(' · ');
    card.node.setAttribute('aria-label',card.node.title);
   }
   const url=safeHudPortraitUrl(rosterUrls.get(key)||rosterUrls.get(kind+':'+String(item.id))||rosterUrls.get(String(item.id))||item.portrait);
   if(card.url!==url||!card.image.children.length){showPortrait(card.image,url,text(item.name));card.url=url}
   if(container.children[position]!==card.node)container.insertBefore(card.node,container.children[position]||null);position++;
  }
  // Keep the bounded ready-portrait cache through transient unavailable/empty snapshots.
  // The controller does not resend an unchanged image when the card reappears.
  for(const [key,card] of cards)if(card.kind===kind&&!seen.has(key)){card.node.remove();cards.delete(key);const index=buttons.findIndex(entry=>entry.node===card.node);if(index>=0)buttons.splice(index,1)}
  container.hidden=!seen.size;return seen.size;
 };
 const setState=next=>{
  if(disposed)return;snapshot=next?.available===true?next:{available:false};
  const player=snapshot.player||{},group=snapshot.gang||{},currentStatus=snapshot.status||{},health=playerHudHealth(player.hp,player.maxHp);
  host.dataset.available=String(snapshot.available===true);name.textContent=text(player.name);rank.textContent='УРОВЕНЬ '+text(player.level);portrait.setAttribute('aria-label','Открыть профиль: '+text(player.name));
  hpLabel.textContent=health.label;fill.style.width=health.percent+'%';bar.dataset.unknown=String(!health.known);bar.setAttribute('aria-valuetext',health.known?health.label:'Нет данных');
  if(health.known){bar.setAttribute('aria-valuemin','0');bar.setAttribute('aria-valuemax',String(player.maxHp));bar.setAttribute('aria-valuenow',String(Math.max(0,Math.min(Number(player.maxHp),Number(player.hp)))))}else{bar.removeAttribute('aria-valuemin');bar.removeAttribute('aria-valuemax');bar.removeAttribute('aria-valuenow')}
  money.textContent=playerHudMoney(player.money);money.title=money.textContent==='—'?'Деньги (доллары): нет данных':'Деньги (доллары): '+money.textContent;money.setAttribute('aria-label',money.title);money.setAttribute('aria-live','polite');money.setAttribute('aria-atomic','true');
  clock.textContent=text(player.timeLabel);clock.title='Игровое время';modeLabel.textContent=text(player.mode);
  empires.badge.textContent=text(snapshot.empires?.count);empires.trigger.setAttribute('aria-label','Империи города: '+text(snapshot.empires?.count));
  const role=playerHudRole(group.role,group.isLeader),gangName=group.name||'Моя банда';gang.heading.textContent=gangName;gang.badge.textContent=text(group.countLabel);gang.badge.title=[gangName,role].filter(Boolean).join(' · ');
  gangRole.textContent=[role,group.canManage===true?'Управление бандой':null].filter(Boolean).join(' · ');gangRole.hidden=!gangRole.textContent;
  gang.section.dataset.kind=String(group.kind||'none');gang.section.dataset.leader=String(group.isLeader===true);gang.trigger.setAttribute('aria-label',[gangName,role,group.countLabel].filter(Boolean).join(' · '));memberStrip.setAttribute('aria-label','Состав банды: '+gangName);
  const members=updateCards(memberStrip,group.members,'member');gangEmpty.hidden=members>0;gangEmpty.textContent=snapshot.available===true?(group.name?'Бойцов пока нет':'Не состоите в банде'):'Состав банды: нет данных';updateCards(bossStrip,snapshot.empires?.bosses,'boss');
  status.heading.textContent=text(currentStatus.label||currentStatus.title);status.badge.textContent=currentStatus.badge==null?'':String(currentStatus.badge);status.badge.hidden=status.badge.textContent==='';status.badge.title=status.badge.textContent;
  const statusRole=playerHudRole(currentStatus.role);detail.textContent=[statusRole&&statusRole!==status.heading.textContent?statusRole:null,currentStatus.detail||'Роли, вступление и бонусы'].filter(Boolean).join(' · ');status.section.dataset.kind=String(currentStatus.kind||'unknown');status.trigger.setAttribute('aria-label',['Статус: '+status.heading.textContent,statusRole,status.badge.textContent].filter(Boolean).join(' · '));
  source.hidden=snapshot.available===true;source.textContent='Данные игрока доступны после подключения к основному миру.';
  for(const entry of buttons){entry.node.disabled=!permitted(entry.action);entry.node.title=entry.node.disabled?'Недоступно: требуется подключение игровой системы':entry.node.getAttribute('aria-label')||''}
 };
 const setPortrait=url=>{if(disposed)return;const next=safeHudPortraitUrl(url);if(next===portraitUrl&&portrait.children.length)return;portraitUrl=next;showPortrait(portrait,next,'Ваш персонаж — текущий внешний вид');};
 const setRosterPortrait=(id,url)=>{if(disposed)return;const key=String(id),safe=safeHudPortraitUrl(url);if(safe)rosterUrls.set(key,safe);else rosterUrls.delete(key);for(const [cardKey,card] of cards){const matches=cardKey===key||key===card.kind+':'+card.id||!key.includes(':')&&card.id===key;if(matches&&card.url!==safe){card.url=safe;showPortrait(card.image,safe,card.label.textContent)}}while(rosterUrls.size>144)rosterUrls.delete(rosterUrls.keys().next().value)};
 setState({available:false});return {host,setState,setPortrait,setRosterPortrait,dispose(){if(disposed)return;disposed=true;cards.clear();rosterUrls.clear();buttons.length=0;host.replaceChildren();host.classList.remove('mfz-player-hud');delete host.dataset.walkUi;delete host.dataset.available;host.removeAttribute('aria-label');style.remove();}};
}
