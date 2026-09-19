import {NPC_ARCHETYPE_CATALOGUE} from './npc_role_catalogue.mjs';
const police=row=>!!row.source?.police||/police|cop/.test(row.role||'');
const civilianArchetypes=new Set(NPC_ARCHETYPE_CATALOGUE.filter(row=>row.key!=='bandit').flatMap(row=>[row.key,row.role]));
export function isInspectionCivilian(row){
 const src=row?.source||{},role=row?.role||src.role||'',arc=src._arcKey||src.arcKey||'';
 if(!row||police(row)||src.empireBoss||src._empireBoss||src._uniqueNpc||src._specialistId||src.gang||src._gang||src._empireCrew||src._empireGuard||/gang|boss|bandit|thug|guard|unique_npc|said|cop|police/.test(role)||['bandit','thug'].includes(arc))return false;
 return civilianArchetypes.has(role)||civilianArchetypes.has(arc)||/(?:^|_)resident_/.test(row.id||'')||['civilian','resident','parking_civilian','pedestrian',''].includes(role);
}
const civilian=isInspectionCivilian;
export function createNpcRuntimeInspection({document:doc=globalThis.document,parent=doc?.body,getActors=()=>[],focusActor=()=>{},getFocus=()=>null,search=doc?.defaultView?.location?.search||''}={}){
 if(new URLSearchParams(search).get('npcqa')!=='1')return {enabled:false,panel:null,update(){},getSelection:()=>null,isFollowing:()=>false,dispose(){}};
 const panel=doc.createElement('aside'),toggle=doc.createElement('button'),body=doc.createElement('div'),select=doc.createElement('select'),status=doc.createElement('div'),nextCivilian=doc.createElement('button'),nextPolice=doc.createElement('button'),follow=doc.createElement('button');
 panel.id='npc-runtime-inspection';panel.style.cssText='position:absolute;right:12px;top:220px;z-index:30;width:min(310px,calc(100vw - 24px));padding:10px;background:#14272ff2;color:#ecf3f4;border:1px solid #76939e;border-radius:8px;font:12px/1.5 system-ui;pointer-events:auto';
 toggle.textContent='Наблюдение NPC · свернуть';toggle.type='button';toggle.setAttribute('aria-expanded','true');
 select.setAttribute('aria-label','Реальный персонаж мира');select.style.cssText='display:block;width:100%;margin:7px 0';status.style.cssText='white-space:pre-wrap;overflow-wrap:anywhere;margin-top:7px';status.setAttribute('aria-live','polite');
 nextCivilian.textContent='Следующий гражданский';nextPolice.textContent='Следующий полицейский';follow.textContent='Следовать камерой: выкл.';
 for(const button of [nextCivilian,nextPolice,follow]){button.type='button';button.style.cssText='margin:3px 3px 3px 0;font:inherit';}
 body.append(select,nextCivilian,nextPolice,follow,status);panel.append(toggle,body);parent.append(panel);
 let rows=[],selected=null,following=false,disposed=false,lastRefresh=-Infinity,signature='',samples=new Map();
 const selection=()=>rows.find(row=>row.id===selected)||null;
 function focus(){const row=Array.from(getActors()||[]).find(row=>row.id===selected);if(row)focusActor(row);}
 function choose(id){selected=rows.some(row=>row.id===id)?id:null;select.value=selected||'';following=!!selected;follow.textContent='Следовать камерой: '+(following?'вкл.':'выкл.');follow.setAttribute('aria-pressed',String(following));focus();lastRefresh=-Infinity;}
 function next(predicate){const candidates=rows.filter(predicate);if(!candidates.length)return;const index=candidates.findIndex(row=>row.id===selected);choose(candidates[(index+1)%candidates.length].id);}
 select.addEventListener('change',()=>choose(select.value));nextCivilian.addEventListener('click',()=>next(civilian));nextPolice.addEventListener('click',()=>next(police));
 toggle.addEventListener('click',()=>{body.hidden=!body.hidden;toggle.textContent='Наблюдение NPC · '+(body.hidden?'развернуть':'свернуть');toggle.setAttribute('aria-expanded',String(!body.hidden))});
 follow.addEventListener('click',()=>{following=!following;follow.textContent='Следовать камерой: '+(following?'вкл.':'выкл.');follow.setAttribute('aria-pressed',String(following));if(following)focus()});
 // Keep UI mouse/keyboard events from becoming gameplay input; never alter NPCs.
 for(const event of ['pointerdown','mousedown','mouseup','keydown','keyup','wheel'])panel.addEventListener(event,e=>e.stopPropagation());
 function update(time=0){
  if(disposed)return;if(following)focus();if(time-lastRefresh<.25)return;lastRefresh=time;
  const origin=getFocus(),seen=new Set();rows=Array.from(getActors()||[]).filter(row=>row&&typeof row.id==='string'&&row.id&&!seen.has(row.id)&&(seen.add(row.id),true));
  if(Number.isFinite(origin?.x)&&Number.isFinite(origin?.z))rows.sort((a,b)=>{const distance=row=>{const p=row.object?.position;return p?Math.hypot(p.x-origin.x,p.z-origin.z):Infinity};return distance(a)-distance(b)});
  rows=rows.slice(0,50);
  const nextSamples=new Map();for(const row of rows){const p=row.object?.position,old=samples.get(row.id),dt=time-(old?.time??time);if(p)nextSamples.set(row.id,{x:p.x,z:p.z,time,speed:dt>0?Math.hypot(p.x-old.x,p.z-old.z)/dt:null})}samples=nextSamples;
  if(!rows.some(row=>row.id===selected))selected=null;
  const key=JSON.stringify(rows.map(row=>[row.id,row.name,row.role]));if(key!==signature){signature=key;select.replaceChildren();const empty=doc.createElement('option');empty.value='';empty.textContent='Выбрать NPC ('+rows.length+')';select.append(empty);for(const row of rows){const option=doc.createElement('option');option.value=row.id;option.textContent=(row.name||row.id)+' · '+(row.role||'civilian');select.append(option)}}select.value=selected||'';
  nextCivilian.disabled=!rows.some(civilian);nextPolice.disabled=!rows.some(police);
  const row=selection(),src=row?.source,sample=row&&samples.get(row.id),behavior=src?.routinePlan?.phase||src?.parkingState||src?.lifeState||src?.state||(src?.walking?'идёт':'ожидает');
  const detail=src?.inspectionActivity,agendaNames={walk:'прогулка',shop:'посещение здания',bench:'отдых на лавочке',drive:'поездка'};
  status.textContent=row?`ID: ${row.id}\nРоль: ${row.role||'civilian'}\nСкорость: ${Number.isFinite(sample?.speed)?sample.speed.toFixed(2)+' м/с':'—'}\nПоведение: ${behavior}`+(detail?`\nЗанятие: ${agendaNames[detail.agenda]||detail.agenda||'—'}\nМаршрут: ${detail.pending?'ожидает '+(detail.waitMs/1000).toFixed(1)+' с':detail.routeRemaining?'готов, точек '+detail.routeRemaining:'нет'}${src.civilianTripPhase?'\nПоездка: '+src.civilianTripPhase:''}`:''):'Выберите существующего NPC. Кнопки меняют только камеру.';
 }
 update();return {enabled:true,panel,update,getSelection:selection,isFollowing:()=>following,dispose(){if(disposed)return;disposed=true;rows=[];samples.clear();panel.remove()}};
}
