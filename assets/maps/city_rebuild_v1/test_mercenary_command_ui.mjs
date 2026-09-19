import test from 'node:test';
import assert from 'node:assert/strict';
import {createMercenaryCommandUI,MERCENARY_PROFESSIONS} from './mercenary_command_ui.mjs';

// Tiny DOM exercises listeners and node identity without starting a graphics scene.
class Element {
 constructor(tag){this.tagName=tag.toUpperCase();this.children=[];this.dataset={};this.attrs={};this.listeners=new Map();this.textContent='';this.value='';this.hidden=false;this.disabled=false;this.writes=0;}
 append(...nodes){for(const n of nodes){n.parentNode=this;this.children.push(n);}this.writes++;}
 replaceChildren(...nodes){for(const n of this.children)n.parentNode=null;this.children=[];this.append(...nodes);}
 remove(){if(this.parentNode){this.parentNode.children=this.parentNode.children.filter(n=>n!==this);this.parentNode=null;}}
 setAttribute(k,v){this.attrs[k]=v;}
 addEventListener(k,f){if(!this.listeners.has(k))this.listeners.set(k,[]);this.listeners.get(k).push(f);}
 removeEventListener(k,f){this.listeners.set(k,(this.listeners.get(k)||[]).filter(v=>v!==f));}
 emit(k,e={}){for(const f of this.listeners.get(k)||[])f(e);}
 focus(){}
}
function setup(options={}){const doc=new Element('document');doc.createElement=t=>new Element(t);doc.body=new Element('body');const ui=createMercenaryCommandUI({document:doc,...options});return{doc,ui};}
function all(node){return[node,...node.children.flatMap(all)];}
function button(ui,label){return all(ui.element).find(n=>n.tagName==='BUTTON'&&n.textContent===label);}
function key(doc,key,options={}){const event={key,code:key==='v'?'KeyV':key,target:new Element('div'),prevented:false,preventDefault(){this.prevented=true;},stopPropagation(){},...options};doc.emit('keydown',event);return event;}
const flush=()=>new Promise(resolve=>setImmediate(resolve));

test('busy specialist can add an eligible job to queue and sees waiting jobs without disabling the action',async()=>{
 let waiting=[{kind:'cut_fence',targetId:'fence'}],calls=0;const roster=()=>({members:[{id:'engineer',name:'Елена',profession:'engineer',phase:'working',queued:waiting}],candidates:[]});
 const{ui}=setup({getRoster:roster,getTarget:()=>({id:'panel',label:'Щиток'}),getActions:()=>[{id:'disable_power',label:'Отключить питание',enabled:true,willQueue:true}],onCommand:()=>{calls++;return{ok:true,queued:true,message:'Добавлено задание №3'};}});
 try{ui.open();const order=button(ui,'В очередь · Отключить питание');assert(order);assert(!order.disabled);assert(all(ui.element).some(n=>n.textContent==='В очереди: 1 · 1. Сетка'));order.emit('click');await flush();assert.equal(calls,1);assert(all(ui.element).some(n=>n.textContent==='Добавлено задание №3'));waiting=[];ui.update(1000,true);assert(!all(ui.element).some(n=>n.textContent.startsWith('В очереди:')&&!n.hidden));}finally{ui.dispose();}
});

test('V orders follow without permanent HUD buttons; explicit management still opens',async()=>{
 assert.equal(Object.keys(MERCENARY_PROFESSIONS).length,5);let blocked=false,calls=0;const changes=[];const{doc,ui}=setup({isBlocked:()=>blocked,onFollow:()=>{calls++;return {ok:true};},onOpenChange:v=>changes.push(v)});
 for(const options of [{repeat:true},{target:new Element('input')},{ctrlKey:true},{defaultPrevented:true},{composedPath:()=>[new Element('input')]}])assert.equal(key(doc,'v',options).prevented,false);
 blocked=true;assert.equal(key(doc,'v').prevented,false);blocked=false;assert.equal(key(doc,'v').prevented,true);assert.equal(calls,1);assert.equal(ui.isOpen,false);await flush();
 assert.equal(button(ui,'Отряд и приказы'),undefined);ui.open();assert.equal(ui.isOpen,true);assert.equal(key(doc,'Escape').prevented,true);assert.equal(ui.isOpen,false);
 ui.open();key(doc,'v');assert.equal(ui.isOpen,false);assert.equal(calls,2);ui.dispose();assert.deepEqual(changes,[true,false,true,false]);assert.equal(doc.body.children.length,0);assert.equal(key(doc,'v').prevented,false);
});

test('command keeps captured target, rechecks eligibility and prevents pending duplicate',async()=>{
 let target={id:'car1',label:'Машина'},enabled=true,resolve;const commands=[];const{ui}=setup({getTarget:()=>target,getActions:()=>[{id:'bomb',label:'Подорвать',enabled}],onCommand:(id,t)=>{commands.push([id,t.id]);return new Promise(r=>resolve=r);}});ui.open();target={id:'car2'};
 const bomb=button(ui,'Подорвать');enabled=false;bomb.emit('click');assert.equal(commands.length,0);enabled=true;ui.update(100000,true);bomb.emit('click');bomb.emit('click');assert.deepEqual(commands,[['bomb','car1']]);assert.equal(bomb.disabled,true);resolve({ok:false,reason:'Цель удалена'});await flush();assert.equal(bomb.disabled,false);assert.ok(all(ui.element).some(n=>n.textContent==='Цель удалена'));ui.dispose();
});

test('recruit weapon selection, hospital availability, dismiss and stable throttled cards',async()=>{
 const calls=[];const candidate={id:'new',name:'Лука',profession:'medic',hireCost:100};const member={id:'old',name:'Карло',profession:'bruiser',hp:180,maxHp:200,phase:'hospital',hospitalRemainingSeconds:299};const roster={members:[member],candidates:[candidate],weapons:[{id:'pistol',label:'Пистолет',count:1}]};let reads=0;
 const{ui}=setup({getRoster:()=>{reads++;return roster;},onRecruit:(...args)=>calls.push(['hire',...args]),onUpgrade:()=>{},onEquip:(...args)=>calls.push(['equip',...args]),onDismiss:(...args)=>calls.push(['dismiss',...args])});
 ui.update(0);assert.equal(reads,1);ui.open();const cards=all(ui.element).filter(n=>n.tagName==='ARTICLE');const candidateCard=cards.find(n=>all(n).some(v=>v.textContent==='Лука'));const select=all(candidateCard).find(n=>n.tagName==='SELECT');select.value='pistol';button(ui,'Нанять · $100').emit('click');await flush();assert.deepEqual(calls[0],['hire','new','pistol']);assert.equal(button(ui,'Улучшить').disabled,true);assert.equal(button(ui,'Выдать оружие').disabled,true);assert.equal(button(ui,'Уволить').disabled,false);
 button(ui,'Уволить').emit('click');await flush();assert.deepEqual(calls[1],['dismiss','old']);ui.update(100000,true);const before=reads;ui.update(100050);assert.equal(reads,before);member.hp=150;ui.update(100101);assert.equal(reads,before+1);assert.equal(all(ui.element).find(n=>n===candidateCard),candidateCard);assert.equal(select.value,'pistol');ui.dispose();
});

test('HTML names are text, stale recruits do not dispatch and node removal follows roster',()=>{
 const roster={members:[],candidates:[{id:'one',name:'<img src=x onerror=evil()>',profession:'medic'}]};let called=0;const{ui}=setup({getRoster:()=>roster,onRecruit:()=>called++});ui.open();assert.ok(all(ui.element).some(n=>n.textContent===roster.candidates[0].name));assert.equal(all(ui.element).some(n=>n.tagName==='IMG'),false);const hire=button(ui,'Нанять');roster.candidates=[];hire.emit('click');assert.equal(called,0);ui.update(100000,true);assert.equal(all(ui.element).filter(n=>n.tagName==='ARTICLE').length,0);ui.dispose();
});

test('personal skill selection is passed to upgrade and preserved, hospital disables choice',async()=>{
 const member={id:'bruiser',name:'Карло',profession:'bruiser',canUpgrade:true,skills:[{id:'melee',label:'Рукопашный бой',level:0},{id:'fitness',label:'Выносливость',level:1}]};const calls=[];const{ui}=setup({getRoster:()=>({members:[member],candidates:[{id:'candidate',profession:'medic',distanceMeters:12.34}]}),onUpgrade:(...args)=>calls.push(args)});ui.open();const select=all(ui.element).find(n=>n.attrs['aria-label']==='Навык для улучшения');select.value='fitness';button(ui,'Улучшить').emit('click');await flush();assert.deepEqual(calls,[['bruiser','fitness']]);ui.update(100000,true);assert.equal(select.value,'fitness');member.status='hospital';ui.update(100101);assert.equal(select.disabled,true);assert.equal(button(ui,'Улучшить').disabled,true);assert.ok(all(ui.element).some(n=>n.textContent==='12.3 м · Подойдите и нажмите E'));ui.dispose();
});
test('openMember selects exact roster identity with equipment, skills and dismissal callbacks',async()=>{const calls=[],roster={members:[{id:'merc_resident_3',name:'Лука',profession:'medic',weaponLabel:'Пистолет',canUpgrade:true,skills:[{id:'medicine',label:'Медицина',level:1}]},{id:'merc_resident_4',name:'Карло',profession:'bruiser'}],candidates:[],weapons:[{id:'rifle',label:'Винтовка',count:1}]};const{ui}=setup({getRoster:()=>roster,onUpgrade:(...a)=>calls.push(['upgrade',...a]),onEquip:(...a)=>calls.push(['equip',...a]),onDismiss:id=>{calls.push(['dismiss',id]);roster.members=roster.members.filter(m=>m.id!==id);return{ok:true};}});assert.equal(ui.openMember('npc_crew_merc_resident_3'),false,'adapter must provide real roster ID');assert.equal(ui.openMember('merc_resident_3'),true);assert.equal(ui.selectedMemberId,'merc_resident_3');assert.equal(all(ui.element).filter(n=>n.tagName==='ARTICLE').length,1);assert.ok(all(ui.element).some(n=>n.textContent.includes('Пистолет')));button(ui,'Улучшить').emit('click');await flush();assert.deepEqual(calls[0],['upgrade','merc_resident_3','medicine']);const weapon=all(ui.element).find(n=>n.attrs['aria-label']==='Оружие из инвентаря');weapon.value='rifle';weapon.emit('change');button(ui,'Выдать оружие').emit('click');await flush();assert.deepEqual(calls[1],['equip','merc_resident_3','rifle']);button(ui,'Уволить').emit('click');await flush();assert.deepEqual(calls[2],['dismiss','merc_resident_3']);assert.equal(ui.selectedMemberId,null);ui.dispose();});
test('V dispatches follow once while pending and never directly cancels armed charges',async()=>{let resolve,calls=0,cancels=0;const{ui,doc}=setup({getActiveCommand:()=>({armed:true,memberId:'demo'}),onCancel:()=>cancels++,onFollow:()=>{calls++;return new Promise(r=>resolve=r);}});assert(key(doc,'v').prevented);key(doc,'v');assert.equal(calls,1);assert.equal(cancels,0);assert.equal(ui.isOpen,false);resolve({ok:true,message:'Отряд следует за вами.'});await flush();assert.ok(all(ui.element).some(n=>n.textContent==='Отряд следует за вами.'));ui.dispose();});

test('hospital notice and real countdown remain visible with menu closed and update at bounded rate',()=>{const m={id:'medic',name:'Лука',status:'active'},roster={members:[m],candidates:[]};let reads=0;const{ui}=setup({getRoster:()=>{reads++;return roster;}});ui.update(0);m.status='hospital';m.hospitalRemainingSeconds=300;ui.update(300);const notice=all(ui.element).find(n=>n.textContent==='Лука отправлен в больницу.');assert(notice);assert.equal(notice.parentNode.hidden,false);assert.equal(ui.isOpen,false);assert.ok(all(ui.element).some(n=>n.textContent==='Лука · 5:00 до возвращения'));const before=reads;ui.update(400);assert.equal(reads,before);m.hospitalRemainingSeconds=299;ui.update(600);assert.ok(all(ui.element).some(n=>n.textContent==='Лука · 4:59 до возвращения'));assert.equal(notice.textContent,'Лука отправлен в больницу.');m.status='returning';ui.update(900);assert.equal(notice.parentNode.hidden,true);ui.dispose();});
test('rally follow action stays inside explicit management and notices reuse HUD',async()=>{const member={id:'one',order:'follow'},roster={members:[member],candidates:[]};let calls=0;const{ui}=setup({getRoster:()=>roster,onFollow:async()=>{calls++;member.order='follow';return{ok:true,message:'Все идут за вами.'};}});ui.update(0);const follow=button(ui,'Следовать за мной');assert.equal(follow.hidden,true);member.order='rally';ui.update(300);assert.equal(follow.hidden,true);ui.open();assert.equal(follow.hidden,false);follow.emit('click');follow.emit('click');await flush();assert.equal(calls,1);assert.equal(follow.hidden,true);assert.ok(all(ui.element).some(n=>n.textContent==='Все идут за вами.'));ui.showNotice('Посмотри на свободную землю');const notice=all(ui.element).find(n=>n.textContent==='Посмотри на свободную землю');assert(notice);ui.showNotice('Метка поставлена');assert.equal(notice.textContent,'Метка поставлена');ui.dispose();});


test('command toast expires after 2.5 seconds, update does not refresh it, and a new command restarts duration',t=>{
 t.mock.timers.enable({apis:['setTimeout']});
 const{ui}=setup();ui.showNotice('Отряд следует за вами.');
 const notice=all(ui.element).find(n=>n.textContent==='Отряд следует за вами.');assert.equal(notice.hidden,false);
 t.mock.timers.tick(2000);ui.update(100000,true);assert.equal(notice.hidden,false);
 t.mock.timers.tick(500);assert.equal(notice.hidden,true);assert.equal(notice.textContent,'');
 ui.showNotice('Приказ принят.');t.mock.timers.tick(2000);ui.showNotice('Новый приказ.');
 t.mock.timers.tick(501);assert.equal(notice.hidden,false);assert.equal(notice.textContent,'Новый приказ.');
 t.mock.timers.tick(1999);assert.equal(notice.hidden,true);ui.dispose();
});
